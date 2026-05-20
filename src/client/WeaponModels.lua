-- WeaponModels.lua
-- Builds a viewmodel-style weapon model from primitives and attaches it to
-- the player's right hand. Code-only -- no MeshParts, no external rigs.
--
-- Each weapon's barrel count matches the Config Rays count: shotgun has
-- 3 visible barrels (3 pellets per pump), minigun has 6 visible barrels in
-- a circle (6 rays per burst). The first/center barrel is always named
-- "Barrel" or "Barrel1" so WeaponClient can find it for muzzle flash.

local WeaponModels = {}

-- ---------- helpers ----------

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

local function cylinder(name, diameter, length, color, material)
	local p = makePart(name, Vector3.new(length, diameter, diameter), color, material)
	-- Cylinders use the Shape property to render as round. We need to rotate
	-- so the long axis is along Z (forward) -- Roblox cylinders extrude
	-- along the X axis by default.
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = p
	-- Reorient by adjusting Size: we want forward-axis length to be `length`.
	p.Size = Vector3.new(diameter, diameter, length)
	mesh.Offset = Vector3.new(0, 0, 0)
	mesh.Scale = Vector3.new(1, 1, 1)
	-- Switch the mesh so it extrudes along Z. Easiest: swap to a SpecialMesh
	-- in cylinder mode pointing forward. CylinderMesh always uses the part's
	-- Y axis as the cylinder's long axis. Workaround: rotate the part 90deg
	-- around X via the Weld C0.
	return p
end

-- Simpler approach: a small helper that builds a forward-facing cylinder
-- using a SpecialMesh + a rectangular part. Roblox auto-renders the part
-- as a slim cylinder via the mesh, and the part's Size already says
-- "thin and long along Z".
local function barrelTube(name, diameter, length, color)
	local p = makePart(name, Vector3.new(diameter, diameter, length), color, Enum.Material.Metal)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	-- SpecialMesh Cylinder is along X by default. Rotate via the Scale +
	-- mesh offset doesn't transpose axes. Cleanest: use a CylinderMesh and
	-- accept that the long axis is Y, then rotate the whole part. But we
	-- want Size.Z to be the length so the welding code stays simple.
	-- Use SpecialMesh with Scale = (length, diameter, diameter) and rotate
	-- the part 90deg around Y via its CFrame.
	mesh.Parent = p
	mesh.Scale = Vector3.new(length / p.Size.X, 1, 1)
	-- Reset to a long-along-X box and let the mesh handle visuals; we'll
	-- compensate in the weld by flipping rotation.
	p.Size = Vector3.new(length, diameter, diameter)
	p.Name = name
	return p
end

local function weld(a, b, c0, c1)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0 or CFrame.new()
	w.C1 = c1 or CFrame.new()
	w.Parent = b
	return w
end

-- Attach a forward-facing barrel cylinder to `parent` at offset `pos`.
-- Length runs along the local -Z axis. We use a thin rectangular Part with
-- a CylinderMesh and rotate it so the cylinder points forward.
local function addBarrel(model, parent, name, diameter, length, color, pos)
	local p = makePart(name, Vector3.new(diameter, diameter, length), color, Enum.Material.Metal)
	-- CylinderMesh extrudes along Y. Rotate 90deg around X so it extrudes
	-- along Z, the same axis that p.Size.Z occupies.
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = p
	mesh.Offset = Vector3.new(0, 0, 0)
	-- CylinderMesh uses (radius, height, radius). We want height = length.
	mesh.Scale = Vector3.new(diameter / p.Size.X, length / p.Size.Y, diameter / p.Size.Z)
	-- Rotate so cylinder's Y axis points along world -Z (forward).
	p.Parent = model
	weld(parent, p, CFrame.new(pos) * CFrame.Angles(math.rad(90), 0, 0))
	return p
end

-- Same as addBarrel but the part is a chunky block with no mesh -- used for
-- bodies, stocks, mags, etc. that don't need to look round.
local function addBlock(model, parent, name, size, color, pos, rotCF)
	local p = makePart(name, size, color, Enum.Material.Metal)
	p.Parent = model
	local c0 = CFrame.new(pos)
	if rotCF then c0 = c0 * rotCF end
	weld(parent, p, c0)
	return p
end

-- ---------- weapon builders ----------

local builders = {}

