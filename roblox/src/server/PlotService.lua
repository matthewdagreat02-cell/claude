-- ServerScriptService.WildWest.PlotService (ModuleScript)
-- Player plots, built to the blueprint (120 x 120 studs, 1 stud ~ 1 ft):
--   * garage with 3 vehicle bays (fits the school bus)
--   * bunkhouse: kitchen/living room, bedroom, storm shelter
--   * survivor drop-off circle
--   * fenced yard with a gate and a driveway to the ranch road
--   * spawn pad
--   * feedback mailbox by the gate
-- Plot local frame: centre of the plot at ground level, gate side = -Z.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local Build = require(script.Parent.Build)
local Buildings = require(script.Parent.Buildings)
local P = Build.Palette

local PlotService = {}

local plots = {} -- array of plot records
local byPlayer = {} -- [player] = plot record
local folder

local GRASS = Color3.fromRGB(176, 196, 112)
local GRAVEL = Color3.fromRGB(190, 176, 150)
local CONCRETE = Color3.fromRGB(170, 170, 165)
local SHELTER = Color3.fromRGB(120, 124, 130)

local BAY_X = { -41.67, -25, -8.33 }

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(Vector3.new(x, Config.Map.GroundY + 400, z), Vector3.new(0, -800, 0), params)
	return hit and hit.Position.Y or Config.Map.GroundY
end

local function buildMailbox(parent, cf)
	local m = Instance.new("Model")
	m.Name = "FeedbackMailbox"
	Build.box(m, cf * CFrame.new(0, 2, 0), Vector3.new(0.6, 4, 0.6), P.DarkWood, "Post")
	local body = Build.box(m, cf * CFrame.new(0, 4.6, 0), Vector3.new(2.2, 1.6, 3.4), Color3.fromRGB(220, 50, 45), "Body")
	local top = Build.part({ Parent = m, Shape = Enum.PartType.Cylinder, Name = "Top", Size = Vector3.new(3.4, 2.2, 2.2), Color = Color3.fromRGB(220, 50, 45) })
	top.CFrame = cf * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, math.pi / 2, 0)
	Build.box(m, cf * CFrame.new(0, 4.9, -1.75), Vector3.new(1.8, 1.8, 0.2), Color3.fromRGB(30, 30, 34), "Slot")
	Build.box(m, cf * CFrame.new(1.2, 5.6, 0.6), Vector3.new(0.2, 1.8, 0.3), P.Mustard, "FlagPole")
	Build.box(m, cf * CFrame.new(1.2, 6.2, 0.1), Vector3.new(0.2, 0.7, 1), P.Mustard, "Flag")
	-- Orange ring on the ground: step into it to open the feedback window.
	local ring = Build.part({
		Parent = m,
		Shape = Enum.PartType.Cylinder,
		Name = "FeedbackZone",
		Size = Vector3.new(0.12, 12, 12),
		Color = Color3.fromRGB(255, 140, 40),
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
		Tags = { "FeedbackMailbox" },
	})
	ring.CFrame = cf * CFrame.new(-4, 0.08, -3) * CFrame.Angles(0, 0, math.pi / 2)
	-- "Feedback" floating label
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 120
	gui.Adornee = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Feedback"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 45, 45)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 0, 0)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = m
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedbackPrompt"
	prompt.ActionText = "Give Feedback"
	prompt.ObjectText = "Mailbox"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	m.Parent = parent
	return m
end

