-- ServerScriptService.WildWest.FeedbackService (ModuleScript)
-- The mailbox feedback system. Players write feedback in the
-- "Share Your Feedback" window; it is saved to a DataStore (anonymously –
-- no name or user ID is stored). Developers can read it in-game with the
-- "Read Feedback" button that only they see in the same window.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)

local FC = Config.Feedback
local FeedbackService = {}

local store, index
pcall(function()
	store = DataStoreService:GetDataStore(FC.DataStoreName)
	index = DataStoreService:GetOrderedDataStore(FC.DataStoreName .. "_Index")
end)

local lastSubmit = {}

local function submit(player, text)
	if type(text) ~= "string" then
		return false, "Please type something first."
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if utf8.len(text) == nil then
		return false, "That text couldn't be read."
	end
	if #text < FC.MinLength then
		return false, "Please write a little more."
	end
	if utf8.len(text) > FC.MaxLength then
		return false, "Please keep it under " .. FC.MaxLength .. " characters."
	end
	local now = os.time()
	if lastSubmit[player.UserId] and now - lastSubmit[player.UserId] < FC.CooldownSeconds then
		return false, "Thanks! You can send more feedback in a minute."
	end
	if not (store and index) then
		return false, "Feedback is unavailable right now."
	end

	-- Roblox text filter (required before another person reads it)
	local okFilter, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not okFilter then
		return false, "Couldn't send right now, please try again."
	end

	local key = string.format("fb_%d_%s", now, HttpService:GenerateGUID(false):sub(1, 8))
	local ok = pcall(function()
		store:SetAsync(key, { Text = filtered, Time = now, Version = game.PlaceVersion })
		index:SetAsync(key, now)
	end)
	if not ok then
		return false, "Couldn't send right now, please try again."
	end
	lastSubmit[player.UserId] = now
	return true, "Thanks for your feedback!"
end

-- Newest feedback first (developers only).
local function fetch(player)
	if not DataService.hasInfiniteCash(player) then
		return {}
	end
	if not (store and index) then
		return {}
	end
	local list = {}
	local ok = pcall(function()
		local pages = index:GetSortedAsync(false, 50)
		for _, entry in pages:GetCurrentPage() do
			local data = store:GetAsync(entry.key)
			if data then
				table.insert(list, { Text = data.Text, Time = data.Time })
			end
		end
	end)
	if not ok then
		return {}
	end
	return list
end

function FeedbackService.start()
	Remotes.SubmitFeedback.OnServerInvoke = submit
	Remotes.GetFeedback.OnServerInvoke = fetch
end

return FeedbackService