-- Pistol: slide, frame, grip, trigger guard, magazine, sights, single barrel.
function builders.Pistol(cfg)
	local model = Instance.new("Model")
	model.Name = "Pistol"

	local bodyColor = cfg.Color
	local accent = cfg.Color:Lerp(Color3.new(0, 0, 0), 0.4)

	-- Grip is the root the player's hand holds.
	local grip = makePart("Grip", Vector3.new(0.5, 1.2, 0.55), bodyColor, Enum.Material.Plastic)
	grip.Parent = model
	model.PrimaryPart = grip

	-- Frame above the grip.
	addBlock(model, grip, "Frame", Vector3.new(0.5, 0.45, 1.4), bodyColor, Vector3.new(0, 0.85, -0.35))
	-- Slide on top of the frame, slightly accent-coloured for contrast.
	addBlock(model, grip, "Slide", Vector3.new(0.55, 0.4, 1.45), accent, Vector3.new(0, 1.3, -0.35))
	-- Trigger guard.
	addBlock(model, grip, "Guard", Vector3.new(0.4, 0.5, 0.5), accent, Vector3.new(0, 0.3, -0.05))
	-- Magazine sticking out the bottom.
	addBlock(model, grip, "Mag", Vector3.new(0.4, 0.3, 0.5), accent, Vector3.new(0, -0.7, 0.0))
	-- Front + rear sights.
	addBlock(model, grip, "FrontSight", Vector3.new(0.08, 0.12, 0.1), accent, Vector3.new(0, 1.6, -1.0))
	addBlock(model, grip, "RearSight", Vector3.new(0.4, 0.12, 0.15), accent, Vector3.new(0, 1.6, 0.25))

	-- Single barrel.
	addBarrel(model, grip, "Barrel", 0.22, cfg.BarrelLength, accent,
		Vector3.new(0, 1.05, -1.05 - cfg.BarrelLength / 2))

	return model
end

-- Shotgun: triple-barrel. Three thick barrels arranged in a horizontal row
-- so the visual matches the 3 bullet lines per shot.
function builders.Shotgun(cfg)
	local model = Instance.new("Model")
	model.Name = "Shotgun"

	local stockColor = cfg.Color
	local metal = Color3.fromRGB(38, 30, 26)
	local wood = Color3.fromRGB(110, 70, 40)

	local stock = makePart("Stock", Vector3.new(0.55, 0.55, 1.6), wood, Enum.Material.Wood)
	stock.Parent = model
	model.PrimaryPart = stock

	-- Buttstock at the back.
	addBlock(model, stock, "Buttstock", Vector3.new(0.55, 0.7, 0.5), wood, Vector3.new(0, 0.05, 1.05))
	-- Pistol grip below.
	addBlock(model, stock, "Grip", Vector3.new(0.45, 0.9, 0.45), wood, Vector3.new(0, -0.65, 0.4),
		CFrame.Angles(math.rad(-12), 0, 0))
	-- Receiver block in front of the stock, where barrels meet.
	addBlock(model, stock, "Receiver", Vector3.new(0.7, 0.6, 0.7), metal, Vector3.new(0, 0, -1.1))
	-- Pump under the barrels.
	addBlock(model, stock, "Pump", Vector3.new(0.55, 0.35, 0.55), wood, Vector3.new(0, -0.35, -1.7))

	-- Three barrels in a horizontal fan: left, center (named "Barrel" so the
	-- weapon-client muzzle-flash code finds it), right.
	local barrelLen = cfg.BarrelLength
	addBarrel(model, stock, "Barrel1", 0.22, barrelLen, metal,
		Vector3.new(-0.32, 0.2, -1.4 - barrelLen / 2))
	addBarrel(model, stock, "Barrel", 0.22, barrelLen, metal,
		Vector3.new(0, 0.2, -1.4 - barrelLen / 2))
	addBarrel(model, stock, "Barrel3", 0.22, barrelLen, metal,
		Vector3.new(0.32, 0.2, -1.4 - barrelLen / 2))

	-- Top sight rib running along the center barrel.
	addBlock(model, stock, "Rib", Vector3.new(0.05, 0.05, barrelLen * 0.7), metal,
		Vector3.new(0, 0.42, -1.4 - barrelLen * 0.35))

	return model
end

-- Auto Rifle: receiver, magazine, fore-grip, stock, scope, suppressor.
function builders.Rifle(cfg)
	local model = Instance.new("Model")
	model.Name = "Rifle"

	local body = cfg.Color
	local accent = cfg.Color:Lerp(Color3.new(0, 0, 0), 0.5)
	local plastic = Color3.fromRGB(20, 25, 20)

	-- Receiver is the central body.
	local receiver = makePart("Receiver", Vector3.new(0.5, 0.6, 1.7), body, Enum.Material.Metal)
	receiver.Parent = model
	model.PrimaryPart = receiver

	-- Hand-guard / fore-end (around the front half of the rifle).
	addBlock(model, receiver, "Foreend", Vector3.new(0.55, 0.55, 1.0), accent,
		Vector3.new(0, 0, -1.2))
	-- Stock at the back.
	addBlock(model, receiver, "Stock", Vector3.new(0.45, 0.55, 0.95), plastic,
		Vector3.new(0, -0.05, 1.15))
	addBlock(model, receiver, "StockButt", Vector3.new(0.5, 0.7, 0.3), plastic,
		Vector3.new(0, 0.05, 1.7))

	-- Pistol grip.
	addBlock(model, receiver, "Grip", Vector3.new(0.4, 0.9, 0.45), plastic,
		Vector3.new(0, -0.7, 0.4),
		CFrame.Angles(math.rad(-12), 0, 0))
	-- Trigger guard.
	addBlock(model, receiver, "Guard", Vector3.new(0.36, 0.4, 0.5), accent,
		Vector3.new(0, -0.3, 0.2))
	-- Magazine in front of the grip.
	addBlock(model, receiver, "Mag", Vector3.new(0.42, 1.0, 0.55), accent,
		Vector3.new(0, -0.85, 0.0))

	-- Scope on top.
	addBlock(model, receiver, "ScopeBase", Vector3.new(0.4, 0.12, 0.6), accent,
		Vector3.new(0, 0.4, 0.1))
	addBarrel(model, receiver, "ScopeTube", 0.32, 0.7, plastic,
		Vector3.new(0, 0.65, 0.1))
	-- Front + rear scope rings (visual flair).
	addBarrel(model, receiver, "ScopeFront", 0.4, 0.1, accent,
		Vector3.new(0, 0.65, -0.25))
	addBarrel(model, receiver, "ScopeRear", 0.4, 0.1, accent,
		Vector3.new(0, 0.65, 0.45))

	-- Single long barrel.
	addBarrel(model, receiver, "Barrel", 0.22, cfg.BarrelLength, accent,
		Vector3.new(0, 0.05, -1.7 - cfg.BarrelLength / 2))
	-- Suppressor on the muzzle for that "premium rifle" look.
	addBarrel(model, receiver, "Suppressor", 0.32, 0.5, plastic,
		Vector3.new(0, 0.05, -1.7 - cfg.BarrelLength - 0.25))

	return model
