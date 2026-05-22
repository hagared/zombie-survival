-- Helicopter.lua
-- Builds a CH-47 Chinook-style heavy transport: long rectangular fuselage,
-- twin tandem rotors on top (front + rear), no tail boom, and a CARGO RAMP
-- at the back that lowers down so the player can walk straight up into the
-- troop bay. The left side of the cargo bay is also open (no wall) so you
-- can see the bench full of soldiers from outside.
--
-- The "step here to host" trigger is on the ground BEHIND the helicopter,
-- right at the foot of the lowered ramp -- the natural spot to walk in.

local Helicopter = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Metal
	p.CanCollide = true
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- Helper: an offset CFrame in the helicopter's local space.
-- offsetCF(pivot, x, y, z, yawRad) returns a CFrame at (x,y,z) in pivot
-- space, optionally rotated yaw degrees around Y so the seat faces a
-- specific direction.
local function offsetCF(pivot, x, y, z, yaw)
	yaw = yaw or 0
	return pivot * CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
end

function Helicopter.Build(roomNumber, pivot)
	local model = Instance.new("Model")
	model.Name = "Heli_" .. roomNumber

	local body = Color3.fromRGB(60, 70, 55)        -- olive drab
	local accent = Color3.fromRGB(35, 40, 30)
	local glass = Color3.fromRGB(70, 100, 110)
	local floorMat = Color3.fromRGB(45, 50, 40)

	-- Reference dimensions:
	--   Total length 22 (along Z), width 8 (X), cabin height 5.5 (Y)
	--   Forward direction is local -Z (nose), aft is +Z (ramp).
	--   Local -X is the OPEN side of the cargo bay.

	-- Main fuselage = the cargo bay enclosure.
	local fuselage = makePart({
		Name = "Fuselage",
		Size = Vector3.new(8, 6, 16),
		CFrame = pivot * CFrame.new(0, 4.5, 0),
		Color = body,
	})
	fuselage.Parent = model
	model.PrimaryPart = fuselage

	-- Cockpit nose (sloped, sticks out forward / -Z).
	local nose = makePart({
		Name = "Nose",
		Size = Vector3.new(7, 4.5, 4),
		CFrame = pivot * CFrame.new(0, 4, -10) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = body,
	})
	nose.Parent = model

	-- Big front windscreen.
	local screen = makePart({
		Name = "Windscreen",
		Size = Vector3.new(6, 2.6, 0.2),
		CFrame = pivot * CFrame.new(0, 5, -12) * CFrame.Angles(math.rad(-22), 0, 0),
		Material = Enum.Material.Glass,
		Color = glass,
		Transparency = 0.3,
	})
	screen.Parent = model

	-- Side cockpit windows.
	for _, side in ipairs({ -1, 1 }) do
		local sideWin = makePart({
			Name = "SideWindow",
			Size = Vector3.new(0.2, 1.6, 3.5),
			CFrame = pivot * CFrame.new(side * 3.55, 5, -10),
			Material = Enum.Material.Glass,
			Color = glass,
			Transparency = 0.3,
		})
		sideWin.Parent = model
	end

	-- Tandem rotors (CH-47 has TWO main rotors -- front + rear, no tail rotor).
	-- Each rotor: a short pylon then a mast then two crossed blades.
	local function buildRotor(zPos, pylonH, isRear)
		local pylonY = 7 + pylonH / 2
		-- Rear pylon is taller (the iconic raised hump on a Chinook).
		local pylon = makePart({
			Name = "Pylon",
			Size = Vector3.new(3, pylonH, isRear and 5 or 4),
			CFrame = pivot * CFrame.new(0, pylonY, zPos),
			Color = body,
		})
		pylon.Parent = model
		local mastY = 7 + pylonH + 0.6
		local mast = makePart({
			Name = "Mast",
			Size = Vector3.new(0.8, 1.2, 0.8),
			CFrame = pivot * CFrame.new(0, mastY, zPos),
			Color = accent,
		})
		mast.Parent = model
		for r = 1, 2 do
			local rot = (r == 1) and 0 or math.rad(90)
			local blade = makePart({
				Name = "Blade",
				Size = Vector3.new(16, 0.18, 0.7),
				CFrame = pivot * CFrame.new(0, mastY + 0.7, zPos) * CFrame.Angles(0, rot, 0),
				Color = Color3.fromRGB(20, 20, 20),
			})
			blade.Parent = model
		end
	end
	buildRotor(-5, 1, false)   -- forward rotor (low pylon)
	buildRotor( 5, 2.5, true)  -- rear rotor (taller "hump" pylon)

	-- Quad landing gear (Chinooks have 4 wheels, not skids).
	for _, off in ipairs({
		Vector3.new(-3, 0.8, -5), Vector3.new(3, 0.8, -5),
		Vector3.new(-3, 0.8, 5),  Vector3.new(3, 0.8, 5),
	}) do
		local strut = makePart({
			Name = "Strut",
			Size = Vector3.new(0.4, 1.6, 0.4),
			CFrame = pivot * CFrame.new(off.X, off.Y, off.Z),
			Color = accent,
		})
		strut.Parent = model
		local wheel = makePart({
			Name = "Wheel",
			Size = Vector3.new(0.6, 1.4, 1.4),
			CFrame = pivot * CFrame.new(off.X, 0.7, off.Z),
			Material = Enum.Material.Rubber,
			Color = Color3.fromRGB(25, 25, 25),
		})
		wheel.Parent = model
	end

	-- ===================================================================
	-- Cargo bay interior. The bay is the inside of the fuselage:
	--   floor at y=1.5
	--   right wall (closed)  at x=+3.7
	--   roof (closed)        at y=7.4
	--   front wall (closed)  at z=-7.5  (separates from cockpit)
	--   LEFT wall: OPEN -- no part. You see straight into the troop bay.
	--   REAR: OPEN -- replaced by the cargo ramp lowered down.
	-- ===================================================================
	local cabinFloor = makePart({
		Name = "CabinFloor",
		Size = Vector3.new(7.6, 0.3, 15.5),
		CFrame = pivot * CFrame.new(0, 1.65, 0),
		Material = Enum.Material.Metal,
		Color = floorMat,
	})
	cabinFloor.Parent = model

	local cabinRightWall = makePart({
		Name = "CabinRightWall",
		Size = Vector3.new(0.3, 5, 15.5),
		CFrame = pivot * CFrame.new(3.85, 4.5, 0),
		Color = body,
	})
	cabinRightWall.Parent = model

	local cabinFrontWall = makePart({
		Name = "CabinFrontWall",
		Size = Vector3.new(7.6, 5, 0.3),
		CFrame = pivot * CFrame.new(0, 4.5, -7.85),
		Color = body,
	})
	cabinFrontWall.Parent = model

	-- Single long bench against the right wall (since the left wall is the
	-- open viewing side, the bench sits on the closed right side facing
	-- out toward the open bay -- looks like 4 soldiers ready to deploy).
	local benchY = 2.6
	local benchX = 2.7
	local bench = makePart({
		Name = "Bench",
		Size = Vector3.new(1.4, 0.9, 13),
		CFrame = pivot * CFrame.new(benchX, benchY, 0),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(50, 45, 35),
	})
	bench.Parent = model
	local benchBack = makePart({
		Name = "BenchBack",
		Size = Vector3.new(0.4, 1.7, 13),
		CFrame = pivot * CFrame.new(benchX + 0.6, benchY + 1.05, 0),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(40, 35, 28),
	})
	benchBack.Parent = model

	-- 4 seat CFrames along the bench. Players face the OPEN side (-X),
	-- so we rotate the seat by -90 degrees around Y so their LookVector
	-- points along world-equivalent -X (out the open bay).
	local seatX = 1.5
	local seatY = benchY + 1.6
	local seatCFrames = {
		offsetCF(pivot, seatX, seatY, -4.5, -math.pi / 2),
		offsetCF(pivot, seatX, seatY, -1.5, -math.pi / 2),
		offsetCF(pivot, seatX, seatY,  1.5, -math.pi / 2),
		offsetCF(pivot, seatX, seatY,  4.5, -math.pi / 2),
	}

	-- ===================================================================
	-- Rear cargo ramp. The iconic Chinook "lowered ramp" -- a big plate
	-- hinged at the back of the cabin floor, angled down to ground level
	-- so the player walks UP the ramp to get inside.
	-- ===================================================================
	local rampLength = 7
	local rampAngle = math.rad(-30) -- pitched down at the back
	-- We position the ramp so its top edge meets the cabin floor at z=+7.75
	-- and its lower edge rests on the ground further back.
	local rampCenterZ = 7.75 + math.cos(rampAngle) * rampLength / 2
	local rampCenterY = 1.5 + math.sin(rampAngle) * rampLength / 2
	local ramp = makePart({
		Name = "CargoRamp",
		Size = Vector3.new(7.6, 0.4, rampLength),
		CFrame = pivot * CFrame.new(0, rampCenterY, rampCenterZ) * CFrame.Angles(rampAngle, 0, 0),
		Material = Enum.Material.DiamondPlate,
		Color = floorMat,
	})
	ramp.Parent = model
	-- Side rails along the ramp so it reads as a real ramp, not a flat plate.
	for _, side in ipairs({ -1, 1 }) do
		local rail = makePart({
			Name = "RampRail",
			Size = Vector3.new(0.3, 0.6, rampLength),
			CFrame = pivot * CFrame.new(side * 3.7, rampCenterY + 0.5, rampCenterZ) * CFrame.Angles(rampAngle, 0, 0),
			Color = accent,
		})
		rail.Parent = model
	end

	-- ===================================================================
	-- Trigger pad on the ground BEHIND the ramp. Stepping on it joins
	-- this helicopter's room. Invisible Part + visible glowing strip
	-- with a floating sign so the player can find it.
	-- ===================================================================
	local TRIGGER_W = 7
	local TRIGGER_D = 5
	-- Foot of the ramp lands at z = 7.75 + cos(angle) * length = ~13.8.
	-- Put the trigger another ~2 studs further back so the player has to
	-- approach the ramp deliberately, not by accidentally clipping it.
	local triggerOffsetZ = 14.5
	local triggerPart = makePart({
		Name = "JoinTrigger",
		Size = Vector3.new(TRIGGER_D + 1, 2, TRIGGER_W + 1),
		CFrame = pivot * CFrame.new(0, 1, triggerOffsetZ),
		Transparency = 1,
		CanCollide = false,
	})
	triggerPart:SetAttribute("RoomNumber", roomNumber)
	triggerPart.Parent = model

	local neonStrip = makePart({
		Name = "NeonStrip",
		Size = Vector3.new(TRIGGER_W + 1, 0.1, TRIGGER_D + 1),
		CFrame = pivot * CFrame.new(0, 0.1, triggerOffsetZ),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 0.15,
	})
	neonStrip.CanCollide = false
	neonStrip.Parent = model
	local glow = Instance.new("PointLight")
	glow.Brightness = 1.8
	glow.Range = 14
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Parent = neonStrip

	local sign = Instance.new("BillboardGui")
	sign.Adornee = neonStrip
	sign.Size = UDim2.fromOffset(180, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	sign.AlwaysOnTop = false
	sign.Parent = neonStrip
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "ROOM #" .. roomNumber .. "\nstep up to host"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(190, 230, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextWrapped = true
	label.Parent = sign

	-- Big tail number painted on the rear pylon hump.
	local tailLabel = Instance.new("BillboardGui")
	tailLabel.Adornee = fuselage
	tailLabel.Size = UDim2.fromOffset(140, 70)
	tailLabel.StudsOffsetWorldSpace = Vector3.new(4.1, 1, 4)
	tailLabel.AlwaysOnTop = false
	tailLabel.Parent = fuselage
	local tailText = Instance.new("TextLabel")
	tailText.BackgroundTransparency = 1
	tailText.Size = UDim2.fromScale(1, 1)
	tailText.Text = "#" .. roomNumber
	tailText.Font = Enum.Font.GothamBlack
	tailText.TextSize = 42
	tailText.TextColor3 = Color3.fromRGB(220, 200, 130)
	tailText.TextStrokeTransparency = 0
	tailText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	tailText.Parent = tailLabel

	model:SetAttribute("RoomNumber", roomNumber)

	return model, triggerPart, seatCFrames
end

return Helicopter
