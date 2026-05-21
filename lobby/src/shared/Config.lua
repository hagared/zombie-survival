-- Lobby Config.
-- Tweak these to change room count / capacity / map size.

local Config = {}

-- IMPORTANT: replace with your actual MainGame Place ID from Roblox once you
-- attach the main game as a sub-place of this universe. Example:
--   Config.MainGamePlaceId = 123456789
-- Until you set this, the "depart" button will print a warning instead of
-- teleporting.
Config.MainGamePlaceId = 0

Config.RoomCount = 6      -- 6 helicopters around the helipad
Config.RoomCapacity = 4   -- 4 players per room

-- Helipad sits in the center of the ruined-city map.
Config.HelipadRadius = 32          -- player-walkable circle
Config.HelicopterRingRadius = 60   -- helicopters are arranged in a circle this far out
Config.MapHalfSize = 360           -- ruined city extends MapHalfSize studs from center on each side

return Config
