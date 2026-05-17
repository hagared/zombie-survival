-- HudGui.lua
-- Builds the heads-up display: money, wave counter, zombies-alive, ammo bar,
-- weapon switcher chips, and a transient announcement toast. Everything
-- animates via TweenService so the UI feels responsive.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local HudGui = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "ZS_Hud"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.Parent = playerGui

-- Helper to build a styled frame.
local function styled(props)
	local f = Instance.new(props.Class or "Frame")
	for k, v in pairs(props) do
		if k ~= "Class" then f[k] = v end
	end
	return f
end

-- ===== Top bar with money + wave =====
local topBar = styled({
	Class = "Frame",
	Name = "TopBar",
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 56),
	Position = UDim2.new(0, 0, 0, 0),
	Parent = screen,
})
local stroke = Instance.new("UIStroke", topBar)
stroke.Color = Color3.fromRGB(255, 200, 60)
stroke.Thickness = 1
stroke.Transparency = 0.6

local moneyLabel = styled({
	Class = "TextLabel",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 220, 1, 0),
	Position = UDim2.new(0, 18, 0, 0),
	Text = "$50",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topBar,
})

local waveLabel = styled({
	Class = "TextLabel",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 600, 1, 0),
	Position = UDim2.new(0.5, -300, 0, 0),
	Text = "Wave 1",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(255, 90, 90),
	TextSize = 28,
	Parent = topBar,
})

local zombiesLabel = styled({
	Class = "TextLabel",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 220, 1, 0),
	Position = UDim2.new(1, -240, 0, 0),
	Text = "Zombies: 0",
	Font = Enum.Font.GothamSemibold,
	TextColor3 = Color3.fromRGB(220, 220, 220),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = topBar,
})

-- ===== Bottom: weapon chips =====
local weaponBar = styled({
	Class = "Frame",
	Name = "WeaponBar",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.new(0, 560, 0, 70),
	Parent = screen,
})
local layout = Instance.new("UIListLayout", weaponBar)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local weaponChips = {}
local function buildWeaponChip(id, cfg)
	local chip = styled({
		Class = "Frame",
		BackgroundColor3 = Color3.fromRGB(35, 35, 42),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 120, 1, 0),
		LayoutOrder = cfg.Order,
		Parent = weaponBar,
	})
	local corner = Instance.new("UICorner", chip)
	corner.CornerRadius = UDim.new(0, 12)
	local outline = Instance.new("UIStroke", chip)
	outline.Color = Color3.fromRGB(80, 80, 100)
	outline.Thickness = 2

	local key = styled({
		Class = "TextLabel",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 6, 0, 4),
		Text = tostring(cfg.Order),
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 80),
		TextSize = 18,
		Parent = chip,
	})

	local name = styled({
		Class = "TextLabel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, 22),
		Position = UDim2.new(0, 5, 0, 22),
		Text = cfg.Name,
		Font = Enum.Font.GothamSemibold,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		TextSize = 16,
		Parent = chip,
	})

	local status = styled({
		Class = "TextLabel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, 18),
		Position = UDim2.new(0, 5, 0, 46),
		Text = "Locked",
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(170, 170, 170),
		TextSize = 12,
		Parent = chip,
	})

	weaponChips[id] = { Frame = chip, Outline = outline, Status = status, NameLabel = name, KeyLabel = key }
end

for id, cfg in pairs(Config.Weapons) do
	buildWeaponChip(id, cfg)
end

local function setActiveChip(id)
	for chipId, chip in pairs(weaponChips) do
		local goal = chipId == id
			and { Color = Color3.fromRGB(255, 220, 80), Thickness = 3, Transparency = 0 }
			or { Color = Color3.fromRGB(80, 80, 100), Thickness = 2, Transparency = 0.2 }
		TweenService:Create(chip.Outline, TweenInfo.new(0.2), goal):Play()
	end
end

local function setOwned(weapons)
	for id, chip in pairs(weaponChips) do
		if weapons[id] then
			chip.Status.Text = "Owned"
			chip.Status.TextColor3 = Color3.fromRGB(120, 220, 120)
		else
			chip.Status.Text = "$" .. Config.Weapons[id].Price
			chip.Status.TextColor3 = Color3.fromRGB(255, 200, 80)
		end
	end