local function buildBunkhouse(parent, cf)
	-- 36 x 28, front door facing -Z. Kitchen/living in front,
	-- bedroom back-left, storm shelter back-right.
	local m = Instance.new("Model")
	m.Name = "Bunkhouse"
	local w, d, H, T = 36, 28, 12, 1
	local base = cf * CFrame.new(0, 1, 0)
	Build.box(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(w, 1, d), P.LightWood, "Floor")
	local function win(len, doorX)
		local list = {}
		for x = -len / 2 + 5, len / 2 - 5, 8 do
			if not doorX or math.abs(x - doorX) > 5 then
				table.insert(list, { x = x, w = 4, y0 = 4, y1 = 8, glass = true })
			end
		end
		return list
	end
	local front = win(w - 2, 0)
	table.insert(front, { x = 0, w = 5, y0 = 0, y1 = 8 })
	Build.wall(m, base * CFrame.new(0, 0, -d / 2 + T / 2), w, H, T, front, P.White)
	Build.wall(m, base * CFrame.new(0, 0, d / 2 - T / 2) * CFrame.Angles(0, math.pi, 0), w, H, T, win(w - 2), P.White)
	for _, side in { -1, 1 } do
		Build.wall(m, base * CFrame.new(side * (w / 2 - T / 2), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), d - 2, H, T, win(d - 2), P.White)
	end
	-- interior walls
	Build.wall(m, base * CFrame.new(0, 0, 0), w - 2, H, 0.6, {
		{ x = -9, w = 5, y0 = 0, y1 = 8 },
		{ x = 9, w = 5, y0 = 0, y1 = 8 },
	}, P.Cream)
	Build.wall(m, base * CFrame.new(0, 0, d / 4) * CFrame.Angles(0, math.pi / 2, 0), d / 2 - 1, H, 0.6, {}, P.Cream)
	-- storm shelter: concrete lining, bench, lantern, sign
	local sx0, sx1, sz0, sz1 = 0.3, w / 2 - T, 0.3, d / 2 - T
	local scx, scz = (sx0 + sx1) / 2, (sz0 + sz1) / 2
	Build.box(m, base * CFrame.new(scx, 0.05, scz), Vector3.new(sx1 - sx0, 0.1, sz1 - sz0), SHELTER, "ShelterFloor")
	Build.box(m, base * CFrame.new(sx1 - 0.3, H / 2, scz), Vector3.new(0.6, H, sz1 - sz0), SHELTER, "ShelterLining")
	Build.box(m, base * CFrame.new(scx, H / 2, sz1 - 0.3), Vector3.new(sx1 - sx0, H, 0.6), SHELTER, "ShelterLining")
	Build.box(m, base * CFrame.new(scx, 1, sz1 - 2), Vector3.new(10, 2, 2), P.DarkWood, "Bench")
	Build.box(m, base * CFrame.new(sx1 - 2, 1.5, sz0 + 3), Vector3.new(3, 3, 3), P.LightWood, "SupplyCrate")
	Build.box(m, base * CFrame.new(scx, H - 1.5, scz), Vector3.new(0.8, 1, 0.8), Color3.fromRGB(255, 220, 140), "Lantern", { Material = Enum.Material.Neon })
	local lamp = Instance.new("PointLight")
	lamp.Range = 16
	lamp.Brightness = 1.4
	lamp.Color = Color3.fromRGB(255, 220, 160)
	lamp.Parent = m:FindFirstChild("Lantern")
	Build.sign(m, base * CFrame.new(9, 9.6, -0.4), Vector3.new(8, 1.8, 0.2), "STORM SHELTER", Color3.fromRGB(200, 40, 40), Color3.new(1, 1, 1))
	-- bedroom
	local k = { P.Rose, P.Sky }
	for i, x in { -w / 2 + 4, -w / 2 + 10 } do
		Build.box(m, base * CFrame.new(x, 0.8, d / 2 - 5), Vector3.new(4, 1.6, 7), P.DarkWood, "BedFrame")
		Build.box(m, base * CFrame.new(x, 1.8, d / 2 - 5), Vector3.new(3.8, 0.5, 6.8), k[i], "Blanket")
		Build.box(m, base * CFrame.new(x, 2.2, d / 2 - 2.3), Vector3.new(3, 0.5, 1.2), P.White, "Pillow")
	end
	-- kitchen / living room
	Build.box(m, base * CFrame.new(-w / 2 + 2.5, 1.5, -4), Vector3.new(3, 3, 2.5), P.Iron, "Stove")
	Build.box(m, base * CFrame.new(-w / 2 + 2.5, 7, -4), Vector3.new(0.6, 8, 0.6), P.Iron, "StovePipe")
	Build.box(m, base * CFrame.new(-w / 2 + 1.5, 1.75, -9), Vector3.new(2, 3.5, 7), P.DarkWood, "KitchenCounter")
	Build.box(m, base * CFrame.new(6, 3, -7), Vector3.new(6, 0.4, 4), P.Wood, "Table")
	Build.box(m, base * CFrame.new(6, 1.4, -7), Vector3.new(0.6, 2.8, 0.6), P.DarkWood, "TableLeg")
	for _, x in { 2.5, 9.5 } do
		Build.box(m, base * CFrame.new(x, 1.2, -7), Vector3.new(1.8, 0.4, 1.8), P.Wood, "Chair")
	end
	Build.box(m, base * CFrame.new(w / 2 - 4, 1.5, -9), Vector3.new(6, 3, 3), P.BarnRed, "Couch")
	Build.gableRoof(m, base, w, d, H, P.RoofBrown, P.White, 0.28)
	-- porch
	Build.box(m, cf * CFrame.new(0, 0.4, -d / 2 - 3), Vector3.new(14, 0.8, 6), P.Wood, "Porch")
	m.Parent = parent
	return m
