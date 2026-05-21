-- MapGenerator.lua (lobby)
-- Builds a small ruined-city map with a fortified concrete helipad in the
-- centre. The walkable area is the helipad + a ring of asphalt around it;
-- the surrounding ruined city is BEHIND an invisible barrier so the player
-- can SEE the apocalypse but can't run off into it.

local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local MapGenerator = {}

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

-- ---------- helipad: fortified concrete pad ----------

local function buildHelipad(parent)
	local r = Config.HelipadRadius
	-- Concrete pad. We keep it as a square block but the visible hexagonal
	-- "H" landing markings in the centre sell it as a helipad.
	local pad = makePart({
		Name = "Helipad",
		Size = Vector3.new(r * 2, 2, r * 2),
		Position = Vector3.new(0, 0, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(110, 105, 95),
	})
	pad.Parent = parent

	-- Yellow-painted "H" in the middle.
	local hThick = 1.4
	local hWidth = 12
	local hHeight = 18
	local hCol = Color3.fromRGB(220, 180, 60)
	for _, off in ipairs({
		Vector3.new(-hWidth / 2, 1.05, 0),
		Vector3.new(hWidth / 2, 1.05, 0),
	}) do
		local v = makePart({
			Size = Vector3.new(hThick, 0.1, hHeight),
			Position = off,
			Material = Enum.Material.Neon,
			Color = hCol,
			Transparency = 0.1,
		})
		v.Parent = parent
	end
	local cross = makePart({
		Size = Vector3.new(hWidth, 0.1, hThick),
		Position = Vector3.new(0, 1.05, 0),
		Material = Enum.Material.Neon,
		Color = hCol,
		Transparency = 0.1,
	})
	cross.Parent = parent

	-- Sandbag walls around the pad's perimeter to read as "fortified".
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local cx = math.cos(angle) * (r - 2)
		local cz = math.sin(angle) * (r - 2)
		local sb = makePart({
			Name = "Sandbags",
			Size = Vector3.new(6, 1.5, 1.6),
			CFrame = CFrame.new(cx, 1.75, cz) * CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Sand,
			Color = Color3.fromRGB(110, 95, 65),
		})
		sb.Parent = parent
	end

	-- A few floodlight poles around the pad for atmosphere.
	for i = 0, 3 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		local cx = math.cos(angle) * (r - 4)
		local cz = math.sin(angle) * (r - 4)
		local pole = makePart({
			Size = Vector3.new(0.4, 8, 0.4),
			Position = Vector3.new(cx, 5, cz),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 65),
		})
		pole.Parent = parent
		local lamp = makePart({
			Size = Vector3.new(1.2, 0.6, 1.2),
			Position = Vector3.new(cx, 9.2, cz),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 220, 140),
			Transparency = 0.2,
		})
		lamp.Parent = parent
		local light = Instance.new("PointLight")
		light.Brightness = 1.5
		light.Range = 28
		light.Color = Color3.fromRGB(255, 220, 140)
		light.Parent = lamp
	end
end

-- ---------- ruined city around the pad (visual only, behind a wall) ----------

