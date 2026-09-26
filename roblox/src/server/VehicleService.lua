-- ServerScriptService.WildWest.VehicleService (ModuleScript)
-- Buying, spawning and parking vehicles. One active vehicle per player.
-- Also flips vehicles back onto their wheels after a crash or tornado landing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)
local VehicleBuilder = require(script.Parent.VehicleBuilder)

local VehicleService = {}
VehicleService.PlotService = nil -- set by Main to avoid a require cycle

local active = {} -- [player] = model
local folder

local function allParts(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

function VehicleService.setNetworkOwner(model, player)
	for _, p in allParts(model) do
		if not p.Anchored and p:CanSetNetworkOwnership() then
			pcall(function()
				p:SetNetworkOwner(player)
			end)
		end
	end
end

-- Server-side motor values are used whenever the server owns the physics
-- (parked, or during a tornado). Parked = strong brake.
function VehicleService.serverBrake(model, strength)
	local torque = (model:GetAttribute("MotorTorque") or 5000) * (strength or 1)
	for _, d in model:GetDescendants() do
		if d:IsA("HingeConstraint") and d.Name == "DriveMotor" then
			d.AngularVelocity = 0
			d.MotorMaxTorque = torque
		elseif d:IsA("HingeConstraint") and d.Name == "Steer" then
			d.TargetAngle = 0
		end
	end
end

function VehicleService.getDriverSeat(model)
	return model:FindFirstChild("DriverSeat", true)
end

-- Give physics back to whoever is driving (or the server if nobody is).
function VehicleService.restoreOwner(model)
	local seat = VehicleService.getDriverSeat(model)
	local occupant = seat and seat.Occupant
	local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
	if player then
		VehicleService.setNetworkOwner(model, player)
	else
		VehicleService.serverBrake(model, 1)
		VehicleService.setNetworkOwner(model, nil)
	end
end

function VehicleService.getVehicle(player)
	local m = active[player]
	if m and m.Parent then
		return m
	end
	return nil
end

function VehicleService.all()
	local list = {}
	for _, m in active do
		if m.Parent then
			table.insert(list, m)
		end
	end
	return list
end

function VehicleService.ownerOf(model)
	for player, m in active do
		if m == model then
			return player
		end
	end
	return nil
end

local function despawn(player)
	local m = active[player]
	active[player] = nil
	if m then
		-- Survivors riding in it go back to being lost (they respawn elsewhere).
		m:Destroy()
	end
end

function VehicleService.spawn(player, id)
	local def = Config.getVehicle(id)
	if not def then
		return false, "Unknown vehicle"
	end
	if not DataService.ownsVehicle(player, id) then
		return false, "You don't own this vehicle yet"
	end
	despawn(player)

	local cf
	if VehicleService.PlotService then
		cf = VehicleService.PlotService.getVehicleSpawn(player)
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not cf and root then
		cf = CFrame.new(root.Position + root.CFrame.LookVector * 14) * CFrame.Angles(0, select(2, root.CFrame:ToOrientation()), 0)
	end
	cf = cf or CFrame.new(Config.Map.Center + Vector3.new(0, 5, 0))

	local model = VehicleBuilder.build(def, cf + Vector3.new(0, 1, 0))
	model:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(model, "Vehicle")
	model.Parent = folder
	active[player] = model

	local seat = VehicleService.getDriverSeat(model)
	VehicleService.serverBrake(model, 1)
	VehicleService.setNetworkOwner(model, nil)

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if model:GetAttribute("InTornado") then
			return -- the tornado controls physics until it lets go
		end
		VehicleService.restoreOwner(model)
	end)

	-- "Drive" prompt, because the body hull blocks walking into the seat.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = def.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(who)
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)

	-- Put the player straight into the driver's seat.
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		if hum.SeatPart then
			hum.Sit = false
			task.wait(0.1)
		end
		task.defer(function()
			if seat.Parent and not seat.Occupant then
				seat:Sit(hum)
			end
		end)
	end
	return true, def.Name .. " ready!"
end

function VehicleService.buy(player, id)
	local def = Config.getVehicle(id)
	if not def then
		return false, "Unknown vehicle"
	end
	if DataService.ownsVehicle(player, id) then
		return false, "You already own the " .. def.Name
	end
	if not DataService.spend(player, def.Price) then
		return false, "Not enough cash"
	end
	DataService.giveVehicle(player, id)
	return true, "Bought the " .. def.Name .. "!"
end

-- Flip vehicles that end up on their roof or side.
local function uprightLoop()
	local stuckSince = {}
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, model in VehicleService.all() do
			local chassis = model.PrimaryPart
			if chassis and not model:GetAttribute("InTornado") then
				local flipped = chassis.CFrame.UpVector.Y < 0.35
				local slow = chassis.AssemblyLinearVelocity.Magnitude < 6
				if flipped and slow then
					stuckSince[model] = stuckSince[model] or now
					if now - stuckSince[model] > 2 then
						stuckSince[model] = nil
						local pos = chassis.Position
						local look = chassis.CFrame.LookVector
						local flat = Vector3.new(look.X, 0, look.Z)
						if flat.Magnitude < 0.1 then
							flat = Vector3.new(0, 0, -1)
						end
						VehicleService.setNetworkOwner(model, nil)
						model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 5, 0), pos + Vector3.new(0, 5, 0) + flat.Unit))
						for _, p in allParts(model) do
							p.AssemblyLinearVelocity = Vector3.zero
							p.AssemblyAngularVelocity = Vector3.zero
						end
						task.delay(0.3, function()
							if model.Parent then
								VehicleService.restoreOwner(model)
							end
						end)
					end
				else
					stuckSince[model] = nil
				end
			end
		end
	end
end

function VehicleService.start()
	folder = Workspace:FindFirstChild("PlayerVehicles") or Instance.new("Folder")
	folder.Name = "PlayerVehicles"
	folder.Parent = Workspace

	Remotes.BuyVehicle.OnServerInvoke = function(player, id)
		if type(id) ~= "string" then
			return false, "Bad request"
		end
		return VehicleService.buy(player, id)
	end
	local lastSpawn = {}
	Remotes.SpawnVehicle.OnServerInvoke = function(player, id)
		if type(id) ~= "string" then
			return false, "Bad request"
		end
		if lastSpawn[player] and os.clock() - lastSpawn[player] < 3 then
			return false, "Wait a moment before spawning again"
		end
		lastSpawn[player] = os.clock()
		return VehicleService.spawn(player, id)
	end
	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		lastSpawn[player] = nil
	end)
	task.spawn(uprightLoop)
end

return VehicleService