end

local function buildGarage(parent, cf)
	-- 50 wide x 30 deep, open front facing -Z, 3 bays.
	local m = Instance.new("Model")
	m.Name = "Garage"
	local w, d, H, T = 50, 30, 14, 1
	Build.box(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(w, 0.2, d), CONCRETE, "GarageFloor")
	local base = cf * CFrame.new(0, 0.7, 0)
	Build.wall(m, base * CFrame.new(0, 0, d / 2 - T / 2) * CFrame.Angles(0, math.pi, 0), w, H, T, {
		{ x = -12, w = 4, y0 = 6, y1 = 10, glass = true },
		{ x = 12, w = 4, y0 = 6, y1 = 10, glass = true },
	}, P.BarnRed)
	for _, side in { -1, 1 } do
		Build.wall(m, base * CFrame.new(side * (w / 2 - T / 2), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), d - 2, H, T, {}, P.BarnRed)
	end
	-- front posts between bays + header
	for _, x in { -w / 2 + 0.5, -w / 6, w / 6, w / 2 - 0.5 } do
		Build.box(m, base * CFrame.new(x, H / 2, -d / 2 + 0.5), Vector3.new(1, H, 1), P.White, "BayPost")
	end
	Build.box(m, base * CFrame.new(0, H - 1, -d / 2 + 0.5), Vector3.new(w, 2, 1), P.White, "Header")
	Build.box(m, base * CFrame.new(0, H + 0.5, 0), Vector3.new(w + 1, 1, d + 1), P.RoofBrown, "Roof")
	Build.sign(m, base * CFrame.new(0, H + 2.6, -d / 2 + 0.2), Vector3.new(14, 3, 0.4), "GARAGE")
	-- bay lines + numbers
	for i, x in { -w / 3, 0, w / 3 } do
		Build.box(m, base * CFrame.new(x, 0.02, 0), Vector3.new(14, 0.02, d - 3), CONCRETE:Lerp(Color3.new(1, 1, 1), 0.15), "Bay" .. i)
	end
	-- tool bench
	Build.box(m, base * CFrame.new(-w / 2 + 2, 1.75, d / 2 - 6), Vector3.new(2.5, 3.5, 8), P.DarkWood, "Workbench")
	Build.box(m, base * CFrame.new(w / 2 - 2.5, 1.5, d / 2 - 3), Vector3.new(2.5, 3, 2.5), P.BarnRed, "FuelBarrel")
	m.Parent = parent
	return m
end

