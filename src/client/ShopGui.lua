-- ShopGui.lua
-- Toggleable shop UI. Two tabs: Weapons and Defenses.
-- Defenses display a live price that scales with the player's purchase count.
-- Everything fades / scales via TweenService for a slick feel.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ShopGui = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "ZS_Shop"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.Enabled = false
screen.Parent = playerGui

-- Dimming backdrop.
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Parent = screen

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
window.Size = UDim2.fromOffset(720, 480)
window.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
window.BorderSizePixel = 0
window.Parent = screen
do
	local c = Instance.new("UICorner", window)
	c.CornerRadius = UDim.new(0, 18)
	local s = Instance.new("UIStroke", window)
	s.Color = Color3.fromRGB(255, 200, 80)
	s.Thickness = 2
	s.Transparency = 0.4
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 56)
title.Text = "SHOP"
title.Font = Enum.Font.GothamBlack
title.TextColor3 = Color3.fromRGB(255, 220, 90)
title.TextSize = 32
title.Parent = window

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -14, 0, 14)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 18
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = window
do
	local c = Instance.new("UICorner", closeBtn)
	c.CornerRadius = UDim.new(1, 0)
end

-- Tabs
local tabContainer = Instance.new("Frame")
tabContainer.BackgroundTransparency = 1
tabContainer.Position = UDim2.new(0, 20, 0, 60)
tabContainer.Size = UDim2.new(1, -40, 0, 40)
tabContainer.Parent = window
do
	local l = Instance.new("UIListLayout", tabContainer)
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 8)
end

local function makeTabButton(text, layoutOrder)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(140, 36)
	b.Text = text
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 16
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	b.TextColor3 = Color3.fromRGB(220, 220, 220)
	b.BorderSizePixel = 0
	b.LayoutOrder = layoutOrder
	b.Parent = tabContainer
	local c = Instance.new("UICorner", b)
	c.CornerRadius = UDim.new(0, 8)
	return b
end

local weaponsTab = makeTabButton("Weapons", 1)
local defenseTab = makeTabButton("Defenses", 2)

-- Item area
local itemArea = Instance.new("ScrollingFrame")
itemArea.Position = UDim2.new(0, 20, 0, 110)
itemArea.Size = UDim2.new(1, -40, 1, -130)
itemArea.BackgroundTransparency = 1
itemArea.BorderSizePixel = 0
itemArea.CanvasSize = UDim2.fromOffset(0, 0)
itemArea.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemArea.ScrollBarThickness = 6
itemArea.Parent = window
do
	local l = Instance.new("UIGridLayout", itemArea)
	l.CellSize = UDim2.fromOffset(206, 130)
	l.CellPadding = UDim2.fromOffset(12, 12)
	l.SortOrder = Enum.SortOrder.LayoutOrder
end

local currentState
local activeTab = "Weapons"

local function makeCard(layoutOrder, name, body, priceText, buyEnabled, onBuy, badge)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(206, 130)
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = itemArea
	do
		local c = Instance.new("UICorner", card)
		c.CornerRadius = UDim.new(0, 10)
		local s = Instance.new("UIStroke", card)
		s.Color = buyEnabled and Color3.fromRGB(120, 220, 120) or Color3.fromRGB(80, 80, 100)
		s.Thickness = 2
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.Text = name
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	if badge then
		local b = Instance.new("TextLabel")
		b.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
		b.TextColor3 = Color3.fromRGB(20, 30, 20)
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -10, 0, 10)
		b.Size = UDim2.fromOffset(60, 20)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.Text = badge
		b.Parent = card
		local c = Instance.new("UICorner", b)
		c.CornerRadius = UDim.new(1, 0)
	end

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Position = UDim2.new(0, 12, 0, 36)
	bodyLabel.Size = UDim2.new(1, -20, 0, 44)
	bodyLabel.Text = body
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 12
	bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 205)
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.Parent = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.AnchorPoint = Vector2.new(0, 1)
	buyBtn.Position = UDim2.new(0, 12, 1, -10)
	buyBtn.Size = UDim2.new(1, -24, 0, 32)
	buyBtn.Text = priceText
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.TextSize = 16
	buyBtn.BackgroundColor3 = buyEnabled and Color3.fromRGB(80, 170, 80) or Color3.fromRGB(60, 60, 70)
	buyBtn.TextColor3 = buyEnabled and Color3.fromRGB(20, 30, 20) or Color3.fromRGB(150, 150, 150)
	buyBtn.BorderSizePixel = 0
	buyBtn.AutoButtonColor = buyEnabled
	buyBtn.Parent = card
	do
		local c = Instance.new("UICorner", buyBtn)
		c.CornerRadius = UDim.new(0, 8)
	end

	if buyEnabled then
		buyBtn.MouseEnter:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.fromOffset(214, 138) }):Play()
		end)
		buyBtn.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.15), { Size = UDim2.fromOffset(206, 130) }):Play()
		end)
		buyBtn.MouseButton1Click:Connect(onBuy)
	end
