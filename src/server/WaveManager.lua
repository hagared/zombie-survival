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

	-- IMPORTANT: increment the alive counter BEFORE we parent the model and
	-- register Died handlers. Otherwise a zombie that dies synchronously on
	-- the very first heartbeat after spawn (e.g. spawned on top of the
	-- fall-kill plate, or out-of-bounds) would fire Died -> onKilled before
	-- our `zombiesAlive += 1` runs, leaving the counter desynced from the
	-- actual world (counter says 1, world has 0; or worse: -1 -> clamped to
	-- 0 then we += 1 leaving a phantom that nothing can kill).
	zombiesAlive += 1
	model.Parent = zombiesFolder

	ZombieAI.Register(model, humanoid, function()
		zombiesAlive = math.max(0, zombiesAlive - 1)
		pushWaveState({ Wave = currentWave, AliveCount = zombiesAlive })
	end)
	ZombieFactory.Animate(model, motors)
end

-- Source-of-truth count: how many zombies in the spawn folder still have a
-- living humanoid. Used to refuse to end the wave while real, breathing
-- zombies are walking around the map -- even if the bookkeeping counter
-- desynced for any reason.
local function countLivingZombies()
	if not zombiesFolder then return 0 end
	local n = 0
	for _, child in ipairs(zombiesFolder:GetChildren()) do
		local hum = child:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			n += 1
		end
	end
	return n
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

			-- Wait for everyone to be dead. Re-poll the spawn folder rather
			-- than trusting the bookkeeping counter, so a single missed
			-- decrement / increment can't end the wave with a living
			-- zombie still walking around. If the counter and the actual
			-- world disagree, the world wins and we update the counter so
			-- the HUD's "Zombies: N" stays honest.
			while true do
				local actual = countLivingZombies()
				if actual == 0 and zombiesAlive == 0 then break end
				if actual ~= zombiesAlive then
					zombiesAlive = actual
					pushWaveState({ Wave = currentWave, AliveCount = zombiesAlive })
				end
				task.wait(0.5)
			end

			announce(string.format("Wave %d cleared! Intermission %ds", currentWave, Config.Waves.IntermissionSeconds), Color3.fromRGB(120, 220, 120))
			pushWaveState({ Wave = currentWave, AliveCount = 0, Total = 0, Status = "intermission", Intermission = Config.Waves.IntermissionSeconds })
			task.wait(Config.Waves.IntermissionSeconds)
		end
	end)
end

return WaveManager
