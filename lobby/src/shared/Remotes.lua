-- Lobby Remotes.
-- The SERVER creates these RemoteEvents on first call. The CLIENT must
-- only ever READ them via WaitForChild -- never call Instance.new on its
-- own copy of ReplicatedStorage, because that would create a duplicate
-- remote on the client side that the server can't see, and FireServer
-- would silently go nowhere.
--
-- This was the cause of the "Join button does nothing" bug: the client's
-- Remotes.JoinRoom() was racing the server's replication and producing
-- a client-only orphan RemoteEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local IS_SERVER = RunService:IsServer()

local function getFolder()
	if IS_SERVER then
		local f = ReplicatedStorage:FindFirstChild("LobbyRemotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "LobbyRemotes"
			f.Parent = ReplicatedStorage
		end
		return f
	else
		-- Client waits for the server-replicated folder. WaitForChild
		-- yields until the server has created it during init.
		return ReplicatedStorage:WaitForChild("LobbyRemotes")
	end
end

local function ensure(name, className)
	className = className or "RemoteEvent"
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then return existing end
	if IS_SERVER then
		local r = Instance.new(className)
		r.Name = name
		r.Parent = folder
		return r
	else
		-- Client must not create remotes -- wait for the server to push it.
		return folder:WaitForChild(name)
	end
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
