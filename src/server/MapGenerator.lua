-- MapGenerator.lua
-- Procedurally builds the arena: a ruined-city map. Cracked asphalt streets,
-- half-collapsed brick buildings (some missing roofs / walls), wrecked cars,
-- concrete debris piles, and a fortified plaza in the middle where players
-- spawn and defend. Mountains around the perimeter form the visual horizon
-- and an invisible barrier stops zombies from wandering off.
--
-- All geometry is built from primitive Parts -- no MeshParts, no asset IDs.

local Workspace = game:GetService("Workspace")

local MapGenerator = {}

local MAP_SIZE = 420 -- length of one side of the playable arena
local MOUNTAIN_BAND = 80
local SPAWN_POINTS = {}
local ZOMBIE_SPAWN_POINTS = {}

-- ---------- helpers ----------

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

-- ---------- ground / streets / plaza ----------

local function buildGround(parent)
	-- Cracked dark earth, the post-apocalypse "everything is dirt now" floor.
	local ground = makePart({
		Name = "Ground",
		Size = Vector3.new(MAP_SIZE, 4, MAP_SIZE),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(48, 42, 36),
	})
	ground.Parent = parent

	-- Cracked asphalt streets: a square loop with crossroads. Slightly raised
	-- above the ground so the dirt edges are visible.
	local roadColor = Color3.fromRGB(40, 38, 40)
	local roadW = 18
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

	-- Sprinkle a few cracked-concrete debris patches across the streets so
	-- they don't read as a clean Roblox surface.
	local rng = Random.new(13371)
	for i = 1, 80 do
		local cx = rng:NextNumber(-half, half)
		local cz = rng:NextNumber(-half, half)
		-- Skip the central plaza area, we'll place plaza-specific debris later.
		if math.abs(cx) > 35 or math.abs(cz) > 35 then
			local crack = makePart({
				Name = "Crack",
				Size = Vector3.new(rng:NextNumber(2, 6), 0.2, rng:NextNumber(2, 6)),
				CFrame = CFrame.new(cx, 0.2, cz) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(70, 65, 60):Lerp(Color3.fromRGB(35, 30, 28), rng:NextNumber()),
			})
			crack.Parent = parent
		end
	end
end

