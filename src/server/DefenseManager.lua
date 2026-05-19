-- DefenseManager.lua
-- Creates and runs deployable defenses: turrets (auto-fire), barbed wire
-- (slows + damages), and proximity mines (explode on contact).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DefenseManager = {}

local defenses = {} -- list of all active defenses
local zombieRegistryGetter -- supplied via Init() so we can poll zombies

local function makePart(name, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function buildTurret(position, ownerName, cfg)
	local model = Instance.new("Model")
	model.Name = "Turret_" .. ownerName

	local base = makePart("Base", {
		Size = Vector3.new(3, 1, 3),
		CFrame = CFrame.new(position),
		Material = Enum.Material.DiamondPlate,
		Color = cfg.Color,
		CanCollide = true,
	})
	base.Parent = model

	local pillar = makePart("Pillar", {
		Size = Vector3.new(0.8, 2, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)),
		Material = Enum.Material.Metal,
		Color = cfg.Color,
	})
	pillar.Parent = model

	local head = makePart("Head", {
		Size = Vector3.new(2.2, 1.6, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 3.3, 0)),
		Material = Enum.Material.Metal,
		Color = cfg.Color:Lerp(Color3.new(0, 0, 0), 0.2),
	})
	head.Parent = model
	model.PrimaryPart = head

	local barrel = makePart("Barrel", {
		Size = Vector3.new(0.4, 0.4, 2.4),
		CFrame = head.CFrame * CFrame.new(0, 0, -1.6),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 40, 45),
	})
	barrel.Parent = model

	model.Parent = Workspace
	return model, head, barrel
end

