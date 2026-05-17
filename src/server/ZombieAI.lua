-- ZombieAI.lua
-- Lightweight homing AI driven on Heartbeat. Picks the closest player, walks
-- toward them, attacks on contact, and applies special-tier behaviour
-- (ranged spitting, hellhound charge bursts, brute knockback).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ZombieAI = {}

local activeZombies = {}

local function getClosestTarget(rootPart)
	local closest, closestDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and hrp then
			local d = (hrp.Position - rootPart.Position).Magnitude
			if not closestDist or d < closestDist then
				closest = character
				closestDist = d
			end
		end
	end
	return closest, closestDist
end

local function spawnSpit(originPart, target, damage)
	local spit = Instance.new("Part")
	spit.Shape = Enum.PartType.Ball
	spit.Size = Vector3.new(1.2, 1.2, 1.2)
	spit.Material = Enum.Material.Neon
	spit.Color = Color3.fromRGB(150, 80, 180)
	spit.CFrame = originPart.CFrame * CFrame.new(0, 0.5, -2)
	spit.CanCollide = false
	spit.Massless = true
	spit.Parent = workspace

	local dir = (target.HumanoidRootPart.Position - spit.Position).Unit
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity = dir * 70
	bv.Parent = spit

	Debris:AddItem(spit, 3)
	spit.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and not hum.Parent:GetAttribute("Tier") then
			hum:TakeDamage(damage)
			spit:Destroy()
		end
	end)
end

function ZombieAI.Register(model, humanoid, onKilled)
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local data = {
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		LastAttack = 0,
		LastRetarget = 0,
		Target = nil,
		BaseSpeed = humanoid.WalkSpeed,
		SpeedMul = 1,
		DamageTickAccum = 0,
	}
	activeZombies[model] = data

	humanoid.Died:Connect(function()
		activeZombies[model] = nil
		if onKilled then
			onKilled(model)
		end
		Debris:AddItem(model, 4)
	end)
end

function ZombieAI.ApplySlow(model, factor, duration)
	local data = activeZombies[model]
	if not data then return end
	data.SpeedMul = math.min(data.SpeedMul, factor)
	data._slowUntil = os.clock() + duration
end

function ZombieAI.ApplyDot(model, dps, duration)
	local data = activeZombies[model]
	if not data then return end
	data._dotDps = dps
	data._dotUntil = os.clock() + duration
end

function ZombieAI.GetAll()
	local list = {}
	for _, d in pairs(activeZombies) do
		table.insert(list, d)
	end
	return list
end

function ZombieAI.Start()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for model, data in pairs(activeZombies) do
			if not model.Parent or data.Humanoid.Health <= 0 then
				activeZombies[model] = nil
				continue
			end

			-- DOT (barbed wire etc.)
			if data._dotUntil and now < data._dotUntil then
				data.DamageTickAccum += dt
				if data.DamageTickAccum >= 0.4 then
					data.Humanoid:TakeDamage(data._dotDps * data.DamageTickAccum)
					data.DamageTickAccum = 0
				end
			else
				data._dotDps = nil
			end

			-- Slow expiry
			if data._slowUntil and now >= data._slowUntil then
				data.SpeedMul = 1
				data._slowUntil = nil
			end
			data.Humanoid.WalkSpeed = data.BaseSpeed * data.SpeedMul

			-- Retarget periodically.
			if now - data.LastRetarget > 1.0 or not data.Target or not data.Target.Parent then
				data.Target = getClosestTarget(data.RootPart)
				data.LastRetarget = now
			end

			if data.Target then
				local hrp = data.Target:FindFirstChild("HumanoidRootPart")
				if hrp then
					local toTarget = hrp.Position - data.RootPart.Position
					local dist = toTarget.Magnitude
					local ranged = model:GetAttribute("Ranged")
					local rangedRange = model:GetAttribute("RangedRange")

					if ranged and dist < rangedRange and dist > 15 then
						data.Humanoid:MoveTo(data.RootPart.Position)
						if now - data.LastAttack > model:GetAttribute("AttackCooldown") then
							data.LastAttack = now
							spawnSpit(data.RootPart, data.Target, model:GetAttribute("Damage"))
						end
					else
						data.Humanoid:MoveTo(hrp.Position)

						if dist < 4.5 and now - data.LastAttack > model:GetAttribute("AttackCooldown") then
							data.LastAttack = now
							local targetHum = data.Target:FindFirstChildOfClass("Humanoid")
							if targetHum and targetHum.Health > 0 then
								targetHum:TakeDamage(model:GetAttribute("Damage"))
							end
						end
					end
				end
			end
		end
	end)
end

return ZombieAI
