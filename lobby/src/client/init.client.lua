-- init.client.lua (lobby)
-- Lobby client entry point. Builds the room-list HUD, listens for room
-- updates, and lets the player join/leave rooms or trigger departure.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local LobbyHud = require(script.LobbyHud)

local localPlayer = Players.LocalPlayer

LobbyHud.Init()

-- Server pushes the room snapshot whenever any player joins / leaves.
Remotes.UpdateRooms().OnClientEvent:Connect(function(snapshot)
	LobbyHud.SetRooms(snapshot, localPlayer.Name)
end)

-- Server pushes per-player status changes (joined / left / departing / error).
Remotes.PlayerStatus().OnClientEvent:Connect(function(status, roomNumber, msg)
	if status == "joined" then
		LobbyHud.SetMyRoom(roomNumber)
		LobbyHud.Toast("Joined helicopter #" .. roomNumber, Color3.fromRGB(120, 220, 120))
	elseif status == "left" then
		LobbyHud.SetMyRoom(nil)
		LobbyHud.Toast("Left helicopter #" .. roomNumber, Color3.fromRGB(220, 200, 90))
	elseif status == "departing" then
		LobbyHud.Toast("Departing! Hold tight...", Color3.fromRGB(120, 220, 220))
	elseif status == "error" then
		LobbyHud.Toast(msg or "Could not join room", Color3.fromRGB(220, 110, 110))
	end
end)

-- Hotkeys: L = leave current room, T = depart now.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.L then
		Remotes.LeaveRoom():FireServer()
	elseif input.KeyCode == Enum.KeyCode.T then
		Remotes.DepartNow():FireServer()
	end
end)

print("[Lobby] Welcome. Walk up to a helicopter and press E to enter. " ..
	"Hotkeys: L = leave, T = depart.")
