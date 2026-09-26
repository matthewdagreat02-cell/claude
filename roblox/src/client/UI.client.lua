-- StarterPlayerScripts.WildWestClient.UI (LocalScript)
-- The whole Wild West HUD, built in code (nothing to set up in StarterGui):
--   left:   Shop (green), Index (blue, with a "new" badge)
--   right:  Vehicles (red), Home (orange)
--   bottom-left:  cash ($150, or ∞ for developers) + Friend Boost and invite button
--   bottom-right: tornado timer
--   panels: Shop / Garage, Survivor Index, Share Your Feedback (+ developer reader)
--   pop-ups: +$ cash, notifications, passengers counter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("WildWestShared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("WildWestRemotes")

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "WildWestHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 820)
	uiScale.Scale = math.clamp(vp.Y / 820, 0.55, 1.25)
end
updateScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function border(thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or BLACK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(thickness)
	return new("UIStroke", { Thickness = thickness or 3, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Round })
end

local function cartoonText(parent, props)
	local base = {
		Parent = parent,
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextScaled = true,
	}
	for k, v in props do
		if k ~= "StrokeThickness" then
			base[k] = v
		end
	end
	local children = {}
	if props.StrokeThickness ~= 0 then
		table.insert(children, textStroke(props.StrokeThickness))
	end
	return new("TextLabel", base, children)
end

local function formatCash(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local function pop(button)
	local scale = button:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
end

-- Chunky cartoon button: bright colour, thick black outline, darker bottom lip.
local function chunkyButton(parent, props)
	local color = props.Color
	local b = new("TextButton", {
		Parent = parent,
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = color,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
	}, {
		corner(8),
		border(3.5),
		new("UIGradient", {
			Color = ColorSequence.new(color:Lerp(WHITE, 0.18), color:Lerp(BLACK, 0.08)),
			Rotation = 90,
		}),
	})
	-- darker lip along the bottom for a 3D look
	new("Frame", {
		Parent = b,
		BackgroundColor3 = color:Lerp(BLACK, 0.3),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 7),
		Position = UDim2.new(0, 0, 1, -7),
	}, { corner(8) })
	-- subtle stud dots
	for i = 1, 4 do
		new("Frame", {
			Parent = b,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(9, 9),
			Position = UDim2.new((i - 0.5) / 4, -4, 0, 5),
		}, { corner(5) })
	end
	if props.Icon and props.Text then
		cartoonText(b, { Text = props.Icon, Size = UDim2.new(0.3, 0, 0.72, 0), Position = UDim2.new(0.05, 0, 0.12, 0), StrokeThickness = 0 })
		cartoonText(b, { Text = props.Text, Size = UDim2.new(0.6, 0, 0.56, 0), Position = UDim2.new(0.36, 0, 0.19, 0), StrokeThickness = 3 })
	elseif props.Icon then
		cartoonText(b, { Text = props.Icon, Size = UDim2.new(0.72, 0, 0.62, 0), Position = UDim2.new(0.14, 0, 0.1, 0), StrokeThickness = 0 })
		if props.Caption then
			cartoonText(b, { Text = props.Caption, Size = UDim2.new(0.92, 0, 0.22, 0), Position = UDim2.new(0.04, 0, 0.7, 0), StrokeThickness = 2 })
		end
	elseif props.Text then
		cartoonText(b, { Text = props.Text, Size = UDim2.new(0.86, 0, 0.62, 0), Position = UDim2.new(0.07, 0, 0.16, 0), StrokeThickness = 3 })
	end
	pop(b)
	return b
end

---------------------------------------------------------------------------
-- Notifications and cash pop-ups
---------------------------------------------------------------------------
local toastHolder = new("Frame", {
	Parent = gui,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(600, 200),
	Position = UDim2.new(0.5, 0, 0, 20),
	AnchorPoint = Vector2.new(0.5, 0),
}, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
})

local function notify(text, color)
	local label = cartoonText(toastHolder, {
		Text = text,
		Size = UDim2.fromOffset(600, 38),
		TextColor3 = color or WHITE,
		TextTransparency = 1,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	stroke.Transparency = 1
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0 }):Play()
	task.delay(3, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.45)
		label:Destroy()
	end)
