-- LobbyHud.lua
-- Lobby-side HUD. Shows a compact list of all rooms with current member
-- counts + names, the player's currently-joined room, and Leave / Depart
-- buttons. Intentionally simple: no shop, no inventory -- this is just a
-- pre-game lobby.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local LobbyHud = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screen
local roomFrames = {}
local myRoom = nil
local toastLabel
local statusLabel

local function styled(props)
	local f = Instance.new(props.Class or "Frame")
	for k, v in pairs(props) do
		if k ~= "Class" then f[k] = v end
	end
	return f
end

local function makeToast(parent)
	local t = styled({
		Class = "TextLabel",
		BackgroundColor3 = Color3.fromRGB(15, 15, 18),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.new(0, 520, 0, 50),
		Text = "",
		Font = Enum.Font.GothamSemibold,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(220, 230, 240),
		Visible = false,
		Parent = parent,
	})
	local c = Instance.new("UICorner", t)
	c.CornerRadius = UDim.new(0, 12)
	return t
end

local function buildHud()
	screen = Instance.new("ScreenGui")
	screen.Name = "ZS_LobbyHud"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.Parent = playerGui

	-- Title bar at the top.
	local title = styled({
		Class = "TextLabel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 480, 0, 40),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Text = "ZOMBIE SURVIVAL -- LOBBY",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		TextSize = 22,
		Parent = screen,
	})
	local tc = Instance.new("UICorner", title)
	tc.CornerRadius = UDim.new(0, 12)

	-- Room list panel on the right side.
	local panel = styled({
		Class = "Frame",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
		Size = UDim2.new(0, 280, 0, 380),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = screen,
	})
	local pc = Instance.new("UICorner", panel)
	pc.CornerRadius = UDim.new(0, 14)

	local header = styled({
		Class = "TextLabel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 0, 6),
		Text = "Helicopters",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(230, 220, 200),
		TextSize = 18,
		Parent = panel,
	})

	local list = styled({
		Class = "Frame",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -90),
		Position = UDim2.new(0, 10, 0, 44),
		Parent = panel,
	})
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- One row per room.
	for i = 1, Config.RoomCount do
		local row = styled({
			Class = "Frame",
			BackgroundColor3 = Color3.fromRGB(35, 35, 45),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 42),
			LayoutOrder = i,
			Parent = list,
		})
		local rc = Instance.new("UICorner", row)
		rc.CornerRadius = UDim.new(0, 8)

		local num = styled({
			Class = "TextLabel",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.new(0, 32, 0.8, 0),
			Text = "#" .. i,
			Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 220, 90),
			TextSize = 18,
			Parent = row,
		})
		local count = styled({
			Class = "TextLabel",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 50, 0.5, 0),
			Size = UDim2.new(0, 60, 0.8, 0),
			Text = "0/" .. Config.RoomCapacity,
			Font = Enum.Font.GothamSemibold,
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextSize = 16,
			Parent = row,
		})
		local who = styled({
			Class = "TextLabel",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 110, 0.5, 0),
			Size = UDim2.new(1, -200, 0.8, 0),
			Text = "(empty)",
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(170, 170, 180),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local joinBtn = styled({
			Class = "TextButton",
			BackgroundColor3 = Color3.fromRGB(60, 130, 60),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 70, 0.7, 0),
			Text = "Join",
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(20, 30, 20),
			TextSize = 14,
			Parent = row,
		})
		local jc = Instance.new("UICorner", joinBtn)
		jc.CornerRadius = UDim.new(0, 8)
		joinBtn.MouseButton1Click:Connect(function()
			Remotes.JoinRoom():FireServer(i)
		end)

		roomFrames[i] = { Row = row, Count = count, Who = who, JoinBtn = joinBtn }
	end

	-- Footer: status label + "Depart" + "Leave" buttons.
	local footer = styled({
		Class = "Frame",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 480, 0, 70),
		Parent = screen,
	})

	statusLabel = styled({
		Class = "TextLabel",
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(0, 460, 0, 28),
		Text = "Walk up to a helicopter and press E to board.",
		Font = Enum.Font.GothamSemibold,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		TextSize = 14,
		Parent = footer,
	})
	local sc = Instance.new("UICorner", statusLabel)
	sc.CornerRadius = UDim.new(0, 10)

	local leaveBtn = styled({
		Class = "TextButton",
		BackgroundColor3 = Color3.fromRGB(120, 70, 70),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -110, 1, 0),
		Size = UDim2.new(0, 200, 0, 38),
		Text = "Leave (L)",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(245, 230, 230),
		TextSize = 16,
		Parent = footer,
	})
	local lc = Instance.new("UICorner", leaveBtn)
	lc.CornerRadius = UDim.new(0, 10)
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.LeaveRoom():FireServer()
	end)

	local departBtn = styled({
		Class = "TextButton",
		BackgroundColor3 = Color3.fromRGB(70, 130, 90),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 110, 1, 0),
		Size = UDim2.new(0, 200, 0, 38),
		Text = "DEPART (T)",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(225, 245, 230),
		TextSize = 18,
		Parent = footer,
	})
	local dc = Instance.new("UICorner", departBtn)
	dc.CornerRadius = UDim.new(0, 10)
	departBtn.MouseButton1Click:Connect(function()
		Remotes.DepartNow():FireServer()
	end)

	-- Toast (transient announcements -- "joined", "left", errors).
	toastLabel = makeToast(screen)
