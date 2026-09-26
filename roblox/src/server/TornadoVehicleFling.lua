-- ServerScriptService.WildWest.TornadoVehicleFling (ModuleScript)
-- Lets the tornado fully pick up vehicles and throw them across the map.
--
--  1. PULL   – inside SuckRadius a VectorForce drags the vehicle toward the
--              funnel (stronger than any car can drive against) and starts
--              lifting it near the core.
--  2. SPIN   – inside CoreRadius the server takes over the physics and carries
--              the vehicle up and around the funnel for 2-4 seconds, tumbling.
--  3. THROW  – it is launched on a ballistic arc that lands on a random spot
--              inside the map at least MinThrowDistance away.
--  4. LAND   – physics goes back to the driver, who stays seated the whole
--              time. The vehicle can't be grabbed again for a few seconds.
--
-- Setup: tag your tornado Model (or its main Part) "Tornado" and give it the
-- attribute TornadoStyle = "Anime". Optional attributes: SuckRadius,
-- CoreRadius, LiftHeight. Works with any Model tagged "Vehicle" too.
--
-- Only the anime tornado is allowed: any tagged tornado whose TornadoStyle
-- is something else is deleted.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local VehicleService = require(script.Parent.VehicleService)

local TC = Config.Tornado
local Fling = {}

local states = {} -- [model] = state
local rng = Random.new()

local function tornadoPosition(t)
	if t:IsA("Model") then
		return t:GetPivot().Position
	elseif t:IsA("BasePart") then
		return t.Position
	end
	return nil
end

local function getTornadoes()
	local list = {}
	for _, t in CollectionService:GetTagged("Tornado") do
		if t:IsDescendantOf(Workspace) then
			local pos = tornadoPosition(t)
			if pos then
				table.insert(list, {
					pos = pos,
					suck = t:GetAttribute("SuckRadius") or TC.SuckRadius,
					core = t:GetAttribute("CoreRadius") or TC.CoreRadius,
					lift = t:GetAttribute("LiftHeight") or TC.LiftHeight,
				})
			end
		end
	end
	return list
end

local function getVehicles()
	local set, list = {}, {}
	for _, m in VehicleService.all() do
		set[m] = true
		table.insert(list, m)
	end
	for _, m in CollectionService:GetTagged("Vehicle") do
		if not set[m] and m:IsA("Model") and m.PrimaryPart and m:IsDescendantOf(Workspace) then
			table.insert(list, m)
		end
	end
	return list
end

-- Each separate physics assembly (chassis, each wheel) in the vehicle.
local function assemblies(model)
	local roots = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			roots[d.AssemblyRootPart or d] = true
		end
	end
	return roots
end

local function totalMass(model)
	local mass = 0
	for root in assemblies(model) do
		mass += root.AssemblyMass
	end
	return math.max(mass, 1)
end

local function setVelocity(model, v, spin)
	for root in assemblies(model) do
		root.AssemblyLinearVelocity = v
		if spin then
			root.AssemblyAngularVelocity = spin
		end
	end
end

local function setOwnerServer(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored and d:CanSetNetworkOwnership() then
			pcall(function()
				d:SetNetworkOwner(nil)
			end)
		end
	end
end

local function giveBack(model)
	if model:GetAttribute("WWVehicle") then
		VehicleService.restoreOwner(model)
		return
	end
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	local player = seat and seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored and d:CanSetNetworkOwnership() then
			pcall(function()
				if player then
					d:SetNetworkOwner(player)
				else
					d:SetNetworkOwnershipAuto()
				end
			end)
		end
	end
end

local function pullForce(model)
	local chassis = model.PrimaryPart
	local vf = chassis:FindFirstChild("TornadoPull")
	if not vf then
		local att = Instance.new("Attachment")
		att.Name = "TornadoPullAttachment"
		att.Parent = chassis
		vf = Instance.new("VectorForce")
		vf.Name = "TornadoPull"
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = true
		vf.Attachment0 = att
		vf.Parent = chassis
	end
	return vf
end

local function clearPull(model)
	local chassis = model.PrimaryPart
	if chassis then
		local vf = chassis:FindFirstChild("TornadoPull")
		if vf then
			vf:Destroy()
		end
		local att = chassis:FindFirstChild("TornadoPullAttachment")
		if att then
			att:Destroy()
		end
	end
end

local function groundBelow(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(pos + Vector3.new(0, 600, 0), Vector3.new(0, -1500, 0), params)
	return hit and hit.Position.Y or Config.Map.GroundY
end

-- Random landing spot inside the map, far away from `from`.
local function pickLanding(from, model)
	local c, size = Config.Map.Center, Config.Map.Size
	local margin = 60
	local best, bestDist = nil, -1
	for _ = 1, 40 do
		local x = rng:NextNumber(c.X - size.X / 2 + margin, c.X + size.X / 2 - margin)
		local z = rng:NextNumber(c.Z - size.Y / 2 + margin, c.Z + size.Y / 2 - margin)
		local dist = (Vector2.new(x, z) - Vector2.new(from.X, from.Z)).Magnitude
		if dist >= TC.MinThrowDistance then
			best = Vector3.new(x, 0, z)
			break
		end
		if dist > bestDist then
			best, bestDist = Vector3.new(x, 0, z), dist
		end
	end
	local players = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(players, p.Character)
		end
	end
	table.insert(players, model)
	return Vector3.new(best.X, groundBelow(best, players) + 4, best.Z)
end

local function capture(model, tornado, now)
	local chassis = model.PrimaryPart
	clearPull(model)
	model:SetAttribute("InTornado", true)
	setOwnerServer(model)
	if model:GetAttribute("WWVehicle") then
		VehicleService.serverBrake(model, 0) -- free-spinning wheels while airborne
	end
	local offset = chassis.Position - tornado.pos
	states[model] = {
		phase = "spin",
		t0 = now,
		duration = rng:NextNumber(TC.SpinSeconds[1], TC.SpinSeconds[2]),
		angle = math.atan2(offset.Z, offset.X),
		radius0 = Vector2.new(offset.X, offset.Z).Magnitude,
		startY = chassis.Position.Y,
		tumble = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-6, 6), rng:NextNumber(-4, 4)),
		tornadoPos = tornado.pos,
		core = tornado.core,
		lift = tornado.lift,
	}
