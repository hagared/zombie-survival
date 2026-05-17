-- WeaponModels.lua
-- Builds a viewmodel-style weapon model from primitives and attaches it to
-- the player's right hand. Code-only -- no MeshParts, no external rigs.

local WeaponModels = {}

local function makePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color or Color3.fromRGB(60, 60, 65)
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	return p
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0 or CFrame.new()
	w.Parent = b
	return w
end

local builders = {}

function builders.Pistol(cfg)
	local model = Instance.new("Model")
	model.Name = "Pistol"

	local grip = makePart("Grip", Vector3.new(0.4, 0.9, 0.5), cfg.Color)
	grip.CFrame = CFrame.new(0, 0, 0)
	grip.Parent = model
	model.PrimaryPart = grip

	local body = makePart("Body", Vector3.new(0.4, 0.5, 1.2), cfg.Color)
	body.Parent = model
	weld(grip, body, CFrame.new(0, 0.6, -0.4))

	local barrel = makePart("Barrel", Vector3.new(0.2, 0.2, cfg.BarrelLength), cfg.Color:Lerp(Color3.new(0,0,0), 0.3))
	barrel.Parent = model
	weld(grip, barrel, CFrame.new(0, 0.7, -1 - cfg.BarrelLength / 2))

	local sight = makePart("Sight", Vector3.new(0.1, 0.15, 0.2), Color3.fromRGB(80, 80, 80))
	sight.Parent = model
	weld(grip, sight, CFrame.new(0, 0.95, -0.4))

	return model
end

function builders.Shotgun(cfg)
	local model = Instance.new("Model")
	model.Name = "Shotgun"

	local stock = makePart("Stock", Vector3.new(0.5, 0.5, 1.4), cfg.Color)
	stock.Parent = model
	model.PrimaryPart = stock

	local grip = makePart("Grip", Vector3.new(0.45, 0.8, 0.4), cfg.Color)
	grip.Parent = model
	weld(stock, grip, CFrame.new(0, -0.4, -0.7))

	-- Two side-by-side barrels for the "two bullet lines".
	for i, side in ipairs({ -0.18, 0.18 }) do
		local barrel = makePart("Barrel" .. i, Vector3.new(0.22, 0.22, cfg.BarrelLength), Color3.fromRGB(40, 30, 25))
		barrel.Parent = model
		weld(stock, barrel, CFrame.new(side, 0.1, -1.4 - cfg.BarrelLength / 2))
	end

	local pump = makePart("Pump", Vector3.new(0.5, 0.4, 0.5), Color3.fromRGB(50, 35, 25))
	pump.Parent = model
	weld(stock, pump, CFrame.new(0, -0.2, -1.4))
	return model
end

function builders.Rifle(cfg)
	local model = Instance.new("Model")
	model.Name = "Rifle"

	local body = makePart("Body", Vector3.new(0.45, 0.55, 1.6), cfg.Color)
	body.Parent = model
	model.PrimaryPart = body

	local stock = makePart("Stock", Vector3.new(0.45, 0.5, 0.8), cfg.Color:Lerp(Color3.new(0,0,0), 0.4))
	stock.Parent = model
	weld(body, stock, CFrame.new(0, 0, 1.0))

	local grip = makePart("Grip", Vector3.new(0.4, 0.8, 0.4), cfg.Color)
	grip.Parent = model
	weld(body, grip, CFrame.new(0, -0.6, 0))

	local mag = makePart("Mag", Vector3.new(0.4, 0.8, 0.5), Color3.fromRGB(40, 40, 40))
	mag.Parent = model
	weld(body, mag, CFrame.new(0, -0.6, -0.4))

	local barrel = makePart("Barrel", Vector3.new(0.22, 0.22, cfg.BarrelLength), Color3.fromRGB(35, 35, 35))
	barrel.Parent = model
	weld(body, barrel, CFrame.new(0, 0.05, -0.8 - cfg.BarrelLength / 2))

	return model
end

function builders.Minigun(cfg)
	local model = Instance.new("Model")
	model.Name = "Minigun"

	local body = makePart("Body", Vector3.new(0.7, 0.7, 1.6), cfg.Color)
	body.Parent = model
	model.PrimaryPart = body

	local grip = makePart("Grip", Vector3.new(0.4, 0.9, 0.4), cfg.Color)
	grip.Parent = model
	weld(body, grip, CFrame.new(0, -0.7, 0.2))

	-- Rotating barrel cluster (3 barrels matching the "3 bullet lines").
	local cluster = Instance.new("Model")
	cluster.Name = "BarrelCluster"
	cluster.Parent = model
	local clusterCore = makePart("ClusterCore", Vector3.new(0.5, 0.5, 0.2), cfg.Color:Lerp(Color3.new(0,0,0), 0.4))
	clusterCore.Parent = cluster
	cluster.PrimaryPart = clusterCore
	weld(body, clusterCore, CFrame.new(0, 0, -0.9))

	for i = 1, 3 do
		local angle = (i - 1) * (math.pi * 2 / 3)
		local offset = Vector3.new(math.cos(angle) * 0.18, math.sin(angle) * 0.18, 0)
		local barrel = makePart("Barrel" .. i, Vector3.new(0.18, 0.18, cfg.BarrelLength), Color3.fromRGB(45, 45, 50))
		barrel.Parent = cluster
		weld(clusterCore, barrel, CFrame.new(offset.X, offset.Y, -cfg.BarrelLength / 2 - 0.1))
	end

	return model, cluster
end

-- cfg = Config.Weapons entry. Returns the model and an optional "extra" table
-- the caller can use to animate parts (e.g. the minigun barrel cluster).
function WeaponModels.Build(id, cfg)
	local builder = builders[id]
	if not builder then return nil end
	return builder(cfg)
end

return WeaponModels
