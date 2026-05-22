-- build-lobby-map.lua
-- Same idea as build-map.lua but for the lobby place (helipad + ring of
-- 6 helicopters + ruined-city horizon). Run in Studio Command Bar while
-- Rojo is synced to lobby.project.json.

local Server = game:GetService("ServerScriptService"):FindFirstChild("Server")
if not Server then
	warn("[build-lobby-map] ServerScriptService.Server not found. " ..
		"Is Rojo synced to lobby.project.json?")
	return
end

local MapGenerator = require(Server:WaitForChild("MapGenerator"))
local Helicopter = require(Server:WaitForChild("Helicopter"))
local Config = require(game:GetService("ReplicatedStorage")
	:WaitForChild("Shared"):WaitForChild("Config"))

-- Wipe old.
local existing = workspace:FindFirstChild("LobbyMap")
if existing then existing:Destroy() end
local oldHelis = workspace:FindFirstChild("Helicopters")
if oldHelis then oldHelis:Destroy() end

-- Bake helipad + ruined-city.
local map = MapGenerator.Build()

-- Bake the 6 helicopters around the helipad. (At runtime, init.server.lua
-- builds them and wires up ProximityPrompts; here we just place them in
-- the place file. The runtime wiring still works because the prompts
-- exist on the parts.)
local heliFolder = Instance.new("Folder")
heliFolder.Name = "Helicopters"
heliFolder.Parent = workspace
for i = 1, Config.RoomCount do
	local angle = (i - 1) * (math.pi * 2 / Config.RoomCount)
	local cx = math.cos(angle) * Config.HelicopterRingRadius
	local cz = math.sin(angle) * Config.HelicopterRingRadius
	local pivot = CFrame.new(cx, 0, cz) * CFrame.Angles(0, -angle - math.pi / 2, 0)
	local heliModel = Helicopter.Build(i, pivot)
	heliModel.Parent = heliFolder
end

print(("[build-lobby-map] Lobby baked. Workspace.LobbyMap (%d parts) + " ..
	"Workspace.Helicopters (%d helicopters). Save the place (Ctrl+S)."):format(
	#map:GetDescendants(), #heliFolder:GetChildren()
))