local function buildBarbedWire(position, lookVector, cfg)
	local model = Instance.new("Model")
	model.Name = "BarbedWire"

	-- Coil-shaped razor wire (matches a real roll of barbed wire visually):
	-- one collidable cylindrical core, surrounded by dozens of small spike
	-- parts arranged in stacked rings around the core, spiralling slightly.
	-- The long axis of the coil runs perpendicular to `lookVector`, so the
	-- coil forms a barrier across the direction the player was facing.
	local up = Vector3.new(0, 1, 0)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
	flatLook = flatLook.Unit
	local right = flatLook:Cross(up).Unit -- coil's long axis
	if right.Magnitude < 0.1 then right = Vector3.new(1, 0, 0) end
	-- Build a CFrame whose local X axis = `right` (length of coil),
	-- local Y = up, local Z = `flatLook` (which way the coil "faces").
	-- This way the coil is a horizontal cylinder running left-right.
	local coilCF = CFrame.fromMatrix(position + Vector3.new(0, 1.2, 0), right, up)

	local coilLength = 6
	local coilRadius = 1.25

	-- Cylindrical core. This is what physically blocks zombies and what
	-- pathfinding sees as a wall.
	local core = makePart("Core", {
		Size = Vector3.new(coilLength, coilRadius * 2, coilRadius * 2),
		CFrame = coilCF,
		Material = Enum.Material.Metal,
		Color = cfg.Color,
		Transparency = 0.4,
		CanCollide = true,
	})
	-- Use a cylinder mesh so the core looks round.
	local coreMesh = Instance.new("SpecialMesh")
	coreMesh.MeshType = Enum.MeshType.Cylinder
	coreMesh.Scale = Vector3.new(1, 1, 1)
	coreMesh.Parent = core
	-- Rotate the mesh so Roblox's cylinder primitive (long axis = X) lines
	-- up with the part's X axis. Mesh long axis is X by default. We need
	-- to be careful: Cylinder MeshType on a Part is oriented along X. Good.
	core.Parent = model
	model.PrimaryPart = core

	-- A faint inner solid cylinder so the coil has a visible "barrel"
	-- behind the spikes (the user's photo shows a clear cylindrical roll).
	local barrel = makePart("Barrel", {
		Size = Vector3.new(coilLength * 0.95, coilRadius * 1.6, coilRadius * 1.6),
		CFrame = coilCF,
		Material = Enum.Material.Metal,
		Color = cfg.Color:Lerp(Color3.new(1, 1, 1), 0.15),
		CanCollide = false,
	})
	local barrelMesh = Instance.new("SpecialMesh")
	barrelMesh.MeshType = Enum.MeshType.Cylinder
	barrelMesh.Parent = barrel
	barrel.Parent = model

	-- Stacked rings of radial spikes spiralling along the coil's long axis.
	local rings = 7
	local spikesPerRing = 14
	for r = 1, rings do
		local along = -coilLength / 2 + (r - 0.5) * (coilLength / rings)
		local twistOffset = (r - 1) * 0.22 -- spiral the rings for razor-wire look
		for k = 1, spikesPerRing do
			local theta = (k - 1) * (math.pi * 2 / spikesPerRing) + twistOffset
			local sinT, cosT = math.sin(theta), math.cos(theta)
			-- Spike's center position in coil-local space (long axis = X).
			-- Radius is slightly outside the core so the spikes stick out.
			local outR = coilRadius + 0.35
			local localCF = CFrame.new(along, cosT * outR, sinT * outR)
				-- Aim spike outward (away from the coil's central axis):
				* CFrame.Angles(0, 0, math.atan2(cosT, sinT) - math.pi / 2)
				-- And tilt each spike slightly along the coil length for variation.
				* CFrame.Angles(((k % 2) * 2 - 1) * 0.35, 0, 0)
			local spike = makePart("Spike", {
				Size = Vector3.new(0.18, 0.7, 0.18),
				CFrame = coilCF * localCF * CFrame.new(0, 0.35, 0),
				Material = Enum.Material.Metal,
				Color = cfg.Color,
				CanCollide = false,
			})
			spike.Parent = model
		end
	end

	-- HP label that hovers above the coil so the player can see how much
	-- abuse the wire can still take.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 18)
	bb.StudsOffset = Vector3.new(0, coilRadius + 1.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = core
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HP"
	hpLabel.Size = UDim2.fromScale(1, 1)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Font = Enum.Font.GothamBlack
	hpLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
	hpLabel.TextStrokeTransparency = 0.3
	hpLabel.TextSize = 14
	hpLabel.Text = tostring(cfg.Health)
	hpLabel.Parent = bb

	model.Parent = Workspace
	return model, core, hpLabel
end

local function buildMine(position, cfg)
	local mine = makePart("Mine", {
		Size = Vector3.new(1.6, 0.4, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)),
		Material = Enum.Material.Metal,
		Color = cfg.Color,
		CanCollide = false,
	})
	-- Pulsing red light to indicate armed status.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Brightness = 1.4
	light.Range = 6
	light.Parent = mine

	mine.Parent = Workspace

	task.spawn(function()
		while mine.Parent do
			light.Brightness = 0.2
			task.wait(0.6)
			light.Brightness = 2
			task.wait(0.05)
		end
	end)
	return mine
end

local function explode(position, radius, damage)
	-- Visual
	local fx = Instance.new("Explosion")
	fx.BlastRadius = radius
	fx.BlastPressure = 0
	fx.Position = position
	fx.DestroyJointRadiusPercent = 0
	fx.Parent = Workspace

	-- Damage zombies within radius.
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("Tier") then
			local hrp = descendant:FindFirstChild("HumanoidRootPart")
			local hum = descendant:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - position).Magnitude
				if d <= radius then
					hum:TakeDamage(damage * (1 - d / radius))
				end
			end
		end
	end
end

function DefenseManager.Place(player, defenseId, position, lookVector)
	local cfg = Config.Defenses[defenseId]
	if not cfg then return end

	if defenseId == "Turret" then
		local model, head, barrel = buildTurret(position, player.Name, cfg)
		local entry = {
			Type = "Turret",
			Model = model,
			Head = head,
			Barrel = barrel,
			Cfg = cfg,
			Health = cfg.Health,
			LastShot = 0,
		}
		table.insert(defenses, entry)
	elseif defenseId == "BarbedWire" then
		local model, core, hpLabel = buildBarbedWire(position, lookVector or Vector3.new(0, 0, -1), cfg)
		local entry = {
			Type = "BarbedWire",
			Model = model,
			Plate = core,
			Cfg = cfg,
			Health = cfg.Health,
			MaxHealth = cfg.Health,
			HpLabel = hpLabel,
		}
		table.insert(defenses, entry)
	elseif defenseId == "Mine" then
		local part = buildMine(position, cfg)
		local entry = { Type = "Mine", Model = part, Cfg = cfg, Armed = false }
		-- Brief arming delay so the player doesn't blow themselves up.
		task.delay(1, function() entry.Armed = true end)
		table.insert(defenses, entry)
	end
end

