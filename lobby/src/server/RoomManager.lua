-- RoomManager.lua
-- Tracks room membership for all players in the lobby. The init.server.lua
-- hooks into SetSeatHandler so we can teleport joining players onto a free
-- bench inside the helicopter's open passenger compartment.
--
-- Public API:
--   * AddPlayer(player, roomNumber)  -> bool, msg
--   * RemovePlayer(player)           -> bool
--   * GetPlayerRoom(player)          -> number | nil
--   * GetSeatSlot(player, room)      -> 1..RoomCapacity | nil
--   * MembersOfRoom(roomNumber)      -> {Player, ...}
--   * SetSeatHandler(fn)             -- fn(player, room, "join"|"leave")
--   * Snapshot()                     -> per-room snapshot
--   * PushTo(player)                 -- send snapshot to one client

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local RoomManager = {}

-- rooms[roomNumber][seatSlot 1..Capacity] = Player (or nil if empty).
local rooms = {}
for i = 1, Config.RoomCount do
	rooms[i] = {}
end

-- Reverse indices.
local playerRoom = {}
local playerSlot = {}

-- init.server.lua wires this up so we can move the player's character
-- onto a bench when they join (and back to the helipad when they leave).
local seatHandler = nil

function RoomManager.SetSeatHandler(fn)
	seatHandler = fn
end

local function broadcast()
	local snapshot = {}
	for i = 1, Config.RoomCount do
		local names = {}
		for _, player in pairs(rooms[i]) do
			table.insert(names, player.Name)
		end
		snapshot[i] = {
			Number = i,
			Capacity = Config.RoomCapacity,
			Members = names,
		}
	end
	Remotes.UpdateRooms():FireAllClients(snapshot)
end

function RoomManager.Snapshot()
	return rooms
end

function RoomManager.GetPlayerRoom(player)
	return playerRoom[player]
end

function RoomManager.GetSeatSlot(player, roomNumber)
	if playerRoom[player] ~= roomNumber then return nil end
	return playerSlot[player]
end

function RoomManager.MembersOfRoom(roomNumber)
	local out = {}
	for _, player in pairs(rooms[roomNumber] or {}) do
		table.insert(out, player)
	end
	return out
end

local function findFreeSlot(roomNumber)
	for slot = 1, Config.RoomCapacity do
		if not rooms[roomNumber][slot] then
			return slot
		end
	end
	return nil
end

function RoomManager.AddPlayer(player, roomNumber)
	if not rooms[roomNumber] then
		return false, "Invalid room"
	end
	-- Kick out of any previous room first.
	if playerRoom[player] and playerRoom[player] ~= roomNumber then
		local oldRoom = playerRoom[player]
		local oldSlot = playerSlot[player]
		if oldSlot then rooms[oldRoom][oldSlot] = nil end
		playerRoom[player] = nil
		playerSlot[player] = nil
	end
	if playerRoom[player] == roomNumber then
		return true, "Already in room " .. roomNumber
	end
	local slot = findFreeSlot(roomNumber)
	if not slot then
		return false, "Room " .. roomNumber .. " is full"
	end
	rooms[roomNumber][slot] = player
	playerRoom[player] = roomNumber
	playerSlot[player] = slot
	broadcast()
	Remotes.PlayerStatus():FireClient(player, "joined", roomNumber)
	if seatHandler then
		task.defer(seatHandler, player, roomNumber, "join")
	end
	return true, "Joined room " .. roomNumber
end

function RoomManager.RemovePlayer(player)
	local rn = playerRoom[player]
	local slot = playerSlot[player]
	if not rn then return false end
	if slot then rooms[rn][slot] = nil end
	playerRoom[player] = nil
	playerSlot[player] = nil
	broadcast()
	Remotes.PlayerStatus():FireClient(player, "left", rn)
	if seatHandler then
		task.defer(seatHandler, player, rn, "leave")
	end
	return true
end

function RoomManager.PushTo(player)
	local snapshot = {}
	for i = 1, Config.RoomCount do
		local names = {}
		for _, p in pairs(rooms[i]) do table.insert(names, p.Name) end
		snapshot[i] = { Number = i, Capacity = Config.RoomCapacity, Members = names }
	end
	Remotes.UpdateRooms():FireClient(player, snapshot)
end

Players.PlayerRemoving:Connect(function(player)
	RoomManager.RemovePlayer(player)
end)

return RoomManager
