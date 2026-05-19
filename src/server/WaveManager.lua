-- WaveManager.lua
-- Endless waves. Every wave: spawn N zombies of allowed tiers, wait for them
-- to die, broadcast intermission, repeat. Every 4-5 waves, zombie roster
-- and count grows automatically through `Config.ZombieTiers` unlock waves and
-- the wave growth formula.

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ZombieFactory = require(script.Parent.ZombieFactory)
local ZombieAI = require(script.Parent.ZombieAI)
local MapGenerator = require(script.Parent.MapGenerator)

local WaveManager = {}

local currentWave = 0
local zombiesAlive = 0
local zombiesFolder

local function allowedTiers(wave)
	local list = {}
	for _, tier in ipairs(Config.ZombieTiers) do
		if wave >= tier.UnlockWave then
			table.insert(list, tier)
		end
	end
	return list
end

local function totalZombiesForWave(wave)
	local base = Config.Waves.StartingZombies + Config.Waves.PerWaveBonus * (wave - 1)
	local grown = base * (Config.Waves.GrowthMul ^ (wave - 1))
	return math.floor(grown + 0.5)
end

local function announce(text, color)
	Remotes.Announce():FireAllClients(text, color or Color3.fromRGB(220, 220, 220))
end

local function pushWaveState(state)
	Remotes.UpdateWaveState():FireAllClients(state)
end

local function spawnZombie(wave, tier)
	local healthMul = 1 + Config.Waves.HealthScalePerWave * (wave - 1)
	local damageMul = 1 + Config.Waves.DamageScalePerWave * (wave - 1)
	local model, humanoid, motors = ZombieFactory.Create(tier, healthMul, damageMul)
	local spawns = MapGenerator.GetZombieSpawnPoints()
	local spawnPos = spawns[math.random(1, #spawns)] + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	model:PivotTo(CFrame.new(spawnPos))
	model.Parent = zombiesFolder

	ZombieAI.Register(model, humanoid, function()
		zombiesAlive = math.max(0, zombiesAlive - 1)
		pushWaveState({ Wave = currentWave, AliveCount = zombiesAlive })
	end)
	ZombieFactory.Animate(model, motors)
	zombiesAlive += 1
end

function WaveManager.Start()
	zombiesFolder = Instance.new("Folder")
	zombiesFolder.Name = "Zombies"
	zombiesFolder.Parent = workspace

	task.spawn(function()
		while true do
			currentWave += 1
			local tiers = allowedTiers(currentWave)
			local count = totalZombiesForWave(currentWave)

			announce(string.format("Wave %d incoming!", currentWave), Color3.fromRGB(255, 90, 90))
			pushWaveState({ Wave = currentWave, AliveCount = count, Total = count, Status = "active" })

			-- Stagger spawns so they don't all come at once.
			for i = 1, count do
				local tier = tiers[math.random(1, #tiers)]
				spawnZombie(currentWave, tier)
				task.wait(0.35 + math.random() * 0.35)
			end

			-- Wait for everyone to be dead.
			while zombiesAlive > 0 do
				task.wait(0.5)
			end

			announce(string.format("Wave %d cleared! Intermission %ds", currentWave, Config.Waves.IntermissionSeconds), Color3.fromRGB(120, 220, 120))
			pushWaveState({ Wave = currentWave, AliveCount = 0, Total = 0, Status = "intermission", Intermission = Config.Waves.IntermissionSeconds })
			task.wait(Config.Waves.IntermissionSeconds)
		end
	end)
end

return WaveManager
