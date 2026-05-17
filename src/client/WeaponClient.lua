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

local currentWeaponId = "Pistol"
local currentModel
local minigunCluster
local heldWeld
local lastFire = 0
local isFiring = false
local clusterSpin = 0
local recoilOffset = 0 -- decays each frame

local function getCharacterParts()
	local character = localPlayer.Character
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	return character, hum, rightHand, hrp
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
end

local function getFireOrigin()
	local _, _, _, hrp = getCharacterParts()
	if not hrp then return camera.CFrame.Position, camera.CFrame.LookVector end
	-- Origin from the player's body so the ray respects line-of-sight.
	return hrp.Position + Vector3.new(0, 1.5, 0), camera.CFrame.LookVector
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
RunService.RenderStepped:Connect(function(dt)
	recoilOffset = math.max(0, recoilOffset - dt * 90)

	if currentModel and heldWeld then
		-- Sway based on camera angular delta.
		local cfg = Config.Weapons[currentWeaponId]
		local rec = -math.rad(recoilOffset)
		heldWeld.C0 = CFrame.new(0, -1, -0.5) * CFrame.Angles(math.rad(-90) + rec * 0.5, rec * 0.05, 0)
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
	equip(id)
	Remotes.SwitchWeapon():FireServer(id)
end

function WeaponClient.SetOwned(weapons, currentId)
	WeaponClient._ownedWeapons = weapons
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
	-- Re-attach the current weapon to the new character.
	task.wait(0.5)
	if currentWeaponId and Config.Weapons[currentWeaponId] then
		equip(currentWeaponId)
	end
end)

return WeaponClient
