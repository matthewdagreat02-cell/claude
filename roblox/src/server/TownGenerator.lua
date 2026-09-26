-- ServerScriptService.WildWest.TownGenerator (ModuleScript)
-- Lays out the western town "Dustwater":
--  * a bending main street with side streets branching off at angles
--  * buildings facing different directions at different setbacks
--  * a plaza with a well, hamlets, farms with fenced fields, a rail line
--    with a station, the mine and Boot Hill
--  * keeps adding content until Config.Town.TargetFill (60%) of the map is
--    used; the rest is open desert with dead trees, cacti and tumbleweeds
--  * survivor spawn points inside buildings and outside on the streets

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Build = require(script.Parent.Build)
local Buildings = require(script.Parent.Buildings)
local P = Build.Palette

local TownGenerator = {}
TownGenerator.Ready = false
TownGenerator.ReadyEvent = Instance.new("BindableEvent")

local rng
local root -- Folder in Workspace
local footprints = {} -- { c = Vector2, hx, hz, ang }
local roads = {} -- { points = {Vector3}, width }
local grid -- coverage grid
local CELL = 50

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------
local mapMin, mapMax

local function v2(v3)
	return Vector2.new(v3.X, v3.Z)
end

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	local origin = Vector3.new(x, Config.Map.GroundY + 400, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -800, 0), params)
	if hit then
		return hit.Position.Y
	end
	return Config.Map.GroundY
end

local function inMap(p2, margin)
	margin = margin or 0
	return p2.X > mapMin.X + margin and p2.X < mapMax.X - margin and p2.Y > mapMin.Y + margin and p2.Y < mapMax.Y - margin
end

-- Oriented rectangle overlap (separating axis test).
local function corners(fp)
	local c, s = math.cos(fp.ang), math.sin(fp.ang)
	local ax = Vector2.new(c, s) * fp.hx
	local az = Vector2.new(-s, c) * fp.hz
	return { fp.c + ax + az, fp.c + ax - az, fp.c - ax - az, fp.c - ax + az }
end

local function overlaps(a, b)
	local ca, cb = corners(a), corners(b)
	for _, poly in { ca, cb } do
		for i = 1, 4 do
			local e = poly[i % 4 + 1] - poly[i]
			local axis = Vector2.new(-e.Y, e.X)
			local minA, maxA, minB, maxB = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ca do
				local d = p:Dot(axis)
				minA, maxA = math.min(minA, d), math.max(maxA, d)
			end
			for _, p in cb do
				local d = p:Dot(axis)
				minB, maxB = math.min(minB, d), math.max(maxB, d)
			end
			if maxA < minB or maxB < minA then
				return false
			end
		end
	end
	return true
end

