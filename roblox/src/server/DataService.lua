-- ServerScriptService.WildWest.DataService (ModuleScript)
-- Cash, owned vehicles and the survivor index. Saved with DataStores.
-- Cash is only ever changed on the server, so players can't cheat it.
--
-- Developers (Config.DevUserIds, or the game owner) have infinite cash:
-- purchases never subtract money and their cash display shows "∞".
--
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to
-- API Services" or saving is skipped (the game still works).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	store = ok and result or nil
	if not ok then
		warn("[WildWest] DataStore unavailable, progress will not save: " .. tostring(result))
	end
end

local profiles = {} -- [player] = { data = {...}, loaded = bool }

local function defaultData()
	return {
		Cash = Config.StartingCash,
		Vehicles = { Starter = true },
		Index = {}, -- ["3"] = number rescued with luck 3
		Rescued = 0,
		TotalEarned = 0, -- all-time cash earned (global leaderboard)
		WeekId = 0,
		WeekEarned = 0, -- cash earned this week (weekly leaderboard)
	}
end

function DataService.currentWeek()
	return math.floor(os.time() / 604800)
end

function DataService.isDev(player)
	if table.find(Config.DevUserIds, player.UserId) then
		return true
	end
	if Config.OwnerIsDev then
		if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			return true
		end
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, rank = pcall(function()
				return player:GetRankInGroup(game.CreatorId)
			end)
			if ok and rank == 255 then
				return true
			end
		end
	end
	return false
end

local function publish(player)
	local prof = profiles[player]
	if not prof then
		return
	end
	local d = prof.data
	player:SetAttribute("Cash", d.Cash)
	player:SetAttribute("OwnedVehicles", HttpService:JSONEncode(d.Vehicles))
	player:SetAttribute("IndexData", HttpService:JSONEncode(d.Index))
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Cash") then
		ls.Cash.Value = prof.infinite and 999999999 or d.Cash
	end
end

local function load(player)
	local data
	local loadedOk = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("u_" .. player.UserId)
			end)
			if ok then
				data = result
				loadedOk = true
				break
			end
			task.wait(attempt)
		end
	end
	local d = defaultData()
	if type(data) == "table" then
		d.Cash = tonumber(data.Cash) or d.Cash
		d.Vehicles = type(data.Vehicles) == "table" and data.Vehicles or d.Vehicles
		d.Vehicles.Starter = true
		d.Index = type(data.Index) == "table" and data.Index or d.Index
		d.Rescued = tonumber(data.Rescued) or 0
		d.TotalEarned = tonumber(data.TotalEarned) or 0
		d.WeekId = tonumber(data.WeekId) or 0
		d.WeekEarned = tonumber(data.WeekEarned) or 0
	end
	if d.WeekId ~= DataService.currentWeek() then
		d.WeekId = DataService.currentWeek()
		d.WeekEarned = 0
	end
	return d, loadedOk
end

-- Saves the player's progress (cash, vehicles, index, earnings).
-- Retries up to 3 times; returns true when saved.
function DataService.save(player)
	local prof = profiles[player]
	-- Never overwrite saved progress if loading failed.
	if not (store and prof and prof.loaded) then
		return false
	end
	local copy = table.clone(prof.data)
	copy.SavedAt = os.time()
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync("u_" .. player.UserId, function()
				return copy
			end)
		end)
		if ok then
			prof.dirty = false
			return true
		end
		warn("[WildWest] Save failed for " .. player.UserId .. " (attempt " .. attempt .. "): " .. tostring(err))
		task.wait(attempt * 2)
	end
	return false
end

