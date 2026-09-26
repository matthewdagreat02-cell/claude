-- ServerScriptService.WildWest.Remotes (ModuleScript)
-- Creates ReplicatedStorage.WildWestRemotes so the client UI can talk to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("WildWestRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WildWestRemotes"
	folder.Parent = ReplicatedStorage
end

local function get(className, name)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = folder
	end
	return r
end

Remotes.BuyVehicle = get("RemoteFunction", "BuyVehicle")
Remotes.SpawnVehicle = get("RemoteFunction", "SpawnVehicle")
Remotes.SubmitFeedback = get("RemoteFunction", "SubmitFeedback")
Remotes.GetFeedback = get("RemoteFunction", "GetFeedback")
Remotes.GoHome = get("RemoteEvent", "GoHome")
Remotes.Notify = get("RemoteEvent", "Notify")
Remotes.CashPopup = get("RemoteEvent", "CashPopup")

function Remotes.notify(player, text, color)
	Remotes.Notify:FireClient(player, text, color)
end

return Remotes
