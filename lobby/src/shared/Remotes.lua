-- Lobby Remotes.
-- Lazily creates RemoteEvents in ReplicatedStorage so the server / client
-- can refer to them without race conditions on first run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function ensure(name, className)
	className = className or "RemoteEvent"
	local folder = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LobbyRemotes"
		folder.Parent = ReplicatedStorage
	end
	local existing = folder:FindFirstChild(name)
	if existing then return existing end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

-- Server -> client: full snapshot of all rooms (occupancy, names, etc).
function Remotes.UpdateRooms() return ensure("UpdateRooms") end
-- Server -> client: a personal status push ("you joined room 3", "kicked", etc).
function Remotes.PlayerStatus() return ensure("PlayerStatus") end
-- Client -> server: "I want to join room N" / "I want to leave my room".
function Remotes.JoinRoom() return ensure("JoinRoom") end
function Remotes.LeaveRoom() return ensure("LeaveRoom") end
-- Client -> server: "depart now" -- teleport everyone in my room to MainGame.
function Remotes.DepartNow() return ensure("DepartNow") end

return Remotes
