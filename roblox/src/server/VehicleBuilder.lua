-- ServerScriptService.WildWest.VehicleBuilder (ModuleScript)
-- Builds drivable low-poly vehicles from parts:
--   Pickup   – the starter: a normal pickup truck (cab, hood, open bed)
--   ShortBus – short yellow school bus with a fold-out stop sign
--   Kei      – tiny flat-fronted Japanese mini truck
--
-- Rig: Chassis (root) + 4 wheels on HingeConstraint motors, front wheels on
-- steering servos. Body parts are welded, massless and non-colliding; one
-- invisible "Hull" gives the body its collision.
-- The VehicleDrive LocalScript drives it using the attributes set here.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Build = require(script.Parent.Build)
local P = Build.Palette

local VehicleBuilder = {}

local STYLES = {
	Pickup = { L = 18, W = 8, R = 1.6, wheelZ = 5.8 },
	ShortBus = { L = 24, W = 9, R = 1.8, wheelZ = 7.6 },
	Kei = { L = 13, W = 6.5, R = 1.2, wheelZ = 4.2 },
}

local TIRE = Color3.fromRGB(35, 35, 40)
local HUB = Color3.fromRGB(200, 200, 205)
local BLACK = Color3.fromRGB(30, 30, 34)
local HEADLIGHT = Color3.fromRGB(255, 244, 200)
local TAILLIGHT = Color3.fromRGB(230, 40, 40)

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function VehicleBuilder.build(def, pivotCF)
	local st = STYLES[def.Style] or STYLES.Pickup
	local L, W, R = st.L, st.W, st.R
	local m = Instance.new("Model")
	m.Name = def.Id

	local chassisY = R + 0.2
	local chassis = Build.box(m, pivotCF * CFrame.new(0, chassisY, 0), Vector3.new(W - 2.8, 1, L - 1), BLACK, "Chassis", {
		Anchored = false,
		CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0, 1, 1),
	})
	m.PrimaryPart = chassis

	-- Body helper: local position is relative to the ground under the vehicle centre.
	local function body(x, y, z, sx, sy, sz, color, name, extra)
		local props = { Anchored = false, CanCollide = false, Massless = true, CanTouch = false }
		if extra then
			for k, v in extra do
				props[k] = v
			end
		end
		local p = Build.box(m, pivotCF * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, name or "Body", props)
		weld(chassis, p)
		return p
	end
	local function glass(x, y, z, sx, sy, sz)
		return body(x, y, z, sx, sy, sz, P.Glass, "Window", { Material = Enum.Material.Glass, Transparency = 0.35 })
	end
	local function light(x, y, z, sx, sy, sz, color)
		return body(x, y, z, sx, sy, sz, color, "Light", { Material = Enum.Material.Neon })
	end
	local function seat(className, x, y, z, name)
		local s = Instance.new(className)
		s.Name = name
		s.Size = Vector3.new(2, 1, 2)
		s.Color = BLACK
		s.Material = Enum.Material.SmoothPlastic
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Anchored = false
		s.Massless = true
		s.CFrame = pivotCF * CFrame.new(x, y, z)
		if s:IsA("VehicleSeat") then
			s.HeadsUpDisplay = false
			s.MaxSpeed = 0 -- driving is handled by VehicleDrive, not the legacy seat
		end
		s.Parent = m
		weld(chassis, s)
		return s
	end

	local top = R + 0.7 -- top of the chassis
	local seatY = top + 0.5
	local color = def.Color
	local hullTop

	if def.Style == "ShortBus" then
		-- Hood
		body(0, top + 1.3, -L / 2 + 2, W - 0.6, 2.6, 4, color, "Hood")
		body(0, top + 0.6, -L / 2 + 0.2, W - 0.2, 1.2, 0.6, BLACK, "Bumper")
		light(-W / 2 + 1.2, top + 1.6, -L / 2 + 0.05, 1.2, 0.8, 0.2, HEADLIGHT)
		light(W / 2 - 1.2, top + 1.6, -L / 2 + 0.05, 1.2, 0.8, 0.2, HEADLIGHT)
		-- Box body
		local z0, z1 = -L / 2 + 4, L / 2
		local bodyH = 9.4
		local zc, zl = (z0 + z1) / 2, z1 - z0
		body(0, top + 0.3, zc, W, 0.6, zl, color, "Floor")
		for _, side in { -1, 1 } do
			body(side * (W / 2 - 0.3), top + 2.2, zc, 0.6, 3.8, zl, color, "SideLower")
			body(side * (W / 2 - 0.25), top + 3.2, zc, 0.62, 0.5, zl, BLACK, "Stripe")
			body(side * (W / 2 - 0.3), top + bodyH - 0.6, zc, 0.6, 1.2, zl, color, "SideUpper")
			-- windows with pillars
			for z = z0 + 1.5, z1 - 1.5, 3.2 do
				glass(side * (W / 2 - 0.3), top + 6, z + 1.6, 0.3, 3.6, 2.6)
				body(side * (W / 2 - 0.3), top + 6, z, 0.6, 3.6, 0.6, color, "Pillar")
			end
		end
		body(0, top + bodyH + 0.3, zc, W + 0.2, 0.6, zl + 0.2, P.White, "Roof")
		glass(0, top + 6, z0 - 0.05, W - 1.2, 3.6, 0.3) -- windshield
		body(0, top + 2.2, z0, W, 3.8, 0.6, color, "FrontWall")
		body(0, top + bodyH / 2, z1 - 0.3, W, bodyH, 0.6, color, "BackWall")
		glass(0, top + 6.5, z1 + 0.02, W - 3, 2.6, 0.2)
		body(0, top + 0.6, z1 + 0.3, W - 0.2, 1.2, 0.6, BLACK, "RearBumper")
		light(-W / 2 + 0.8, top + 2, z1 + 0.05, 0.8, 1, 0.2, TAILLIGHT)
		light(W / 2 - 0.8, top + 2, z1 + 0.05, 0.8, 1, 0.2, TAILLIGHT)
		-- Door on the front right
		body(W / 2 + 0.05, top + 4.5, z0 + 1.6, 0.2, 7.5, 2.6, BLACK, "Door")
		-- Fold-out stop sign on the driver's side
		local sign = body(-W / 2 - 0.9, top + 5.5, z0 + 3, 0.2, 2, 2, Color3.fromRGB(210, 30, 30), "StopSign")
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.Parent = sign
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "STOP"
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = gui
		body(-W / 2 - 0.4, top + 5.5, z0 + 3, 0.8, 0.3, 0.3, BLACK, "StopArm")
		-- Seats: driver + rows of passenger seats
		seat("VehicleSeat", -W / 2 + 2, seatY, z0 + 1.8, "DriverSeat")
		for z = z0 + 5.5, z1 - 2.5, 3.4 do
			seat("Seat", -W / 2 + 2, seatY, z, "PassengerSeat")
			seat("Seat", W / 2 - 2, seatY, z, "PassengerSeat")
		end
		hullTop = top + bodyH + 0.6
	elseif def.Style == "Kei" then
		-- Flat-fronted cab
		local cz0, cz1 = -L / 2, -L / 2 + 5
		local cabH = 6.3
		local czc = (cz0 + cz1) / 2
		body(0, top + 1.2, czc, W, 2.4, 5, color, "CabLower")
		glass(0, top + 4.2, cz0 + 0.1, W - 0.8, 3.2, 0.3) -- big flat windshield
		for _, side in { -1, 1 } do
			glass(side * (W / 2 - 0.1), top + 4.2, czc + 0.4, 0.3, 3, 3.6)
			body(side * (W / 2 - 0.2), top + 4.2, cz0 + 0.3, 0.5, 3.6, 0.5, color, "APillar")
			body(side * (W / 2 - 0.2), top + 4.2, cz1 - 0.3, 0.5, 3.6, 0.5, color, "BPillar")
		end
		body(0, top + cabH - 0.2, czc, W + 0.1, 0.6, 5.2, color, "CabRoof")
		body(0, top + 3.2, cz1 - 0.2, W, 6, 0.4, color, "CabBack")
		body(0, top + 0.5, cz0 - 0.3, W, 1, 0.6, Color3.fromRGB(120, 120, 125), "Bumper")
		body(0, top + 2.4, cz0 - 0.05, W * 0.5, 0.6, 0.2, Color3.fromRGB(150, 150, 155), "Grille")
		light(-W / 2 + 0.8, top + 2.4, cz0 - 0.05, 1, 0.8, 0.2, HEADLIGHT)
		light(W / 2 - 0.8, top + 2.4, cz0 - 0.05, 1, 0.8, 0.2, HEADLIGHT)
		-- Flat bed with fold-down sides
		local bz0, bz1 = cz1, L / 2
		local bzc, bl = (bz0 + bz1) / 2, bz1 - bz0
		body(0, top + 0.3, bzc, W, 0.6, bl, color, "BedFloor")
		for _, side in { -1, 1 } do
			body(side * (W / 2 - 0.15), top + 1.3, bzc, 0.3, 1.4, bl, color, "BedSide")
		end
		body(0, top + 1.3, bz1 - 0.15, W, 1.4, 0.3, color, "Tailgate")
		body(0, top + 3.5, bz0 + 0.4, W, 0.3, 0.3, BLACK, "HeadacheRack")
		light(-W / 2 + 0.5, top + 0.9, bz1 + 0.05, 0.6, 0.6, 0.2, TAILLIGHT)
		light(W / 2 - 0.5, top + 0.9, bz1 + 0.05, 0.6, 0.6, 0.2, TAILLIGHT)
		-- Right-hand drive, like a real kei truck
		seat("VehicleSeat", W / 2 - 1.6, seatY, czc + 0.6, "DriverSeat")
		seat("Seat", -W / 2 + 1.6, seatY, czc + 0.6, "PassengerSeat")
		seat("Seat", -1.4, seatY, bzc - 1.2, "PassengerSeat")
		seat("Seat", 1.4, seatY, bzc + 1.8, "PassengerSeat")
		hullTop = top + 1.6
	else
		-- Normal pickup truck
		local hz0, hz1 = -L / 2, -L / 2 + 5 -- hood
		local cz0, cz1 = hz1, hz1 + 6 -- cab
		local bz0, bz1 = cz1, L / 2 -- bed
		body(0, top + 1.3, (hz0 + hz1) / 2, W, 2.6, 5, color, "Hood")
		body(0, top + 0.6, hz0 - 0.3, W + 0.2, 1.2, 0.6, Color3.fromRGB(160, 160, 165), "Bumper")
		body(0, top + 1.6, hz0 - 0.05, W * 0.6, 1.4, 0.2, BLACK, "Grille")
		light(-W / 2 + 1, top + 1.8, hz0 - 0.05, 1.3, 0.9, 0.2, HEADLIGHT)
		light(W / 2 - 1, top + 1.8, hz0 - 0.05, 1.3, 0.9, 0.2, HEADLIGHT)
		local czc = (cz0 + cz1) / 2
		body(0, top + 1.3, czc, W, 2.6, 6, color, "CabLower")
		glass(0, top + 4.3, cz0 + 0.5, W - 0.8, 3.2, 0.3) -- windshield
		for _, side in { -1, 1 } do
			glass(side * (W / 2 - 0.1), top + 4.3, czc, 0.3, 3, 4.6)
			body(side * (W / 2 - 0.2), top + 4.3, cz0 + 0.4, 0.5, 3.4, 0.5, color, "APillar")
			body(side * (W / 2 - 0.2), top + 4.3, cz1 - 0.3, 0.5, 3.4, 0.5, color, "BPillar")
		end
		body(0, top + 6.1, czc, W, 0.6, 6, color, "CabRoof")
		body(0, top + 3.4, cz1 - 0.2, W, 6.2, 0.4, color, "CabBack")
		glass(0, top + 4.5, cz1 + 0.02, W - 2, 1.6, 0.2)
		-- open bed
		local bzc, bl = (bz0 + bz1) / 2, bz1 - bz0
		body(0, top + 0.3, bzc, W, 0.6, bl, BLACK, "BedFloor")
		for _, side in { -1, 1 } do
			body(side * (W / 2 - 0.2), top + 1.4, bzc, 0.4, 2.2, bl, color, "BedSide")
		end
		body(0, top + 1.4, bz1 - 0.2, W, 2.2, 0.4, color, "Tailgate")
		body(0, top + 0.6, bz1 + 0.3, W + 0.2, 1.2, 0.6, Color3.fromRGB(160, 160, 165), "RearBumper")
		light(-W / 2 + 0.5, top + 1.8, bz1 + 0.05, 0.6, 1.2, 0.2, TAILLIGHT)
		light(W / 2 - 0.5, top + 1.8, bz1 + 0.05, 0.6, 1.2, 0.2, TAILLIGHT)
		seat("VehicleSeat", -W / 2 + 2, seatY, czc + 0.8, "DriverSeat")
		seat("Seat", W / 2 - 2, seatY, czc + 0.8, "PassengerSeat")
		seat("Seat", -1.6, seatY, bzc - 1.5, "PassengerSeat")
		seat("Seat", 1.6, seatY, bzc + 1.5, "PassengerSeat")
		hullTop = top + 2.6
	end

	-- Invisible collision hull above the wheels.
	local hullBottom = 2 * R + 0.3
	if hullTop > hullBottom + 0.5 then
		local hull = Build.box(m, pivotCF * CFrame.new(0, (hullBottom + hullTop) / 2, 0), Vector3.new(W, hullTop - hullBottom, L), BLACK, "Hull", {
			Anchored = false,
			Massless = true,
			Transparency = 1,
			CanTouch = false,
		})
		weld(chassis, hull)
	end

	-- Wheels
	local motors, steers = {}, {}
	for _, zSide in { -1, 1 } do
		for _, xSide in { -1, 1 } do
			local x, z = xSide * (W / 2 - 0.6), zSide * st.wheelZ
			local front = zSide == -1
			local wheel = Build.part({
				Parent = m,
				Shape = Enum.PartType.Cylinder,
				Name = "Wheel",
				Size = Vector3.new(1.2, 2 * R, 2 * R),
				CFrame = pivotCF * CFrame.new(x, R, z),
				Color = TIRE,
				Anchored = false,
				CustomPhysicalProperties = PhysicalProperties.new(1, 2, 0, 100, 1),
			})
			local hub = Build.part({
				Parent = m,
				Shape = Enum.PartType.Cylinder,
				Name = "Hubcap",
				Size = Vector3.new(1.3, R * 1.1, R * 1.1),
				CFrame = wheel.CFrame,
				Color = HUB,
				Anchored = false,
				Massless = true,
				CanCollide = false,
			})
			weld(wheel, hub)

			local chassisLocal = CFrame.new(x, R - chassisY, z)
			local wheelAtt = Instance.new("Attachment")
			wheelAtt.Name = "AxleAttachment"
			wheelAtt.Parent = wheel

			local motor = Instance.new("HingeConstraint")
			motor.Name = "DriveMotor"
			motor.ActuatorType = Enum.ActuatorType.Motor
			motor.AngularVelocity = 0
			motor.MotorMaxTorque = 0
			motor.Attachment1 = wheelAtt

			if front then
				local knuckle = Build.part({
					Parent = m,
					Name = "Knuckle",
					Size = Vector3.new(0.4, 0.4, 0.4),
					CFrame = wheel.CFrame,
					Anchored = false,
					CanCollide = false,
					Transparency = 1,
				})
				local sA0 = Instance.new("Attachment")
				sA0.Name = "SteerAttachment"
				sA0.CFrame = chassisLocal * CFrame.Angles(0, 0, math.pi / 2)
				sA0.Parent = chassis
				local sA1 = Instance.new("Attachment")
				sA1.Name = "SteerAttachment"
				sA1.CFrame = CFrame.Angles(0, 0, math.pi / 2)
				sA1.Parent = knuckle
				local steer = Instance.new("HingeConstraint")
				steer.Name = "Steer"
				steer.ActuatorType = Enum.ActuatorType.Servo
				steer.ServoMaxTorque = 1e7
				steer.AngularSpeed = 12
				steer.TargetAngle = 0
				steer.Attachment0 = sA0
				steer.Attachment1 = sA1
				steer.Parent = knuckle
				steer:SetAttribute("Side", xSide) -- -1 left, 1 right (for Ackermann steering)
				table.insert(steers, steer)

				local kA = Instance.new("Attachment")
				kA.Name = "AxleAttachment"
				kA.Parent = knuckle
				motor.Attachment0 = kA
				motor.Parent = knuckle
			else
				local cA = Instance.new("Attachment")
				cA.Name = "AxleAttachment"
				cA.CFrame = chassisLocal
				cA.Parent = chassis
				motor.Attachment0 = cA
				motor.Parent = wheel
			end
			table.insert(motors, motor)
		end
	end

	-- Motor torque from mass so every vehicle reaches its acceleration.
	local mass = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d.Massless then
			mass += d:GetMass()
		end
	end
	local torque = mass * def.Acceleration * R / 4 * 1.6

	m:SetAttribute("WWVehicle", true)
	m:SetAttribute("VehicleId", def.Id)
	m:SetAttribute("TopSpeed", def.TopSpeed)
	m:SetAttribute("WheelRadius", R)
	m:SetAttribute("MotorTorque", torque)
	m:SetAttribute("MaxSteer", Config.MaxSteerDegrees)
	m:SetAttribute("TurnRate", def.TurnRate or 2)
	m:SetAttribute("TurnAssist", Config.TurnAssist)
	m:SetAttribute("SideGrip", Config.SideGrip)
	m:SetAttribute("InvertDrive", Config.InvertDrive)
	m:SetAttribute("InTornado", false)
	return m, motors, steers
end

return VehicleBuilder