end

local function launch(model, st, now)
	local chassis = model.PrimaryPart
	local from = chassis.Position
	local target = pickLanding(from, model)
	local flat = Vector2.new(target.X - from.X, target.Z - from.Z)
	local dist = flat.Magnitude
	local T = math.clamp(dist / 200, 3, 7)
	local g = Workspace.Gravity
	local v = Vector3.new(flat.X / T, (target.Y - from.Y + 0.5 * g * T * T) / T, flat.Y / T)
	setVelocity(model, v, st.tumble * 0.6)
	st.phase = "flight"
	st.launchedAt = now
	st.flightTime = T
end

local function finish(model, now)
	clearPull(model)
	model:SetAttribute("InTornado", false)
	states[model] = { phase = "cooldown", untilT = now + TC.RegrabCooldown }
	giveBack(model)
end

local function step(dt)
	local now = os.clock()
	local tornadoes = getTornadoes()
	ReplicatedStorage:SetAttribute("TornadoActive", #tornadoes > 0)

	for _, model in getVehicles() do
		local chassis = model.PrimaryPart
		if not chassis or not chassis.Parent then
			states[model] = nil
			continue
		end
		local st = states[model]

		if st == nil or (st.phase == "cooldown" and now >= st.untilT) then
			if st then
				states[model] = nil
			end
			-- Nearest tornado
			local nearest, nd = nil, math.huge
			for _, t in tornadoes do
				local d = (Vector2.new(chassis.Position.X, chassis.Position.Z) - Vector2.new(t.pos.X, t.pos.Z)).Magnitude
				if d < nd then
					nearest, nd = t, d
				end
			end
			if nearest and nd < nearest.suck then
				if nd < nearest.core then
					capture(model, nearest, now)
				else
					local toCentre = Vector3.new(nearest.pos.X - chassis.Position.X, 0, nearest.pos.Z - chassis.Position.Z).Unit
					local swirl = Vector3.new(-toCentre.Z, 0, toCentre.X)
					local k = 1 - nd / nearest.suck
					local accel = TC.MaxPullAccel * k ^ 0.6
					local lift = 0
					if nd < nearest.core * 2.2 then
						lift = Workspace.Gravity * (0.6 + 0.7 * (1 - nd / (nearest.core * 2.2)))
					end
					local vf = pullForce(model)
					vf.Force = (toCentre * accel + swirl * accel * 0.35 + Vector3.new(0, lift, 0)) * totalMass(model)
				end
			else
				clearPull(model)
			end
		elseif st.phase == "spin" then
			-- follow the tornado if it moved
			local nearest, nd = nil, math.huge
			for _, t in tornadoes do
				local d = (t.pos - st.tornadoPos).Magnitude
				if d < nd then
					nearest, nd = t, d
				end
			end
			if nearest then
				st.tornadoPos = nearest.pos
			end
			local t = math.clamp((now - st.t0) / st.duration, 0, 1)
			st.angle += (2.2 + 3.5 * t) * dt
			local radius = st.radius0 + (st.core * 0.7 - st.radius0) * t
			local height = st.startY + st.lift * (1 - (1 - t) ^ 2)
			local target = Vector3.new(
				st.tornadoPos.X + math.cos(st.angle) * radius,
				height,
				st.tornadoPos.Z + math.sin(st.angle) * radius
			)
			local v = (target - chassis.Position) / 0.2
			if v.Magnitude > 320 then
				v = v.Unit * 320
			end
			setVelocity(model, v, st.tumble)
			if t >= 1 or not nearest then
				launch(model, st, now)
			end
		elseif st.phase == "flight" then
			local elapsed = now - st.launchedAt
			local landed = false
			if elapsed > st.flightTime * 0.7 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { model }
				local hit = Workspace:Raycast(chassis.Position, Vector3.new(0, -7, 0), params)
				landed = hit ~= nil and chassis.AssemblyLinearVelocity.Magnitude < 60
			end
			if landed or elapsed > st.flightTime + 4 then
				finish(model, now)
			end
		end
	end

	for model in states do
		if not model.Parent then
			states[model] = nil
		end
	end
end

-- Only the anime tornado is allowed in the game.
local function enforceStyle(inst)
	local style = inst:GetAttribute("TornadoStyle")
	if style == nil then
		warn("[WildWest] Tornado '" .. inst:GetFullName() .. "' has no TornadoStyle attribute. Set TornadoStyle = \"" .. TC.OnlyStyle .. "\" on the anime tornado.")
	elseif style ~= TC.OnlyStyle then
		warn("[WildWest] Removing non-anime tornado " .. inst:GetFullName())
		inst:Destroy()
	end
end

function Fling.start()
	for _, t in CollectionService:GetTagged("Tornado") do
		enforceStyle(t)
	end
	CollectionService:GetInstanceAddedSignal("Tornado"):Connect(function(t)
		task.defer(enforceStyle, t)
	end)
	RunService.Heartbeat:Connect(step)
end

return Fling
