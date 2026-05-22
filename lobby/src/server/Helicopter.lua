-- Helicopter.lua
-- Builds a small military-style helicopter with an OPEN passenger compartment
-- (the side door is missing on purpose -- you can see the bench seats from
-- the outside) plus a glowing-edge trigger box on the ground in front of
-- the cockpit door. Stepping on the trigger box joins the helicopter's
-- room and the player is teleported onto a seat inside the compartment.

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

-- Helper: an "off-axis" position from a CFrame pivot, used by init.server.lua
-- to place each seat / trigger relative to the helicopter's nose direction.
local function offsetCF(pivot, x, y, z)
	return pivot:ToWorldSpace(CFrame.new(x, y, z))
end

-- Build a single helicopter at the given pivot.
-- Returns:
--   model       -- the Model instance (just parent it under Workspace)
--   triggerPart -- the invisible "stand here to host" pad part. Connect
--                  Touched on this from init.server.lua.
--   seatCFrames -- array of 4 CFrames for the passenger benches inside.
--                  init.server.lua uses these to PivotTo the player's
--                  character when they join the room.
function Helicopter.Build(roomNumber, pivot)
	local model = Instance.new("Model")
	model.Name = "Heli_" .. roomNumber

	local body = Color3.fromRGB(60, 70, 55)        -- olive drab
	local accent = Color3.fromRGB(35, 40, 30)
	local glass = Color3.fromRGB(70, 100, 110)
	local floorMat = Color3.fromRGB(45, 50, 40)

	-- Main fuselage. Slightly wider than before so the open cabin reads.
	local fuselage = makePart({
		Name = "Fuselage",
		Size = Vector3.new(7, 4.5, 10),
		CFrame = pivot * CFrame.new(0, 3.5, 0),
		Color = body,
	})
	fuselage.Parent = model
	model.PrimaryPart = fuselage

	-- Cockpit nose -- a wedge / tilted block at the front (negative Z is "forward").
	local nose = makePart({
		Name = "Nose",
		Size = Vector3.new(5.4, 3, 3.5),
		CFrame = pivot * CFrame.new(0, 3.5, -6.4) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = body,
	})
	nose.Parent = model

	-- Big front windscreen.
	local screen = makePart({
		Name = "Windscreen",
		Size = Vector3.new(4.8, 2.5, 0.2),
		CFrame = pivot * CFrame.new(0, 3.9, -7.9) * CFrame.Angles(math.rad(-30), 0, 0),
		Material = Enum.Material.Glass,
		Color = glass,
		Transparency = 0.3,
	})
	screen.Parent = model

	-- Tail boom.
	local tail = makePart({
		Name = "Tail",
		Size = Vector3.new(1.6, 1.6, 8),
		CFrame = pivot * CFrame.new(0, 4.5, 7.5),
		Color = body,
	})
	tail.Parent = model

	-- Vertical fin + tail rotor.
	local fin = makePart({
		Name = "Fin",
		Size = Vector3.new(0.4, 3.5, 1.5),
		CFrame = pivot * CFrame.new(0.4, 5.5, 10.5),
		Color = accent,
	})
	fin.Parent = model
	local tailRotor = makePart({
		Name = "TailRotor",
		Size = Vector3.new(0.6, 3, 0.2),
		CFrame = pivot * CFrame.new(-0.4, 5.7, 11),
		Color = Color3.fromRGB(20, 20, 20),
	})
	tailRotor.Parent = model

	-- Skids (landing gear) + connector struts.
	for _, off in ipairs({ Vector3.new(2.7, 0.4, 0), Vector3.new(-2.7, 0.4, 0) }) do
		local skid = makePart({
			Name = "Skid",
			Size = Vector3.new(0.4, 0.5, 9),
			CFrame = pivot * CFrame.new(off),
			Color = accent,
		})
		skid.Parent = model
		local strutF = makePart({
			Name = "Strut",
			Size = Vector3.new(0.3, 1.7, 0.3),
			CFrame = pivot * CFrame.new(off + Vector3.new(0, 1.1, -2.5)),
			Color = accent,
		})
		strutF.Parent = model
		local strutB = makePart({
			Name = "Strut",
			Size = Vector3.new(0.3, 1.7, 0.3),
			CFrame = pivot * CFrame.new(off + Vector3.new(0, 1.1, 2.5)),
			Color = accent,
		})
		strutB.Parent = model
	end

	-- Main rotor mast + two crossed blades.
	local mast = makePart({
		Name = "Mast",
		Size = Vector3.new(0.6, 1.2, 0.6),
		CFrame = pivot * CFrame.new(0, 6.5, 0),
		Color = accent,
	})
	mast.Parent = model
	for r = 1, 2 do
		local rot = (r == 1) and 0 or math.rad(90)
		local blade = makePart({
			Name = "Blade",
			Size = Vector3.new(14, 0.18, 0.7),
			CFrame = pivot * CFrame.new(0, 7.1, 0) * CFrame.Angles(0, rot, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(20, 20, 20),
		})
		blade.Parent = model
	end

	-- ===================================================================
	-- Open passenger compartment.
	-- The whole left side of the fuselage is "missing" (no wall), so you
	-- can see straight into the cabin where players sit on benches. We
	-- fake this by NOT building a left-side panel and putting a visible
	-- floor + back wall + two parallel benches inside.
	-- ===================================================================

	-- Cabin floor (raised slightly, painted dark to read as "interior").
	local cabinFloor = makePart({
		Name = "CabinFloor",
		Size = Vector3.new(6.8, 0.3, 6.5),
		CFrame = pivot * CFrame.new(0, 1.85, 0),
		Material = Enum.Material.Metal,
		Color = floorMat,
	})
	cabinFloor.Parent = model

	-- Right wall of the cabin (the closed side).
	local cabinRightWall = makePart({
		Name = "CabinWall",
		Size = Vector3.new(0.3, 3, 6.5),
		CFrame = pivot * CFrame.new(3.3, 3.5, 0),
		Material = Enum.Material.Metal,
		Color = body,
	})
	cabinRightWall.Parent = model

	-- Cabin back wall (separates passenger compartment from the tail boom).
	local cabinBackWall = makePart({
		Name = "CabinBackWall",
		Size = Vector3.new(6.8, 3, 0.3),
		CFrame = pivot * CFrame.new(0, 3.5, 3.3),
		Material = Enum.Material.Metal,
		Color = body,
	})
	cabinBackWall.Parent = model

	-- Cabin front wall (separates cabin from the cockpit / nose).
	local cabinFrontWall = makePart({
		Name = "CabinFrontWall",
		Size = Vector3.new(6.8, 3, 0.3),
		CFrame = pivot * CFrame.new(0, 3.5, -3.3),
		Material = Enum.Material.Metal,
		Color = body,
	})
	cabinFrontWall.Parent = model

	-- Two passenger benches running front-to-back along each side of the
	-- cabin. Players sit facing each other, two per bench, four total.
	local benchY = 2.6  -- top surface of bench
	for _, side in ipairs({ -1, 1 }) do
		local bench = makePart({
			Name = "Bench",
			Size = Vector3.new(1.4, 0.9, 5.5),
			CFrame = pivot * CFrame.new(side * 1.8, benchY, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(50, 45, 35),
		})
		bench.Parent = model
		local back = makePart({
			Name = "BenchBack",
			Size = Vector3.new(0.4, 1.6, 5.5),
			CFrame = pivot * CFrame.new(side * 2.4, benchY + 1.0, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(40, 35, 28),
		})
		back.Parent = model
	end

	-- Compute four seat CFrames (head-on) so init.server.lua can teleport
	-- the player onto each bench. Two per side, spaced along Z.
	-- Y is bench top (2.6) + ~1.5 capsule half-height = ~4.1 above ground.
	local seatY = benchY + 1.6
	local seatCFrames = {
		offsetCF(pivot, -1.8, seatY, -1.5),
		offsetCF(pivot, -1.8, seatY,  1.5),
		offsetCF(pivot,  1.8, seatY, -1.5),
		offsetCF(pivot,  1.8, seatY,  1.5),
	}

	-- ===================================================================
	-- Trigger pad on the ground in front of the cabin opening.
	-- Invisible (Transparency = 1) box that the lobby server hooks Touched
	-- on, with a thin glowing neon strip JUST under it so the pad is
	-- discoverable to the player without breaking the apocalypse aesthetic.
	-- ===================================================================
	local TRIGGER_W = 6
	local TRIGGER_D = 4
	-- The cabin opening is on the -X (left) side of the helicopter. Place
	-- the trigger 6.5 studs out from the helicopter, centered along the
	-- cabin length, just barely above the floor.
	local triggerOffset = Vector3.new(-6.5, 1, 0)
	local triggerPart = makePart({
		Name = "JoinTrigger",
		Size = Vector3.new(TRIGGER_D, 2, TRIGGER_W),
		CFrame = pivot * CFrame.new(triggerOffset),
		Transparency = 1,
		CanCollide = false,
	})
	triggerPart:SetAttribute("RoomNumber", roomNumber)
	triggerPart.Parent = model

	-- The neon strip: a flat bar painted on the ground that pulses so the
	-- player notices "step here". Sized to match the trigger.
	local neonStrip = makePart({
		Name = "NeonStrip",
		Size = Vector3.new(TRIGGER_D + 0.2, 0.1, TRIGGER_W + 0.2),
		CFrame = pivot * CFrame.new(triggerOffset.X, 0.1, triggerOffset.Z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 200, 255),
		Transparency = 0.15,
	})
	neonStrip.CanCollide = false
	neonStrip.Parent = model
	local glow = Instance.new("PointLight")
	glow.Brightness = 1.5
	glow.Range = 12
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Parent = neonStrip
	-- Floating "ROOM #N -- step to host" sign above the strip.
	local sign = Instance.new("BillboardGui")
	sign.Adornee = neonStrip
	sign.Size = UDim2.fromOffset(160, 50)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	sign.AlwaysOnTop = false
	sign.Parent = neonStrip
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "ROOM #" .. roomNumber .. "\nstep to host"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(190, 230, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextWrapped = true
	label.Parent = sign

	-- Big tail number painted on the side -- the room number, so the
	-- player can recognise "Helicopter 3" at a glance.
	local tailLabel = Instance.new("BillboardGui")
	tailLabel.Adornee = tail
	tailLabel.Size = UDim2.fromOffset(120, 60)
	tailLabel.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	tailLabel.AlwaysOnTop = false
	tailLabel.Parent = tail
	local tailText = Instance.new("TextLabel")
	tailText.BackgroundTransparency = 1
	tailText.Size = UDim2.fromScale(1, 1)
	tailText.Text = "#" .. roomNumber
	tailText.Font = Enum.Font.GothamBlack
	tailText.TextSize = 36
	tailText.TextColor3 = Color3.fromRGB(220, 200, 130)
	tailText.TextStrokeTransparency = 0
	tailText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	tailText.Parent = tailLabel

	model:SetAttribute("RoomNumber", roomNumber)

	return model, triggerPart, seatCFrames
end

return Helicopter
