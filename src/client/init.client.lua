-- init.client.lua
-- Client entry point. Builds the GUIs, equips the weapon, and runs the
-- "placement" mode that takes over when the player purchases a defense.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local HudGui = require(script.HudGui)
local ShopGui = require(script.ShopGui)
local WeaponClient = require(script.WeaponClient)

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local camera = Workspace.CurrentCamera

-- Listen for player state pushes so the weapon system knows what's owned.
Remotes.UpdatePlayerState().OnClientEvent:Connect(function(state)
	WeaponClient.SetOwned(state.Weapons, state.CurrentWeapon)
end)

-- ===== Defense placement mode =====
local placing = nil -- { id = "Turret", preview = Part, color = ... }

local function buildPreview(defenseId)
	local cfg = Config.Defenses[defenseId]
	local preview = Instance.new("Part")
	preview.Anchored = true
	preview.CanCollide = false
	preview.Material = Enum.Material.ForceField
	preview.Color = cfg.Color or Color3.fromRGB(255, 255, 255)
	preview.Transparency = 0.4
	if defenseId == "Turret" then
		preview.Size = Vector3.new(3, 4, 3)
	elseif defenseId == "BarbedWire" then
		preview.Size = Vector3.new(7, 1.6, 1.5)
	elseif defenseId == "Mine" then
		preview.Size = Vector3.new(1.6, 0.4, 1.6)
	end
	preview.Parent = Workspace
	return preview
end

local function endPlacement(cancel)
	if not placing then return end
	if placing.preview then placing.preview:Destroy() end
	placing = nil
end

Remotes.PlaceDefense().OnClientEvent:Connect(function(action, id)
	if action == "BeginPlacement" then
		endPlacement(true)
		placing = { id = id, preview = buildPreview(id) }
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not placing then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if placing.validPos then
			Remotes.PlaceDefense():FireServer("Confirm", placing.id, placing.validPos)
			endPlacement(false)
		end
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
		endPlacement(true)
	end
end)

RunService.RenderStepped:Connect(function()
	if not placing then return end
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {
		placing.preview,
		localPlayer.Character,
		Workspace:FindFirstChild("Zombies"),
	}
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, rp)
	if result then
		local pos = result.Position + Vector3.new(0, placing.preview.Size.Y / 2, 0)
		placing.preview.CFrame = CFrame.new(pos)
		-- Validate: not too close to player but within play area.
		local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local valid = true
		if hrp and (pos - hrp.Position).Magnitude > 30 then valid = false end
		if math.abs(pos.X) > 220 or math.abs(pos.Z) > 220 then valid = false end
		placing.preview.Color = valid and Color3.fromRGB(120, 220, 120) or Color3.fromRGB(220, 80, 80)
		placing.validPos = valid and pos or nil
	end
end)

-- Suppress unused-require warnings while keeping the requires that build the
-- GUIs and weapon system at startup.
local _ = HudGui
local _ = ShopGui

-- Print a quick controls note to the dev console (helpful for new players).
print("[ZombieSurvival] Controls:  WASD move • LMB shoot • 1-4 switch weapons • B open shop • Q cancel placement")