end

-- ===== Announcement toast =====
local toast = styled({
	Class = "TextLabel",
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0, 480, 0, 50),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 220, 90),
	Visible = false,
	Parent = screen,
})
local tcorner = Instance.new("UICorner", toast)
tcorner.CornerRadius = UDim.new(0, 12)
local tstroke = Instance.new("UIStroke", toast)
tstroke.Color = Color3.fromRGB(255, 220, 80)
tstroke.Thickness = 2

local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(255, 220, 90)
	tstroke.Color = color or Color3.fromRGB(255, 220, 80)
	toast.Position = UDim2.new(0.5, 0, 0, 40)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 80),
		BackgroundTransparency = 0.2,
		TextTransparency = 0,
	}):Play()
	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 0, 0, 40),
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		task.delay(0.55, function()
			if toast.TextTransparency >= 0.95 then
				toast.Visible = false
			end
		end)
	end)
end

-- ===== Health bar =====
local healthFrame = styled({
	Class = "Frame",
	Name = "HealthFrame",
	BackgroundColor3 = Color3.fromRGB(20, 20, 25),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0, 320, 0, 12),
	Parent = screen,
})
local hCorner = Instance.new("UICorner", healthFrame)
hCorner.CornerRadius = UDim.new(0, 6)

local healthFill = styled({
	Class = "Frame",
	BackgroundColor3 = Color3.fromRGB(220, 80, 80),
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 1, 0),
	Parent = healthFrame,
})
local hfCorner = Instance.new("UICorner", healthFill)
hfCorner.CornerRadius = UDim.new(0, 6)

-- Continuously update health bar from the local humanoid.
RunService.RenderStepped:Connect(function()
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum and hum.MaxHealth > 0 then
		local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		healthFill.Size = UDim2.new(pct, 0, 1, 0)
		healthFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80):Lerp(Color3.fromRGB(80, 220, 90), pct)
	end
end)

-- ===== Wave count down (intermission) =====
local waveTimer = styled({
	Class = "TextLabel",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0, 600, 0, 30),
	Text = "",
	Font = Enum.Font.GothamSemibold,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(180, 220, 255),
	Parent = screen,
})

local intermissionEndsAt
RunService.Heartbeat:Connect(function()
	if intermissionEndsAt then
		local remaining = math.ceil(intermissionEndsAt - os.clock())
		if remaining > 0 then
			waveTimer.Text = "Next wave in " .. remaining .. "s"
		else
			waveTimer.Text = ""
			intermissionEndsAt = nil
		end
	end
end)

-- ===== Money tween =====
local displayedMoney = Config.StartingMoney
local targetMoney = Config.StartingMoney

local function setMoney(amount)
	targetMoney = amount
end

RunService.RenderStepped:Connect(function(dt)
	if displayedMoney ~= targetMoney then
		local diff = targetMoney - displayedMoney
		displayedMoney += diff * math.min(1, dt * 10)
		if math.abs(displayedMoney - targetMoney) < 1 then
			displayedMoney = targetMoney
		end
		moneyLabel.Text = "$" .. math.floor(displayedMoney + 0.5)
	end
end)

-- Wire up RemoteEvents.
Remotes.UpdatePlayerState().OnClientEvent:Connect(function(state)
	setMoney(state.Money)
	setOwned(state.Weapons)
	setActiveChip(state.CurrentWeapon)
	HudGui._lastState = state
end)

Remotes.UpdateWaveState().OnClientEvent:Connect(function(state)
	waveLabel.Text = "Wave " .. (state.Wave or "?")
	zombiesLabel.Text = "Zombies: " .. (state.AliveCount or 0)
	if state.Status == "intermission" and state.Intermission then
		intermissionEndsAt = os.clock() + state.Intermission
	elseif state.Status == "active" then
		intermissionEndsAt = nil
		waveTimer.Text = ""
	end
end)

Remotes.Announce().OnClientEvent:Connect(function(text, color)
	showToast(text, color)
end)

function HudGui.GetLastState() return HudGui._lastState end
function HudGui.SetActiveChip(id) setActiveChip(id) end

return HudGui
