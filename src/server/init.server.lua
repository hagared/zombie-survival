-- init.server.lua
-- Server entry point. Wires together map generation, wave system, weapons,
-- shop, and the defense placement system.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- =========================================================================
-- Force-R6 every player character.
-- We can't change the place's Avatar Type at runtime (it's a place setting,
-- not a script-mutable property), so instead we intercept each character on
-- spawn and replace it with an R6 build of the same HumanoidDescription.
-- =========================================================================
local convertingPlayers = {}

local function ensureR6(player, character)
	if convertingPlayers[player] then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = character:WaitForChild("Humanoid", 5)
	end
	if not hum then return end
	if hum.RigType == Enum.HumanoidRigType.R6 then return end

	convertingPlayers[player] = true
	local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
	if not ok or not desc then
		convertingPlayers[player] = nil
		return
	end

	local pivot = character:GetPivot()
	local r6, err = nil, nil
	ok, err = pcall(function()
		r6 = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not r6 then
		warn("[ZombieSurvival] R6 conversion failed: " .. tostring(err))
		convertingPlayers[player] = nil
		return
	end

	r6.Name = player.Name
	-- Swap the character in. Setting player.Character before reparenting
	-- avoids a frame where the player has no character at all.
	player.Character = r6
	r6.Parent = Workspace
	r6:PivotTo(pivot)

	-- Tidy: destroy the old rig and clear the converting flag once the
	-- engine has had a tick to settle (camera/controls).
	character:Destroy()
	task.delay(0.1, function() convertingPlayers[player] = nil end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char) ensureR6(player, char) end)
	if player.Character then ensureR6(player, player.Character) end
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function(char) ensureR6(p, char) end)
	if p.Character then ensureR6(p, p.Character) end
end
-- Ensure all RemoteEvents exist before any client tries to use them.
for _, name in ipairs({ "FireWeapon", "PurchaseItem", "PlaceDefense", "UpdatePlayerState", "UpdateWaveState", "SwitchWeapon", "HitFeedback", "Announce" }) do
	Remotes[name]()
end

local MapGenerator = require(script.MapGenerator)
local ZombieAI = require(script.ZombieAI)
local WaveManager = require(script.WaveManager)
local WeaponServer = require(script.WeaponServer)
local ShopServer = require(script.ShopServer)
local DefenseManager = require(script.DefenseManager)
local PlayerData = require(script.PlayerData)

-- Build the world ONLY if no `Map` folder is already saved in Workspace.
-- This lets you bake the procedural map into the place via the Command Bar
-- (see scripts/build-map.lua) and then hand-edit it without the server
-- regenerating from scratch on every Play.
if not workspace:FindFirstChild("Map") then
	MapGenerator.Build()
else
	-- Map is already in the place file -- still need to seed the spawn-point
	-- caches so other systems (WaveManager, init.server.lua spawn pads) can
	-- ask for the player + zombie spawn lists.
	MapGenerator.IndexExisting(workspace.Map)
end

-- Place player spawns so respawning works in the plaza.
local function ensureSpawnLocations()
	local spawns = MapGenerator.GetPlayerSpawnPoints()
	local folder = workspace:FindFirstChild("PlayerSpawns")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "PlayerSpawns"
	folder.Parent = workspace

	for i, pos in ipairs(spawns) do
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn_" .. i
		s.Size = Vector3.new(6, 1, 6)
		s.Position = pos
		s.Anchored = true
		s.CanCollide = true
		s.Transparency = 1
		s.Material = Enum.Material.SmoothPlastic
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Neutral = true
		s.Parent = folder
	end
end
ensureSpawnLocations()

ZombieAI.Start()
DefenseManager.Init(function() return ZombieAI.GetAll() end)
WeaponServer.Setup()
ShopServer.Setup()

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Push initial state after a tick so the client is listening.
		task.defer(function()
			PlayerData.Push(player)
		end)
	end)
end)
-- Players who were already connected when this script started running
-- (common in Studio when you press Play with multiple players already in
-- the session): wire up the same CharacterAdded -> Push handler and
-- push the current state right now so their HUD/shop populate.
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function(character)
		task.defer(function()
			PlayerData.Push(p)
		end)
	end)
	if p.Character then
		task.defer(function() PlayerData.Push(p) end)
	end
end

WaveManager.Start()