end

local function rebuild()
	for _, child in ipairs(itemArea:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if not currentState then return end

	if activeTab == "Weapons" then
		for id, cfg in pairs(Config.Weapons) do
			local owned = currentState.Weapons[id]
			local affordable = currentState.Money >= cfg.Price
			local rays = cfg.Rays > 1 and (cfg.Rays .. " barrels") or "1 barrel"
			local body = string.format("Damage %d • %.2fs/shot\n%s • Range %d", cfg.Damage, cfg.FireRate, rays, cfg.Range)
			local priceText = owned and "OWNED" or ("$" .. cfg.Price)
			makeCard(cfg.Order, cfg.Name, body, priceText, (not owned) and affordable, function()
				Remotes.PurchaseItem():FireServer("Weapon", id)
			end, owned and "OWNED" or nil)
		end
	else
		for id, cfg in pairs(Config.Defenses) do
			local count = (currentState.DefensePurchases or {})[id] or 0
			local price = math.floor(cfg.BasePrice * (cfg.PriceMul ^ count) + 0.5)
			local affordable = currentState.Money >= price
			local body
			if id == "Turret" then
				body = string.format("Auto-fires at zombies in range.\nDmg %d / %.2fs • Range %d", cfg.Damage, cfg.FireRate, cfg.Range)
			elseif id == "BarbedWire" then
				body = string.format("Slows zombies to %d%% and\ndeals %d dmg/sec.", math.floor(cfg.SlowFactor * 100), cfg.DamagePerSec)
			elseif id == "Mine" then
				body = string.format("Explodes on contact.\nDmg %d • Radius %d", cfg.Damage, cfg.Radius)
			end
			body = body .. string.format("\nOwned: %d • next +%d%%", count, math.floor((cfg.PriceMul - 1) * 100))
			makeCard(cfg.Order, cfg.Name, body, "$" .. price, affordable, function()
				Remotes.PurchaseItem():FireServer("Defense", id)
			end)
		end
	end
end

local function setTab(name)
	activeTab = name
	for _, btn in ipairs({ weaponsTab, defenseTab }) do
		TweenService:Create(btn, TweenInfo.new(0.18), {
			BackgroundColor3 = (btn.Text == name) and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(40, 40, 50),
			TextColor3 = (btn.Text == name) and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(220, 220, 220),
		}):Play()
	end
	rebuild()
end
setTab("Weapons")

weaponsTab.MouseButton1Click:Connect(function() setTab("Weapons") end)
defenseTab.MouseButton1Click:Connect(function() setTab("Defenses") end)

-- Tween-driven open/close.
local function setOpen(open)
	if open then
		screen.Enabled = true
		window.Size = UDim2.fromOffset(720 * 0.8, 480 * 0.8)
		backdrop.BackgroundTransparency = 1
		TweenService:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(720, 480),
		}):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	else
		TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(720 * 0.85, 480 * 0.85),
		}):Play()
		local fade = TweenService:Create(backdrop, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			if backdrop.BackgroundTransparency > 0.9 then
				screen.Enabled = false
			end
		end)
	end
end

closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

-- B toggles the shop.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		setOpen(not screen.Enabled)
	elseif input.KeyCode == Enum.KeyCode.Escape and screen.Enabled then
		setOpen(false)
	end
end)

Remotes.UpdatePlayerState().OnClientEvent:Connect(function(state)
	currentState = state
	if screen.Enabled then rebuild() end
end)

function ShopGui.Open() setOpen(true) end
function ShopGui.Close() setOpen(false) end
function ShopGui.IsOpen() return screen.Enabled end

return ShopGui