local function buildPlaza(parent)
	-- The "last stand" plaza: a fortified concrete pad with sandbag walls.
	local plaza = makePart({
		Name = "Plaza",
		Size = Vector3.new(60, 0.6, 60),
		Position = Vector3.new(0, 0.3, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(120, 115, 105),
	})
	plaza.Parent = parent

	-- Sandbag perimeter -- low walls just on the corners so zombies still
	-- have to come at you, but the plaza reads as defended.
	local sandColor = Color3.fromRGB(110, 95, 65)
	for _, corner in ipairs({
		Vector3.new(28, 1, 28), Vector3.new(-28, 1, 28),
		Vector3.new(28, 1, -28), Vector3.new(-28, 1, -28),
	}) do
		local sb = makePart({
			Name = "Sandbags",
			Size = Vector3.new(10, 1.6, 2),
			CFrame = CFrame.new(corner) * CFrame.Angles(0, math.rad(45), 0),
			Material = Enum.Material.Sand,
			Color = sandColor,
		})
		sb.Parent = parent
	end

	-- Four glowing spawn pads (kept from the old map -- player respawns).
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

-- ---------- ruined buildings ----------

-- Build one building in a half-collapsed state. Each building is laid out
-- on a footprint w x l, height h, but:
--   * one of the four walls is randomly missing (collapsed)
--   * another wall might have a chunk torn out the middle
--   * the roof has a 50% chance of being absent (sky-open ruin)
--   * a pile of broken bricks/concrete rubble sits where the missing wall
--     was, so the building reads as "fell over here"
--   * the south wall always has a doorway gap (sealed by an invisible
--     CanCollide block so AI can't path inside)
local function buildRuinedBuilding(parent, cf, w, l, h, palette, rng)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent

	local wallThick = 1

	-- Cracked / stained concrete floor.
	local floor = makePart({
		Size = Vector3.new(w, 0.6, l),
		CFrame = cf * CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Concrete,
		Color = palette.floor,
	})
	floor.Parent = model

	local function wall(size, offset, color)
		local p = makePart({
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Material = Enum.Material.Brick,
			Color = color or palette.wall,
		})
		p.Parent = model
		return p
	end

	-- Pick which wall is "fully collapsed" -- it just isn't built. Choose
	-- between the three non-south walls (south is the doorway side, we
	-- always keep that wall for visual definition).
	local collapsed = ({ "north", "east", "west" })[rng:NextInteger(1, 3)]

	-- North wall
	if collapsed ~= "north" then
		wall(Vector3.new(w, h, wallThick), Vector3.new(0, h / 2, -l / 2))
	end
	-- East wall
	if collapsed ~= "east" then
		wall(Vector3.new(wallThick, h, l), Vector3.new(w / 2, h / 2, 0))
	end
	-- West wall
	if collapsed ~= "west" then
		wall(Vector3.new(wallThick, h, l), Vector3.new(-w / 2, h / 2, 0))
	end

	-- South wall: doorway gap with two side pieces + header (always present).
	local doorW = 4
	local sideW = (w - doorW) / 2
	if sideW > 0 then
		wall(Vector3.new(sideW, h, wallThick), Vector3.new(-(doorW / 2 + sideW / 2), h / 2, l / 2))
		wall(Vector3.new(sideW, h, wallThick), Vector3.new((doorW / 2 + sideW / 2), h / 2, l / 2))
	end
	local headerH = math.max(h - 7, 1)
	wall(Vector3.new(doorW, headerH, wallThick), Vector3.new(0, h - headerH / 2, l / 2))

	-- Invisible collision pane in the doorway so AI stays out (same trick
	-- as the original map).
	local gapH = math.min(h - headerH, 7)
	if gapH > 0 then
		local block = makePart({
			Name = "DoorBlock",
			Size = Vector3.new(doorW, gapH, wallThick),
			CFrame = cf * CFrame.new(0, gapH / 2, l / 2),
			Transparency = 1,
		})
		block.CanCollide = true
		block.CastShadow = false
		block.Parent = model
	end

	-- Roof: 50% present, 50% open ruin. If present, we tilt it slightly and
	-- chip off a corner to keep the "broken" feel.
	if rng:NextNumber() < 0.5 then
		local roof = makePart({
			Size = Vector3.new(w + 1, 0.6, l + 1),
			CFrame = cf * CFrame.new(0, h + 0.3, 0) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04)),
			Material = Enum.Material.Slate,
			Color = palette.roof,
		})
		roof.Parent = model
	end

	-- Rubble pile where the collapsed wall used to be.
	local rubblePos
	if collapsed == "north" then rubblePos = Vector3.new(0, 0, -l / 2)
	elseif collapsed == "east" then rubblePos = Vector3.new(w / 2, 0, 0)
	else rubblePos = Vector3.new(-w / 2, 0, 0) end
	for j = 1, rng:NextInteger(3, 6) do
		local rsx = rng:NextNumber(1.5, 3.5)
		local rsy = rng:NextNumber(0.6, 2.0)
		local rsz = rng:NextNumber(1.5, 3.5)
		local off = rubblePos + Vector3.new(rng:NextNumber(-2, 2), rsy / 2, rng:NextNumber(-2, 2))
		local chunk = makePart({
			Name = "Rubble",
			Size = Vector3.new(rsx, rsy, rsz),
			CFrame = cf * CFrame.new(off) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Concrete,
			Color = palette.floor:Lerp(Color3.fromRGB(50, 45, 40), rng:NextNumber(0.3, 0.7)),
		})
		chunk.Parent = model
	end

	-- Exposed rebar -- a couple of thin dark bars sticking out of the rubble.
	for j = 1, rng:NextInteger(0, 3) do
		local bar = makePart({
			Name = "Rebar",
			Size = Vector3.new(0.15, rng:NextNumber(2, 4), 0.15),
			CFrame = cf * CFrame.new(rubblePos + Vector3.new(rng:NextNumber(-2, 2), 0.6, rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 35, 25),
		})
		bar.Parent = model
	end
end

local function buildBuildings(parent)
	-- Faded, weathered colours -- think apocalypse reds, blue-greys, bone.
	local palettes = {
		{ wall = Color3.fromRGB(120, 60, 50), floor = Color3.fromRGB(80, 75, 70), roof = Color3.fromRGB(45, 35, 35) },
		{ wall = Color3.fromRGB(110, 95, 80), floor = Color3.fromRGB(90, 85, 80), roof = Color3.fromRGB(60, 50, 40) },
		{ wall = Color3.fromRGB(70, 80, 90), floor = Color3.fromRGB(100, 100, 100), roof = Color3.fromRGB(40, 50, 60) },
		{ wall = Color3.fromRGB(95, 65, 50), floor = Color3.fromRGB(85, 80, 75), roof = Color3.fromRGB(55, 45, 40) },
		{ wall = Color3.fromRGB(85, 80, 70), floor = Color3.fromRGB(95, 90, 85), roof = Color3.fromRGB(50, 45, 40) },
	}
	local rng = Random.new(7331)

	-- Three rings of ruined buildings around the plaza.
	for ring = 1, 3 do
		local radius = 70 + ring * 35
		local count = 5 + ring * 2
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.15, 0.15) + ring * 0.3
			local cx = math.cos(angle) * radius
			local cz = math.sin(angle) * radius
			local w = rng:NextInteger(14, 26)
			local l = rng:NextInteger(14, 26)
			local h = rng:NextInteger(10, 20) -- shorter overall, ruined buildings
			local yaw = rng:NextNumber(-math.pi, math.pi)
			local palette = palettes[rng:NextInteger(1, #palettes)]
			local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, yaw, 0)
			buildRuinedBuilding(parent, cf, w, l, h, palette, rng)
		end
	end

	-- A few signature taller "skeleton" towers in the corners -- mostly
	-- frame and rubble, no roofs, dramatic silhouettes.
	for _, sign in ipairs({ Vector3.new(1, 1), Vector3.new(-1, 1), Vector3.new(1, -1), Vector3.new(-1, -1) }) do
		local cf = CFrame.new(sign.X * 150, 0, sign.Y * 150) * CFrame.Angles(0, math.rad(45), 0)
		buildRuinedBuilding(parent, cf, 22, 22, 32, palettes[3], rng)
	end
end

-- ---------- street debris: wrecked cars + barricades ----------

local function buildWreckedCar(parent, cf, palette)
	-- Burned-out hulk: rectangular body, no glass, four squished tyres,
	-- a charred top.
	local model = Instance.new("Model")
	model.Name = "Wreck"
	model.Parent = parent

	local body = makePart({
		Size = Vector3.new(4.5, 1.4, 2.2),
		CFrame = cf * CFrame.new(0, 1.0, 0),
		Material = Enum.Material.Metal,
		Color = palette.body,
	})
	body.Parent = model

	-- Top / cabin (charred, slightly tilted to read as "smashed").
	local top = makePart({
		Size = Vector3.new(2.8, 1.1, 2.0),
		CFrame = cf * CFrame.new(-0.2, 2.2, 0) * CFrame.Angles(0, 0, math.rad(palette.tilt or 0)),
		Material = Enum.Material.Metal,
		Color = palette.top,
	})
	top.Parent = model

	-- Tyres: small dark cylinders.
	for _, off in ipairs({
		Vector3.new(-1.6, 0.4, -1.05), Vector3.new(1.6, 0.4, -1.05),
		Vector3.new(-1.6, 0.4, 1.05), Vector3.new(1.6, 0.4, 1.05),
	}) do
		local t = makePart({
			Size = Vector3.new(0.5, 0.9, 0.9),
			CFrame = cf * CFrame.new(off),
			Material = Enum.Material.Rubber,
			Color = Color3.fromRGB(25, 25, 25),
		})
		t.Parent = model
	end
end

local function buildBarricade(parent, cf, rng)
	-- Stacked sandbags + a couple of wooden planks. Just enough to break
	-- up the streets visually.
	local model = Instance.new("Model")
	model.Name = "Barricade"
	model.Parent = parent

	for i = 0, rng:NextInteger(2, 4) do
		local sb = makePart({
			Size = Vector3.new(2.5, 0.7, 1.2),
			CFrame = cf * CFrame.new(rng:NextNumber(-0.3, 0.3), 0.35 + i * 0.7, rng:NextNumber(-0.3, 0.3))
				* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
			Material = Enum.Material.Sand,
			Color = Color3.fromRGB(110, 95, 65),
		})
		sb.Parent = model
	end
	if rng:NextNumber() < 0.5 then
		local plank = makePart({
			Size = Vector3.new(4, 0.2, 0.4),
			CFrame = cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(80, 55, 35),
		})
		plank.Parent = model
	end
end

local function buildStreetClutter(parent)
	local rng = Random.new(99887)
	local carPalettes = {
		{ body = Color3.fromRGB(120, 30, 30), top = Color3.fromRGB(50, 30, 25), tilt = 4 },
		{ body = Color3.fromRGB(80, 80, 90), top = Color3.fromRGB(40, 40, 45), tilt = -3 },
		{ body = Color3.fromRGB(140, 110, 50), top = Color3.fromRGB(60, 50, 30), tilt = 2 },
		{ body = Color3.fromRGB(50, 50, 55), top = Color3.fromRGB(30, 30, 35), tilt = 0 },
	}

	-- 12 wrecked cars scattered along the streets (between plaza and the
	-- inner ring of buildings, where the road loop is visible).
	for i = 1, 12 do
		local lane = rng:NextInteger(1, 4)
		local roadHalf = MAP_SIZE / 2 - 40
		local along = rng:NextNumber(-roadHalf + 15, roadHalf - 15)
		local pos
		if lane == 1 then pos = Vector3.new(along, 0, roadHalf)
		elseif lane == 2 then pos = Vector3.new(along, 0, -roadHalf)
		elseif lane == 3 then pos = Vector3.new(roadHalf, 0, along)
		else pos = Vector3.new(-roadHalf, 0, along) end
		local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
		buildWreckedCar(parent, cf, carPalettes[rng:NextInteger(1, #carPalettes)])
	end

	-- A handful of barricades sprinkled around the plaza approach.
	for i = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(45, 60)
		local cx = math.cos(angle) * r
		local cz = math.sin(angle) * r
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
		buildBarricade(parent, cf, rng)
	end
end

-- ---------- mountains (perimeter visual + path block) ----------

local function buildMountains(parent)
	local rng = Random.new(424242)
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
					-- Apocalypse palette: bleached grey-brown rather than the
					-- old "lush mountain" greens.
					Color = Color3.fromRGB(70, 65, 60):Lerp(Color3.fromRGB(110, 100, 90), rng:NextNumber()),
				})
				rock.Parent = parent

				if rng:NextNumber() < 0.7 then
					local cap = makePart({
						Name = "Cap",
						Size = Vector3.new(width * 0.55, height * 0.35, depth * 0.55),
						CFrame = CFrame.new(pos + Vector3.new(0, height * 0.55, 0)) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0),
						Material = Enum.Material.Slate,
						Color = Color3.fromRGB(140, 130, 120),
					})
					cap.Parent = parent
				end
			end
		end
	end
end

-- ---------- zombie spawn markers ----------

local function buildZombieSpawners(parent)
	local r = 65
	local count = 8
	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count) + math.pi / count
		local cx = math.cos(angle) * r
		local cz = math.sin(angle) * r
		local pos = Vector3.new(cx, 5, cz)
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

