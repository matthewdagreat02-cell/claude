-- StarterPlayerScripts.WildWestClient.VehicleDrive (LocalScript)
-- Drives Wild West vehicles on the driver's own machine (the server gives
-- the driver physics ownership), so steering and throttle feel instant.
-- While the tornado has the vehicle, the server controls it and jumping out
-- is disabled so the driver stays seated.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local cache = {} -- [model] = { motors = {}, steers = {} }
local jumpDisabled = false

local function rig(model)
	local r = cache[model]
	if r then
		return r
	end
	r = { motors = {}, steers = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("HingeConstraint") then
			if d.Name == "DriveMotor" then
				table.insert(r.motors, d)
			elseif d.Name == "Steer" then
				table.insert(r.steers, d)
			end
		end
	end
	cache[model] = r
	model.Destroying:Connect(function()
		cache[model] = nil
	end)
	return r
end

local function setJump(hum, enabled)
	if jumpDisabled == not enabled then
		return
	end
	jumpDisabled = not enabled
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local seat = hum.SeatPart
	local model = seat and seat:IsA("VehicleSeat") and seat.Parent
	if not (model and model:GetAttribute("WWVehicle")) then
		setJump(hum, true)
		return
	end

	if model:GetAttribute("InTornado") then
		setJump(hum, false) -- hold on tight!
		return
	end
	setJump(hum, true)

	local r = rig(model)
	local chassis = model.PrimaryPart
	if not chassis then
		return
	end
	local top = model:GetAttribute("TopSpeed") or 60
	local radius = model:GetAttribute("WheelRadius") or 1.6
	local torque = model:GetAttribute("MotorTorque") or 5000
	local maxSteer = model:GetAttribute("MaxSteer") or 30
	local dir = model:GetAttribute("InvertDrive") and 1 or -1

	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat
	local forwardSpeed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)

	local angVel, tq
	if throttle > 0 then
		if forwardSpeed < -2 then
			angVel, tq = 0, torque * 1.5 -- braking from reverse
		else
			angVel, tq = dir * top / radius, torque
		end
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			angVel, tq = 0, torque * 1.5 -- braking
		else
			angVel, tq = -dir * top * 0.45 / radius, torque
		end
	else
		angVel, tq = 0, torque * 0.08 -- coasting
	end
	for _, m in r.motors do
		m.AngularVelocity = angVel
		m.MotorMaxTorque = tq
	end

	local speedFactor = math.clamp(math.abs(forwardSpeed) / top, 0, 1)
	local angle = -steer * maxSteer * (1 - 0.55 * speedFactor)
	for _, s in r.steers do
		s.TargetAngle = angle
	end
end)
