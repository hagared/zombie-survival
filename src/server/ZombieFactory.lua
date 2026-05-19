-- ZombieFactory.lua
-- Builds zombie humanoid models in code, using the **standard Roblox R6 rig
-- layout** (HumanoidRootPart + Torso + Head + Left/Right Arm/Leg with the
-- joint names Roblox's Humanoid expects). Doing it that way means Roblox's
-- own humanoid standup / walk / animation logic just works -- no fighting
-- with HipHeight or custom rig quirks.
--
-- A procedural shambling-zombie animation is driven on top of the R6 motors
-- via Heartbeat (see Animate). No AnimationTracks/external assets are used.

local RunService = game:GetService("RunService")

local ZombieFactory = {}

-- Base R6 sizes (Roblox's stock R6 character is a `s=1` reference). Every
-- tier multiplies these by `tier.Scale` so bigger zombies are uniformly
-- bigger.
local R6 = {
	HRP = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	Arm = Vector3.new(1, 2, 1),
	Leg = Vector3.new(1, 2, 1),
}

local function newPart(name, size, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide == true
	return p
end

local function joint(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0 or CFrame.new()
	m.C1 = c1 or CFrame.new()
	m.Parent = p0
	return m
end

function ZombieFactory.Create(tier, waveHealthMul, waveDamageMul)
	local s = tier.Scale or 1
	local color = tier.BodyColor

	local model = Instance.new("Model")
	model.Name = "Zombie_" .. tier.Id

	-- Parts. HRP and arms are non-collide; torso, head and legs collide so
	-- the model physically rests on its feet (standard R6 setup).
	local hrp = newPart("HumanoidRootPart", R6.HRP * s, color, Enum.Material.SmoothPlastic, false)
	hrp.Transparency = 1
	hrp.Massless = true
	hrp.Parent = model
	model.PrimaryPart = hrp

	local torso = newPart("Torso", R6.Torso * s, color, Enum.Material.SmoothPlastic, true)
	torso.Parent = model

	local head = newPart("Head", R6.Head * s, color:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.SmoothPlastic, true)
	head.Parent = model
	-- Round the head visually using the built-in head mesh (no external assets).
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local lArm = newPart("Left Arm", R6.Arm * s, color, Enum.Material.SmoothPlastic, false)
	lArm.Parent = model
	local rArm = newPart("Right Arm", R6.Arm * s, color, Enum.Material.SmoothPlastic, false)
	rArm.Parent = model
	local lLeg = newPart("Left Leg", R6.Leg * s, color, Enum.Material.SmoothPlastic, true)
	lLeg.Parent = model
	local rLeg = newPart("Right Leg", R6.Leg * s, color, Enum.Material.SmoothPlastic, true)
	rLeg.Parent = model

	-- Position the parts roughly where the welds will hold them, so physics
	-- doesn't have to resolve a giant offset on spawn.
	hrp.CFrame = CFrame.new(0, 0, 0)
	torso.CFrame = CFrame.new(0, 0, 0)
	head.CFrame = CFrame.new(0, 1.5 * s, 0)
	lArm.CFrame = CFrame.new(-1.5 * s, 0, 0)
	rArm.CFrame = CFrame.new(1.5 * s, 0, 0)
	lLeg.CFrame = CFrame.new(-0.5 * s, -2 * s, 0)
	rLeg.CFrame = CFrame.new(0.5 * s, -2 * s, 0)

	-- Standard R6 Motor6D joints. Offsets are Roblox's stock R6 character
	-- verbatim, scaled by `s`.
	local rootJoint = joint("RootJoint", hrp, torso,
		CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0),
		CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
	local neck = joint("Neck", torso, head,
		CFrame.new(0, 1 * s, 0) * CFrame.Angles(0, math.pi, 0),
		CFrame.new(0, -0.5 * s, 0) * CFrame.Angles(0, math.pi, 0))
	local lShoulder = joint("Left Shoulder", torso, lArm,
		CFrame.new(-1 * s, 0.5 * s, 0), CFrame.new(0.5 * s, 0.5 * s, 0))
	local rShoulder = joint("Right Shoulder", torso, rArm,
		CFrame.new(1 * s, 0.5 * s, 0), CFrame.new(-0.5 * s, 0.5 * s, 0))
	local lHip = joint("Left Hip", torso, lLeg,
		CFrame.new(-1 * s, -1 * s, 0), CFrame.new(-0.5 * s, 1 * s, 0))
	local rHip = joint("Right Hip", torso, rLeg,
		CFrame.new(1 * s, -1 * s, 0), CFrame.new(0.5 * s, 1 * s, 0))

	-- Glowing eyes for flavour (welded to head, non-collide).
	for _, off in ipairs({ Vector3.new(-0.3, 0.1, -0.5), Vector3.new(0.3, 0.1, -0.5) }) do
		local eye = newPart("Eye", Vector3.new(0.18, 0.18, 0.18) * s, Color3.fromRGB(255, 220, 80), Enum.Material.Neon, false)
		eye.Parent = model
		eye.CFrame = head.CFrame * CFrame.new(off * s)
		local w = Instance.new("Weld")
		w.Part0 = head
		w.Part1 = eye
		w.C0 = CFrame.new(off * s)
		w.Parent = eye
	end

	-- Humanoid. R6 rig type so Roblox's stock standup/walk applies.
	-- For a scaled rig the HRP center needs to sit at y = 3*s instead of
	-- y = 3, so HipHeight = (3*s - 3) -- works for upscaled and downscaled
	-- tiers (HipHeight can be negative for s < 1).
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 3 * s - 3
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
	model:SetAttribute("RigScale", s)

	-- Pack motors + their base C0 so the animator can drive deltas on top
	-- without recomputing the rest-pose offsets every frame.
	local motors = {
		Root = { motor = rootJoint, c0 = rootJoint.C0 },
		Neck = { motor = neck, c0 = neck.C0 },
		LeftShoulder = { motor = lShoulder, c0 = lShoulder.C0 },
		RightShoulder = { motor = rShoulder, c0 = rShoulder.C0 },
		LeftHip = { motor = lHip, c0 = lHip.C0 },
		RightHip = { motor = rHip, c0 = rHip.C0 },
	}

	return model, humanoid, motors
end

-- Drive a procedural shambling-zombie animation on the R6 motors. Runs on
-- Heartbeat and cleans itself up when the humanoid dies / model is gone.
--
-- Layers:
--   * IDLE    -- subtle breathing sway, head loll
--   * WALK    -- legs swing, torso tilts side to side, arms reach forward
--             with a counter-sway, and the body bobs vertically a touch
--   * ATTACK  -- short pose triggered by ZombieAI when the zombie strikes:
--             whole upper body lurches forward and arms slam down (melee)
--             or both arms thrust toward the target (spit). Driven by the
--             "AttackingUntil" attribute on the model: ZombieAI sets it to
--             os.clock() + duration, the animator interpolates a punch /
--             thrust until that time.
--   * DEATH   -- snapping joints + impulse on the Torso so corpses tip
--             over in a believable direction instead of standing rigid.
function ZombieFactory.Animate(model, motors)
	local phase = math.random() * math.pi * 2
	local bob = math.random() * math.pi * 2
	local conn
	local diedHandled = false
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	-- Ragdoll on death: break joints + give the torso a small backward
	-- shove so the corpse falls in a direction matching the kill, and
	-- recolor the body slightly grey for that "spent" look. We also turn
	-- HumanoidRootPart non-massless temporarily so the parts settle on
	-- the ground instead of floating.
	local function ragdoll()
		if diedHandled then return end
		diedHandled = true
		local torso = model:FindFirstChild("Torso")
		local hrp = model:FindFirstChild("HumanoidRootPart")
		-- Break every Motor6D so each limb becomes its own free part. The
		-- Humanoid dies regardless; we just want a tumbling corpse.
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				d:Destroy()
			end
		end
		if torso then
			torso.Color = torso.Color:Lerp(Color3.fromRGB(60, 60, 65), 0.4)
			-- Toss the torso a bit in the look direction so it falls forward.
			local dir = torso.CFrame.LookVector
			torso.AssemblyLinearVelocity = Vector3.new(dir.X, 0.5, dir.Z) * 14
				+ Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
			torso.AssemblyAngularVelocity = Vector3.new(
				(math.random() - 0.5) * 8,
				(math.random() - 0.5) * 8,
				(math.random() - 0.5) * 8
			)
		end
		if hrp then hrp.Massless = false end
	end

	if humanoid then
		humanoid.Died:Connect(ragdoll)
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			conn:Disconnect()
			return
		end
		if not humanoid or humanoid.Health <= 0 then
			ragdoll()
			conn:Disconnect()
			return
		end

		phase += dt * 6
		bob += dt * 12
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local amp = moving and 1 or 0.18
		local s = math.sin(phase) * amp
		local c = math.cos(phase) * amp

		-- Active attack window? Mix in a punch / thrust pose. Strength
		-- ramps in over the first ~half then ramps out, so it reads as
		-- a single deliberate swing rather than a sudden snap.
		local attackingUntil = model:GetAttribute("AttackingUntil") or 0
		local now = os.clock()
		local atk = 0
		if attackingUntil > now then
			local windowSize = 0.4
			local timeLeft = attackingUntil - now
			-- Bell-curve: 0 at edges, 1 in the middle of the window.
			atk = math.clamp(1 - math.abs((windowSize - timeLeft) / (windowSize * 0.5) - 1), 0, 1)
		end

		-- LEGS: slow shamble swing forward/back. Almost no swing while
		-- standing still (just a tiny breathing wobble).
		motors.LeftHip.motor.C0 = motors.LeftHip.c0 * CFrame.Angles(s * 0.8, 0, 0)
		motors.RightHip.motor.C0 = motors.RightHip.c0 * CFrame.Angles(-s * 0.8, 0, 0)

		-- TORSO: side-to-side stagger plus a vertical bob while walking.
		-- The bob is achieved by tweaking the Root joint Y offset --
		-- visually it looks like the zombie is dragging itself forward.
		local torsoTilt = moving and (math.sin(phase) * 0.12) or 0
		local torsoBob = moving and (math.sin(bob) * 0.08) or 0
		motors.Root.motor.C0 = motors.Root.c0
			* CFrame.new(0, torsoBob, 0)
			* CFrame.Angles(atk * 0.6, 0, torsoTilt)

		-- ARMS: classic outstretched-forward zombie pose with a lazy
		-- counter-sway from the legs. During an attack swing both arms
		-- snap upward (+atk * 0.9 makes the rotation more aggressive)
		-- to read as a slam / lunge.
		local armForward = 1.3
		local armSwing = 0.18
		motors.LeftShoulder.motor.C0 = motors.LeftShoulder.c0
			* CFrame.Angles(armForward + c * armSwing - atk * 0.9, 0, 0)
		motors.RightShoulder.motor.C0 = motors.RightShoulder.c0
			* CFrame.Angles(armForward - c * armSwing - atk * 0.9, 0, 0)

		-- HEAD: slow loll left/right, tilt down during attack.
		motors.Neck.motor.C0 = motors.Neck.c0
			* CFrame.Angles(
				math.sin(phase * 0.5) * 0.2 + atk * 0.3,
				0,
				math.sin(phase * 0.3) * 0.18
			)
	end)
end

return ZombieFactory
