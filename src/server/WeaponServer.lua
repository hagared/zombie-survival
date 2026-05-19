-- WeaponServer.lua
-- Validates incoming FireWeapon requests, performs the raycasts, applies
-- damage to zombies/turrets and awards money/feedback. The client predicts
-- visuals but the server is the source of truth for damage.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local WeaponServer = {}

local lastShotByPlayer = {}

local function rotateAroundY(dir, angleDeg)
	local rad = math.rad(angleDeg)
	local c, s = math.cos(rad), math.sin(rad)
	return Vector3.new(c * dir.X + s * dir.Z, dir.Y, -s * dir.X + c * dir.Z).Unit
end

local function performShot(player, origin, dir, weaponData, killedCallback)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local excludes = { player.Character }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(excludes, p.Character) end
	end
	rayParams.FilterDescendantsInstances = excludes

	-- Multi-ray spread: shotgun=2 (split L/R), minigun=3 (L/center/R).
	local rays = weaponData.Rays or 1
	local spread = weaponData.Spread or 0
	local hits = {}
	for i = 1, rays do
		local offset
		if rays == 1 then
			offset = 0
		else
			-- centered around 0; e.g. rays=2 -> [-spread/2, spread/2]; rays=3 -> [-spread, 0, spread]
			offset = ((i - 1) / (rays - 1) - 0.5) * spread * (rays - 1)
		end
		local rayDir = rotateAroundY(dir, offset) * weaponData.Range
		local result = Workspace:Raycast(origin, rayDir, rayParams)
		if result then
			local hitInstance = result.Instance
			local parent = hitInstance.Parent
			-- Try humanoid hit (zombie or turret/wire with humanoid).
			local hum = parent and parent:FindFirstChildOfClass("Humanoid")
			if hum and parent:GetAttribute("Tier") then
				local previousHealth = hum.Health
				hum:TakeDamage(weaponData.Damage)
				table.insert(hits, { Position = result.Position, Killed = hum.Health <= 0 and previousHealth > 0 })
				if hum.Health <= 0 and previousHealth > 0 then
					local reward = parent:GetAttribute("Reward") or 0
					PlayerData.AddMoney(player, reward)
					if killedCallback then killedCallback(player, parent) end
				end
			else
				table.insert(hits, { Position = result.Position, Killed = false })
			end
		else
			table.insert(hits, { Position = origin + rayDir, Killed = false })
		end
	end
	return hits
end

function WeaponServer.Setup(onZombieKilled)
	Remotes.FireWeapon().OnServerEvent:Connect(function(player, origin, dir)
		if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then return end
		dir = dir.Unit

		local state = PlayerData.Get(player)
		local weaponId = state.CurrentWeapon or "Pistol"
		if not state.Weapons[weaponId] then return end

		local weapon = Config.Weapons[weaponId]
		if not weapon then return end

		-- Fire rate enforcement.
		local now = os.clock()
		local last = lastShotByPlayer[player] or 0
		if now - last < weapon.FireRate * 0.9 then return end
		lastShotByPlayer[player] = now

		-- Sanity check origin (must be near the player to prevent trivial exploits).
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or (origin - hrp.Position).Magnitude > 12 then return end

		local hits = performShot(player, origin, dir, weapon, onZombieKilled)
		Remotes.HitFeedback():FireAllClients(player, weaponId, origin, dir, hits)
	end)

	Remotes.SwitchWeapon().OnServerEvent:Connect(function(player, weaponId)
		if typeof(weaponId) ~= "string" then return end
		PlayerData.SetCurrentWeapon(player, weaponId)
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastShotByPlayer[p] = nil
	end)
end

return WeaponServer