function DefenseManager.Init(getZombies)
	zombieRegistryGetter = getZombies

	-- Turret tick loop.
	task.spawn(function()
		while true do
			task.wait(0.08)
			local zombies = zombieRegistryGetter and zombieRegistryGetter() or {}
			for i = #defenses, 1, -1 do
				local entry = defenses[i]
				if not entry.Model or not entry.Model.Parent then
					table.remove(defenses, i)
					continue
				end

				if entry.Type == "Turret" then
					local now = os.clock()
					-- Find nearest zombie in range.
					local turretPos = entry.Head.Position
					local nearest, nearestDist
					for _, z in ipairs(zombies) do
						if z.Humanoid.Health > 0 then
							local d = (z.RootPart.Position - turretPos).Magnitude
							if d <= entry.Cfg.Range and (not nearestDist or d < nearestDist) then
								nearest = z
								nearestDist = d
							end
						end
					end
					if nearest then
						-- Smoothly rotate the head toward the target.
						local look = CFrame.lookAt(turretPos, nearest.RootPart.Position)
						TweenService:Create(entry.Head, TweenInfo.new(0.15, Enum.EasingStyle.Sine), { CFrame = look }):Play()
						TweenService:Create(entry.Barrel, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {
							CFrame = look * CFrame.new(0, 0, -1.6),
						}):Play()

						if now - entry.LastShot >= entry.Cfg.FireRate then
							entry.LastShot = now
							nearest.Humanoid:TakeDamage(entry.Cfg.Damage)
							-- Tracer beam
							local beam = Instance.new("Part")
							beam.Anchored = true
							beam.CanCollide = false
							beam.Material = Enum.Material.Neon
							beam.Color = Color3.fromRGB(255, 220, 100)
							beam.Size = Vector3.new(0.15, 0.15, nearestDist)
							beam.CFrame = CFrame.lookAt(turretPos, nearest.RootPart.Position) * CFrame.new(0, 0, -nearestDist / 2)
							beam.Parent = Workspace
							TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 }):Play()
							Debris:AddItem(beam, 0.2)
						end
					end
				elseif entry.Type == "BarbedWire" then
					-- Zombies in contact:
					--   * take DOT + slow (from the wire itself)
					--   * deal damage to the wire (so they "attack" it)
					-- Player priority is NOT changed here -- the AI still
					-- pursues the closest player. The wire only takes damage
					-- when zombies physically run into it on their way.
					local TICK = 0.08
					-- A bit beyond the coil's outer radius so the spikes feel
					-- "wide" rather than razor-thin.
					local CONTACT_DIST = 4.5
					local damageThisTick = 0
					for _, z in ipairs(zombies) do
						if z.Humanoid.Health > 0 then
							local d = (z.RootPart.Position - entry.Plate.Position).Magnitude
							if d <= CONTACT_DIST then
								local ZombieAI_ = require(script.Parent.ZombieAI)
								ZombieAI_.ApplySlow(z.Model, entry.Cfg.SlowFactor, TICK * 2)
								ZombieAI_.ApplyDot(z.Model, entry.Cfg.DamagePerSec, TICK * 2)
								-- Zombie also chips away at the wire while
								-- being slowed/cut. We approximate one
								-- "attack" per attack cooldown.
								local zDmg = z.Model:GetAttribute("Damage") or 8
								local zCd = z.Model:GetAttribute("AttackCooldown") or 1
								damageThisTick += zDmg * (TICK / math.max(zCd, 0.2))
							end
						end
					end
					if damageThisTick > 0 then
						entry.Health -= damageThisTick
						if entry.HpLabel then
							entry.HpLabel.Text = tostring(math.max(0, math.floor(entry.Health + 0.5)))
						end
						-- Fade the coil's main parts toward black so the
						-- player can see damage even without reading HP.
						local pct = math.clamp(entry.Health / (entry.MaxHealth or 1), 0, 1)
						entry.Plate.Color = entry.Cfg.Color:Lerp(Color3.fromRGB(40, 20, 20), 1 - pct)
						if entry.Health <= 0 then
							entry.Model:Destroy()
							table.remove(defenses, i)
							continue
						end
					end
				elseif entry.Type == "Mine" and entry.Armed then
					for _, z in ipairs(zombies) do
						if z.Humanoid.Health > 0 then
							local d = (z.RootPart.Position - entry.Model.Position).Magnitude
							if d <= 4 then
								explode(entry.Model.Position, entry.Cfg.Radius, entry.Cfg.Damage)
								entry.Model:Destroy()
								table.remove(defenses, i)
								break
							end
						end
					end
				end
			end
		end
	end)
end

return DefenseManager
