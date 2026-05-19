-- WeaponClient.lua
-- Drives weapon visuals on the local player. Builds the viewmodel,
-- handles input + fire rate, fires the network event, and animates recoil.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local WeaponModels = require(script.Parent.WeaponModels)
local Effects = require(script.Parent.Effects)

local WeaponClient = {}

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

local currentWeaponId = "Pistol"
local currentModel
local minigunCluster
local heldWeld
local lastFire = 0
local isFiring = false
local clusterSpin = 0
local recoilOffset = 0 -- decays each frame

-- Arm-raise tracking. While a weapon is equipped we override ONLY
-- the right shoulder Motor6D every frame so the gun-hand arm points
-- straight forward (zombie pose), and we zero out its `Transform` so
-- the default Roblox Animate script's walk/idle cycle can't swing it.
-- The LEFT arm is left completely alone -- it keeps its normal idle
-- and walk animation. Original C0 is cached so we can restore the
-- natural rest pose when the weapon is put away.
local rightShoulder    -- Motor6D in Torso
local rightShoulderC0  -- CFrame snapshot of rest C0
local armRaised = false

local function getCharacterParts()
	local character = localPlayer.Character
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	return character, hum, rightHand, hrp
end

-- Grab the player's R6 Right Shoulder Motor6D (lives in Torso).
local function captureRightShoulder()
	local character = localPlayer.Character
	if not character then return nil end
	local torso = character:FindFirstChild("Torso")
	if not torso then return nil end
	local m = torso:FindFirstChild("Right Shoulder")
	if not m or not m:IsA("Motor6D") then return nil end
	return m
end

-- (Re)discover the right shoulder and cache its original rest C0. Called
-- both on first raise and lazily inside RenderStepped if the character
-- was rebuilt (e.g. the R6 force-rebuild on spawn destroys old motors).
local function refreshShoulder()
	if not rightShoulder or not rightShoulder.Parent then
		rightShoulder = captureRightShoulder()
		if rightShoulder then rightShoulderC0 = rightShoulder.C0 end
	end
end

local function raiseArm()
	-- IMPORTANT: if the arm is already raised, do NOT recapture C0.
	-- The current C0 is our previously-rotated pose, not the rest pose;
	-- recapturing it and rotating again accumulates every press of the
	-- weapon hotkey, ending up with the arm pointing random directions.
	if armRaised and rightShoulder and rightShoulder.Parent then
		return
	end
	refreshShoulder()
	armRaised = rightShoulder ~= nil
end

local function lowerArm()
	if rightShoulder and rightShoulder.Parent and rightShoulderC0 then
		rightShoulder.C0 = rightShoulderC0
		rightShoulder.Transform = CFrame.new()
	end
	armRaised = false
	rightShoulder = nil
	rightShoulderC0 = nil
end

local function detachCurrent()
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
		minigunCluster = nil
		heldWeld = nil
	end
end

local function attachToHand(model, cluster)
	local character, _, rightHand = getCharacterParts()
	if not character or not rightHand then return end

	model.Parent = character
	local primary = model.PrimaryPart
	if not primary then return end

	heldWeld = Instance.new("Motor6D")
	heldWeld.Part0 = rightHand
	heldWeld.Part1 = primary
	-- Position so the grip rests in the hand and the barrel points forward.
	heldWeld.C0 = CFrame.new(0, -1, -0.5) * CFrame.Angles(math.rad(-90), 0, 0)
	heldWeld.Parent = rightHand

	minigunCluster = cluster
end

local function equip(id)
	detachCurrent()
	local cfg = Config.Weapons[id]
	if not cfg then return end
	local model, cluster = WeaponModels.Build(id, cfg)
	if not model then return end
	currentModel = model
	currentWeaponId = id
	attachToHand(model, cluster)
	-- Raise the right arm forward (zombie-style) so the weapon visibly
	-- points where the player is aiming, instead of dangling at the hip.
	raiseArm()
end

-- True unequip: destroy the weapon model AND drop the raised arm. Triggered
-- by the 0 / X key. (Switching between weapons does NOT call this -- the
-- shoulder stays raised throughout because equip() always re-raises it.)
local function unequip()
	detachCurrent()
	lowerArm()
	currentWeaponId = nil
