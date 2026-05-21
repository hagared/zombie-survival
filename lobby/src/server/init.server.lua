-- init.server.lua (lobby)
-- Lobby entry point. Builds the ruined-city map + helipad + 6 helicopters,
-- spawns players on the helipad, wires up the helicopter ProximityPrompts
-- to the RoomManager, and teleports a room's members to the main game
-- when they trigger "Depart".

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local MapGenerator = require(script.MapGenerator)
local Helicopter = require(script.Helicopter)
local RoomManager = require(script.RoomManager)

-- Build the world.
MapGenerator.Build()

-- SpawnLocations on the helipad so players spawn there on join / respawn.
local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "PlayerSpawns"
spawnFolder.Parent = Workspace
for i, pos in ipairs(MapGenerator.GetSpawnPoints()) do
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
	s.Parent = spawnFolder
end

-- Build N helicopters in a circle around the helipad. Each one points its
-- nose outward, away from the centre, so the cockpit door opens toward the
-- helipad and the player walks in from the inside of the ring.
local heliFolder = Instance.new("Folder")
heliFolder.Name = "Helicopters"
heliFolder.Parent = Workspace

for i = 1, Config.RoomCount do
	local angle = (i - 1) * (math.pi * 2 / Config.RoomCount)
	local cx = math.cos(angle) * Config.HelicopterRingRadius
	local cz = math.sin(angle) * Config.HelicopterRingRadius
	-- Point the helicopter's nose outward (away from the helipad).
	local pivot = CFrame.new(cx, 0, cz) * CFrame.Angles(0, -angle - math.pi / 2, 0)

	local model, cockpitFloor, prompt = Helicopter.Build(i, pivot)
	model.Parent = heliFolder

	-- Triggering the prompt joins the room.
	prompt.Triggered:Connect(function(player)
		local ok, msg = RoomManager.AddPlayer(player, i)
		if not ok then
			Remotes.PlayerStatus():FireClient(player, "error", i, msg)
		end
	end)
end

-- Client asks to leave their room (button in HUD).
Remotes.LeaveRoom().OnServerEvent:Connect(function(player)
	RoomManager.RemovePlayer(player)
end)

-- Client asks to depart now -- teleport everyone in their room to MainGame.
Remotes.DepartNow().OnServerEvent:Connect(function(player)
	local rn = RoomManager.GetPlayerRoom(player)
	if not rn then return end
	if Config.MainGamePlaceId == 0 then
		-- No place ID configured yet -- just print so the dev can see it.
		warn("[Lobby] DepartNow triggered for room " .. rn ..
			" but Config.MainGamePlaceId is 0. Set it to your MainGame place ID in lobby/src/shared/Config.lua.")
		Remotes.PlayerStatus():FireClient(player, "error", rn, "Departure not configured")
		return
	end
	local members = RoomManager.MembersOfRoom(rn)
	-- Teleport them all together so they end up in the same MainGame server.
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	-- Pass the room number as join data in case the main game wants it.
	options:SetTeleportData({ FromLobbyRoom = rn })
	pcall(function()
		TeleportService:TeleportAsync(Config.MainGamePlaceId, members, options)
	end)
	for _, p in ipairs(members) do
		Remotes.PlayerStatus():FireClient(p, "departing", rn)
	end
end)

-- Allow client to join a room directly via UI button (in addition to the
-- in-world ProximityPrompt).
Remotes.JoinRoom().OnServerEvent:Connect(function(player, roomNumber)
	if type(roomNumber) ~= "number" then return end
	local ok, msg = RoomManager.AddPlayer(player, roomNumber)
	if not ok then
		Remotes.PlayerStatus():FireClient(player, "error", roomNumber, msg)
	end
end)

-- Push initial room snapshot to every joining player.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.defer(function() RoomManager.PushTo(player) end)
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function()
		task.defer(function() RoomManager.PushTo(p) end)
	end)
	if p.Character then task.defer(function() RoomManager.PushTo(p) end) end
end

print("[Lobby] Ready. " .. Config.RoomCount .. " rooms, " ..
	Config.RoomCapacity .. " players each. MainGame place ID: " ..
	tostring(Config.MainGamePlaceId))
