-- init.server.lua
-- Server entry point. Wires together map generation, wave system, weapons,
-- shop, and the defense placement system.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
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

-- Build the world.
MapGenerator.Build()

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

WaveManager.Start()
