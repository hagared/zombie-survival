-- Config.lua
-- Central balance / data table for the game. Tuned for fast feedback loops.

local Config = {}

Config.StartingMoney = 50

-- Weapons. Each weapon has a number of "rays" per shot (shotgun=3, minigun=6),
-- a horizontal spread between rays, damage per ray, fire rate, etc.
--
-- Rough DPS targets (single target, all rays land):
--   * Pistol  ~70 DPS  -- starter, reliable
--   * Shotgun ~65 DPS but 54 burst -- close-range nuke per pump
--   * Rifle   ~125 DPS -- bread-and-butter chase weapon
--   * Minigun ~450 DPS -- top tier, melts everything in front of you
Config.Weapons = {
	Pistol = {
		Name = "Pistol",
		Order = 1,
		Price = 0, -- starter
		Damage = 22,
		Rays = 1,
		Spread = 0,
		FireRate = 0.32, -- seconds between shots
		Range = 250,
		Color = Color3.fromRGB(60, 60, 65),
		BarrelLength = 1.1,
		RecoilDeg = 6,
	},
	Shotgun = {
		Name = "Shotgun",
		Order = 2,
		Price = 250,
		Damage = 18,
		Rays = 3, -- triple-barrel: three pellets per pump in a horizontal fan
		Spread = 7, -- degrees between adjacent rays (wider than rifle)
		FireRate = 0.85,
		Range = 130,
		Color = Color3.fromRGB(80, 50, 30),
		BarrelLength = 1.6,
		RecoilDeg = 16,
	},
	Rifle = {
		Name = "Auto Rifle",
		Order = 3,
		Price = 750,
		Damage = 14,
		Rays = 1,
		Spread = 2,
		FireRate = 0.11,
		Range = 320,
		Color = Color3.fromRGB(40, 55, 40),
		BarrelLength = 1.8,
		RecoilDeg = 5,
	},
	Minigun = {
		Name = "Minigun",
		Order = 4,
		Price = 2400,
		Damage = 6,
		Rays = 6, -- six-barrel rotary: spits all six in a tight cone per shot
		Spread = 5,
		FireRate = 0.08,
		Range = 280,
		Color = Color3.fromRGB(35, 35, 40),
		BarrelLength = 2.2,
		RecoilDeg = 4,
	},
}

-- Placeable defenses. Each purchase multiplies the price.
Config.Defenses = {
	Turret = {
		Name = "Turret",
		Order = 1,
		BasePrice = 350,
		PriceMul = 1.45,
		Damage = 14,
		FireRate = 0.35,
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
		DamagePerSec = 8,
		Health = 120,
		Color = Color3.fromRGB(180, 180, 180),
	},
	Mine = {
		Name = "Mine",
		Order = 3,
		BasePrice = 120,
		PriceMul = 1.5,
		Damage = 320,
		Radius = 12,
		Color = Color3.fromRGB(120, 30, 30),
	},
}

-- Zombies. Each tier unlocks at a specific wave.
-- HP rebalanced upward to compensate for the buffed weapons (esp. Shotgun
-- 3-ray and Minigun 6-ray) so early waves stay tense and Brute / Hellhound
-- still threaten a Rifle-equipped player.
Config.ZombieTiers = {
	{
		Id = "Walker",
		UnlockWave = 1,
		Health = 70,
		Damage = 10,
		WalkSpeed = 9,
		AttackCooldown = 1.0,
		BodyColor = Color3.fromRGB(70, 110, 60),
		Reward = 8,
		Scale = 1.0,
	},
	{
		Id = "Runner",
		UnlockWave = 5,
		Health = 60,
		Damage = 12,
		WalkSpeed = 16,
		AttackCooldown = 0.7,
		BodyColor = Color3.fromRGB(160, 110, 50),
		Reward = 12,
		Scale = 0.95,
	},
	{
		Id = "Brute",
		UnlockWave = 10,
		Health = 320,
		Damage = 28,
		WalkSpeed = 7,
		AttackCooldown = 1.4,
		BodyColor = Color3.fromRGB(95, 50, 50),
		Reward = 30,
		Scale = 1.45,
	},
	{
		Id = "Spitter",
		UnlockWave = 15,
		Health = 115,
		Damage = 16,
		WalkSpeed = 10,
		AttackCooldown = 2.2,
		BodyColor = Color3.fromRGB(120, 70, 140),
		Reward = 20,
		Scale = 1.1,
		Ranged = true,
		RangedRange = 45,
	},
	{
		Id = "Hellhound",
		UnlockWave = 20,
		Health = 85,
		Damage = 20,
		WalkSpeed = 22,
		AttackCooldown = 0.6,
		BodyColor = Color3.fromRGB(30, 30, 35),
		Reward = 24,
		Scale = 0.8,
	},
}

-- Wave scaling.
Config.Waves = {
	StartingZombies = 6,
	PerWaveBonus = 2, -- linear add
	GrowthMul = 1.10, -- multiplicative
	IntermissionSeconds = 12,
	HealthScalePerWave = 0.08, -- +8% hp per wave on top of base
	DamageScalePerWave = 0.04,
}

return Config
