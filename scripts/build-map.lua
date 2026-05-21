-- build-map.lua
-- Run this in the Roblox Studio Command Bar (View -> Command Bar) while
-- Rojo is synced and you are in EDIT MODE (NOT in Play). It calls the
-- server-side MapGenerator and bakes the procedural ruined-city map into
-- the place file as real Workspace parts you can hand-edit.
--
-- Usage:
--   1. Open Studio with Rojo connected to default.project.json.
--   2. View -> Command Bar (or Ctrl+`).
--   3. Paste the contents of this file.
--   4. Press Enter.
--   5. The Map folder appears under Workspace. Save the place (Ctrl+S).
--   6. Edit parts inside Workspace.Map however you want.
--
-- After baking, init.server.lua skips MapGenerator.Build() because
-- Workspace.Map already exists -- so your hand-edits stick across Play.

local Server = game:GetService("ServerScriptService"):FindFirstChild("Server")
if not Server then
	warn("[build-map] ServerScriptService.Server not found. Is Rojo synced?")
	return
end

local MapGenerator = require(Server:WaitForChild("MapGenerator"))

-- Wipe any existing map first so re-running the command rebuilds cleanly.
local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end

local map = MapGenerator.Build()
print(("[build-map] Map baked into Workspace.%s -- %d total parts. Save the place (Ctrl+S) to keep it."):format(
	map.Name, #map:GetDescendants()
))
