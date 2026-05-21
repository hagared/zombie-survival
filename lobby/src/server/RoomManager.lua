-- RoomManager.lua
-- Tracks room membership for all players in the lobby and exposes:
--   * AddPlayer(player, roomNumber)  -> bool, msg
--   * RemovePlayer(player)           -> bool
--   * Snapshot()                     -> per-room player list
--   * MembersOfRoom(roomNumber)      -> {Player, ...}
-- Also fires Remotes.UpdateRooms() to all clients on every change so the
-- HUD's room-list panel is always current.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local RoomManager = {}

-- rooms[1..RoomCount] = { [Player] = true, ... }
local rooms = {}
for i = 1, Config.RoomCount do
	rooms[i] = {}
end

-- Reverse index: which room is each player currently in (or nil).
local playerRoom = {}

local function broadcast()
	-- Per-room snapshot the client renders into its room-list UI.
	local snapshot = {}
	for i = 1, Config.RoomCount do
		local names = {}
		for player in pairs(rooms[i]) do
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

function RoomManager.MembersOfRoom(roomNumber)
	local out = {}
	for player in pairs(rooms[roomNumber] or {}) do
		table.insert(out, player)
	end
	return out
end

-- Try to add `player` to `roomNumber`. Refuses if room is full or invalid.
function RoomManager.AddPlayer(player, roomNumber)
	if not rooms[roomNumber] then
		return false, "Invalid room"
	end
	-- If player is already in another room, kick them out first.
	if playerRoom[player] and playerRoom[player] ~= roomNumber then
		rooms[playerRoom[player]][player] = nil
		playerRoom[player] = nil
	end
	-- Already in this room? Nothing to do.
	if playerRoom[player] == roomNumber then
		return true, "Already in room " .. roomNumber
	end
	-- Capacity check.
	local count = 0
	for _ in pairs(rooms[roomNumber]) do count += 1 end
	if count >= Config.RoomCapacity then
		return false, "Room " .. roomNumber .. " is full"
	end
	rooms[roomNumber][player] = true
	playerRoom[player] = roomNumber
	broadcast()
	Remotes.PlayerStatus():FireClient(player, "joined", roomNumber)
	return true, "Joined room " .. roomNumber
end

function RoomManager.RemovePlayer(player)
	local rn = playerRoom[player]
	if not rn then return false end
	rooms[rn][player] = nil
	playerRoom[player] = nil
	broadcast()
	Remotes.PlayerStatus():FireClient(player, "left", rn)
	return true
end

-- Push the current snapshot to a single player (used on player join so the
-- HUD populates immediately).
function RoomManager.PushTo(player)
	local snapshot = {}
	for i = 1, Config.RoomCount do
		local names = {}
		for p in pairs(rooms[i]) do table.insert(names, p.Name) end
		snapshot[i] = { Number = i, Capacity = Config.RoomCapacity, Members = names }
	end
	Remotes.UpdateRooms():FireClient(player, snapshot)
end

-- Cleanup on disconnect.
Players.PlayerRemoving:Connect(function(player)
	RoomManager.RemovePlayer(player)
end)

return RoomManager
