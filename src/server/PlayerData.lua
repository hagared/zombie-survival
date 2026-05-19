-- PlayerData.lua
-- Simple in-memory storage of currency + unlocked weapons per player.
-- Pushes updates to clients through a RemoteEvent so the HUD/shop stay in sync.

local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Config = require(game.ReplicatedStorage.Shared.Config)

local PlayerData = {}

local data = {} -- [player] = {Money=, Weapons={Pistol=true}, DefensePurchases={Turret=0,...}, CurrentWeapon="Pistol"}

local function freshState()
	return {
		Money = Config.StartingMoney,
		Weapons = { Pistol = true },
		DefensePurchases = { Turret = 0, BarbedWire = 0, Mine = 0 },
		CurrentWeapon = "Pistol",
	}
end

function PlayerData.Get(player)
	if not data[player] then
		data[player] = freshState()
	end
	return data[player]
end

function PlayerData.Push(player)
	local state = PlayerData.Get(player)
	Remotes.UpdatePlayerState():FireClient(player, state)
end

function PlayerData.AddMoney(player, amount)
	local state = PlayerData.Get(player)
	state.Money = math.max(0, state.Money + amount)
	PlayerData.Push(player)
end

function PlayerData.SetCurrentWeapon(player, weapon)
	local state = PlayerData.Get(player)
	if state.Weapons[weapon] then
		state.CurrentWeapon = weapon
		PlayerData.Push(player)
		return true
	end
	return false
end

function PlayerData.GetDefensePrice(player, defenseId)
	local state = PlayerData.Get(player)
	local def = Config.Defenses[defenseId]
	if not def then return math.huge end
	local count = state.DefensePurchases[defenseId] or 0
	return math.floor(def.BasePrice * (def.PriceMul ^ count) + 0.5)
end

Players.PlayerAdded:Connect(function(player)
	data[player] = freshState()
	player.CharacterAdded:Connect(function()
		task.defer(function()
			PlayerData.Push(player)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	data[player] = nil
end)

return PlayerData
