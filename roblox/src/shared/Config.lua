-- ReplicatedStorage.WildWestShared.Config (ModuleScript)
-- Every tunable number for the Wild West systems lives here.
-- The server and the client both read it.

local Config = {}

---------------------------------------------------------------------------
-- DEVELOPER / INFINITE CASH
---------------------------------------------------------------------------
-- Put your Roblox user ID here (the number in your profile link:
-- roblox.com/users/<THIS NUMBER>/profile). Accounts listed here get
-- infinite cash and can read feedback from the mailbox.
Config.DevUserIds = {
	-- 123456789,
}
-- If the game is owned by your own account (not a group), the owner is
-- automatically treated as a developer. For a group game, rank 255
-- (the group owner) is treated as a developer.
Config.OwnerIsDev = true

---------------------------------------------------------------------------
-- CASH / SAVING
---------------------------------------------------------------------------
Config.StartingCash = 150
Config.DataStoreName = "WildWestPlayerData_v1"
Config.AutosaveSeconds = 120

-- Friend Boost: +10% cash for every friend in the same server, max +50%.
Config.FriendBoostPerFriend = 0.10
Config.FriendBoostMax = 0.50

---------------------------------------------------------------------------
-- SURVIVOR LUCK LEVELS (shown with a four-leaf clover, never a name)
---------------------------------------------------------------------------
-- Weight = how common the level is. Cash = paid when dropped off.
Config.LuckLevels = {
	{ Level = 1, Weight = 50, Cash = 25, Color = Color3.fromRGB(120, 220, 110) },
	{ Level = 2, Weight = 25, Cash = 60, Color = Color3.fromRGB(70, 200, 90) },
	{ Level = 3, Weight = 13, Cash = 150, Color = Color3.fromRGB(40, 190, 170) },
	{ Level = 4, Weight = 8, Cash = 400, Color = Color3.fromRGB(80, 150, 255) },
	{ Level = 5, Weight = 4, Cash = 1200, Color = Color3.fromRGB(255, 205, 40) },
}
Config.CloverIcon = "🍀"

Config.Survivors = {
	MaxInWorld = 45, -- survivors alive in the map at once
	RespawnSeconds = 6, -- how often a missing survivor is replaced
	IndoorShare = 0.6, -- 60% spawn inside buildings, 40% outside
	RescueRange = 70, -- your vehicle must be this close (studs) to rescue
	MaxPerVehicle = 1, -- survivors a vehicle can carry at once (extra seats are for friends)
	RunToVehicleTimeout = 10, -- seconds before a stuck survivor is placed in the seat
	DropOffRadius = 16,
}

---------------------------------------------------------------------------
-- VEHICLES
---------------------------------------------------------------------------
-- TopSpeed is in studs/second. The starter used to be 50, so 1.5x = 75.
-- If your existing starter truck has a different speed, set
-- StarterBaseSpeed to that value and the 1.5x is applied automatically.
Config.StarterBaseSpeed = 50
Config.StarterSpeedMultiplier = 1.5

Config.Vehicles = {
	{
		Id = "Starter",
		Name = "Pickup Truck",
		Icon = "🛻",
		Price = 0,
		Style = "Pickup",
		TopSpeed = Config.StarterBaseSpeed * Config.StarterSpeedMultiplier, -- 75
		Acceleration = 45,
		Color = Color3.fromRGB(200, 60, 50),
	},
	{
		Id = "SchoolBus",
		Name = "Short School Bus",
		Icon = "🚌",
		Price = 25000,
		Style = "ShortBus",
		TopSpeed = 100, -- 2nd fastest
		Acceleration = 50,
		Color = Color3.fromRGB(255, 196, 30),
	},
	{
		Id = "KeiTruck",
		Name = "Kei Truck",
		Icon = "🚚",
		Price = 100000,
		Style = "Kei",
		TopSpeed = 125, -- fastest in the game
		Acceleration = 70,
		Color = Color3.fromRGB(245, 245, 240),
	},
}
-- Flip this if vehicles drive backwards when you press W.
Config.InvertDrive = false
Config.MaxSteerDegrees = 32

