-- MapGenerator.lua
-- Procedurally builds the arena: ground, mountains around the perimeter,
-- a handful of buildings, and a center plaza where players spawn.

local Workspace = game:GetService("Workspace")

local MapGenerator = {}

local MAP_SIZE = 420 -- length of one side of the arena
local MOUNTAIN_BAND = 80 -- thickness of mountain ring around arena
local SPAWN_POINTS = {}
local ZOMBIE_SPAWN_POINTS = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function buildGround(parent)
	local ground = makePart({
		Name = "Ground",
		Size = Vector3.new(MAP_SIZE, 4, MAP_SIZE),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(60, 80, 55),
	})
	ground.Parent = parent

	-- Dirt road that loops in a square so zombies have a path to wander on.
	local roadColor = Color3.fromRGB(120, 95, 70)
	local roadW = 16
	local half = MAP_SIZE / 2 - 40
	local roads = {
		{ Size = Vector3.new(half * 2, 0.4, roadW), Position = Vector3.new(0, 0.1, half) },
		{ Size = Vector3.new(half * 2, 0.4, roadW), Position = Vector3.new(0, 0.1, -half) },
		{ Size = Vector3.new(roadW, 0.4, half * 2), Position = Vector3.new(half, 0.1, 0) },
		{ Size = Vector3.new(roadW, 0.4, half * 2), Position = Vector3.new(-half, 0.1, 0) },
	}
	for _, r in ipairs(roads) do
		local rp = makePart({
			Name = "Road",
			Size = r.Size,
			Position = r.Position,
			Material = Enum.Material.Slate,
			Color = roadColor,
		})
		rp.Parent = parent
	end
end

