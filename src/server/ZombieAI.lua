-- ZombieAI.lua
-- Lightweight homing AI driven on Heartbeat. Picks the closest player, walks
-- toward them, attacks on contact, and applies special-tier behaviour
-- (ranged spitting, hellhound charge bursts, brute knockback).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")

local ZombieAI = {}

local activeZombies = {}

-- Each zombie recomputes its path roughly this often. Staggered with a
-- random offset per zombie so we don't recompute everyone on the same frame.
local PATH_REFRESH_SECONDS = 1.4
-- If we're closer than this to the target, skip pathfinding (we have line of
-- sight, just walk straight — faster and avoids weird detours).
local DIRECT_CHASE_DIST = 18

local function buildPath()
	return PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5.5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 6,
	})
end

local function computeWaypoints(startPos, targetPos)
	local path = buildPath()
	local ok = pcall(function() path:ComputeAsync(startPos, targetPos) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local wps = path:GetWaypoints()
	-- Drop the first waypoint — it's our current position.
	if #wps > 1 then
		table.remove(wps, 1)
	end
	return wps
end

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
		-- Pathfinding state:
		Waypoints = nil,    -- array of PathWaypoint, sequentially consumed
		WaypointIndex = 1,
		NextPathAt = 0,     -- os.clock() when we should recompute next
		PathInFlight = false,
		-- Stuck-detection state:
		LastPos = rootPart.Position,
		StuckTime = 0,
	}
	activeZombies[model] = data

	humanoid.Died:Connect(function()
		activeZombies[model] = nil
		if onKilled then
			onKilled(model)
		end
		-- Model cleanup is handled by ZombieFactory.Animate (sink-into-ground
		-- sequence). Don't Debris:AddItem here or the body may vanish before
		-- the sink animation finishes.
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

			-- Safety: kill anything that fell out of the world or wandered
			-- past the arena edge. Without this the wave counter can hang
			-- forever on a zombie that's stuck in the void / outside the
			-- mountain ring (which the no-jump pathfinder can't escape from).
			local pos = data.RootPart.Position
			if pos.Y < -20 or math.abs(pos.X) > 260 or math.abs(pos.Z) > 260 then
				data.Humanoid.Health = 0
				activeZombies[model] = nil
				continue
			end

			-- Stuck detection: if we've barely moved AND we're not actively
			-- engaging a target (melee distance, or sitting in spit range
			-- as a Spitter), count up; after a few seconds, give up and
			-- kill the zombie so the wave can complete. This catches
			-- zombies that pathed onto a rooftop, into a wall, or got
			-- pinched between two buildings.
			--
			-- 0.05 studs/heartbeat = ~3 studs/sec. The slowest normal
			-- zombie (Brute) walks at 7 studs/sec ~= 0.12 per heartbeat,
			-- so any genuinely-walking zombie clears this threshold every
			-- frame and StuckTime resets. Only a physically blocked
			-- zombie (or one whose pathfinder gave up) keeps accumulating.
			local moved = (pos - data.LastPos).Magnitude
			data.LastPos = pos
			local engaging = false
			if data.Target then
				local th = data.Target:FindFirstChild("HumanoidRootPart")
				if th then
					local td = (th.Position - pos).Magnitude
					local ranged = model:GetAttribute("Ranged")
					local rangedRange = model:GetAttribute("RangedRange") or 0
					engaging = (td < 6) or (ranged and td < rangedRange and td > 15)
				end
			end
			if not engaging and moved < 0.05 then
				data.StuckTime += dt
				if data.StuckTime > 10 then
					data.Humanoid.Health = 0
					activeZombies[model] = nil
					continue
				end
			else
				data.StuckTime = 0
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
				local prev = data.Target
				data.Target = getClosestTarget(data.RootPart)
				data.LastRetarget = now
				-- If we switched target, invalidate the path so we recompute now.
				if data.Target ~= prev then
					data.Waypoints = nil
					data.NextPathAt = 0
				end
			end

			if data.Target then
				local hrp = data.Target:FindFirstChild("HumanoidRootPart")
				if hrp then
					local toTarget = hrp.Position - data.RootPart.Position
					local dist = toTarget.Magnitude
					local ranged = model:GetAttribute("Ranged")
					local rangedRange = model:GetAttribute("RangedRange")

					if ranged and dist < rangedRange and dist > 15 then
						-- Ranged tier: stop and spit projectiles.
						data.Humanoid:MoveTo(data.RootPart.Position)
						data.Waypoints = nil
						if now - data.LastAttack > model:GetAttribute("AttackCooldown") then
							data.LastAttack = now
							-- Tell the procedural animator to play a spit-attack pose for ~0.4s.
							model:SetAttribute("AttackingUntil", now + 0.4)
							spawnSpit(data.RootPart, data.Target, model:GetAttribute("Damage"))
						end
					else
						-- Movement: follow pathfinding waypoints when far, walk
						-- straight when in line-of-sight range. Pathfinding is
						-- recomputed off-thread so this tick never blocks.
						if dist < DIRECT_CHASE_DIST then
							-- Close enough — just charge straight at the target.
							data.Waypoints = nil
							data.Humanoid:MoveTo(hrp.Position)
						else
							-- Far — keep following the cached waypoint list,
							-- recompute when stale / exhausted.
							if data.Waypoints then
								local wp = data.Waypoints[data.WaypointIndex]
								if not wp then
									data.Waypoints = nil
								else
									local flat = wp.Position - data.RootPart.Position
									flat = Vector3.new(flat.X, 0, flat.Z)
									if flat.Magnitude < 3.5 then
										data.WaypointIndex += 1
									end
									data.Humanoid:MoveTo(wp.Position)
								end
							end

							-- Schedule a path recompute periodically (or now if
							-- we have no path yet). Stagger so we don't compute
							-- every zombie's path on the same frame.
							if not data.PathInFlight and now >= data.NextPathAt then
								data.PathInFlight = true
								data.NextPathAt = now + PATH_REFRESH_SECONDS + math.random() * 0.4
								task.spawn(function()
									local target = data.Target
									local targetHrp = target and target:FindFirstChild("HumanoidRootPart")
									if targetHrp and data.RootPart.Parent then
										local wps = computeWaypoints(data.RootPart.Position, targetHrp.Position)
										if wps and data.Model.Parent then
											data.Waypoints = wps
											data.WaypointIndex = 1
										end
									end
									data.PathInFlight = false
								end)
							end

							-- If pathfinding hasn't returned anything yet, walk
							-- straight as a fallback so we never freeze.
							if not data.Waypoints then
								data.Humanoid:MoveTo(hrp.Position)
							end
						end

						-- Melee attack on contact.
						if dist < 4.5 and now - data.LastAttack > model:GetAttribute("AttackCooldown") then
							data.LastAttack = now
							-- Tell the procedural animator to play a melee
							-- swing pose for ~0.35s. The Animate Heartbeat
							-- in ZombieFactory reads this attribute to bend
							-- the zombie forward and slam its arms down.
							model:SetAttribute("AttackingUntil", now + 0.35)
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