end

local function getFireOrigin()
	local _, _, _, hrp = getCharacterParts()
	-- Prefer the gun barrel as the visible origin so tracers come out of the
	-- weapon; fall back to chest height if the gun isn't ready yet. Direction
	-- is always toward where the mouse cursor is pointing in the world, not
	-- the camera lookvector (third-person camera looks down at the player).
	local origin
	local barrel = currentModel and (currentModel:FindFirstChild("Barrel") or currentModel:FindFirstChild("Barrel1"))
	if barrel then
		origin = barrel.Position
	elseif hrp then
		origin = hrp.Position + Vector3.new(0, 1.5, 0)
	else
		origin = camera.CFrame.Position
	end
	-- The server clamps origin within 12 studs of the player's HRP. If for
	-- some reason the barrel ended up farther (e.g. detached weapon), fall
	-- back to chest so the server doesn't reject the shot.
	if hrp and (origin - hrp.Position).Magnitude > 11 then
		origin = hrp.Position + Vector3.new(0, 1.5, 0)
	end

	local target = mouse.Hit.Position
	local diff = target - origin
	local dir
	if diff.Magnitude < 0.1 then
		dir = camera.CFrame.LookVector
	else
		dir = diff.Unit
	end
	return origin, dir
end

local function fire()
	if not currentModel then return end
	local cfg = Config.Weapons[currentWeaponId]
	local now = os.clock()
	if now - lastFire < cfg.FireRate then return end
	lastFire = now

	local origin, dir = getFireOrigin()
	Remotes.FireWeapon():FireServer(origin, dir)

	-- Local muzzle flash from the actual barrel position.
	local barrel = currentModel:FindFirstChild("Barrel") or currentModel:FindFirstChild("Barrel1")
	if barrel then
		Effects.MuzzleFlash(barrel.Position, dir)
	else
		Effects.MuzzleFlash(origin, dir)
	end

	-- Add some camera kick.
	recoilOffset = math.min(recoilOffset + cfg.RecoilDeg, 25)
end

-- Per-frame: recoil decay, weapon sway, minigun spin, camera kick.
--
-- Bound at Enum.RenderPriority.Last.Value + 1 so we run AFTER the camera AND
-- AFTER Roblox's Animator has finished writing animation deltas into every
-- Motor6D's `Transform` for this frame. With a plain `RenderStepped:Connect`
-- (default priority = Camera ~200) the Animator could in some frames win the
-- race and the gun-arm would visibly twitch with the walk / jump animation.
-- Running last guarantees our `Transform = identity` and our forward-arm C0
-- are the very last things written before the GPU draws this frame, so the
-- shoulder is rock-frozen no matter what other animations are playing.
local RENDER_BIND_NAME = "WeaponClient_PerFrame"
RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Last.Value + 1, function(dt)
	recoilOffset = math.max(0, recoilOffset - dt * 90)

	if currentModel and heldWeld then
		-- Sway based on camera angular delta.
		local rec = -math.rad(recoilOffset)
		heldWeld.C0 = CFrame.new(0, -1, -0.5) * CFrame.Angles(math.rad(-90) + rec * 0.5, rec * 0.05, 0)
	end

	-- Continuously override the RIGHT shoulder so the default Roblox
	-- Animate script's walk/idle keyframes can't drop the gun-arm. We
	-- run on RenderStepped so we get the last word before the frame is
	-- drawn. The LEFT arm is deliberately untouched -- it keeps its
	-- normal idle/walk swing.
	--   * C0  -> raised straight forward (90deg)
	--   * Transform -> identity (kills the shoulder swing baked into
	--     Animate's walk/run/idle animations)
	if armRaised then
		refreshShoulder()
		if rightShoulder and rightShoulderC0 then
			-- Rotate ONLY the orientation of the shoulder joint -- keep
			-- its position locked to the original anchor at the top-right
			-- corner of the torso. If we just left-multiply Angles(90,0,0)
			-- onto the whole C0, the X-rotation also drags the position
			-- component: the shoulder anchor swings from (1, 0.5, 0) to
			-- (1, 0, 0.5), i.e. into the BACK face of the torso. The arm
			-- then visibly starts behind the body and pokes out the back.
			-- Splitting C0 into its Position and Rotation parts and only
			-- rotating the Rotation part keeps the shoulder pinned where
			-- it should be while still swinging the arm forward.
			--   * Angles(90 + recoil, 0, 0) rotates the rest "hanging
			--     down" pose to "stretched forward". Recoil kicks the
			--     arm slightly further up past forward.
			local rec = math.rad(recoilOffset)
			rightShoulder.C0 = CFrame.new(rightShoulderC0.Position)
				* CFrame.Angles(math.rad(90) + rec * 0.3, 0, 0)
				* rightShoulderC0.Rotation
			rightShoulder.Transform = CFrame.new()
		end
	end

	if minigunCluster and isFiring then
		clusterSpin += dt * 30
		if minigunCluster.PrimaryPart then
			-- Spin the entire cluster around its forward axis.
			minigunCluster:PivotTo(minigunCluster:GetPivot() * CFrame.Angles(0, 0, dt * 30))
		end
	end

	-- Camera recoil
	local rec = math.rad(recoilOffset)
	if rec > 0 then
		camera.CFrame = camera.CFrame * CFrame.Angles(rec * 0.2 * dt * 10, 0, 0)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = true
	elseif input.KeyCode == Enum.KeyCode.One then
		WeaponClient.RequestSwitch("Pistol")
	elseif input.KeyCode == Enum.KeyCode.Two then
		WeaponClient.RequestSwitch("Shotgun")
	elseif input.KeyCode == Enum.KeyCode.Three then
		WeaponClient.RequestSwitch("Rifle")
	elseif input.KeyCode == Enum.KeyCode.Four then
		WeaponClient.RequestSwitch("Minigun")
	elseif input.KeyCode == Enum.KeyCode.Zero
		or input.KeyCode == Enum.KeyCode.X then
		-- Holster the weapon: destroy the held model and drop the arm.
		unequip()
		isFiring = false
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = false
	end
end)

