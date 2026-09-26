-- ServerScriptService.WildWest.SurvivorService (ModuleScript)
-- Survivors spawn inside homes/buildings and outside around town.
-- They NEVER show a name – only a four-leaf clover luck level (🍀 Luck 3).
--
-- Rescue: drive near a survivor, hold E on "Rescue". They run to your
-- vehicle and sit in a free passenger seat.
-- Drop-off: drive onto the green drop-off circle at your plot. Each
-- survivor pays Config.LuckLevels[luck].Cash (+ Friend Boost).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)
local VehicleService = require(script.Parent.VehicleService)

local SC = Config.Survivors
local SurvivorService = {}
SurvivorService.PlotService = nil -- set by Main

local rng = Random.new()
local folder
local waiting = {} -- survivors standing in the world, [model] = spawnPart
local usedSpawns = {} -- [spawnPart] = model

local SKIN = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(241, 194, 150), Color3.fromRGB(224, 172, 125),
	Color3.fromRGB(198, 134, 90), Color3.fromRGB(141, 85, 54), Color3.fromRGB(90, 60, 40),
}
local CLOTHES = {
	Color3.fromRGB(196, 60, 50), Color3.fromRGB(60, 110, 190), Color3.fromRGB(90, 150, 80),
	Color3.fromRGB(220, 170, 60), Color3.fromRGB(120, 80, 60), Color3.fromRGB(150, 90, 170),
	Color3.fromRGB(230, 230, 220), Color3.fromRGB(70, 70, 80),
}
local ANIMS = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Sit = "rbxassetid://2506281703",
}

local function rollLuck()
	local total = 0
	for _, l in Config.LuckLevels do
		total += l.Weight
	end
	local r = rng:NextNumber(0, total)
	for _, l in Config.LuckLevels do
		r -= l.Weight
		if r <= 0 then
			return l.Level
		end
	end
	return 1
end

local function makeLuckLabel(model, luck)
	local info = Config.getLuck(luck)
	local head = model:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Name = "LuckLabel"
	gui.Size = UDim2.fromOffset(120, 36)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = Config.CloverIcon .. " Luck " .. luck
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = info.Color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = model
end

local function playAnim(humanoid, id, looped)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.2)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = looped ~= false
		track:Play(0.2)
	end
end

