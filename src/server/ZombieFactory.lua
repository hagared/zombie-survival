-- ZombieFactory.lua
-- Builds humanoid zombie models entirely from primitives plus a code-driven
-- walk/attack animation loop. No external rigs or animations are required.

local RunService = game:GetService("RunService")

local ZombieFactory = {}

local function makePart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color or Color3.fromRGB(80, 100, 70)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	return p
end

local function weld(a, b, c0, c1)
	local w = Instance.new("Motor6D")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0 or CFrame.new()
	w.C1 = c1 or CFrame.new()
	w.Parent = a
	return w
end

-- Build a zombie model from primitives. `tier` is a Config tier table.
function ZombieFactory.Create(tier, waveHealthMul, waveDamageMul)
	local s = tier.Scale or 1
	local model = Instance.new("Model")
	model.Name = "Zombie_" .. tier.Id

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1) * s, tier.BodyColor)
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	local torso = makePart("Torso", Vector3.new(2, 2, 1) * s, tier.BodyColor)
	torso.CanCollide = true
	torso.Parent = model
	local torsoWeld = weld(root, torso, CFrame.new(0, 0, 0))

	local head = makePart("Head", Vector3.new(1.2, 1.2, 1.2) * s, tier.BodyColor:Lerp(Color3.new(1, 1, 1), 0.1))
	head.Shape = Enum.PartType.Ball
	head.CanCollide = true
	head.Parent = model
	local headWeld = weld(torso, head, CFrame.new(0, 1.6 * s, 0))

	-- eyes
	for _, off in ipairs({ Vector3.new(-0.25, 0.1, -0.5), Vector3.new(0.25, 0.1, -0.5) }) do
		local eye = makePart("Eye", Vector3.new(0.18, 0.18, 0.18) * s, Color3.fromRGB(255, 220, 80), Enum.Material.Neon)
		eye.CFrame = head.CFrame * CFrame.new(off * s)
		eye.Parent = model
		weld(head, eye, CFrame.new(off * s))
	end

	local function makeLimb(name, parent, c0, color)
		local limb = makePart(name, Vector3.new(0.9, 2.2, 0.9) * s, color or tier.BodyColor)
		limb.CanCollide = false
		limb.Parent = model
		local m = weld(parent, limb, c0)
		return limb, m
	end

	local _, lArm = makeLimb("LeftArm", torso, CFrame.new(-1.4 * s, 0.2, 0))
	local _, rArm = makeLimb("RightArm", torso, CFrame.new(1.4 * s, 0.2, 0))
	local _, lLeg = makeLimb("LeftLeg", torso, CFrame.new(-0.5 * s, -2.0 * s, 0))
	local _, rLeg = makeLimb("RightLeg", torso, CFrame.new(0.5 * s, -2.0 * s, 0))

	-- Humanoid for damage / death handling.
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = tier.Health * (waveHealthMul or 1)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = tier.WalkSpeed
	humanoid.AutoRotate = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	-- Attributes used by other systems.
	model:SetAttribute("Tier", tier.Id)
	model:SetAttribute("Reward", tier.Reward)
	model:SetAttribute("BaseSpeed", tier.WalkSpeed)
	model:SetAttribute("Damage", tier.Damage * (waveDamageMul or 1))
	model:SetAttribute("AttackCooldown", tier.AttackCooldown)
	model:SetAttribute("Ranged", tier.Ranged == true)
	model:SetAttribute("RangedRange", tier.RangedRange or 0)

	-- Hide internal Motor6Ds in the explorer (cosmetic).
	for _, j in ipairs(model:GetDescendants()) do
		if j:IsA("Motor6D") then
			j.Archivable = false
		end
	end

	-- Stash motors on the model for the animator to reach later.
	local motors = {
		LeftArm = lArm, RightArm = rArm, LeftLeg = lLeg, RightLeg = rLeg, Head = headWeld, Torso = torsoWeld,
	}
	return model, humanoid, motors
end

-- Drive a procedural walk/attack animation on the zombie's motors. Runs on
-- Heartbeat; cleaned up automatically when the model is destroyed.
function ZombieFactory.Animate(model, motors)
	local phase = math.random() * math.pi * 2
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			conn:Disconnect()
			return
		end

		phase += dt * 6
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local amp = moving and 1 or 0.15
		local s = math.sin(phase) * amp
		local c = math.cos(phase) * amp
		motors.LeftLeg.C0 = CFrame.new(-0.5, -2.0, 0) * CFrame.Angles(s * 0.9, 0, 0)
		motors.RightLeg.C0 = CFrame.new(0.5, -2.0, 0) * CFrame.Angles(-s * 0.9, 0, 0)
		-- Arms outstretched forward, with subtle sway.
		motors.LeftArm.C0 = CFrame.new(-1.4, 0.2, -0.6) * CFrame.Angles(-1.1 + c * 0.2, 0, 0.15)
		motors.RightArm.C0 = CFrame.new(1.4, 0.2, -0.6) * CFrame.Angles(-1.1 - c * 0.2, 0, -0.15)
		-- Head lolls.
		motors.Head.C0 = CFrame.new(0, 1.6, 0) * CFrame.Angles(math.sin(phase * 0.5) * 0.2, 0, math.sin(phase * 0.3) * 0.15)
	end)
end

return ZombieFactory
