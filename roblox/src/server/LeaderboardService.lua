-- ServerScriptService.WildWest.LeaderboardService (ModuleScript)
-- Two GLOBAL leaderboards (every server, not just this one), one on each
-- side of the row of player plots:
--   left:  "Top Earners – All Time"
--   right: "Top Earners – This Week" (resets every week)
-- They rank total cash earned (rescue money, incl. Friend Boost), so
-- spending money never drops you down the board.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local P = Build.Palette

local LC = Config.Leaderboards
local LeaderboardService = {}

local RANK_COLORS = {
	Color3.fromRGB(255, 205, 40), -- gold
	Color3.fromRGB(215, 220, 230), -- silver
	Color3.fromRGB(225, 140, 70), -- bronze
}

local names = {}
local function nameFor(userId)
	if names[userId] == nil then
		local ok, n = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		names[userId] = ok and n or ("Player " .. userId)
	end
	return names[userId]
end

local function formatCash(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local function groundY(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, Config.Map.GroundY + 400, z), Vector3.new(0, -800, 0))
	return hit and hit.Position.Y or Config.Map.GroundY
end

local function makeText(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		label[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Builds a wooden billboard and returns the rows to fill in.
local function buildBoard(parent, cf, title, subtitle, headerColor)
	local w, h = LC.Width, LC.Height
	local y = groundY(cf.X, cf.Z)
	local base = CFrame.new(cf.X, y, cf.Z) -- front faces -Z (toward the ranch road)
	local m = Instance.new("Model")
	m.Name = "Leaderboard_" .. title
	for _, x in { -w / 2 + 1, w / 2 - 1 } do
		Build.box(m, base * CFrame.new(x, (h + 6) / 2, 0.8), Vector3.new(1.4, h + 6, 1.4), P.DarkWood, "Post")
	end
	local board = Build.box(m, base * CFrame.new(0, 6 + h / 2, 0), Vector3.new(w, h, 0.8), Color3.fromRGB(60, 40, 28), "Board")
	Build.box(m, base * CFrame.new(0, 6 + h + 0.8, 0), Vector3.new(w + 2, 1.6, 1.6), P.Wood, "TopTrim")
	Build.box(m, base * CFrame.new(0, 5.2, 0), Vector3.new(w + 2, 1.6, 1.6), P.Wood, "BottomTrim")

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.16, 0)
	header.BackgroundColor3 = headerColor
	header.BorderSizePixel = 0
	header.Parent = gui
	makeText(header, { Text = "🏆 " .. title, Size = UDim2.new(0.94, 0, 0.62, 0), Position = UDim2.new(0.03, 0, 0.06, 0) })
	makeText(header, { Text = subtitle, Size = UDim2.new(0.94, 0, 0.28, 0), Position = UDim2.new(0.03, 0, 0.68, 0), TextColor3 = Color3.fromRGB(255, 245, 220) })

	local rows = {}
	local rowH = 0.8 / LC.Entries
	for i = 1, LC.Entries do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.94, 0, rowH * 0.9, 0)
		row.Position = UDim2.new(0.03, 0, 0.18 + (i - 1) * rowH, 0)
		row.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(80, 56, 40) or Color3.fromRGB(96, 68, 48)
		row.BorderSizePixel = 0
		row.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.2, 0)
		c.Parent = row
		local rank = makeText(row, { Text = "#" .. i, Size = UDim2.new(0.14, 0, 0.8, 0), Position = UDim2.new(0.02, 0, 0.1, 0), TextColor3 = RANK_COLORS[i] or Color3.new(1, 1, 1) })
		local name = makeText(row, { Text = "—", Size = UDim2.new(0.5, 0, 0.7, 0), Position = UDim2.new(0.17, 0, 0.15, 0), TextXAlignment = Enum.TextXAlignment.Left })
		local amount = makeText(row, { Text = "", Size = UDim2.new(0.3, 0, 0.7, 0), Position = UDim2.new(0.68, 0, 0.15, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(110, 240, 70) })
		rows[i] = { rank = rank, name = name, amount = amount }
	end
	m.Parent = parent
	return rows
end

local function fill(rows, store)
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, LC.Entries):GetCurrentPage()
	end)
	if not ok then
		return
	end
	for i, r in rows do
		local entry = page[i]
		if entry then
			r.name.Text = nameFor(tonumber(entry.key))
			r.amount.Text = formatCash(entry.value)
		else
			r.name.Text = "—"
			r.amount.Text = ""
		end
	end
end

function LeaderboardService.start()
	local allTime, weekly, weekOpen
	pcall(function()
		allTime = DataStoreService:GetOrderedDataStore(LC.AllTimeStore)
	end)
	local function weeklyStore()
		local week = DataService.currentWeek()
		if week ~= weekOpen then
			weekOpen = week
			pcall(function()
				weekly = DataStoreService:GetOrderedDataStore(LC.WeeklyStorePrefix .. week)
			end)
		end
		return weekly
	end

	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = Workspace
	local cfs = Config.leaderboardCFrames()
	local allRows = buildBoard(folder, cfs.AllTime, "Top Earners", "ALL TIME • every server", Color3.fromRGB(230, 150, 20))
	local weekRows = buildBoard(folder, cfs.Weekly, "Top Earners", "THIS WEEK • every server", Color3.fromRGB(40, 150, 230))

	local function push(player)
		local d = DataService.get(player)
		if not d then
			return
		end
		local key = tostring(player.UserId)
		if allTime and d.TotalEarned > 0 then
			pcall(function()
				allTime:SetAsync(key, math.floor(d.TotalEarned))
			end)
		end
		local ws = weeklyStore()
		if ws and d.WeekId == DataService.currentWeek() and d.WeekEarned > 0 then
			pcall(function()
				ws:SetAsync(key, math.floor(d.WeekEarned))
			end)
		end
	end
	Players.PlayerRemoving:Connect(push)

	task.spawn(function()
		while true do
			for _, p in Players:GetPlayers() do
				push(p)
			end
			fill(allRows, allTime)
			fill(weekRows, weeklyStore())
			task.wait(LC.RefreshSeconds)
		end
	end)
end

return LeaderboardService
