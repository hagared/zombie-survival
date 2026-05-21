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

-- Arm-raise tracking. While a weapon is equipped we want the gun-arm to
-- point straight forward AND ignore every walk / run / jump / idle anim
-- the stock R6 `Animate` LocalScript tries to play on it. The robust way
-- to do that is to REPLACE the Right Shoulder Motor6D with a plain Weld:
--   * Weld rigidly fixes Part0 -> Part1 using its C0/C1 (arm stays attached)
--   * Roblox's Animator only writes to Motor6D, never to Weld, so the
--     animation system literally cannot drive this joint anymore
-- We keep a snapshot of the original Motor6D's C0/C1 so we can rebuild it
-- when the weapon is put away (or when the character is rebuilt on spawn).
local shoulderWeld           -- the Weld that's currently locking the arm
local shoulderRestC0         -- original Motor6D C0 (rest "hanging down" pose)
local shoulderRestC1         -- original Motor6D C1
local shoulderTorso          -- Torso the joint lives on
local shoulderArmPart        -- Right Arm part the joint connects to
local armRaised = false

local function getCharacterParts()
	local character = localPlayer.Character
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	return character, hum, rightHand, hrp
end

-- Apply the locked C0 to whatever joint type we currently own (Weld during
-- equip, Motor6D as a fallback if for some reason the swap didn't happen).
local function setLockedC0(angleRad)
	if not shoulderRestC0 then return end
	local target = CFrame.new(shoulderRestC0.Position)
		* CFrame.Angles(angleRad, 0, 0)
		* shoulderRestC0.Rotation
	if shoulderWeld and shoulderWeld.Parent then
		shoulderWeld.C0 = target
	end
end

-- Find the Right Shoulder joint (Motor6D OR our previously-installed Weld)
-- in the current character's Torso.
local function findExistingShoulderJoint()
	local character = localPlayer.Character
	if not character then return nil, nil end
	local torso = character:FindFirstChild("Torso")
	if not torso then return nil, nil end
	local j = torso:FindFirstChild("Right Shoulder")
	return j, torso
end

-- Replace the stock R6 Right Shoulder Motor6D with a Weld, rotated forward.
-- If we've already done it (e.g. weapon hotkey pressed twice) -- bail out
-- so we don't compound the rotation onto our own Weld's C0.
local function raiseArm()
	if armRaised and shoulderWeld and shoulderWeld.Parent then
		return
	end

	local joint, torso = findExistingShoulderJoint()
	if not joint or not torso then return end

	if joint:IsA("Weld") then
		-- Already locked (probably by us, after a respawn re-equip). Just
		-- adopt it and re-derive armRaised state.
		shoulderWeld = joint
		shoulderTorso = torso
		shoulderArmPart = joint.Part1
		armRaised = true
		return
	end
	if not joint:IsA("Motor6D") then return end

	-- Snapshot the original motor so we can rebuild it on lowerArm.
	shoulderRestC0 = joint.C0
	shoulderRestC1 = joint.C1
	shoulderTorso = joint.Part0
	shoulderArmPart = joint.Part1

	-- Build the replacement Weld at the rotated pose. Same name so any
	-- code looking up "Right Shoulder" (HUDs, third-party scripts, etc)
	-- still finds it -- it just happens to be a Weld now, not a Motor6D.
	local weld = Instance.new("Weld")
	weld.Name = "Right Shoulder"
	weld.Part0 = shoulderTorso
	weld.Part1 = shoulderArmPart
	weld.C0 = CFrame.new(shoulderRestC0.Position)
		* CFrame.Angles(math.rad(90), 0, 0)
		* shoulderRestC0.Rotation
	weld.C1 = shoulderRestC1
	weld.Parent = torso

	-- Now destroy the original Motor6D. Order matters: the Weld is parented
	-- first, so the arm is held by it before the Motor6D goes away. There's
	-- never an instant where the arm is unparented to anything.
	joint:Destroy()

	shoulderWeld = weld
	armRaised = true
end

local function lowerArm()
	-- Tear down our Weld and put the original Motor6D back so the Animate
	-- script can resume driving the arm normally.
	if shoulderWeld and shoulderWeld.Parent then
		shoulderWeld:Destroy()
	end
	if shoulderTorso and shoulderTorso.Parent and shoulderArmPart and shoulderArmPart.Parent then
		local motor = Instance.new("Motor6D")
		motor.Name = "Right Shoulder"
		motor.Part0 = shoulderTorso
		motor.Part1 = shoulderArmPart
		motor.C0 = shoulderRestC0 or CFrame.new()
		motor.C1 = shoulderRestC1 or CFrame.new()
		motor.Parent = shoulderTorso
	end
	shoulderWeld = nil
	shoulderRestC0 = nil
	shoulderRestC1 = nil
	shoulderTorso = nil
	shoulderArmPart = nil
	armRaised = false
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

	-- Continuously update the locked shoulder pose so recoil reads on the
	-- weapon arm (the arm kicks slightly upward past forward and decays
	-- back). The arm is held by a Weld we installed in raiseArm(), so the
	-- stock R6 `Animate` LocalScript's walk/idle/jump animations have no
	-- way to drive this joint -- Animator only writes to Motor6D, never
	-- to Weld. The LEFT arm and legs / torso are untouched, so the rest
	-- of the body still walks and idles normally.
	if armRaised then
		-- If the arm somehow got "unraised" by a respawn-mid-life, re-raise.
		if not shoulderWeld or not shoulderWeld.Parent then
			armRaised = false
			raiseArm()
		end
		if shoulderWeld and shoulderWeld.Parent and shoulderRestC0 then
			-- Rotate ONLY the orientation of the joint -- keep its position
			-- locked at the original anchor (top-right corner of the torso).
			-- See the long comment in the previous revision: rotating the
			-- whole CFrame would drag the position component into the back
			-- face of the torso, making the arm visibly poke out the back.
			local rec = math.rad(recoilOffset)
			setLockedC0(math.rad(90) + rec * 0.3)
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
	local lockedWeapons = WeaponClient._lockedWeapons or {}
	-- Reject any switch attempt to a weapon the player no longer owns OR
	-- to a weapon that has been replaced by a newer purchase. Belt-and-
	-- braces: ownedWeapons should already exclude locked guns, but we
	-- check both so a stale ownedWeapons table can't let a player switch
	-- to a replaced gun.
	if lockedWeapons[id] or not ownedWeapons[id] then return end
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

function WeaponClient.SetOwned(weapons, currentId, lockedWeapons)
	WeaponClient._ownedWeapons = weapons
	WeaponClient._lockedWeapons = lockedWeapons or {}
	-- If the player's currently-equipped weapon got locked out by the server
	-- (e.g. they bought a higher-tier weapon), fall through and equip the
	-- new current one. Otherwise respect a deliberate "weapon holstered"
	-- choice the player already made.
	local stillOwnsCurrent = currentWeaponId and weapons[currentWeaponId]
	if WeaponClient._userUnequipped and stillOwnsCurrent then return end
	if not stillOwnsCurrent then
		-- Force-detach the now-locked weapon model so it doesn't dangle
		-- in the player's hand when the new one auto-equips.
		detachCurrent()
		WeaponClient._userUnequipped = false
	end
	if currentId and weapons[currentId] then
		equip(currentId)
	else
		-- Fall back to ANY owned weapon. We can't hard-code "Pistol" as the
		-- fallback anymore: once the player buys a different gun, Pistol
		-- gets locked too, and the only owned weapon is the new one.
		for ownedId in pairs(weapons) do
			equip(ownedId)
			break
		end
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
	local owned = WeaponClient._ownedWeapons or {}
	if not id or not Config.Weapons[id] or not owned[id] then
		-- Pick the first weapon the player currently owns. We can't
		-- hard-code Pistol here -- once a higher-tier weapon is bought,
		-- Pistol moves to LockedWeapons and is no longer in `owned`.
		id = nil
		for ownedId in pairs(owned) do
			id = ownedId
			break
		end
	end
	if id then equip(id) end
end)

return WeaponClient