-- Hold-to-fire loop for automatic weapons; one-tap also works because we
-- check fire rate inside fire().
task.spawn(function()
	while true do
		if isFiring then fire() end
		task.wait(0.02)
	end
end)

-- Remote-driven hit feedback (shared between all clients).
Remotes.HitFeedback().OnClientEvent:Connect(function(shooter, weaponId, origin, dir, hits)
	for _, hit in ipairs(hits) do
		Effects.Tracer(origin, hit.Position)
		if hit.Killed ~= nil then
			Effects.HitPuff(hit.Position, hit.Killed)
		end
	end
end)

function WeaponClient.RequestSwitch(id)
	local ownedWeapons = WeaponClient._ownedWeapons or {}
	if not ownedWeapons[id] then return end
	-- Pressing the same weapon's hotkey while it's already in your hand
	-- holsters it (Minecraft-style toggle). This is the user-facing way
	-- to "put the weapon away" without remembering the X/0 key.
	if currentWeaponId == id and currentModel then
		unequip()
		return
	end
	WeaponClient._userUnequipped = false
	equip(id)
	Remotes.SwitchWeapon():FireServer(id)
end

function WeaponClient.SetOwned(weapons, currentId)
	WeaponClient._ownedWeapons = weapons
	-- Respect an explicit "weapon holstered" choice. Otherwise every time
	-- the server pushes player state (kills, purchases, etc) we'd silently
	-- re-equip the gun and the player could never put it away.
	if WeaponClient._userUnequipped then return end
	if currentId and weapons[currentId] then
		equip(currentId)
	elseif weapons.Pistol then
		equip("Pistol")
	end
end

function WeaponClient.Reattach()
	if currentModel then
		attachToHand(currentModel, minigunCluster)
	end
end

localPlayer.CharacterAdded:Connect(function()
	-- Re-attach the current weapon to the new character. Reset the
	-- holster flag too so the player respawns with their last weapon
	-- in hand (instead of perma-unequipped from before they died).
	task.wait(0.5)
	WeaponClient._userUnequipped = false
	local id = currentWeaponId
	if not id or not Config.Weapons[id] then
		local owned = WeaponClient._ownedWeapons or {}
		id = owned.Pistol and "Pistol" or nil
	end
	if id then equip(id) end
end)

return WeaponClient
