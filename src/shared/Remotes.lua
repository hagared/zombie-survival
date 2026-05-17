-- Remotes.lua
-- Lazily creates RemoteEvents under ReplicatedStorage so server and client can share them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local function getOrCreate(name, className)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		if RunService:IsServer() then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("Remotes")
		end
	end

	local remote = folder:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name)
		end
	end
	return remote
end

Remotes.FireWeapon = function() return getOrCreate("FireWeapon", "RemoteEvent") end
Remotes.PurchaseItem = function() return getOrCreate("PurchaseItem", "RemoteEvent") end
Remotes.PlaceDefense = function() return getOrCreate("PlaceDefense", "RemoteEvent") end
Remotes.UpdatePlayerState = function() return getOrCreate("UpdatePlayerState", "RemoteEvent") end
Remotes.UpdateWaveState = function() return getOrCreate("UpdateWaveState", "RemoteEvent") end
Remotes.SwitchWeapon = function() return getOrCreate("SwitchWeapon", "RemoteEvent") end
Remotes.HitFeedback = function() return getOrCreate("HitFeedback", "RemoteEvent") end
Remotes.Announce = function() return getOrCreate("Announce", "RemoteEvent") end

return Remotes