end

function LobbyHud.Init()
	if screen then return end
	buildHud()
end

function LobbyHud.SetRooms(snapshot, myName)
	for i, info in ipairs(snapshot) do
		local frame = roomFrames[i]
		if frame then
			local n = #info.Members
			frame.Count.Text = n .. "/" .. info.Capacity
			frame.Count.TextColor3 = (n >= info.Capacity)
				and Color3.fromRGB(220, 110, 110)
				or  Color3.fromRGB(220, 220, 220)
			if n == 0 then
				frame.Who.Text = "(empty)"
			else
				frame.Who.Text = table.concat(info.Members, ", ")
			end
			-- Highlight the row that contains the local player.
			local mineHere = false
			for _, m in ipairs(info.Members) do
				if m == myName then mineHere = true; break end
			end
			frame.Row.BackgroundColor3 = mineHere
				and Color3.fromRGB(40, 60, 40)
				or  Color3.fromRGB(35, 35, 45)
			-- Disable Join button if the room is full or we're already in it.
			if mineHere then
				frame.JoinBtn.Text = "In here"
				frame.JoinBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
			elseif n >= info.Capacity then
				frame.JoinBtn.Text = "Full"
				frame.JoinBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
			else
				frame.JoinBtn.Text = "Join"
				frame.JoinBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
			end
		end
	end
end

function LobbyHud.SetMyRoom(roomNumber)
	myRoom = roomNumber
	if statusLabel then
		if roomNumber then
			statusLabel.Text = "You're in helicopter #" .. roomNumber ..
				". Press T (or DEPART) to launch the run."
			statusLabel.TextColor3 = Color3.fromRGB(180, 230, 180)
		else
			statusLabel.Text = "Walk up to a helicopter and press E to board."
			statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		end
	end
end

function LobbyHud.Toast(text, color)
	if not toastLabel then return end
	toastLabel.Text = text
	toastLabel.TextColor3 = color or Color3.fromRGB(220, 230, 240)
	toastLabel.Visible = true
	toastLabel.TextTransparency = 1
	toastLabel.BackgroundTransparency = 1
	TweenService:Create(toastLabel, TweenInfo.new(0.3), {
		TextTransparency = 0, BackgroundTransparency = 0.1,
	}):Play()
	task.delay(2.5, function()
		TweenService:Create(toastLabel, TweenInfo.new(0.4), {
			TextTransparency = 1, BackgroundTransparency = 1,
		}):Play()
		task.delay(0.5, function()
			if toastLabel.TextTransparency >= 0.95 then
				toastLabel.Visible = false
			end
		end)
	end)
end

return LobbyHud