end
Remotes:WaitForChild("Notify").OnClientEvent:Connect(notify)

---------------------------------------------------------------------------
-- Left: Shop + Index
---------------------------------------------------------------------------
local shopButton = chunkyButton(gui, {
	Name = "ShopButton",
	Color = Color3.fromRGB(110, 214, 30),
	Icon = "🛒",
	Text = "Shop",
	Size = UDim2.fromOffset(210, 82),
	Position = UDim2.new(0, 14, 0.4, -46),
	AnchorPoint = Vector2.new(0, 0.5),
})
local indexButton = chunkyButton(gui, {
	Name = "IndexButton",
	Color = Color3.fromRGB(28, 186, 240),
	Icon = "📖",
	Text = "Index",
	Size = UDim2.fromOffset(210, 82),
	Position = UDim2.new(0, 14, 0.4, 50),
	AnchorPoint = Vector2.new(0, 0.5),
})
local badge = new("Frame", {
	Parent = indexButton,
	Size = UDim2.fromOffset(46, 46),
	Position = UDim2.new(1, -30, 1, -26),
	BackgroundColor3 = Color3.fromRGB(40, 170, 60),
	Visible = false,
	ZIndex = 5,
}, { corner(23), border(3.5, WHITE) })
local badgeText = cartoonText(badge, { Text = "1", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), ZIndex = 6 })

---------------------------------------------------------------------------
-- Right: Vehicles + Home
---------------------------------------------------------------------------
local garageButton = chunkyButton(gui, {
	Name = "VehiclesButton",
	Color = Color3.fromRGB(235, 45, 45),
	Icon = "🚚",
	Caption = "Vehicles",
	Size = UDim2.fromOffset(92, 92),
	Position = UDim2.new(1, -14, 0.4, -50),
	AnchorPoint = Vector2.new(1, 0.5),
})
local homeButton = chunkyButton(gui, {
	Name = "HomeButton",
	Color = Color3.fromRGB(255, 130, 30),
	Icon = "🏠",
	Caption = "Home",
	Size = UDim2.fromOffset(92, 92),
	Position = UDim2.new(1, -14, 0.4, 54),
	AnchorPoint = Vector2.new(1, 0.5),
})
homeButton.MouseButton1Click:Connect(function()
	Remotes.GoHome:FireServer()
end)

