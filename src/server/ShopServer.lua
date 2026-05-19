-- ShopServer.lua
-- Handles weapon and defense purchases. Defense prices scale per purchase.

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local DefenseManager = require(script.Parent.DefenseManager)

local ShopServer = {}

function ShopServer.Setup()
	Remotes.PurchaseItem().OnServerEvent:Connect(function(player, kind, id)
		local state = PlayerData.Get(player)
		if kind == "Weapon" then
			local def = Config.Weapons[id]
			if not def then return end
			if state.Weapons[id] then return end
			if state.Money < def.Price then
				Remotes.Announce():FireClient(player, "Not enough money for " .. def.Name, Color3.fromRGB(255, 90, 90))
				return
			end
			state.Money -= def.Price
			state.Weapons[id] = true
			state.CurrentWeapon = id
			PlayerData.Push(player)
			Remotes.Announce():FireClient(player, "Purchased " .. def.Name, Color3.fromRGB(120, 220, 120))
		elseif kind == "Defense" then
			local def = Config.Defenses[id]
			if not def then return end
			local price = PlayerData.GetDefensePrice(player, id)
			if state.Money < price then
				Remotes.Announce():FireClient(player, "Not enough money for " .. def.Name, Color3.fromRGB(255, 90, 90))
				return
			end
			state.Money -= price
			state.DefensePurchases[id] = (state.DefensePurchases[id] or 0) + 1
			PlayerData.Push(player)

			-- Barbed wire drops in front of the player's feet immediately,
			-- no placement cursor (it's a body-block defense). Other defenses
			-- still go through the click-to-place flow.
			if id == "BarbedWire" then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					-- Drop the coil right at the player's feet so it pops up
					-- where they're standing -- matches the "place where you
					-- stand" UX the player asked for.
					local feet = hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + 1.5, 0)
					DefenseManager.Place(player, id, feet, hrp.CFrame.LookVector)
					Remotes.Announce():FireClient(player, "Deployed " .. def.Name, Color3.fromRGB(120, 220, 120))
				else
					Remotes.Announce():FireClient(player, "Spawn first before placing wire", Color3.fromRGB(255, 90, 90))
				end
			else
				Remotes.Announce():FireClient(player, "Purchased " .. def.Name .. " (place it!)", Color3.fromRGB(120, 220, 120))
				-- Tell the client to enter placement mode.
				Remotes.PlaceDefense():FireClient(player, "BeginPlacement", id)
			end
		end
	end)

	Remotes.PlaceDefense().OnServerEvent:Connect(function(player, action, id, position)
		if action == "Confirm" and typeof(position) == "Vector3" then
			-- Reject placements outside the play area.
			if position.Magnitude > 250 or position.Y < -5 or position.Y > 40 then return end
			DefenseManager.Place(player, id, position)
		end
	end)
end

return ShopServer
