-- Helicopter.lua
-- Builds a small military-style helicopter from primitives. The cockpit is
-- where players stand to "join" this room. Each helicopter has a unique
-- room number painted on the tail.

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

-- Build a single helicopter at the given pivot. Returns the model + a
-- reference to the cockpit floor (the ProximityPrompt anchor).
function Helicopter.Build(roomNumber, pivot)
	local model = Instance.new("Model")
	model.Name = "Heli_" .. roomNumber

	local body = Color3.fromRGB(60, 70, 55)        -- olive drab
	local accent = Color3.fromRGB(35, 40, 30)
	local glass = Color3.fromRGB(70, 100, 110)

	-- Main fuselage.
	local fuselage = makePart({
		Name = "Fuselage",
		Size = Vector3.new(6, 4, 9),
		CFrame = pivot * CFrame.new(0, 3, 0),
		Color = body,
	})
	fuselage.Parent = model
	model.PrimaryPart = fuselage

	-- Cockpit nose -- a wedge / tilted block at the front.
	local nose = makePart({
		Name = "Nose",
		Size = Vector3.new(5.2, 3, 3.5),
		CFrame = pivot * CFrame.new(0, 3, -5.8) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = body,
	})
	nose.Parent = model

	-- Big front windscreen (slightly transparent neon for a "cockpit glass" feel).
	local screen = makePart({
		Name = "Windscreen",
		Size = Vector3.new(4.5, 2.4, 0.2),
		CFrame = pivot * CFrame.new(0, 3.4, -7.3) * CFrame.Angles(math.rad(-30), 0, 0),
		Material = Enum.Material.Glass,
		Color = glass,
		Transparency = 0.3,
	})
	screen.Parent = model

	-- Tail boom.
	local tail = makePart({
		Name = "Tail",
		Size = Vector3.new(1.6, 1.6, 8),
		CFrame = pivot * CFrame.new(0, 4, 7),
		Color = body,
	})
	tail.Parent = model

	-- Tail rotor (vertical fin + small disk).
	local fin = makePart({
		Name = "Fin",
		Size = Vector3.new(0.4, 3.5, 1.5),
		CFrame = pivot * CFrame.new(0.4, 5, 10),
		Color = accent,
	})
	fin.Parent = model
	local tailRotor = makePart({
		Name = "TailRotor",
		Size = Vector3.new(0.6, 3, 0.2),
		CFrame = pivot * CFrame.new(-0.4, 5.2, 10.5),
		Color = Color3.fromRGB(20, 20, 20),
	})
	tailRotor.Parent = model

	-- Skids (landing gear).
	for _, off in ipairs({ Vector3.new(2.4, 0.4, 0), Vector3.new(-2.4, 0.4, 0) }) do
		local skid = makePart({
			Name = "Skid",
			Size = Vector3.new(0.4, 0.5, 8),
			CFrame = pivot * CFrame.new(off),
			Color = accent,
		})
		skid.Parent = model
		-- Connector struts to fuselage.
		local strutF = makePart({
			Name = "Strut",
			Size = Vector3.new(0.3, 1.5, 0.3),
			CFrame = pivot * CFrame.new(off + Vector3.new(0, 1, -2)),
			Color = accent,
		})
		strutF.Parent = model
		local strutB = makePart({
			Name = "Strut",
			Size = Vector3.new(0.3, 1.5, 0.3),
			CFrame = pivot * CFrame.new(off + Vector3.new(0, 1, 2)),
			Color = accent,
		})
		strutB.Parent = model
	end

	-- Main rotor mast + blades. Two crossed blades to read as a rotor.
	local mast = makePart({
		Name = "Mast",
		Size = Vector3.new(0.6, 1.2, 0.6),
		CFrame = pivot * CFrame.new(0, 5.8, 0),
		Color = accent,
	})
	mast.Parent = model
	for r = 1, 2 do
		local rot = (r == 1) and 0 or math.rad(90)
		local blade = makePart({
			Name = "Blade",
			Size = Vector3.new(13, 0.18, 0.6),
			CFrame = pivot * CFrame.new(0, 6.4, 0) * CFrame.Angles(0, rot, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(20, 20, 20),
		})
		blade.Parent = model
	end

	-- Sliding side door opening (left side) -- the player walks in here.
	-- We just leave a gap in the side; the cockpit floor inside is the
	-- "join" anchor.
	local cockpitFloor = makePart({
		Name = "CockpitFloor",
		Size = Vector3.new(5, 0.4, 6),
		CFrame = pivot * CFrame.new(0, 1.4, 0),
		Material = Enum.Material.Metal,
		Color = accent,
	})
	cockpitFloor.Parent = model

	-- Bench seats inside (just for show).
	for i = -1, 1, 2 do
		local bench = makePart({
			Name = "Bench",
			Size = Vector3.new(1.2, 1.2, 5),
			CFrame = pivot * CFrame.new(i * 1.7, 2.2, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(50, 45, 35),
		})
		bench.Parent = model
	end

	-- Big tail number painted on the side -- the room number, so the player
	-- can recognise "Helicopter 3" at a glance.
	local label = Instance.new("BillboardGui")
	label.Adornee = tail
	label.Size = UDim2.fromOffset(120, 60)
	label.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	label.AlwaysOnTop = false
	label.Parent = tail
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "#" .. roomNumber
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 36
	text.TextColor3 = Color3.fromRGB(220, 200, 130)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.Parent = label

	-- ProximityPrompt to "Enter" the helicopter -- anchored on the cockpit
	-- floor. The lobby server picks up its Triggered event and adds the
	-- player to the corresponding room.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Enter helicopter"
	prompt.ObjectText = "Room " .. roomNumber
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = cockpitFloor

	model:SetAttribute("RoomNumber", roomNumber)

	return model, cockpitFloor, prompt
end

return Helicopter