local function buildRuinedCity(parent)
	local rng = Random.new(20251)
	local mapHalf = Config.MapHalfSize

	-- Dirt floor extending out to the map edge.
	local ground = makePart({
		Name = "Ground",
		Size = Vector3.new(mapHalf * 2, 4, mapHalf * 2),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(48, 42, 36),
	})
	ground.Parent = parent

	-- Cracked-asphalt approach roads radiating from the helipad ring.
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local len = mapHalf - Config.HelicopterRingRadius - 5
		local mid = Config.HelicopterRingRadius + len / 2
		local cx = math.cos(angle) * mid
		local cz = math.sin(angle) * mid
		local road = makePart({
			Name = "Road",
			Size = Vector3.new(8, 0.4, len),
			CFrame = CFrame.new(cx, 0.1, cz) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(40, 38, 40),
		})
		road.Parent = parent
	end

	-- Half-collapsed buildings scattered in the outer ring (visual only).
	-- Each is just a foundation + 1-3 walls + rubble pile so the silhouette
	-- reads as ruins.
	local palettes = {
		{ wall = Color3.fromRGB(120, 60, 50), floor = Color3.fromRGB(80, 75, 70) },
		{ wall = Color3.fromRGB(110, 95, 80), floor = Color3.fromRGB(90, 85, 80) },
		{ wall = Color3.fromRGB(70, 80, 90), floor = Color3.fromRGB(100, 100, 100) },
	}
	-- Inner ruin ring (just outside the helicopter ring), and an outer ring
	-- closer to the map edge. Both are decorative.
	for ring = 1, 2 do
		local radius = Config.HelicopterRingRadius + 35 + (ring - 1) * 60
		local count = 10 + ring * 4
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local cx = math.cos(angle) * radius
			local cz = math.sin(angle) * radius
			if math.abs(cx) > Config.HelipadRadius + 8 or math.abs(cz) > Config.HelipadRadius + 8 then
				local w = rng:NextInteger(12, 22)
				local l = rng:NextInteger(12, 22)
				local h = rng:NextInteger(8, 18)
				local yaw = rng:NextNumber(-math.pi, math.pi)
				local palette = palettes[rng:NextInteger(1, #palettes)]
				local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, yaw, 0)

				-- Foundation
				local floor = makePart({
					Size = Vector3.new(w, 0.6, l),
					CFrame = cf * CFrame.new(0, 0.3, 0),
					Material = Enum.Material.Concrete,
					Color = palette.floor,
				})
				floor.Parent = parent

				-- 1-3 walls (rest collapsed)
				local wallList = { "n", "e", "w", "s" }
				local survivors = rng:NextInteger(1, 3)
				for s = 1, survivors do
					local idx = rng:NextInteger(1, #wallList)
					local side = wallList[idx]
					table.remove(wallList, idx)
					local size, off
					if side == "n" then
						size = Vector3.new(w, h, 1); off = Vector3.new(0, h / 2, -l / 2)
					elseif side == "s" then
						size = Vector3.new(w, h, 1); off = Vector3.new(0, h / 2, l / 2)
					elseif side == "e" then
						size = Vector3.new(1, h, l); off = Vector3.new(w / 2, h / 2, 0)
					else
						size = Vector3.new(1, h, l); off = Vector3.new(-w / 2, h / 2, 0)
					end
					local wall = makePart({
						Size = size,
						CFrame = cf * CFrame.new(off),
						Material = Enum.Material.Brick,
						Color = palette.wall,
					})
					wall.Parent = parent
				end

				-- Rubble pile in the middle
				for j = 1, rng:NextInteger(2, 5) do
					local rsx = rng:NextNumber(1.5, 3.5)
					local rsy = rng:NextNumber(0.5, 1.6)
					local rsz = rng:NextNumber(1.5, 3.5)
					local off = Vector3.new(rng:NextNumber(-w / 3, w / 3), rsy / 2 + 0.6, rng:NextNumber(-l / 3, l / 3))
					local chunk = makePart({
						Size = Vector3.new(rsx, rsy, rsz),
						CFrame = cf * CFrame.new(off) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-0.3, 0.3)),
						Material = Enum.Material.Concrete,
						Color = palette.floor:Lerp(Color3.fromRGB(50, 45, 40), 0.5),
					})
					chunk.Parent = parent
				end
			end
		end
	end

	-- A handful of wrecked cars on the radial roads.
	for i = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(Config.HelicopterRingRadius + 20, mapHalf - 30)
		local cx = math.cos(angle) * r
		local cz = math.sin(angle) * r
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
		local body = makePart({
			Size = Vector3.new(4.5, 1.4, 2.2),
			CFrame = cf * CFrame.new(0, 1.0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(rng:NextInteger(60, 140), rng:NextInteger(40, 80), rng:NextInteger(40, 70)),
		})
		body.Parent = parent
		local top = makePart({
			Size = Vector3.new(2.8, 1.1, 2.0),
			CFrame = cf * CFrame.new(-0.2, 2.2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-5, 5))),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(35, 30, 30),
		})
		top.Parent = parent
	end
end

-- Invisible cylindrical barrier at the edge of the helipad ring so players
-- can see the ruined city but can't walk into it. Built as 24 narrow walls
-- forming a polygonal ring.
local function buildPlayerBarrier(parent)
	local r = Config.HelicopterRingRadius + 6
	-- Slightly outside the helicopter ring so players can still walk up to
	-- and into the helicopters but can't get past them into the ruins.
	local segments = 32
	local segLen = 2 * math.pi * r / segments + 0.5
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local cx = math.cos(angle) * r
		local cz = math.sin(angle) * r
		local b = makePart({
			Name = "PlayerBarrier",
			Size = Vector3.new(segLen, 30, 1),
			CFrame = CFrame.new(cx, 15, cz) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			Transparency = 1,
		})
		b.CanCollide = true
		b.CastShadow = false
		b.Parent = parent
	end
end

-- Mountain ring out at the very edge of the visible map for a dramatic
-- horizon silhouette.
local function buildMountains(parent)
	local rng = Random.new(11117)
	local r = Config.MapHalfSize - 10
	for i = 0, 47 do
		local angle = (i / 48) * math.pi * 2
		local cx = math.cos(angle) * (r + rng:NextNumber(-15, 15))
		local cz = math.sin(angle) * (r + rng:NextNumber(-15, 15))
		local h = rng:NextNumber(45, 80)
		local rock = makePart({
			Name = "Mountain",
			Size = Vector3.new(rng:NextNumber(28, 50), h, rng:NextNumber(28, 50)),
			CFrame = CFrame.new(cx, h / 2 - 2, cz) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-0.1, 0.1)),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(70, 65, 60):Lerp(Color3.fromRGB(110, 100, 90), rng:NextNumber()),
		})
		rock.Parent = parent
	end
end

function MapGenerator.Build()
	local existing = Workspace:FindFirstChild("LobbyMap")
	if existing then existing:Destroy() end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "LobbyMap"
	mapFolder.Parent = Workspace

	buildHelipad(mapFolder)
	buildRuinedCity(mapFolder)
	buildPlayerBarrier(mapFolder)
	buildMountains(mapFolder)

	return mapFolder
end

-- Spawn pads on the helipad for player respawns.
function MapGenerator.GetSpawnPoints()
	local r = Config.HelipadRadius - 6
	local out = {}
	for i = 0, 5 do
		local angle = (i / 6) * math.pi * 2
		table.insert(out, Vector3.new(math.cos(angle) * r * 0.5, 4, math.sin(angle) * r * 0.5))
	end
	return out
end

return MapGenerator