local function buildPlot(index)
	local pcf = Config.plotCFrame(index)
	local y = groundY(pcf.X, pcf.Z)
	local cf = CFrame.new(pcf.X, y, pcf.Z) -- identity rotation: gate side = -Z
	local half = Config.Plots.Size / 2

	local m = Instance.new("Model")
	m.Name = "Plot" .. index
	m.Parent = folder

	Build.box(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(Config.Plots.Size, 1, Config.Plots.Size), GRASS, "Ground")
	local top = cf * CFrame.new(0, 1, 0)
	-- driveway + apron in front of the garage
	Build.box(m, top * CFrame.new(-12, 0.05, -51), Vector3.new(16, 0.1, 18), GRAVEL, "Driveway")
	Build.box(m, top * CFrame.new(-25, 0.05, -35), Vector3.new(50, 0.1, 14), GRAVEL, "Apron")
	-- driveway out to the ranch road
	Build.box(m, cf * CFrame.new(-12, 0.15, -half - 8), Vector3.new(16, 0.3, 16), GRAVEL, "DrivewayOut")

	buildGarage(m, top * CFrame.new(-25, -0.7, -13))
	buildBunkhouse(m, top * CFrame.new(30, -1, 14))

	-- Survivor drop-off
	local drop = Build.part({
		Parent = m,
		Shape = Enum.PartType.Cylinder,
		Name = "DropOff",
		Size = Vector3.new(0.3, Config.Survivors.DropOffRadius * 2, Config.Survivors.DropOffRadius * 2),
		Color = Color3.fromRGB(90, 230, 110),
		Transparency = 0.35,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	drop.CFrame = top * CFrame.new(30, 0.12, -38) * CFrame.Angles(0, 0, math.pi / 2)
	for _, x in { 22, 38 } do
		Build.box(m, top * CFrame.new(x, 4, -20), Vector3.new(0.6, 8, 0.6), P.DarkWood, "SignPost")
	end
	Build.sign(m, top * CFrame.new(30, 7, -20.2), Vector3.new(18, 3, 0.4), Config.CloverIcon .. " SURVIVOR DROP-OFF", Color3.fromRGB(40, 140, 60), Color3.new(1, 1, 1))

	-- Spawn pad
	local spawnPad = Build.part({
		Parent = m,
		Shape = Enum.PartType.Cylinder,
		Name = "SpawnPad",
		Size = Vector3.new(0.4, 8, 8),
		Color = Color3.fromRGB(90, 170, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	spawnPad.CFrame = top * CFrame.new(5, 0.2, -20) * CFrame.Angles(0, 0, math.pi / 2)

	-- Fence with the gate gap in front of the driveway
	local c1 = (top * CFrame.new(-half, 0, -half)).Position
	local c2 = (top * CFrame.new(half, 0, -half)).Position
	local c3 = (top * CFrame.new(half, 0, half)).Position
	local c4 = (top * CFrame.new(-half, 0, half)).Position
	Buildings.fence(m, c1, c2, (top * CFrame.new(-12, 0, -half)).Position, 20)
	Buildings.fence(m, c2, c3)
	Buildings.fence(m, c3, c4)
	Buildings.fence(m, c4, c1)
	-- Gate arch with the owner's name
	for _, x in { -23, -1 } do
		Build.box(m, top * CFrame.new(x, 8, -half), Vector3.new(1.2, 16, 1.2), P.DarkWood, "GatePost")
	end
	Build.box(m, top * CFrame.new(-12, 15.5, -half), Vector3.new(24, 1.2, 1.2), P.DarkWood, "GateBeam")
	local ownerSign = Build.sign(m, top * CFrame.new(-12, 13.3, -half - 0.5), Vector3.new(18, 3, 0.4), "OPEN RANCH")
	ownerSign.Name = "OwnerSign"

	-- Feedback mailbox beside the gate
	buildMailbox(m, top * CFrame.new(-30, 0, -54))

	-- Yard details
	Build.box(m, top * CFrame.new(-54, 1.5, 20), Vector3.new(4, 3, 3), P.Hay, "HayBale")
	Build.box(m, top * CFrame.new(-54, 1.5, 25), Vector3.new(4, 3, 3), P.Hay, "HayBale")
	Build.box(m, top * CFrame.new(-54, 4.5, 22.5), Vector3.new(4, 3, 3), P.Hay, "HayBale")
	Build.box(m, top * CFrame.new(-40, 1, 30), Vector3.new(8, 2, 3), P.DarkWood, "WaterTrough")
	Build.box(m, top * CFrame.new(-40, 1.9, 30), Vector3.new(7.4, 0.2, 2.4), Color3.fromRGB(90, 160, 220), "Water")

	return {
		Index = index,
		Model = m,
		CFrame = top,
		DropOff = drop,
		SpawnPad = spawnPad,
		OwnerSign = ownerSign,
		Owner = nil,
	}
end

local function setOwnerText(plot, text)
	local gui = plot.OwnerSign:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

local function teleportHome(player)
	local plot = byPlayer[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (plot and hum) then
		return
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait(0.15)
	end
	char:PivotTo(plot.SpawnPad.CFrame * CFrame.Angles(0, 0, -math.pi / 2) + Vector3.new(0, 4, 0))
end

function PlotService.getPlot(player)
	return byPlayer[player]
end

function PlotService.getVehicleSpawn(player)
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	return plot.CFrame * CFrame.new(BAY_X[1], 0, -14)
end

function PlotService.start()
	folder = Workspace:FindFirstChild("PlayerPlots") or Instance.new("Folder")
	folder.Name = "PlayerPlots"
	folder.Parent = Workspace
	for i = 1, Config.Plots.Count do
		plots[i] = buildPlot(i)
	end

	local function assign(player)
		for _, plot in plots do
			if not plot.Owner then
				plot.Owner = player
				byPlayer[player] = plot
				setOwnerText(plot, player.DisplayName .. "'s Ranch")
				player:SetAttribute("PlotIndex", plot.Index)
				return plot
			end
		end
		return nil
	end

	local function onPlayer(player)
		assign(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			teleportHome(player)
		end)
		if player.Character then
			teleportHome(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local plot = byPlayer[player]
		if plot then
			plot.Owner = nil
			setOwnerText(plot, "OPEN RANCH")
		end
		byPlayer[player] = nil
	end)

	local lastHome = {}
	Remotes.GoHome.OnServerEvent:Connect(function(player)
		if lastHome[player] and os.clock() - lastHome[player] < 3 then
			return
		end
		lastHome[player] = os.clock()
		teleportHome(player)
	end)
end

return PlotService