end

-- Minigun: chunky body + grip + 6-barrel rotary cluster (matches Rays=6).
function builders.Minigun(cfg)
	local model = Instance.new("Model")
	model.Name = "Minigun"

	local body = cfg.Color
	local accent = cfg.Color:Lerp(Color3.new(0, 0, 0), 0.4)
	local barrelMat = Color3.fromRGB(50, 50, 55)
	local ammoCol = Color3.fromRGB(170, 130, 50)

	-- Bulky receiver body.
	local receiver = makePart("Receiver", Vector3.new(0.95, 0.95, 1.7), body, Enum.Material.Metal)
	receiver.Parent = model
	model.PrimaryPart = receiver

	-- Massive front grip / handle on the underside.
	addBlock(model, receiver, "Grip", Vector3.new(0.4, 1.0, 0.5), accent,
		Vector3.new(0, -0.85, 0.4),
		CFrame.Angles(math.rad(-8), 0, 0))
	-- Rear support handle.
	addBlock(model, receiver, "RearHandle", Vector3.new(0.35, 0.7, 0.35), accent,
		Vector3.new(0, -0.55, 1.05))
	-- Trigger guard near the front grip.
	addBlock(model, receiver, "Guard", Vector3.new(0.32, 0.4, 0.5), accent,
		Vector3.new(0, -0.4, 0.2))

	-- Big drum magazine on top to read as "lots of ammo".
	addBarrel(model, receiver, "AmmoDrum", 0.85, 0.5, ammoCol,
		Vector3.new(0, 0.85, 0.0))
	addBlock(model, receiver, "AmmoBelt", Vector3.new(0.25, 0.25, 0.7), ammoCol,
		Vector3.new(0.25, 0.6, 0.6))

	-- Forward muzzle housing -- the thing the spinning barrels attach to.
	addBarrel(model, receiver, "MuzzleHousing", 0.85, 0.4, accent,
		Vector3.new(0, 0, -1.0))

	-- Spinning 6-barrel cluster. Same hierarchy the old code used so the
	-- per-frame spin in WeaponClient still works (it expects a Model named
	-- "BarrelCluster" or similar with PrimaryPart set).
	local cluster = Instance.new("Model")
	cluster.Name = "BarrelCluster"
	cluster.Parent = model
	local clusterCore = makePart("ClusterCore", Vector3.new(0.55, 0.55, 0.2), accent, Enum.Material.Metal)
	clusterCore.Parent = cluster
	cluster.PrimaryPart = clusterCore
	weld(receiver, clusterCore, CFrame.new(0, 0, -1.25))

	-- Six barrels arranged on a circle. The first one is named "Barrel"
	-- (no number) so WeaponClient can find it for muzzle flash. The other
	-- five are Barrel2..Barrel6.
	local clusterRadius = 0.28
	local barrelLen = cfg.BarrelLength
	local barrelDia = 0.18
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6)
		local ox = math.cos(angle) * clusterRadius
		local oy = math.sin(angle) * clusterRadius
		local name = (i == 1) and "Barrel" or ("Barrel" .. i)
		addBarrel(model, clusterCore, name, barrelDia, barrelLen, barrelMat,
			Vector3.new(ox, oy, -barrelLen / 2 - 0.1))
	end

	return model, cluster
end

-- ---------- public API ----------

-- cfg = Config.Weapons entry. Returns the model and an optional "extra" value
-- the caller can use to animate parts (e.g. the minigun barrel cluster).
function WeaponModels.Build(id, cfg)
	local builder = builders[id]
	if not builder then return nil end
	return builder(cfg)
end

return WeaponModels