-- ---------- arena barriers ----------

local function buildArenaBarriers(parent)
	-- Invisible walls just outside the playable area + a kill plane below.
	local edgeY = 80
	local edgeT = 4
	local edgeL = MAP_SIZE + 40
	local edgeD = MAP_SIZE / 2 + 4
	local sides = {
		{ size = Vector3.new(edgeL, edgeY, edgeT), pos = Vector3.new(0, edgeY / 2, edgeD) },
		{ size = Vector3.new(edgeL, edgeY, edgeT), pos = Vector3.new(0, edgeY / 2, -edgeD) },
		{ size = Vector3.new(edgeT, edgeY, edgeL), pos = Vector3.new(edgeD, edgeY / 2, 0) },
		{ size = Vector3.new(edgeT, edgeY, edgeL), pos = Vector3.new(-edgeD, edgeY / 2, 0) },
	}
	for i, s in ipairs(sides) do
		local b = makePart({
			Name = "ArenaBarrier_" .. i,
			Size = s.size,
			Position = s.pos,
			Transparency = 1,
		})
		b.CanCollide = true
		b.CastShadow = false
		b.Parent = parent
	end

	local killBlock = makePart({
		Name = "FallKill",
		Size = Vector3.new(MAP_SIZE * 4, 1, MAP_SIZE * 4),
		Position = Vector3.new(0, -30, 0),
		Transparency = 1,
	})
	killBlock.CanCollide = false
	killBlock.CastShadow = false
	killBlock.Parent = parent
	killBlock.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
	end)
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
	buildStreetClutter(mapFolder)
	buildMountains(mapFolder)
	buildZombieSpawners(mapFolder)
	buildArenaBarriers(mapFolder)

	return mapFolder
end

function MapGenerator.GetPlayerSpawnPoints()
	return SPAWN_POINTS
end

function MapGenerator.GetZombieSpawnPoints()
	return ZOMBIE_SPAWN_POINTS
end

return MapGenerator