local function createSurvivor(spawnPart)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = CLOTHES[rng:NextInteger(1, #CLOTHES)]
	local legs = CLOTHES[rng:NextInteger(1, #CLOTHES)]
	desc.LeftLegColor, desc.RightLegColor = legs, legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Survivor"
	local hum = model:FindFirstChildOfClass("Humanoid")
	-- No names above survivors – only the luck label.
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.NameDisplayDistance = 0
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.WalkSpeed = 22
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- client animate script doesn't run on NPCs
	end

	local luck = rollLuck()
	model:SetAttribute("Luck", luck)
	model:SetAttribute("IsSurvivor", true)
	makeLuckLabel(model, luck)
	CollectionService:AddTag(model, "Survivor")

	model:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder
	pcall(function()
		model.PrimaryPart:SetNetworkOwner(nil)
	end)
	playAnim(hum, ANIMS.Idle)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "Rescue"
	prompt.ObjectText = Config.CloverIcon .. " Luck " .. luck
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 30
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("HumanoidRootPart")
	prompt.Triggered:Connect(function(player)
		SurvivorService.rescue(model, player)
	end)

	hum.Died:Connect(function()
		SurvivorService.release(model)
		task.delay(3, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end)
	return model
end

function SurvivorService.release(model)
	local sp = waiting[model]
	waiting[model] = nil
	if sp then
		usedSpawns[sp] = nil
	end
end

-- Survivors riding in (or running to) this vehicle.
local function survivorLoad(vehicle)
	local count = 0
	for _, d in vehicle:GetDescendants() do
		if d:IsA("Seat") and d.Name == "PassengerSeat" then
			local occ = d.Occupant
			if d:GetAttribute("Reserved") or (occ and occ.Parent and occ.Parent:GetAttribute("IsSurvivor")) then
				count += 1
			end
		end
	end
	return count
end

local function freeSeat(vehicle)
	if survivorLoad(vehicle) >= SC.MaxPerVehicle then
		return nil
	end
	for _, d in vehicle:GetDescendants() do
		if d:IsA("Seat") and d.Name == "PassengerSeat" and not d.Occupant and not d:GetAttribute("Reserved") then
			return d
		end
	end
	return nil
end

local function seatSurvivor(model, seat)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (hum and seat.Parent and model.Parent) then
		return false
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
		end
	end
	model:PivotTo(seat.CFrame + Vector3.new(0, 2, 0))
	seat:Sit(hum)
	playAnim(hum, ANIMS.Sit)
	return true
end

function SurvivorService.rescue(model, player)
	if not waiting[model] then
		return
	end
	local vehicle = VehicleService.getVehicle(player)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not vehicle or not vehicle.PrimaryPart then
		Remotes.notify(player, "Spawn your vehicle first (red button)!", Color3.fromRGB(255, 120, 90))
		return
	end
	if (vehicle.PrimaryPart.Position - root.Position).Magnitude > SC.RescueRange then
		Remotes.notify(player, "Bring your vehicle closer to rescue survivors!", Color3.fromRGB(255, 200, 80))
		return
	end
	local seat = freeSeat(vehicle)
	if not seat then
		Remotes.notify(player, "You already have a survivor! Drop them off at your plot first.", Color3.fromRGB(255, 200, 80))
		return
	end
	seat:SetAttribute("Reserved", true)
	SurvivorService.release(model)
	model:SetAttribute("RescuedBy", player.UserId)
	local prompt = root:FindFirstChild("RescuePrompt")
	if prompt then
		prompt:Destroy()
	end

	-- Run out to the vehicle (pathfinding so they leave buildings through the door)
	local hum = model:FindFirstChildOfClass("Humanoid")
	model:SetAttribute("Running", true)
	task.spawn(function()
		playAnim(hum, ANIMS.Run)
		local startT = os.clock()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(root.Position, seat.Position)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in path:GetWaypoints() do
				if os.clock() - startT > SC.RunToVehicleTimeout or not seat.Parent or not model.Parent then
					break
				end
				if wp.Action == Enum.PathWaypointAction.Jump then
					hum.Jump = true
				end
				hum:MoveTo(wp.Position)
				local reached = false
				local conn = hum.MoveToFinished:Connect(function()
					reached = true
				end)
				local t0 = os.clock()
				while not reached and os.clock() - t0 < 1.5 do
					task.wait(0.05)
					if (root.Position - seat.Position).Magnitude < 7 then
						break
					end
				end
				conn:Disconnect()
				if (root.Position - seat.Position).Magnitude < 7 then
					break
				end
			end
		else
			-- no path: run straight at the vehicle
			while os.clock() - startT < SC.RunToVehicleTimeout and seat.Parent and model.Parent do
				hum:MoveTo(seat.Position)
				if (root.Position - seat.Position).Magnitude < 7 then
					break
				end
				task.wait(0.2)
			end
		end
		seat:SetAttribute("Reserved", nil)
		if seat.Parent and model.Parent and not seat.Occupant then
			seatSurvivor(model, seat)
			Remotes.notify(player, Config.CloverIcon .. " Survivor rescued! Take them to your drop-off.", Color3.fromRGB(120, 230, 110))
		elseif model.Parent then
			-- the seat got taken or the vehicle vanished: try another seat
			local other = vehicle.Parent and survivorLoad(vehicle) < SC.MaxPerVehicle and freeSeat(vehicle)
			if other then
				seatSurvivor(model, other)
			else
				model:Destroy()
			end
		end
		-- give the seat weld a moment before the cleanup check can run
		task.wait(1)
		if model.Parent then
			model:SetAttribute("Running", nil)
		end
	end)
end

-- Pay for every survivor riding in a vehicle parked on its owner's drop-off.
local function dropOffLoop()
	while true do
		task.wait(0.5)
		-- Rescued survivors whose vehicle was removed are cleaned up.
		for _, m in folder:GetChildren() do
			local hum = m:FindFirstChildOfClass("Humanoid")
			if m:GetAttribute("RescuedBy") and not m:GetAttribute("Running") and hum and not hum.SeatPart then
				m:Destroy()
			end
		end
		for _, player in Players:GetPlayers() do
			local vehicle = VehicleService.getVehicle(player)
			local plot = SurvivorService.PlotService and SurvivorService.PlotService.getPlot(player)
			if vehicle and vehicle.PrimaryPart and plot and plot.DropOff then
				local d = vehicle.PrimaryPart.Position - plot.DropOff.Position
				if Vector2.new(d.X, d.Z).Magnitude < SC.DropOffRadius then
					local total, count = 0, 0
					for _, seat in vehicle:GetDescendants() do
						if seat:IsA("Seat") and seat.Occupant then
							local survivor = seat.Occupant.Parent
							if survivor and survivor:GetAttribute("IsSurvivor") then
								local luck = survivor:GetAttribute("Luck") or 1
								total += Config.getLuck(luck).Cash
								count += 1
								DataService.recordRescue(player, luck)
								survivor:Destroy()
							end
						end
					end
					if count > 0 then
						local paid = DataService.addCash(player, total, true)
						Remotes.notify(player, string.format("%d survivor%s saved! +$%d", count, count == 1 and "" or "s", paid), Color3.fromRGB(120, 230, 110))
					end
				end
			end
		end
	end
end

local function spawnLoop()
	while true do
		local count = 0
		for m in waiting do
			if m.Parent then
				count += 1
			else
				SurvivorService.release(m)
			end
		end
		if count < SC.MaxInWorld then
			local wantIndoor = rng:NextNumber() < SC.IndoorShare
			local candidates, fallback = {}, {}
			for _, sp in CollectionService:GetTagged("SurvivorSpawn") do
				if sp:IsDescendantOf(Workspace) and not usedSpawns[sp] then
					if (sp:GetAttribute("Indoor") == true) == wantIndoor then
						table.insert(candidates, sp)
					else
						table.insert(fallback, sp)
					end
				end
			end
			if #candidates == 0 then
				candidates = fallback
			end
			if #candidates > 0 then
				local sp = candidates[rng:NextInteger(1, #candidates)]
				local m = createSurvivor(sp)
				if m then
					waiting[m] = sp
					usedSpawns[sp] = m
				end
			end
			task.wait(count < SC.MaxInWorld * 0.5 and 0.2 or SC.RespawnSeconds)
		else
			task.wait(SC.RespawnSeconds)
		end
	end
end

function SurvivorService.start()
	folder = Workspace:FindFirstChild("Survivors") or Instance.new("Folder")
	folder.Name = "Survivors"
	folder.Parent = Workspace
	task.spawn(spawnLoop)
	task.spawn(dropOffLoop)
end

return SurvivorService
