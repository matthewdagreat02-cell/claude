-- ServerScriptService.WildWest.Main (Script)
-- Starts every Wild West system in the right order.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))

local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local VehicleService = require(script.Parent.VehicleService)
local TornadoVehicleFling = require(script.Parent.TornadoVehicleFling)
local SurvivorService = require(script.Parent.SurvivorService)
local FeedbackService = require(script.Parent.FeedbackService)
local TownGenerator = require(script.Parent.TownGenerator)
local LeaderboardService = require(script.Parent.LeaderboardService)

local _ = Remotes

VehicleService.PlotService = PlotService
SurvivorService.PlotService = PlotService

DataService.start()
PlotService.start() -- plots first, so the town leaves room for them
VehicleService.start()
TornadoVehicleFling.start()
FeedbackService.start()
LeaderboardService.start()

if Config.Town.Enabled then
	task.spawn(function()
		TownGenerator.generate()
		SurvivorService.start()
	end)
else
	-- Town built by hand: survivors use any Parts tagged "SurvivorSpawn".
	SurvivorService.start()
end
