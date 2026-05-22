-- init.server.lua (lobby)
-- Lobby entry point. Builds the ruined-city map + helipad + 6 helicopters,
-- spawns players on the helipad, wires up each helicopter's neon trigger
-- pad to the RoomManager, and teleports a room's members to the main game
-- when they trigger "Depart". Also sits players on a free bench inside
-- the helicopter's open passenger compartment when they join the room.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local MapGenerator = require(script.MapGenerator)
local Helicopter = require(script.Helicopter)
local RoomManager = require(script.RoomManager)

-- IMPORTANT: touch the Remotes BEFORE clients connect so they exist in
-- ReplicatedStorage by the time the client calls Remotes.JoinRoom() etc.
-- The client uses WaitForChild on these and would yield forever if the
-- server forgot to materialize them.
Remotes.UpdateRooms()
Remotes.PlayerStatus()
Remotes.JoinRoom()
Remotes.LeaveRoom()
Remotes.DepartNow()

-- Build the world ONLY if there's no `LobbyMap` folder already saved.
if not Workspace:FindFirstChild("LobbyMap") then
	MapGenerator.Build()
end

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
-- nose outward, away from the centre. Save each helicopter's seat CFrames
-- so we can teleport joining players onto a free bench inside.
--   heliSeats[roomNumber] = { CFrame, CFrame, CFrame, CFrame }
local heliSeats = {}
local heliFolder = Instance.new("Folder")
heliFolder.Name = "Helicopters"
heliFolder.Parent = Workspace

-- Anti-spam: each player can only fire one trigger every 0.5 seconds.
-- Without this, walking onto the trigger pad would fire Touched dozens
-- of times per second and the server would log spam.
local lastTrigger = {}

for i = 1, Config.RoomCount do
	local angle = (i - 1) * (math.pi * 2 / Config.RoomCount)
	local cx = math.cos(angle) * Config.HelicopterRingRadius
	local cz = math.sin(angle) * Config.HelicopterRingRadius
	local pivot = CFrame.new(cx, 0, cz) * CFrame.Angles(0, -angle - math.pi / 2, 0)

	local model, triggerPart, seatCFrames = Helicopter.Build(i, pivot)
	model.Parent = heliFolder
	heliSeats[i] = seatCFrames

	-- Touched event: anyone whose character steps on the neon pad joins
	-- this helicopter's room.
	triggerPart.Touched:Connect(function(otherPart)
		local character = otherPart.Parent
		if not character then return end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Debounce per-player.
		local now = os.clock()
		local last = lastTrigger[player] or 0
		if now - last < 0.5 then return end
		lastTrigger[player] = now

		local ok, msg = RoomManager.AddPlayer(player, i)
		if not ok then
			Remotes.PlayerStatus():FireClient(player, "error", i, msg)
		end
	end)
end

-- Helper: place a player's character onto a free seat inside their room's
-- helicopter. Picks the seat slot the RoomManager assigned them.
local function seatPlayerInRoom(player, roomNumber)
	local seats = heliSeats[roomNumber]
	if not seats then return end
	local slot = RoomManager.GetSeatSlot(player, roomNumber)
	if not slot then return end
	local target = seats[slot]
	if not target then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	-- Pivot the whole character so they land standing upright on the bench.
	char:PivotTo(target)
end

-- Wire the RoomManager so we can react to seat assignments + leaves.
RoomManager.SetSeatHandler(function(player, roomNumber, action)
	if action == "join" then
		seatPlayerInRoom(player, roomNumber)
	end
	-- "leave" doesn't need to teleport -- the player just walks off.
end)

-- Client asks to leave their room (button in HUD).
Remotes.LeaveRoom().OnServerEvent:Connect(function(player)
	RoomManager.RemovePlayer(player)
end)

-- Client asks to depart now -- teleport everyone in their room to MainGame.
Remotes.DepartNow().OnServerEvent:Connect(function(player)
	local rn = RoomManager.GetPlayerRoom(player)
	if not rn then return end
	if Config.MainGamePlaceId == 0 then
		warn("[Lobby] DepartNow triggered for room " .. rn ..
			" but Config.MainGamePlaceId is 0. Set it to your MainGame place ID in lobby/src/shared/Config.lua.")
		Remotes.PlayerStatus():FireClient(player, "error", rn, "Departure not configured")
		return
	end
	local members = RoomManager.MembersOfRoom(rn)
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ FromLobbyRoom = rn })
	pcall(function()
		TeleportService:TeleportAsync(Config.MainGamePlaceId, members, options)
	end)
	for _, p in ipairs(members) do
		Remotes.PlayerStatus():FireClient(p, "departing", rn)
	end
end)

-- Allow client to join a room directly via UI button (in addition to the
-- in-world trigger pad).
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

-- Cleanup on disconnect.
Players.PlayerRemoving:Connect(function(player)
	lastTrigger[player] = nil
end)

print("[Lobby] Ready. " .. Config.RoomCount .. " rooms, " ..
	Config.RoomCapacity .. " players each. MainGame place ID: " ..
	tostring(Config.MainGamePlaceId))