---------------------------------------------------------------------------
-- Bottom-left: cash + friend boost
---------------------------------------------------------------------------
local cashFrame = new("Frame", {
	Parent = gui,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(360, 120),
	Position = UDim2.new(0, 14, 1, -14),
	AnchorPoint = Vector2.new(0, 1),
})
cartoonText(cashFrame, { Text = "💵", Size = UDim2.fromOffset(78, 62), Position = UDim2.fromOffset(0, 0), StrokeThickness = 0 })
local cashLabel = cartoonText(cashFrame, {
	Text = "$0",
	Size = UDim2.fromOffset(270, 62),
	Position = UDim2.fromOffset(84, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(80, 235, 40),
	StrokeThickness = 3.5,
})
local boostLabel = cartoonText(cashFrame, {
	Text = "Friend Boost: +0%",
	Size = UDim2.fromOffset(240, 34),
	Position = UDim2.fromOffset(2, 72),
	TextXAlignment = Enum.TextXAlignment.Left,
	StrokeThickness = 2.5,
})
local inviteButton = chunkyButton(cashFrame, {
	Name = "InviteButton",
	Color = Color3.fromRGB(80, 200, 60),
	Text = "+",
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.fromOffset(250, 67),
})
inviteButton.MouseButton1Click:Connect(function()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and can then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		notify("Invites aren't available right now.")
	end
end)

local passengersLabel = cartoonText(gui, {
	Text = "",
	Size = UDim2.fromOffset(330, 34),
	Position = UDim2.new(0, 16, 1, -140),
	AnchorPoint = Vector2.new(0, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
})

local function refreshCash()
	if player:GetAttribute("InfiniteCash") then
		cashLabel.Text = "∞"
	else
		cashLabel.Text = formatCash(player:GetAttribute("Cash") or 0)
	end
	local boost = player:GetAttribute("FriendBoost") or 0
	boostLabel.Text = string.format("Friend Boost: +%d%%", math.floor(boost * 100 + 0.5))
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
player:GetAttributeChangedSignal("InfiniteCash"):Connect(refreshCash)
player:GetAttributeChangedSignal("FriendBoost"):Connect(refreshCash)
refreshCash()

Remotes:WaitForChild("CashPopup").OnClientEvent:Connect(function(amount)
	local label = cartoonText(gui, {
		Text = "+" .. formatCash(amount),
		Size = UDim2.fromOffset(220, 48),
		Position = UDim2.new(0, 100, 1, -150),
		AnchorPoint = Vector2.new(0, 1),
		TextColor3 = Color3.fromRGB(120, 255, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 100, 1, -230),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(1.3), { Transparency = 1 }):Play()
	task.delay(1.4, function()
		label:Destroy()
	end)
end)

---------------------------------------------------------------------------
-- Bottom-right: tornado timer
---------------------------------------------------------------------------
local timerFrame = new("Frame", {
	Parent = gui,
	BackgroundColor3 = Color3.fromRGB(95, 97, 104),
	BackgroundTransparency = 0.1,
	Size = UDim2.fromOffset(260, 72),
	Position = UDim2.new(1, -14, 1, -14),
	AnchorPoint = Vector2.new(1, 1),
	Visible = false,
}, { corner(14), border(3, Color3.fromRGB(60, 62, 68)) })
local timerLabel = cartoonText(timerFrame, {
	Text = "🌪️ in 54s",
	Size = UDim2.new(0.9, 0, 0.72, 0),
	Position = UDim2.new(0.05, 0, 0.14, 0),
})
task.spawn(function()
	while true do
		local active = ReplicatedStorage:GetAttribute("TornadoActive")
		local nextAt = ReplicatedStorage:GetAttribute("NextTornadoAt")
		if active then
			timerFrame.Visible = true
			timerFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			timerLabel.Text = "🌪️ NOW!"
		elseif type(nextAt) == "number" then
			local secs = math.ceil(nextAt - Workspace:GetServerTimeNow())
			if secs > 0 then
				timerFrame.Visible = true
				timerFrame.BackgroundColor3 = Color3.fromRGB(95, 97, 104)
				if secs >= 60 then
					timerLabel.Text = string.format("🌪️ in %dm %02ds", secs // 60, secs % 60)
				else
					timerLabel.Text = string.format("🌪️ in %ds", secs)
				end
			else
				timerFrame.Visible = false
			end
		else
			timerFrame.Visible = false
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------------
-- Cartoon panels (Shop / Garage / Index)
---------------------------------------------------------------------------
local openPanel = nil
local function makePanel(title, headerColor)
	local panel = new("Frame", {
		Parent = gui,
		Size = UDim2.fromOffset(600, 440),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 246, 225),
		Visible = false,
		ZIndex = 10,
	}, { corner(16), border(4) })
	local header = new("Frame", {
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = headerColor,
		ZIndex = 11,
	}, { corner(16), border(4) })
	local titleLabel = cartoonText(header, { Text = title, Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.new(0.15, 0, 0.15, 0), ZIndex = 12 })
	local close = chunkyButton(panel, {
		Name = "Close",
		Color = Color3.fromRGB(235, 45, 45),
		Text = "X",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
	})
	close.ZIndex = 13
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
		openPanel = nil
	end)
	local list = new("ScrollingFrame", {
		Parent = panel,
		Size = UDim2.new(1, -30, 1, -90),
		Position = UDim2.fromOffset(15, 78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	})
	return panel, list, titleLabel
end

local function showPanel(panel)
	if openPanel and openPanel ~= panel then
		openPanel.Visible = false
	end
	panel.Visible = not panel.Visible
	openPanel = panel.Visible and panel or nil
	if panel.Visible then
		local s = panel:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = panel })
		s.Scale = 0.85
		TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- Shop / Garage
local shopPanel, shopList, shopTitle = makePanel("Shop", Color3.fromRGB(110, 214, 30))
new("UIListLayout", { Parent = shopList, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local garageOnly = false


local function owned()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("OwnedVehicles") or "{}")
	return ok and t or {}
end

local function refreshShop()
	for _, c in shopList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local own = owned()
	local fastest = 0
	for _, v in Config.Vehicles do
		fastest = math.max(fastest, v.TopSpeed)
	end
	for i, v in Config.Vehicles do
		local isOwned = own[v.Id] == true
		if garageOnly and not isOwned then
			continue
		end
		local card = new("Frame", {
			Parent = shopList,
			LayoutOrder = i,
			Size = UDim2.new(1, -12, 0, 100),
			BackgroundColor3 = WHITE,
			ZIndex = 11,
		}, { corner(12), border(3) })
		cartoonText(card, { Text = v.Icon, Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(10, 10), StrokeThickness = 0, ZIndex = 12 })
		cartoonText(card, {
			Text = v.Name,
			Size = UDim2.new(0.5, 0, 0, 38),
			Position = UDim2.fromOffset(100, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
		})
		local tag = v.TopSpeed == fastest and "  ⚡ FASTEST" or ""
		new("TextLabel", {
			Parent = card,
			BackgroundTransparency = 1,
			Text = string.format("Top speed %d%s", v.TopSpeed, tag),
			Font = FONT,
			TextSize = 20,
			TextColor3 = Color3.fromRGB(70, 60, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.55, 0, 0, 28),
			Position = UDim2.fromOffset(102, 56),
			ZIndex = 12,
		})
		local btn
		if isOwned then
			btn = chunkyButton(card, { Color = Color3.fromRGB(28, 186, 240), Text = "Spawn", Size = UDim2.fromOffset(150, 62), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
			btn.MouseButton1Click:Connect(function()
				local ok, msg = Remotes.SpawnVehicle:InvokeServer(v.Id)
				notify(msg, ok and Color3.fromRGB(120, 230, 110) or Color3.fromRGB(255, 120, 90))
				if ok then
					shopPanel.Visible = false
					openPanel = nil
				end
			end)
		else
			local priceText = player:GetAttribute("InfiniteCash") and "FREE" or formatCash(v.Price)
			btn = chunkyButton(card, { Color = Color3.fromRGB(110, 214, 30), Text = priceText, Size = UDim2.fromOffset(150, 62), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
			btn.MouseButton1Click:Connect(function()
				local ok, msg = Remotes.BuyVehicle:InvokeServer(v.Id)
				notify(msg, ok and Color3.fromRGB(120, 230, 110) or Color3.fromRGB(255, 120, 90))
			end)
		end
		btn.ZIndex = 12
	end
end
player:GetAttributeChangedSignal("OwnedVehicles"):Connect(refreshShop)

shopButton.MouseButton1Click:Connect(function()
	garageOnly = false
	shopTitle.Text = "Shop"
	refreshShop()
	showPanel(shopPanel)
end)
garageButton.MouseButton1Click:Connect(function()
	garageOnly = true
	shopTitle.Text = "My Vehicles"
	refreshShop()
	showPanel(shopPanel)
end)

-- Survivor Index (luck levels rescued)
local indexPanel, indexList = makePanel("Survivor Index", Color3.fromRGB(28, 186, 240))
new("UIGridLayout", { Parent = indexList, CellSize = UDim2.fromOffset(170, 150), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center })
local seenLevels = {}

local function indexData()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("IndexData") or "{}")
	return ok and t or {}
end

local function refreshBadge()
	local data = indexData()
	local new_ = 0
	for _, l in Config.LuckLevels do
		if (data[tostring(l.Level)] or 0) > 0 and not seenLevels[l.Level] then
			new_ += 1
		end
	end
	badge.Visible = new_ > 0
	badgeText.Text = tostring(new_)
end

local function refreshIndex()
	for _, c in indexList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local data = indexData()
	for _, l in Config.LuckLevels do
		local count = data[tostring(l.Level)] or 0
		local found = count > 0
		local card = new("Frame", {
			Parent = indexList,
			LayoutOrder = l.Level,
			BackgroundColor3 = found and WHITE or Color3.fromRGB(200, 200, 200),
			ZIndex = 11,
		}, { corner(12), border(3) })
		cartoonText(card, { Text = found and Config.CloverIcon or "❔", Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -30, 0, 8), StrokeThickness = 0, ZIndex = 12 })
		cartoonText(card, { Text = "Luck " .. l.Level, Size = UDim2.new(0.9, 0, 0, 34), Position = UDim2.new(0.05, 0, 0, 70), TextColor3 = found and l.Color or Color3.fromRGB(150, 150, 150), ZIndex = 12 })
		new("TextLabel", {
			Parent = card,
			BackgroundTransparency = 1,
			Text = found and ("Rescued: " .. count) or "Not found yet",
			Font = FONT,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(70, 60, 50),
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.new(0, 0, 0, 110),
			ZIndex = 12,
		})
	end
end
player:GetAttributeChangedSignal("IndexData"):Connect(function()
	refreshBadge()
	if indexPanel.Visible then
		refreshIndex()
	end
end)
refreshBadge()

indexButton.MouseButton1Click:Connect(function()
	refreshIndex()
	local data = indexData()
	for _, l in Config.LuckLevels do
		if (data[tostring(l.Level)] or 0) > 0 then
			seenLevels[l.Level] = true
		end
	end
	refreshBadge()
	showPanel(indexPanel)
end)

---------------------------------------------------------------------------
-- Share Your Feedback (dark window, like Roblox's own feedback prompt)
---------------------------------------------------------------------------
local UI_FONT = Enum.Font.BuilderSans
local DARK = Color3.fromRGB(35, 37, 41)
local FIELD = Color3.fromRGB(46, 48, 53)
local MUTED = Color3.fromRGB(170, 172, 178)
local BLUE = Color3.fromRGB(51, 95, 255)
local BLUE_OFF = Color3.fromRGB(44, 62, 140)

local feedback = new("Frame", {
	Parent = gui,
	Size = UDim2.fromOffset(440, 360),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = DARK,
	Visible = false,
	ZIndex = 20,
}, { corner(12) })
local fbClose = new("TextButton", {
	Parent = feedback,
	Text = "✕",
	Font = UI_FONT,
	TextSize = 26,
	TextColor3 = WHITE,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.fromOffset(14, 10),
	ZIndex = 21,
})
new("TextLabel", {
	Parent = feedback,
	Text = "Share Your Feedback",
	Font = Enum.Font.BuilderSansBold,
	TextSize = 22,
	TextColor3 = WHITE,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 44),
	Position = UDim2.fromOffset(0, 10),
	ZIndex = 21,
})
new("Frame", { Parent = feedback, BackgroundColor3 = Color3.fromRGB(62, 64, 70), BorderSizePixel = 0, Size = UDim2.new(1, -40, 0, 1), Position = UDim2.fromOffset(20, 62), ZIndex = 21 })
new("TextLabel", {
	Parent = feedback,
	Text = "Tell us about your experience.",
	Font = UI_FONT,
	TextSize = 19,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -48, 0, 26),
	Position = UDim2.fromOffset(24, 80),
	ZIndex = 21,
})
local fbBox = new("TextBox", {
	Parent = feedback,
	Text = "",
	PlaceholderText = "Tell us what you think...",
	PlaceholderColor3 = Color3.fromRGB(140, 142, 148),
	Font = UI_FONT,
	TextSize = 18,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	MultiLine = true,
	ClearTextOnFocus = false,
	BackgroundColor3 = FIELD,
	Size = UDim2.new(1, -48, 0, 92),
	Position = UDim2.fromOffset(24, 114),
	ZIndex = 21,
}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }) })
local fbCount = new("TextLabel", {
	Parent = feedback,
	Text = "0/" .. Config.Feedback.MaxLength,
	Font = UI_FONT,
	TextSize = 13,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -48, 0, 16),
	Position = UDim2.fromOffset(24, 208),
	ZIndex = 21,
})
local fbSubmit = new("TextButton", {
	Parent = feedback,
	Text = "Submit",
	Font = UI_FONT,
	TextSize = 17,
	TextColor3 = MUTED,
	AutoButtonColor = false,
	BackgroundColor3 = BLUE_OFF,
	Size = UDim2.new(1, -48, 0, 40),
	Position = UDim2.fromOffset(24, 232),
	ZIndex = 21,
}, { corner(8) })
local fbStatus = new("TextLabel", {
	Parent = feedback,
	Text = "",
	Font = UI_FONT,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(120, 230, 110),
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -48, 0, 18),
	Position = UDim2.fromOffset(24, 276),
	ZIndex = 21,
})
new("TextLabel", {
	Parent = feedback,
	Text = "Responses are shared anonymously with the developer and must follow the Roblox Terms of Use.",
	Font = UI_FONT,
	TextSize = 13,
	TextWrapped = true,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -48, 0, 36),
	Position = UDim2.fromOffset(24, 300),
	ZIndex = 21,
})
local fbRead = new("TextButton", {
	Parent = feedback,
	Text = "Read Feedback (dev)",
	Font = UI_FONT,
	TextSize = 14,
	TextColor3 = WHITE,
	BackgroundColor3 = Color3.fromRGB(70, 72, 80),
	Size = UDim2.fromOffset(150, 28),
	Position = UDim2.new(1, -20, 0, 18),
	AnchorPoint = Vector2.new(1, 0),
	Visible = false,
	ZIndex = 21,
}, { corner(6) })