-- Save soon after something important (a purchase), without spamming.
function DataService.saveSoon(player)
	local prof = profiles[player]
	if not prof or prof.saveQueued then
		return
	end
	prof.saveQueued = true
	task.delay(6, function()
		prof.saveQueued = false
		if profiles[player] == prof then
			DataService.save(player)
		end
	end)
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	ls.Parent = player

	local infinite = DataService.isDev(player)
	player:SetAttribute("InfiniteCash", infinite)
	player:SetAttribute("IsDev", infinite)

	local data, loadedOk = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, loaded = loadedOk, infinite = infinite }
	publish(player)
	DataService.updateFriendBoosts()
	if store and not loadedOk then
		-- Roblox's save servers didn't answer. Don't let this session
		-- overwrite the real progress; tell the player.
		Remotes.notify(player, "⚠️ Couldn't load your saved progress. Rejoin to try again – nothing from this visit will be saved.", Color3.fromRGB(255, 120, 90))
	end
end

local function onPlayerRemoving(player)
	DataService.save(player)
	profiles[player] = nil
	task.defer(DataService.updateFriendBoosts)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function DataService.get(player)
	local prof = profiles[player]
	return prof and prof.data
end

function DataService.waitFor(player)
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player] and profiles[player].data
end

function DataService.hasInfiniteCash(player)
	local prof = profiles[player]
	return prof ~= nil and prof.infinite == true
end

function DataService.getCash(player)
	local d = DataService.get(player)
	if DataService.hasInfiniteCash(player) then
		return math.huge
	end
	return d and d.Cash or 0
end

-- Add cash (boosted by Friend Boost when applyBoost is true). Returns amount added.
function DataService.addCash(player, amount, applyBoost)
	local d = DataService.get(player)
	if not d or amount <= 0 then
		return 0
	end
	if applyBoost then
		amount = amount * (1 + (player:GetAttribute("FriendBoost") or 0))
	end
	amount = math.floor(amount + 0.5)
	d.Cash += amount
	d.TotalEarned += amount
	if d.WeekId ~= DataService.currentWeek() then
		d.WeekId = DataService.currentWeek()
		d.WeekEarned = 0
	end
	d.WeekEarned += amount
	publish(player)
	Remotes.CashPopup:FireClient(player, amount)
	return amount
end

-- Spend cash. Developers always succeed and never lose money.
function DataService.spend(player, amount)
	local d = DataService.get(player)
	if not d then
		return false
	end
	if DataService.hasInfiniteCash(player) then
		return true
	end
	if d.Cash < amount then
		return false
	end
	d.Cash -= amount
	publish(player)
	return true
end

function DataService.ownsVehicle(player, id)
	local d = DataService.get(player)
	return d ~= nil and d.Vehicles[id] == true
end

function DataService.giveVehicle(player, id)
	local d = DataService.get(player)
	if d then
		d.Vehicles[id] = true
		publish(player)
		DataService.saveSoon(player) -- purchases are saved right away
	end
end

function DataService.recordRescue(player, luck)
	local d = DataService.get(player)
	if d then
		local key = tostring(luck)
		d.Index[key] = (d.Index[key] or 0) + 1
		d.Rescued += 1
		publish(player)
	end
end

---------------------------------------------------------------------------
-- Friend Boost: +10% per friend in the server
---------------------------------------------------------------------------
local friendCache = {}
local function areFriends(a, b)
	local key = math.min(a.UserId, b.UserId) .. "_" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, res = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[key] = ok and res or false
	end
	return friendCache[key]
end

function DataService.updateFriendBoosts()
	local list = Players:GetPlayers()
	for _, p in list do
		local count = 0
		for _, other in list do
			if other ~= p and areFriends(p, other) then
				count += 1
			end
		end
		p:SetAttribute("FriendBoost", math.min(Config.FriendBoostMax, count * Config.FriendBoostPerFriend))
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for p in profiles do
				task.spawn(DataService.save, p)
			end
		end
	end)
	-- Server shutting down: save everyone at the same time (Roblox allows ~30s).
	game:BindToClose(function()
		local pending = 0
		for p in profiles do
			pending += 1
			task.spawn(function()
				DataService.save(p)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