---------------------------------------------------------------------------
-- TORNADO VEHICLE THROW
---------------------------------------------------------------------------
-- Tag your tornado Model (or its main Part) with the CollectionService
-- tag "Tornado". Optional attributes on it override these defaults.
Config.Tornado = {
	SuckRadius = 110, -- vehicles inside this start getting pulled in
	CoreRadius = 24, -- vehicles inside this get picked up
	MaxPullAccel = 160, -- studs/s^2 at the core (more than any car can fight)
	LiftHeight = 140, -- how high a vehicle is carried before the throw
	SpinSeconds = { 2, 4 },
	MinThrowDistance = 700, -- thrown at least this far
	RegrabCooldown = 5,
	-- Only the anime tornado is allowed in the game. Give your anime tornado
	-- the attribute TornadoStyle = "Anime". Any tornado tagged "Tornado"
	-- with a different TornadoStyle is deleted as soon as it appears.
	OnlyStyle = "Anime",
}

-- The playable area. Throw targets are kept inside it, and the town
-- generator fills it. Center is the middle, Size is X/Z width in studs.
Config.Map = {
	Center = Vector3.new(0, 0, 0),
	Size = Vector2.new(1600, 1600),
	GroundY = 0, -- used if nothing is found under a point
}

---------------------------------------------------------------------------
-- TOWN GENERATOR
---------------------------------------------------------------------------
Config.Town = {
	Enabled = true,
	Seed = 1885, -- change for a different layout, or nil for random each server
	TargetFill = 0.60, -- 60% of the map gets buildings / farms / roads
	MainStreetWidth = 26,
	SideStreetWidth = 18,
	SideStreets = 6,
	-- Put Blender models here (ServerStorage.TownModels.<Kind>) and they
	-- replace the placeholder buildings with the same name, e.g. "Bank".
	ModelsFolderName = "TownModels",
}

---------------------------------------------------------------------------
-- PLAYER PLOTS (built from the blueprint)
---------------------------------------------------------------------------
Config.Plots = {
	Count = 6,
	Size = 120,
	Spacing = 135,
	-- Row of plots along X near the edge of the map. Front edge (the gate
	-- and the ranch road) faces -Z, toward town.
	Origin = Vector3.new(0, 0, 700),
}

-- Ground-centre CFrame of plot number i (front faces -Z).
function Config.plotCFrame(i)
	local pc = Config.Plots
	local x = pc.Origin.X + (i - (pc.Count + 1) / 2) * pc.Spacing
	return CFrame.new(x, pc.Origin.Y, pc.Origin.Z)
end

---------------------------------------------------------------------------
-- GLOBAL LEADERBOARDS (one on each side of the row of player plots)
---------------------------------------------------------------------------
Config.Leaderboards = {
	AllTimeStore = "WildWestEarnings_AllTime_v1",
	WeeklyStorePrefix = "WildWestEarnings_Week_v1_",
	Entries = 10,
	RefreshSeconds = 60,
	Width = 22,
	Height = 30,
}

-- Ground-centre CFrames of the two boards, facing the ranch road (-Z).
function Config.leaderboardCFrames()
	local pc = Config.Plots
	local left = Config.plotCFrame(1)
	local right = Config.plotCFrame(pc.Count)
	local gap = pc.Size / 2 + 22
	return {
		AllTime = CFrame.new(left.X - gap, pc.Origin.Y, pc.Origin.Z - 20),
		Weekly = CFrame.new(right.X + gap, pc.Origin.Y, pc.Origin.Z - 20),
	}
end

---------------------------------------------------------------------------
-- FEEDBACK MAILBOX
---------------------------------------------------------------------------
Config.Feedback = {
	DataStoreName = "WildWestFeedback_v1",
	MinLength = 3,
	MaxLength = 500,
	CooldownSeconds = 60,
}

function Config.getVehicle(id)
	for _, v in Config.Vehicles do
		if v.Id == id then
			return v
		end
	end
	return nil
end

function Config.getLuck(level)
	return Config.LuckLevels[level] or Config.LuckLevels[1]
end

return Config