local function distToSegment(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function distToRoads(p2)
	local best = math.huge
	for _, r in roads do
		local pts = r.points
		for i = 1, #pts - 1 do
			local d = distToSegment(p2, v2(pts[i]), v2(pts[i + 1])) - r.width / 2
			if d < best then
				best = d
			end
		end
	end
	return best
end

-- Footprint rectangle from a lot CFrame + building size.
local function makeFootprint(cf, w, d, offsetZ, pad)
	local c = cf * CFrame.new(0, 0, offsetZ or 0)
	-- angle of the building's local X axis in the XZ plane
	local right = cf.RightVector
	return {
		c = v2(c.Position),
		hx = w / 2 + (pad or 0),
		hz = d / 2 + (pad or 0),
		ang = math.atan2(right.Z, right.X),
	}
end

local function footprintFree(fp, roadClear)
	for _, other in footprints do
		if (other.c - fp.c).Magnitude < (other.hx + other.hz + fp.hx + fp.hz) and overlaps(fp, other) then
			return false
		end
	end
	local cs = corners(fp)
	for _, p in cs do
		if not inMap(p, 10) then
			return false
		end
	end
	if roadClear then
		table.insert(cs, fp.c)
		for i = 1, 4 do
			table.insert(cs, (cs[i] + cs[i % 4 + 1]) / 2)
		end
		for _, p in cs do
			if distToRoads(p) < roadClear then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Coverage grid (how much of the map is "filled")
---------------------------------------------------------------------------
local gridW, gridH, filledCount = 0, 0, 0

local function cellIndex(ix, iz)
	return iz * gridW + ix
end

local function markCircle(p2, radius)
	local ix0 = math.max(0, math.floor((p2.X - radius - mapMin.X) / CELL))
	local ix1 = math.min(gridW - 1, math.floor((p2.X + radius - mapMin.X) / CELL))
	local iz0 = math.max(0, math.floor((p2.Y - radius - mapMin.Y) / CELL))
	local iz1 = math.min(gridH - 1, math.floor((p2.Y + radius - mapMin.Y) / CELL))
	for ix = ix0, ix1 do
		for iz = iz0, iz1 do
			local cc = Vector2.new(mapMin.X + (ix + 0.5) * CELL, mapMin.Y + (iz + 0.5) * CELL)
			if (cc - p2).Magnitude <= radius + CELL * 0.35 then
				local k = cellIndex(ix, iz)
				if not grid[k] then
					grid[k] = true
					filledCount += 1
				end
			end
		end
	end
end

local function markFootprint(fp, yard)
	markCircle(fp.c, math.max(fp.hx, fp.hz) + (yard or 12))
end

local function fillRatio()
	return filledCount / (gridW * gridH)
end

local function addFootprint(fp, yard)
	table.insert(footprints, fp)
	markFootprint(fp, yard)
end

---------------------------------------------------------------------------
-- Roads
---------------------------------------------------------------------------
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function smoothPath(ctrl, step)
	local out = {}
	for i = 1, #ctrl - 1 do
		local p0 = ctrl[math.max(1, i - 1)]
		local p1, p2 = ctrl[i], ctrl[i + 1]
		local p3 = ctrl[math.min(#ctrl, i + 2)]
		local n = math.max(2, math.floor((p2 - p1).Magnitude / step))
		for s = 0, n - 1 do
			table.insert(out, catmull(p0, p1, p2, p3, s / n))
		end
	end
	table.insert(out, ctrl[#ctrl])
	return out
end

local function drawRoad(points, width, color)
	local folder = Instance.new("Folder")
	folder.Name = "Road"
	folder.Parent = root.Roads
	for i = 1, #points do
		local p = points[i]
		points[i] = Vector3.new(p.X, groundY(p.X, p.Z), p.Z)
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2 + Vector3.new(0, 0.12, 0)
		local len = (b - a).Magnitude
		if len > 0.1 then
			Build.box(folder, CFrame.lookAt(mid, mid + (b - a)), Vector3.new(width, 0.3, len + 0.6), color, "RoadSegment", { CanQuery = false })
		end
		-- round joint so bends have no gaps
		local joint = Build.part({ Parent = folder, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, width, width), Color = color, Name = "RoadJoint", CanQuery = false })
		joint.CFrame = CFrame.new(a + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	table.insert(roads, { points = points, width = width })
	for i = 1, #points, 2 do
		markCircle(v2(points[i]), width / 2 + 8)
	end
end

local function makeMainStreet()
	local c = Config.Map.Center
	local half = math.min(Config.Map.Size.X, Config.Map.Size.Y) * 0.42
	local ctrl = {}
	local z = c.Z + rng:NextNumber(-60, 60)
	local n = 9
	for i = 0, n do
		local x = c.X - half + (2 * half) * i / n
		z += rng:NextNumber(-45, 45)
		z = math.clamp(z, c.Z - 180, c.Z + 180)
		table.insert(ctrl, Vector3.new(x, 0, z))
	end
	local pts = smoothPath(ctrl, 10)
	drawRoad(pts, Config.Town.MainStreetWidth, P.Dirt)
	return pts
end

local function makeSideStreet(mainPts, index, side, lengthStuds)
	local i = math.clamp(index, 2, #mainPts - 1)
	local origin = mainPts[i]
	local tangent = (mainPts[i + 1] - mainPts[i - 1]).Unit
	local normal = Vector3.new(-tangent.Z, 0, tangent.X) * side
	local heading = math.atan2(normal.Z, normal.X) + math.rad(rng:NextNumber(-35, 35))
	local pts = { origin }
	local p = origin
	local step = 12
	for _ = 1, math.floor(lengthStuds / step) do
		heading += math.rad(rng:NextNumber(-7, 7))
		p = p + Vector3.new(math.cos(heading), 0, math.sin(heading)) * step
		if not inMap(v2(p), 40) then
			break
		end
		table.insert(pts, p)
	end
	if #pts >= 4 then
		drawRoad(pts, Config.Town.SideStreetWidth, P.Dirt)
		return pts
	end
	return nil
end

---------------------------------------------------------------------------
-- Placing buildings
---------------------------------------------------------------------------
local placedCount = 0
local function yieldSometimes()
	placedCount += 1
	if placedCount % 6 == 0 then
		RunService.Heartbeat:Wait()
	end
end

-- Place a building at a ground position facing a direction. Returns model or nil.
local function tryPlace(kind, pos2, faceDir2, roadClear, yard)
	local w, d, offsetZ = Buildings.footprint(kind)
	local y = groundY(pos2.X, pos2.Y)
	local pos = Vector3.new(pos2.X, y, pos2.Y)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(faceDir2.X, 0, faceDir2.Y))
	local fp = makeFootprint(cf, w, d, offsetZ, 3)
	if not footprintFree(fp, roadClear) then
		return nil
	end
	addFootprint(fp, yard or 10)
	local m = Buildings.build(kind, cf, root.Buildings, rng)
	yieldSometimes()
	return m, cf
end

local function weightedPick(list)
	local total = 0
	for _, e in list do
		total += e[2]
	end
	local r = rng:NextNumber(0, total)
	for _, e in list do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return list[#list][1]
end

local HOMES = { { "HomeSmall", 4 }, { "HomeMedium", 4 }, { "HomeLarge", 2 }, { "Adobe", 3 }, { "Shack", 2 } }
local MAIN_FILL = { { "Shop", 5 }, { "HomeMedium", 2 }, { "HomeSmall", 1 }, { "Adobe", 1 } }

-- Walk along a road and line both sides with buildings.
local function lineRoad(pts, width, uniques, fillList, density)
	local seg = {}
	local total = 0
	for i = 1, #pts - 1 do
		local len = (v2(pts[i + 1]) - v2(pts[i])).Magnitude
		table.insert(seg, { a = v2(pts[i]), b = v2(pts[i + 1]), len = len, s0 = total })
		total += len
	end
	local function sample(s)
		for _, sg in seg do
			if s <= sg.s0 + sg.len then
				local t = (s - sg.s0) / math.max(sg.len, 1e-3)
				return sg.a:Lerp(sg.b, t), (sg.b - sg.a).Unit
			end
		end
		local last = seg[#seg]
		return last.b, (last.b - last.a).Unit
	end

	for _, side in { 1, -1 } do
		local s = rng:NextNumber(10, 30)
		while s < total - 10 do
			local kind
			local isUnique = false
			if #uniques > 0 and rng:NextNumber() < 0.55 then
				kind = table.remove(uniques, rng:NextInteger(1, #uniques))
				isUnique = true
			else
				kind = weightedPick(fillList)
			end
			local w, d, offsetZ = Buildings.footprint(kind)
			local p, tangent = sample(s + w / 2)
			local normal = Vector2.new(-tangent.Y, tangent.X) * side
			local setback = rng:NextNumber(3, 14)
			-- face the road, with a random twist; sometimes turned side-on
			local face = -normal
			local twist = math.rad(rng:NextNumber(-20, 20))
			local sideOn = rng:NextNumber() < 0.12
			if sideOn then
				twist += (rng:NextNumber() < 0.5 and 1 or -1) * math.pi / 2
			end
			-- distance from the road centre to the building centre, allowing
			-- for the porch (offsetZ) and the corners swinging out when twisted
			local depth = sideOn and w / 2 or (d / 2 - offsetZ)
			local swing = (sideOn and d / 2 or w / 2) * math.abs(math.sin(twist % (math.pi / 2)))
			local center = p + normal * (width / 2 + setback + depth + swing)
			local c, sn = math.cos(twist), math.sin(twist)
			face = Vector2.new(face.X * c - face.Y * sn, face.X * sn + face.Y * c)
			local placed = rng:NextNumber() < density and tryPlace(kind, center, face, 2)
			if not placed and isUnique then
				table.insert(uniques, kind) -- try the unique building again later
			end
			s += w + rng:NextNumber(4, 18)
		end
	end
end

---------------------------------------------------------------------------
-- Clusters outside town
---------------------------------------------------------------------------
local function randomOpenPoint(margin)
	for _ = 1, 40 do
		local p = Vector2.new(rng:NextNumber(mapMin.X + margin, mapMax.X - margin), rng:NextNumber(mapMin.Y + margin, mapMax.Y - margin))
		local ix = math.floor((p.X - mapMin.X) / CELL)
		local iz = math.floor((p.Y - mapMin.Y) / CELL)
		if not grid[cellIndex(ix, iz)] and distToRoads(p) > 30 then
			return p
		end
	end
	return nil
end

local function randomDir()
	local a = rng:NextNumber(0, math.pi * 2)
	return Vector2.new(math.cos(a), math.sin(a))
end

local function makeFarm(center)
	local face = randomDir()
	local fm = tryPlace("Farmhouse", center, face, 4, 20)
	if not fm then
		return false
	end
	local right = Vector2.new(-face.Y, face.X)
	tryPlace("Barn", center + right * 45 + face * -10, randomDir(), 4, 20)
	-- fields
	for i = 1, rng:NextInteger(1, 3) do
		local fc = center - face * (50 + i * 10) + right * rng:NextNumber(-60, 60)
		local fw, fd = rng:NextNumber(40, 70), rng:NextNumber(50, 80)
		local y = groundY(fc.X, fc.Y)
		local cf = CFrame.lookAt(Vector3.new(fc.X, y, fc.Y), Vector3.new(fc.X, y, fc.Y) + Vector3.new(face.X, 0, face.Y))
		local fp = makeFootprint(cf, fw, fd, 0, 2)
		if footprintFree(fp, 4) then
			addFootprint(fp, 10)
			Buildings.field(root.Buildings, cf, fw, fd, rng)
		end
	end
	if rng:NextNumber() < 0.6 then
		local wp = center + right * -35 + face * 8
		local y = groundY(wp.X, wp.Y)
		local fp = { c = wp, hx = 5, hz = 5, ang = 0 }
		if footprintFree(fp, 4) then
			addFootprint(fp, 8)
			Buildings.windmill(root.Buildings, CFrame.new(wp.X, y, wp.Y) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end
	-- a couple of outdoor survivor spots in the farmyard
	local yardP = center + face * 20
	Build.survivorSpawn(root.Spawns, Vector3.new(yardP.X, groundY(yardP.X, yardP.Y) + 3, yardP.Y), false)
	return true
end

local function makeHamlet(center)
	local count = rng:NextInteger(3, 6)
	local any = false
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(26, 42)
		local p = center + Vector2.new(math.cos(a), math.sin(a)) * r
		-- mostly facing the middle, but not perfectly
		local face = (center - p).Unit
		if rng:NextNumber() < 0.35 then
			face = randomDir()
		end
		if tryPlace(weightedPick(HOMES), p, face, 4, 14) then
			any = true
		end
	end
	if any then
		local y = groundY(center.X, center.Y)
		Build.survivorSpawn(root.Spawns, Vector3.new(center.X, y + 3, center.Y), false)
		Build.box(root.Buildings, CFrame.new(center.X, y + 0.1, center.Y), Vector3.new(30, 0.2, 30), P.Dirt, "HamletYard", { CanQuery = false })
	end
	return any
end

local function makeHomestead(center)
	local face = randomDir()
	local ok = tryPlace(weightedPick(HOMES), center, face, 4, 16)
	if ok then
		local right = Vector2.new(-face.Y, face.X)
		tryPlace("Shack", center + right * 24, randomDir(), 4, 8)
		local fc = center - face * 24
		local y = groundY(fc.X, fc.Y)
		local corral = CFrame.lookAt(Vector3.new(fc.X, y, fc.Y), Vector3.new(fc.X, y, fc.Y) + Vector3.new(face.X, 0, face.Y))
		local cw = 26
		local c1 = (corral * CFrame.new(-cw / 2, 0, -cw / 2)).Position
		local c2 = (corral * CFrame.new(cw / 2, 0, -cw / 2)).Position
		local c3 = (corral * CFrame.new(cw / 2, 0, cw / 2)).Position
		local c4 = (corral * CFrame.new(-cw / 2, 0, cw / 2)).Position
		local fp = makeFootprint(corral, cw, cw, 0, 1)
		if footprintFree(fp, 4) then
			addFootprint(fp, 6)
			Buildings.fence(root.Buildings, c1, c2, (c1 + c2) / 2, 8)
			Buildings.fence(root.Buildings, c2, c3)
			Buildings.fence(root.Buildings, c3, c4)
			Buildings.fence(root.Buildings, c4, c1)
		end
	end
	return ok ~= nil and ok ~= false
end

---------------------------------------------------------------------------
-- Desert scatter
---------------------------------------------------------------------------
local function deadTree(parent, pos)
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	local h = rng:NextNumber(10, 18)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-8, 8)))
	local base = CFrame.new(pos) * lean
	Build.box(m, base * CFrame.new(0, h / 2, 0), Vector3.new(1.4, h, 1.4), P.DeadTree, "Trunk")
	for _ = 1, rng:NextInteger(3, 5) do
		local y = h * rng:NextNumber(0.45, 0.95)
		local len = rng:NextNumber(3, 7)
		local b = base * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(30, 60)))
		Build.box(m, b * CFrame.new(0, len / 2, 0), Vector3.new(0.6, len, 0.6), P.DeadTree, "Branch")
	end
	m.Parent = parent
end

local function cactus(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Cactus"
	local h = rng:NextNumber(7, 13)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	Build.box(m, base * CFrame.new(0, h / 2, 0), Vector3.new(1.8, h, 1.8), P.Green, "Cactus")
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.75 then
			local ay = h * rng:NextNumber(0.35, 0.6)
			local up = rng:NextNumber(2.5, 4.5)
			Build.box(m, base * CFrame.new(side * 1.8, ay, 0), Vector3.new(2, 1.2, 1.2), P.Green, "CactusArm")
			Build.box(m, base * CFrame.new(side * 2.4, ay + up / 2, 0), Vector3.new(1.2, up, 1.2), P.Green, "CactusArm")
		end
	end
	m.Parent = parent
end

local function rock(parent, pos)
	local s = rng:NextNumber(2, 6)
	Build.box(parent, CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		Vector3.new(s * 1.3, s * 0.8, s), P.Stone, "Rock")
end

TownGenerator.Tumbleweeds = {}
local function tumbleweed(parent, pos)
	local size = rng:NextNumber(2.6, 4.2)
	local ball = Build.part({
		Parent = parent,
		Shape = Enum.PartType.Ball,
		Name = "Tumbleweed",
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos + Vector3.new(0, size / 2 + 0.5, 0)),
		Color = P.Hay,
		Anchored = false,
		Transparency = 0.15,
		CustomPhysicalProperties = PhysicalProperties.new(0.08, 0.3, 0.6),
	})
	for i = 1, 3 do
		local ring = Build.part({
			Parent = parent,
			Shape = Enum.PartType.Cylinder,
			Name = "TumbleweedTwig",
			Size = Vector3.new(0.25, size * 1.12, size * 1.12),
			Color = P.DeadTree,
			Anchored = false,
			Massless = true,
			CanCollide = false,
		})
		ring.CFrame = ball.CFrame * CFrame.Angles(i * 1.1, i * 0.7, i * 0.4)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ball
		weld.Part1 = ring
		weld.Parent = ring
	end
	table.insert(TownGenerator.Tumbleweeds, ball)
end

local function scatterDesert()
	local folder = root.Desert
	for ix = 0, gridW - 1 do
		for iz = 0, gridH - 1 do
			if not grid[cellIndex(ix, iz)] then
				local n = rng:NextInteger(1, 3)
				for _ = 1, n do
					local x = mapMin.X + (ix + rng:NextNumber(0.1, 0.9)) * CELL
					local z = mapMin.Y + (iz + rng:NextNumber(0.1, 0.9)) * CELL
					local pos = Vector3.new(x, groundY(x, z), z)
					local r = rng:NextNumber()
					if r < 0.32 then
						deadTree(folder, pos)
					elseif r < 0.58 then
						cactus(folder, pos)
					elseif r < 0.78 then
						tumbleweed(folder, pos)
					else
						rock(folder, pos)
					end
				end
			end
		end
		if ix % 4 == 0 then
			RunService.Heartbeat:Wait()
		end
	end
end

-- Tumbleweeds roll with the wind and wrap around the map.
local function startWind()
	local windDir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	if windDir.Magnitude < 0.1 then
		windDir = Vector3.new(1, 0, 0)
	end
	windDir = windDir.Unit
	task.spawn(function()
		while true do
			task.wait(0.4)
			windDir = (windDir + Vector3.new(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))).Unit
			for i = #TownGenerator.Tumbleweeds, 1, -1 do
				local tw = TownGenerator.Tumbleweeds[i]
				if not tw.Parent then
					table.remove(TownGenerator.Tumbleweeds, i)
				else
					local v = tw.AssemblyLinearVelocity
					local target = windDir * rng:NextNumber(9, 16)
					local hop = (rng:NextNumber() < 0.08) and 14 or 0
					tw.AssemblyLinearVelocity = Vector3.new(target.X, math.max(v.Y, 0) + hop, target.Z)
					tw.AssemblyAngularVelocity = Vector3.new(target.Z, 0, -target.X) * 0.6
					local p = tw.Position
					if not inMap(v2(p), 0) or p.Y < Config.Map.GroundY - 50 then
						-- wrap to the upwind edge
						local q = Vector2.new(p.X, p.Z)
						q = Vector2.new(
							math.clamp(q.X - windDir.X * (mapMax.X - mapMin.X) * 0.95, mapMin.X + 5, mapMax.X - 5),
							math.clamp(q.Y - windDir.Z * (mapMax.Y - mapMin.Y) * 0.95, mapMin.Y + 5, mapMax.Y - 5)
						)
						tw.CFrame = CFrame.new(q.X, groundY(q.X, q.Y) + 4, q.Y)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------
-- For debugging / map previews: the placed footprints and road polylines.
function TownGenerator.getLayout()
	return footprints, roads
end

function TownGenerator.generate()
	rng = Random.new(Config.Town.Seed or os.clock() * 1000)
	local c, size = Config.Map.Center, Config.Map.Size
	mapMin = Vector2.new(c.X - size.X / 2, c.Z - size.Y / 2)
	mapMax = Vector2.new(c.X + size.X / 2, c.Z + size.Y / 2)
	gridW, gridH = math.ceil(size.X / CELL), math.ceil(size.Y / CELL)
	grid, filledCount = {}, 0

	local old = Workspace:FindFirstChild("WildWestTown")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "WildWestTown"
	for _, name in { "Roads", "Buildings", "Spawns", "Desert" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
	end
	root.Parent = Workspace

	-- 1. Main street + plaza
	local main = makeMainStreet()
	local mid = main[math.floor(#main / 2)]
	local plazaR = 32
	local plazaY = groundY(mid.X, mid.Z)
	local plaza = Build.part({ Parent = root.Roads, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, plazaR * 2, plazaR * 2), Color = P.Sand, Name = "Plaza", CanQuery = false })
	plaza.CFrame = CFrame.new(mid.X, plazaY + 0.14, mid.Z) * CFrame.Angles(0, 0, math.pi / 2)
	Buildings.well(root.Buildings, CFrame.new(mid.X, plazaY, mid.Z))
	addFootprint({ c = v2(mid), hx = plazaR, hz = plazaR, ang = 0 }, 10)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		Build.survivorSpawn(root.Spawns, mid + Vector3.new(math.cos(a) * 20, plazaY - mid.Y + 3, math.sin(a) * 20), false)
	end

	-- 1b. Keep the player plots clear and link them to town with a ranch road
	local connector
	do
		local pc = Config.Plots
		for i = 1, pc.Count do
			local pcf = Config.plotCFrame(i)
			addFootprint({ c = Vector2.new(pcf.X, pcf.Z), hx = pc.Size / 2 + 6, hz = pc.Size / 2 + 6, ang = 0 }, 10)
		end
		for _, bcf in Config.leaderboardCFrames() do
			addFootprint({ c = Vector2.new(bcf.X, bcf.Z), hx = Config.Leaderboards.Width / 2 + 8, hz = 14, ang = 0 }, 8)
		end
		local rz = pc.Origin.Z - pc.Size / 2 - 14
		local x0 = Config.plotCFrame(1).X - pc.Size / 2 - 20
		local x1 = Config.plotCFrame(pc.Count).X + pc.Size / 2 + 20
		drawRoad(smoothPath({ Vector3.new(x0, 0, rz), Vector3.new(x1, 0, rz) }, 12), 22, P.Dirt)
		-- connect to the nearest point on the main street
		local target = Vector3.new(pc.Origin.X, 0, rz)
		local bestI, bestD = 1, math.huge
		for i, p in main do
			local d = (Vector2.new(p.X, p.Z) - Vector2.new(target.X, target.Z)).Magnitude
			if d < bestD then
				bestI, bestD = i, d
			end
		end
		local s0 = main[bestI]
		local ctrl = { Vector3.new(s0.X, 0, s0.Z) }
		for _, t in { 0.33, 0.66 } do
			local p = s0:Lerp(target, t)
			table.insert(ctrl, Vector3.new(p.X + rng:NextNumber(-40, 40), 0, p.Z))
		end
		table.insert(ctrl, target)
		connector = smoothPath(ctrl, 10)
		drawRoad(connector, Config.Town.SideStreetWidth + 2, P.Dirt)
	end

	-- 2. Side streets branching at angles
	local sideStreets = {}
	for i = 1, Config.Town.SideStreets do
		local idx = math.floor(#main * (i / (Config.Town.SideStreets + 1))) + rng:NextInteger(-3, 3)
		local side = (i % 2 == 0) and 1 or -1
		local st = makeSideStreet(main, idx, side, rng:NextNumber(160, 300))
		if st then
			table.insert(sideStreets, st)
		end
	end

	-- 3. Line the streets with buildings
	local uniques = { "Bank", "Saloon", "Saloon", "GeneralStore", "Sheriff", "Hotel", "Church", "PostOffice", "Blacksmith", "Barber", "Doctor", "Undertaker", "Livery" }
	lineRoad(main, Config.Town.MainStreetWidth, uniques, MAIN_FILL, 0.95)
	for _, st in sideStreets do
		lineRoad(st, Config.Town.SideStreetWidth, uniques, HOMES, 0.85)
	end
	lineRoad(connector, Config.Town.SideStreetWidth + 2, uniques, HOMES, 0.55)
	-- Outdoor survivor spots along the streets
	for _, r in roads do
		for i = 1, #r.points, 9 do
			local p = r.points[i]
			local j = math.min(i + 1, #r.points)
			local t = (r.points[j] - p)
			if t.Magnitude > 0.01 then
				local n = Vector3.new(-t.Z, 0, t.X).Unit * (r.width / 2 + 1.5) * (rng:NextNumber() < 0.5 and 1 or -1)
				Build.survivorSpawn(root.Spawns, p + n + Vector3.new(0, 3, 0), false)
			end
		end
	end

	-- 4. Rail line + station along one edge of town
	do
		local railZ = c.Z + size.Y * 0.3
		local pts = {}
		for x = mapMin.X + 10, mapMax.X - 10, 16 do
			table.insert(pts, Vector3.new(x, groundY(x, railZ), railZ + math.sin(x / 180) * 20))
		end
		local rails = Instance.new("Folder")
		rails.Name = "Railroad"
		rails.Parent = root.Roads
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local mid2 = (a + b) / 2
			local cf = CFrame.lookAt(mid2, mid2 + (b - a))
			Build.box(rails, cf * CFrame.new(0, 0.3, 0), Vector3.new(9, 0.6, 2), P.DarkWood, "Tie")
			for _, x in { -2.5, 2.5 } do
				Build.box(rails, cf * CFrame.new(x, 0.8, 0), Vector3.new(0.5, 0.5, (b - a).Magnitude + 0.2), P.Iron, "Rail")
			end
		end
		table.insert(roads, { points = pts, width = 10 })
		-- try spots along the line until the station fits
		for _, offset in { -140, 140, -260, 260, -380, 380, -60, 60 } do
			local sx = c.X + offset + rng:NextNumber(-20, 20)
			local sp = Vector2.new(sx, railZ + math.sin(sx / 180) * 20 - 26)
			local tower = Vector2.new(sp.X + 34, sp.Y)
			local towerFp = { c = tower, hx = 7, hz = 7, ang = 0 }
			if footprintFree(towerFp, 2) and tryPlace("Station", sp, Vector2.new(0, 1), 1, 20) then
				Buildings.waterTower(root.Buildings, CFrame.new(tower.X, groundY(tower.X, tower.Y), tower.Y))
				addFootprint(towerFp, 8)
				break
			end
		end
	end

	-- 5. Mine and Boot Hill near the edges
	do
		local mp = Vector2.new(mapMin.X + 90, mapMin.Y + 90)
		local y = groundY(mp.X, mp.Y)
		local fp = { c = mp, hx = 30, hz = 26, ang = 0 }
		if footprintFree(fp, 4) then
			addFootprint(fp, 20)
			Buildings.mine(root.Buildings, CFrame.lookAt(Vector3.new(mp.X, y, mp.Y), Vector3.new(c.X, y, c.Z)))
		end
		local bp = Vector2.new(mapMax.X - 110, mapMin.Y + 120)
		local by = groundY(bp.X, bp.Y)
		fp = { c = bp, hx = 24, hz = 20, ang = 0 }
		if footprintFree(fp, 4) then
			addFootprint(fp, 16)
			Buildings.bootHill(root.Buildings, CFrame.new(bp.X, by, bp.Y) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), rng)
		end
	end

	-- 6. Farms, hamlets and homesteads until the map is ~60% filled
	local attempts = 0
	while fillRatio() < Config.Town.TargetFill and attempts < 400 do
		attempts += 1
		local p = randomOpenPoint(80)
		if not p then
			break
		end
		local r = rng:NextNumber()
		if r < 0.4 then
			makeFarm(p)
		elseif r < 0.75 then
			makeHamlet(p)
		else
			makeHomestead(p)
		end
		RunService.Heartbeat:Wait()
	end

	-- 7. Everything else is desert
	scatterDesert()
	startWind()

	TownGenerator.Ready = true
	TownGenerator.ReadyEvent:Fire()
	print(string.format("[WildWest] Town built: %d buildings, %.0f%% of the map filled", #footprints, fillRatio() * 100))
end

return TownGenerator