local function fbValid()
	local len = utf8.len(fbBox.Text) or 0
	return len >= Config.Feedback.MinLength and len <= Config.Feedback.MaxLength
end
fbBox:GetPropertyChangedSignal("Text"):Connect(function()
	local len = utf8.len(fbBox.Text) or 0
	if len > Config.Feedback.MaxLength then
		local cut = utf8.offset(fbBox.Text, Config.Feedback.MaxLength + 1) or (#fbBox.Text + 1)
		fbBox.Text = fbBox.Text:sub(1, cut - 1)
		return
	end
	fbCount.Text = len .. "/" .. Config.Feedback.MaxLength
	local ok = fbValid()
	fbSubmit.BackgroundColor3 = ok and BLUE or BLUE_OFF
	fbSubmit.TextColor3 = ok and WHITE or MUTED
end)

local function openFeedback()
	if feedback.Visible then
		return
	end
	if openPanel then
		openPanel.Visible = false
		openPanel = nil
	end
	fbStatus.Text = ""
	fbRead.Visible = player:GetAttribute("IsDev") == true
	feedback.Visible = true
end
fbClose.MouseButton1Click:Connect(function()
	feedback.Visible = false
end)

local sending = false
fbSubmit.MouseButton1Click:Connect(function()
	if sending or not fbValid() then
		return
	end
	sending = true
	fbSubmit.Text = "Sending..."
	local ok, msg = Remotes.SubmitFeedback:InvokeServer(fbBox.Text)
	sending = false
	fbSubmit.Text = "Submit"
	fbStatus.TextColor3 = ok and Color3.fromRGB(120, 230, 110) or Color3.fromRGB(255, 120, 90)
	fbStatus.Text = msg or ""
	if ok then
		fbBox.Text = ""
		task.delay(1.2, function()
			feedback.Visible = false
		end)
	end
end)

-- Developer-only reader
local reader = new("Frame", {
	Parent = gui,
	Size = UDim2.fromOffset(520, 440),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = DARK,
	Visible = false,
	ZIndex = 30,
}, { corner(12) })
new("TextLabel", {
	Parent = reader,
	Text = "Player Feedback",
	Font = Enum.Font.BuilderSansBold,
	TextSize = 22,
	TextColor3 = WHITE,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 50),
	ZIndex = 31,
})
local readerClose = new("TextButton", {
	Parent = reader,
	Text = "✕",
	Font = UI_FONT,
	TextSize = 26,
	TextColor3 = WHITE,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.fromOffset(12, 4),
	ZIndex = 31,
})
local readerList = new("ScrollingFrame", {
	Parent = reader,
	Size = UDim2.new(1, -30, 1, -66),
	Position = UDim2.fromOffset(15, 56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 31,
}, { new("UIListLayout", { Padding = UDim.new(0, 8) }) })
readerClose.MouseButton1Click:Connect(function()
	reader.Visible = false
end)
fbRead.MouseButton1Click:Connect(function()
	feedback.Visible = false
	for _, c in readerList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	reader.Visible = true
	local entries = Remotes.GetFeedback:InvokeServer()
	if #entries == 0 then
		new("Frame", { Parent = readerList, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), ZIndex = 31 }, {
			new("TextLabel", { Text = "No feedback yet.", Font = UI_FONT, TextSize = 18, TextColor3 = MUTED, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 32 }),
		})
	end
	for _, e in entries do
		local entry = new("Frame", {
			Parent = readerList,
			BackgroundColor3 = FIELD,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 31,
		}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
			new("UIListLayout", { Padding = UDim.new(0, 4) }) })
		new("TextLabel", {
			Parent = entry,
			Text = os.date("%b %d, %Y  %H:%M", e.Time or 0),
			Font = UI_FONT,
			TextSize = 13,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 32,
		})
		new("TextLabel", {
			Parent = entry,
			Text = e.Text or "",
			Font = UI_FONT,
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 32,
		})
	end
