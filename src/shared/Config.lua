-- Config.lua
-- Central balance / data table for the game. Tuned for fast feedback loops.

local Config = {}

Config.StartingMoney = 50

-- Weapons. Each weapon has a number of "rays" per shot (shotgun=2, minigun=3),
-- a horizontal spread between rays, damage per ray, fire rate, reserve cost, etc.
Config.Weapons = {
	Pistol = {
		Name = "Pistol",
		Order = 1,
		Price = 0, -- starter
		Damage = 18,
		Rays = 1,
		Spread = 0,
		FireRate = 0.35, -- seconds between shots
		Range = 250,
		Color = Color3.fromRGB(60, 60, 65),
		BarrelLength = 1.1,
		RecoilDeg = 6,
	},
	Shotgun = {
		Name = "Shotgun",
		Order = 2,
		Price = 220,
		Damage = 14,
		Rays = 2,
		Spread = 4, -- degrees between adjacent rays
		FireRate = 0.7,
		Range = 120,
		Color = Color3.fromRGB(80, 50, 30),
		BarrelLength = 1.6,
		RecoilDeg = 12,
	},
	Rifle = {
		Name = "Auto Rifle",
		Order = 3,
		Price = 600,
		Damage = 12,
		Rays = 1,
		Spread = 2,
		FireRate = 0.11,
		Range = 320,
		Color = Color3.fromRGB(40, 55, 40),
		BarrelLength = 1.8,
		RecoilDeg = 4,
	},
	Minigun = {
		Name = "Minigun",
		Order = 4,
		Price = 1800,
		Damage = 9,
		Rays = 3,
		Spread = 3,
		FireRate = 0.09,
		Range = 280,
		Color = Color3.fromRGB(35, 35, 40),
		BarrelLength = 2.2,
		RecoilDeg = 3,
	},
}

-- Placeable defenses. Each purchase multiplies the price.
Config.Defenses = {
	Turret = {
		Name = "Turret",
		Order = 1,
		BasePrice = 350,
		PriceMul = 1.45,
		Damage = 10,
		FireRate = 0.4,
		Range = 60,
		Health = 250,
		Color = Color3.fromRGB(60, 60, 70),
	},
	BarbedWire = {
		Name = "Barbed Wire",
		Order = 2,
		BasePrice = 80,
		PriceMul = 1.35,
		SlowFactor = 0.45, -- multiplies zombie walk speed
		DamagePerSec = 4,
		Health = 120,
		Color = Color3.fromRGB(180, 180, 180),
	},
	Mine = {
		Name = "Mine",
		Order = 3,
		BasePrice = 120,
		PriceMul = 1.5,
		Damage = 220,
		Radius = 12,
		Color = Color3.fromRGB(120, 30, 30),
	},
}

-- Zombies. Each tier unlocks at a specific wave.
Config.ZombieTiers = {
	{
		Id = "Walker",
		UnlockWave = 1,
		Health = 60,
		Damage = 8,
		WalkSpeed = 9,
		AttackCooldown = 1.0,
		BodyColor = Color3.fromRGB(70, 110, 60),
		Reward = 6,
		Scale = 1.0,
	},
	{
		Id = "Runner",
		UnlockWave = 5,
		Health = 55,
		Damage = 10,
		WalkSpeed = 16,
		AttackCooldown = 0.7,
		BodyColor = Color3.fromRGB(160, 110, 50),
		Reward = 9,
		Scale = 0.95,
	},
	{
		Id = "Brute",
		UnlockWave = 10,
		Health = 240,
		Damage = 22,
		WalkSpeed = 7,
		AttackCooldown = 1.4,
		BodyColor = Color3.fromRGB(95, 50, 50),
		Reward = 22,
		Scale = 1.45,
	},
	{
		Id = "Spitter",
		UnlockWave = 15,
		Health = 95,
		Damage = 14,
		WalkSpeed = 10,
		AttackCooldown = 2.2,
		BodyColor = Color3.fromRGB(120, 70, 140),
		Reward = 16,
		Scale = 1.1,
		Ranged = true,
		RangedRange = 45,
	},
	{
		Id = "Hellhound",
		UnlockWave = 20,
		Health = 70,
		Damage = 16,
		WalkSpeed = 22,
		AttackCooldown = 0.6,
		BodyColor = Color3.fromRGB(30, 30, 35),
		Reward = 18,
		Scale = 0.8,
	},
}

-- Wave scaling.
Config.Waves = {
	StartingZombies = 5,
	PerWaveBonus = 2, -- linear add
	GrowthMul = 1.10, -- multiplicative
	IntermissionSeconds = 12,
	HealthScalePerWave = 0.06, -- +6% hp per wave on top of base
	DamageScalePerWave = 0.03,
}

return Config
