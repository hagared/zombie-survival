-- Effects.lua
-- Bullet tracers, muzzle flash, hit puffs. All purely cosmetic and client-only.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	for k, v in pairs(props) do p[k] = v end
	return p
end

function Effects.Tracer(from, to, color)
	local dist = (to - from).Magnitude
	if dist < 1 then return end
	local mid = (from + to) / 2
	local beam = makePart({
		Size = Vector3.new(0.12, 0.12, dist),
		CFrame = CFrame.lookAt(mid, to),
		Material = Enum.Material.Neon,
		Color = color or Color3.fromRGB(255, 220, 110),
		Transparency = 0.1,
	})
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.25)
end

function Effects.MuzzleFlash(origin, dir)
	local flash = makePart({
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = CFrame.new(origin) * CFrame.new(dir.Unit * 0.2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 80),
		Shape = Enum.PartType.Ball,
	})
	flash.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = flash.Color
	light.Brightness = 5
	light.Range = 8
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.12), { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.2)
end

function Effects.HitPuff(position, killed)
	for i = 1, killed and 8 or 3 do
		local fragment = makePart({
			Size = Vector3.new(0.25, 0.25, 0.25),
			CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi),
			Material = Enum.Material.Neon,
			Color = killed and Color3.fromRGB(255, 90, 70) or Color3.fromRGB(220, 70, 70),
			Anchored = false,
			CanCollide = false,
		})
		fragment.Velocity = Vector3.new(math.random(-15, 15), math.random(5, 20), math.random(-15, 15))
		fragment.Parent = workspace
		TweenService:Create(fragment, TweenInfo.new(killed and 0.8 or 0.4), { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }):Play()
		Debris:AddItem(fragment, 1)
	end
end

return Effects
