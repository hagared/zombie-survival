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

local function buildBarbedWire(position, cfg)
	local model = Instance.new("Model")
	model.Name = "BarbedWire"
	-- A pair of crossing spike rows.
	for i = 1, 6 do
		local spike = makePart("Spike", {
			Size = Vector3.new(0.4, 1.6, 0.4),
			CFrame = CFrame.new(position + Vector3.new(-3 + i, 0.8, 0)) * CFrame.Angles(math.rad(((i % 2) * 2 - 1) * 25), 0, 0),
			Material = Enum.Material.Metal,
			Color = cfg.Color,
		})
		spike.Parent = model
	end
	local plate = makePart("Plate", {
		Size = Vector3.new(7, 0.2, 1.5),
		CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)),
		Material = Enum.Material.Metal,
		Color = cfg.Color:Lerp(Color3.new(0, 0, 0), 0.4),
		CanCollide = true,
	})
	plate.Parent = model
	model.PrimaryPart = plate
	model.Parent = Workspace
	return model, plate
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

function DefenseManager.Place(player, defenseId, position)
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
		local model, plate = buildBarbedWire(position, cfg)
		local entry = { Type = "BarbedWire", Model = model, Plate = plate, Cfg = cfg, Health = cfg.Health }
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
					for _, z in ipairs(zombies) do
						if z.Humanoid.Health > 0 then
							local d = (z.RootPart.Position - entry.Plate.Position).Magnitude
							if d <= 4 then
								require(script.Parent.ZombieAI).ApplySlow(z.Model, entry.Cfg.SlowFactor, 0.5)
								require(script.Parent.ZombieAI).ApplyDot(z.Model, entry.Cfg.DamagePerSec, 0.5)
							end
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
