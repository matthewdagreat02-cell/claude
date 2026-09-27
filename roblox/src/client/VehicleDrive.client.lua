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

	-- Wheel angle: full lock at low speed, still 70% at top speed.
	local speedFactor = math.clamp(math.abs(forwardSpeed) / top, 0, 1)
	local angle = -steer * maxSteer * (1 - 0.3 * speedFactor)
	for _, s in r.steers do
		-- Ackermann: the inside wheel turns more than the outside wheel
		local side = s:GetAttribute("Side") or 0
		local inside = (angle < 0 and side > 0) or (angle > 0 and side < 0)
		s.TargetAngle = angle * (inside and 1.12 or 0.9)
	end

	-- Turn assist + grip, only while the wheels are on the ground.
	local assist = model:GetAttribute("TurnAssist") or 1
	if assist > 0 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model, char }
		local grounded = workspace:Raycast(chassis.Position, -chassis.CFrame.UpVector * (radius * 2 + 2.5), params) ~= nil
		if grounded then
			local turnRate = model:GetAttribute("TurnRate") or 2
			local vel = chassis.AssemblyLinearVelocity
			local ang = chassis.AssemblyAngularVelocity
			local up = chassis.CFrame.UpVector
			-- Turning right = negative spin around the vehicle's up axis.
			-- Needs a little speed so it doesn't spin on the spot; flips in reverse.
			local moving = math.clamp(math.abs(forwardSpeed) / 10, 0, 1)
			local direction = forwardSpeed >= 0 and 1 or -1
			local targetYaw = -steer * turnRate * moving * direction
			local currentYaw = ang:Dot(up)
			local newYaw = currentYaw + (targetYaw - currentYaw) * 0.35 * assist
			if steer == 0 then
				newYaw = currentYaw * (1 - 0.15 * assist) -- straighten out, no drifting spin
			end
			chassis.AssemblyAngularVelocity = ang + up * (newYaw - currentYaw)

			-- Remove some sideways sliding so turns bite instead of skidding.
			local grip = model:GetAttribute("SideGrip") or 0.18
			local right = chassis.CFrame.RightVector
			local side = vel:Dot(right)
			chassis.AssemblyLinearVelocity = vel - right * side * grip
		end
	end
end)