end)

-- Open the feedback window from the mailbox (prompt or stepping in the ring)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FeedbackPrompt" then
		openFeedback()
	end
end)
local insideZone = false
task.spawn(function()
	while true do
		task.wait(0.2)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local inside = false
		if root then
			for _, zone in CollectionService:GetTagged("FeedbackMailbox") do
				local d = root.Position - zone.Position
				if Vector2.new(d.X, d.Z).Magnitude < zone.Size.Y / 2 and math.abs(d.Y) < 8 then
					inside = true
					break
				end
			end
		end
		if inside and not insideZone then
			openFeedback()
		end
		insideZone = inside
	end
end)

---------------------------------------------------------------------------
-- Passengers counter while driving
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.3)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		local model = seat and seat.Parent
		if model and model:GetAttribute("WWVehicle") then
			local total, riding = Config.Survivors.MaxPerVehicle, 0
			for _, d in model:GetDescendants() do
				if d:IsA("Seat") and d.Name == "PassengerSeat" then
					if d.Occupant and d.Occupant.Parent and d.Occupant.Parent:GetAttribute("IsSurvivor") then
						riding += 1
					end
				end
			end
			passengersLabel.Visible = true
			passengersLabel.Text = string.format("%s Survivors: %d/%d", Config.CloverIcon, riding, total)
		else
			passengersLabel.Visible = false
		end
	end
end)