local function buildPlaza(parent)
	local plaza = makePart({
		Name = "Plaza",
		Size = Vector3.new(60, 0.6, 60),
		Position = Vector3.new(0, 0.3, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(170, 170, 175),
	})
	plaza.Parent = parent

	-- Four spawn pads with subtle glow.
	for i, offset in ipairs({
		Vector3.new(20, 0.7, 20),
		Vector3.new(-20, 0.7, 20),
		Vector3.new(20, 0.7, -20),
		Vector3.new(-20, 0.7, -20),
	}) do
		local pad = makePart({
			Name = "SpawnPad_" .. i,
			Size = Vector3.new(8, 0.4, 8),
			Position = offset,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(80, 180, 255),
			Transparency = 0.3,
		})
		pad.Parent = parent
		table.insert(SPAWN_POINTS, offset + Vector3.new(0, 4, 0))
	end
end

local function buildBuilding(parent, cf, w, l, h, palette)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent

	local wallThick = 1
	-- floor
	local floor = makePart({
		Size = Vector3.new(w, 0.6, l),
		CFrame = cf * CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Concrete,
		Color = palette.floor,
	})
	floor.Parent = model

	-- walls (north, south, east, west with a door gap on south)
	local function wall(size, offset)
		local p = makePart({
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Material = Enum.Material.Brick,
			Color = palette.wall,
		})
		p.Parent = model
	end

	wall(Vector3.new(w, h, wallThick), Vector3.new(0, h / 2, -l / 2)) -- north
	-- south wall with a 4-stud door gap in the middle
	local doorW = 4
	local sideW = (w - doorW) / 2
	if sideW > 0 then
		wall(Vector3.new(sideW, h, wallThick), Vector3.new(-(doorW / 2 + sideW / 2), h / 2, l / 2))
		wall(Vector3.new(sideW, h, wallThick), Vector3.new((doorW / 2 + sideW / 2), h / 2, l / 2))
	end
	-- header above the door
	wall(Vector3.new(doorW, math.max(h - 7, 1), wallThick), Vector3.new(0, h - (h - 7) / 2, l / 2))

	wall(Vector3.new(wallThick, h, l), Vector3.new(w / 2, h / 2, 0)) -- east
	wall(Vector3.new(wallThick, h, l), Vector3.new(-w / 2, h / 2, 0)) -- west

	-- roof
	local roof = makePart({
		Size = Vector3.new(w + 1, 0.6, l + 1),
		CFrame = cf * CFrame.new(0, h + 0.3, 0),
		Material = Enum.Material.Slate,
		Color = palette.roof,
	})
	roof.Parent = model
end

local function buildBuildings(parent)
	local rng = Random.new(7331)
	local palettes = {
		{ wall = Color3.fromRGB(170, 90, 70), floor = Color3.fromRGB(110, 110, 115), roof = Color3.fromRGB(60, 50, 50) },
		{ wall = Color3.fromRGB(160, 150, 130), floor = Color3.fromRGB(120, 120, 120), roof = Color3.fromRGB(80, 70, 60) },
		{ wall = Color3.fromRGB(90, 100, 110), floor = Color3.fromRGB(140, 140, 140), roof = Color3.fromRGB(40, 60, 80) },
		{ wall = Color3.fromRGB(120, 80, 60), floor = Color3.fromRGB(115, 115, 115), roof = Color3.fromRGB(70, 60, 55) },
	}

	-- Place buildings in a ring around the plaza, with random sizes / rotations.
	for ring = 1, 3 do
		local radius = 70 + ring * 35
		local count = 5 + ring * 2
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.15, 0.15) + ring * 0.3
			local cx = math.cos(angle) * radius
			local cz = math.sin(angle) * radius
			local w = rng:NextInteger(14, 26)
			local l = rng:NextInteger(14, 26)
			local h = rng:NextInteger(12, 22)
			local yaw = rng:NextNumber(-math.pi, math.pi)
			local palette = palettes[rng:NextInteger(1, #palettes)]
			local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, yaw, 0)
			buildBuilding(parent, cf, w, l, h, palette)
		end
	end

	-- A few signature tall towers in the far corners.
	for _, sign in ipairs({ Vector3.new(1, 1), Vector3.new(-1, 1), Vector3.new(1, -1), Vector3.new(-1, -1) }) do
		local cf = CFrame.new(sign.X * 150, 0, sign.Y * 150) * CFrame.Angles(0, math.rad(45), 0)
		buildBuilding(parent, cf, 22, 22, 38, palettes[3])
	end
end

local function buildMountains(parent)
	local rng = Random.new(424242)
	-- Build a ring of rocky peaks around the arena edges by stacking rotated blocks.
	local half = MAP_SIZE / 2
	for side = 1, 4 do
		local axis = (side == 1 or side == 3) and "x" or "z"
		local sign = (side == 1 or side == 2) and 1 or -1
		for step = -half, half, 24 do
			local count = rng:NextInteger(2, 4)
			for j = 1, count do
				local height = rng:NextNumber(28, 60)
				local width = rng:NextNumber(20, 36)
				local depth = rng:NextNumber(20, 36)
				local pos
				if axis == "x" then
					pos = Vector3.new(step + rng:NextNumber(-6, 6), height / 2, sign * (half + MOUNTAIN_BAND / 2 + rng:NextNumber(-12, 12)))
				else
					pos = Vector3.new(sign * (half + MOUNTAIN_BAND / 2 + rng:NextNumber(-12, 12)), height / 2, step + rng:NextNumber(-6, 6))
				end
				local rock = makePart({
					Name = "Mountain",
					Size = Vector3.new(width, height, depth),
					CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-0.1, 0.1)),
					Material = Enum.Material.Rock,
					Color = Color3.fromRGB(80, 75, 70):Lerp(Color3.fromRGB(120, 110, 95), rng:NextNumber()),
				})
				rock.Parent = parent

				-- Add a smaller cap to give the mountains shape.
				if rng:NextNumber() < 0.7 then
					local cap = makePart({
						Name = "Cap",
						Size = Vector3.new(width * 0.55, height * 0.35, depth * 0.55),
						CFrame = CFrame.new(pos + Vector3.new(0, height * 0.55, 0)) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0),
						Material = Enum.Material.Slate,
						Color = Color3.fromRGB(190, 190, 195),
					})
					cap.Parent = parent
				end
			end
		end
	end
end

local function buildZombieSpawners(parent)
	-- 8 spawn points spread around the edge of the arena, on the road ring.
	local half = MAP_SIZE / 2 - 50
	local points = {
		Vector3.new(half, 5, 0), Vector3.new(-half, 5, 0),
		Vector3.new(0, 5, half), Vector3.new(0, 5, -half),
		Vector3.new(half, 5, half), Vector3.new(-half, 5, -half),
		Vector3.new(half, 5, -half), Vector3.new(-half, 5, half),
	}
	for i, pos in ipairs(points) do
		local marker = makePart({
			Name = "ZombieSpawn_" .. i,
			Size = Vector3.new(4, 0.4, 4),
			Position = pos - Vector3.new(0, 4.6, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(180, 60, 60),
			Transparency = 0.5,
		})
		marker.Parent = parent
		table.insert(ZOMBIE_SPAWN_POINTS, pos)
	end
end

function MapGenerator.Build()
	local existing = Workspace:FindFirstChild("Map")
	if existing then existing:Destroy() end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	buildGround(mapFolder)
	buildPlaza(mapFolder)
	buildBuildings(mapFolder)
	buildMountains(mapFolder)
	buildZombieSpawners(mapFolder)

	return mapFolder
end

function MapGenerator.GetPlayerSpawnPoints()
	return SPAWN_POINTS
end

function MapGenerator.GetZombieSpawnPoints()
	return ZOMBIE_SPAWN_POINTS
end

return MapGenerator
