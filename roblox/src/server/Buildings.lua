-- ServerScriptService.WildWest.Buildings (ModuleScript)
-- Builds every western building type with a walk-in interior sized for a
-- Roblox character (doors 5 x 8, ceilings 12, stairs 1 stud per step).
--
-- If ServerStorage.TownModels.<Kind> exists (e.g. an imported Blender model
-- called "Bank"), that model is used instead of the placeholder. Put Parts
-- named "SurvivorSpawn" inside a Blender model to control where survivors
-- appear; otherwise one is added in the middle of the building.
--
-- Local frame: origin = ground centre of the footprint, FRONT faces -Z
-- (the CFrame's LookVector).

local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("WildWestShared")
local Config = require(Shared:WaitForChild("Config"))
local Build = require(script.Parent.Build)
local P = Build.Palette

local Buildings = {}

local DOOR_W, DOOR_H = 5, 8
local T = 1 -- wall thickness

Buildings.Specs = {
	Bank = { w = 28, d = 24, floors = 1, floorH = 14, roof = "flat", facade = true, sign = "BANK", wall = P.Stone, porch = true, interior = "bank" },
	Saloon = { w = 30, d = 28, floors = 2, roof = "flat", facade = true, sign = "SALOON", wall = P.BarnRed, porch = true, balcony = true, interior = "saloon" },
	GeneralStore = { w = 26, d = 22, floors = 1, roof = "flat", facade = true, sign = "GENERAL STORE", wall = P.Mustard, porch = true, interior = "store" },
	Sheriff = { w = 22, d = 20, floors = 1, roof = "flat", facade = true, sign = "SHERIFF", wall = P.Cream, porch = true, interior = "jail" },
	Hotel = { w = 32, d = 26, floors = 2, roof = "flat", facade = true, sign = "HOTEL", wall = P.Teal, porch = true, balcony = true, interior = "hotel" },
	Church = { w = 22, d = 34, floors = 1, floorH = 16, roof = "gable", steeple = true, wall = P.White, interior = "church" },
	PostOffice = { w = 20, d = 18, floors = 1, roof = "flat", facade = true, sign = "POST OFFICE", wall = P.Sky, porch = true, interior = "office" },
	Blacksmith = { w = 22, d = 20, floors = 1, roof = "gable", wall = P.DarkWood, sign = "BLACKSMITH", wideDoor = true, interior = "forge" },
	Barber = { w = 16, d = 18, floors = 1, roof = "flat", facade = true, sign = "BARBER", wall = P.Rose, porch = true, interior = "barber" },
	Doctor = { w = 18, d = 18, floors = 1, roof = "flat", facade = true, sign = "DOCTOR", wall = P.White, porch = true, interior = "doctor" },
	Undertaker = { w = 16, d = 20, floors = 1, roof = "flat", facade = true, sign = "UNDERTAKER", wall = P.Slate, porch = true, interior = "undertaker" },
	Livery = { w = 30, d = 28, floors = 1, floorH = 16, roof = "gable", wall = P.BarnRed, sign = "LIVERY", wideDoor = true, interior = "stable" },
	Shop = { w = 20, d = 20, floors = 1, roof = "flat", facade = true, sign = "SHOP", wall = P.Sage, porch = true, interior = "store" },
	HomeSmall = { w = 18, d = 16, floors = 1, roof = "gable", wall = P.Cream, porch = true, interior = "home" },
	HomeMedium = { w = 22, d = 20, floors = 1, roof = "gable", wall = P.Sky, porch = true, interior = "home" },
	HomeLarge = { w = 26, d = 24, floors = 2, roof = "gable", wall = P.Sage, porch = true, interior = "home" },
	Adobe = { w = 20, d = 18, floors = 1, roof = "flat", wall = P.Adobe, interior = "home", adobe = true },
	Shack = { w = 14, d = 14, floors = 1, floorH = 11, roof = "shed", wall = P.LightWood, interior = "shack" },
	Farmhouse = { w = 26, d = 24, floors = 2, roof = "gable", wall = P.White, porch = true, interior = "home" },
	Barn = { w = 30, d = 40, floors = 1, floorH = 18, roof = "gable", wall = P.BarnRed, wideDoor = true, interior = "barn" },
	Station = { w = 30, d = 18, floors = 1, floorH = 13, roof = "gable", wall = P.Mustard, sign = "DUSTWATER STATION", porch = true, interior = "office" },
}

Buildings.ShopNames = { "GUNSMITH", "BAKERY", "TAILOR", "ASSAY OFFICE", "GAZETTE", "CANDY", "BOOTS & SADDLES", "LAND OFFICE" }

-- Footprint used by the town generator for spacing (includes the porch).
function Buildings.footprint(kind)
	local s = Buildings.Specs[kind]
	if not s then
		return 20, 20, 0
	end
	local porch = s.porch and 7 or 0
	return s.w, s.d + porch, -porch / 2
end

---------------------------------------------------------------------------
-- Furniture
---------------------------------------------------------------------------
local function furnitureKit(m, base)
	local k = {}
	function k.box(x, y, z, sx, sy, sz, color, name, extra)
		return Build.box(m, base * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, name or "Furniture", extra)
	end
	function k.table(x, z)
		k.box(x, 3, z, 4, 0.4, 4, P.Wood, "Table")
		k.box(x, 1.4, z, 0.6, 2.8, 0.6, P.DarkWood, "TableLeg")
	end
	function k.chair(x, z)
		k.box(x, 1.2, z, 1.8, 0.4, 1.8, P.Wood, "Chair")
		k.box(x, 0.5, z, 0.4, 1, 0.4, P.DarkWood, "ChairLeg")
		k.box(x, 2.4, z + 0.8, 1.8, 2.2, 0.3, P.Wood, "ChairBack")
	end
	function k.bed(x, z, color)
		k.box(x, 0.8, z, 4, 1.6, 7, P.DarkWood, "BedFrame")
		k.box(x, 1.8, z, 3.8, 0.5, 6.8, color or P.Rose, "Blanket")
		k.box(x, 2.2, z + 2.7, 3, 0.5, 1.2, P.White, "Pillow")
	end
	function k.counter(x, z, len, rot)
		local cf = base * CFrame.new(x, 1.75, z) * CFrame.Angles(0, rot or 0, 0)
		Build.box(m, cf, Vector3.new(len, 3.5, 2), P.DarkWood, "Counter")
		Build.box(m, cf * CFrame.new(0, 1.85, 0), Vector3.new(len + 0.4, 0.2, 2.4), P.Wood, "CounterTop")
	end
	function k.shelf(x, z, len, rot)
		local cf = base * CFrame.new(x, 4, z) * CFrame.Angles(0, rot or 0, 0)
		Build.box(m, cf, Vector3.new(len, 8, 1.5), P.Wood, "Shelf")
		local goods = { P.Rose, P.Sky, P.Mustard, P.Sage, P.Cream }
		for i = 1, math.max(1, math.floor(len / 2.5)) do
			local gx = -len / 2 + i * 2.5 - 1.2
			Build.box(m, cf * CFrame.new(gx, 1, -0.9), Vector3.new(1.4, 1.4, 0.8), goods[(i % #goods) + 1], "Goods")
			Build.box(m, cf * CFrame.new(gx, -2, -0.9), Vector3.new(1.2, 1.6, 0.8), goods[((i + 2) % #goods) + 1], "Goods")
		end
	end
	function k.stove(x, z)
		k.box(x, 1.5, z, 3, 3, 2.5, P.Iron, "Stove")
		k.box(x, 7, z + 0.6, 0.6, 8, 0.6, P.Iron, "StovePipe")
	end
	return k
end

local function furnish(m, base, s, rng, kind)
	local k = furnitureKit(m, base)
	local w, d = s.w, s.d
	local hw, hd = w / 2 - T, d / 2 - T
	local interior = s.interior
	-- Keep the right side clear in two-storey buildings (stairs are there).
	local leftX = -hw / 2

	if interior == "bank" then
		k.counter(0, -hd + 8, w - 8)
		for x = -w / 2 + 6, w / 2 - 6, 5 do
			k.box(x, 5.5, -hd + 8, 0.2, 4, 0.2, P.Iron, "TellerBar")
		end
		-- Vault in the back
		k.box(0, 5, hd - 3.5, 10, 10, 6, P.Iron, "Vault")
		local door = Build.part({ Parent = m, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 7, 7), Color = P.Stone, Name = "VaultDoor" })
		door.CFrame = base * CFrame.new(0, 5, hd - 6.8) * CFrame.Angles(0, math.pi / 2, 0)
		k.box(-4, 1, hd - 9, 2, 2, 2, P.Mustard, "GoldBars")
	elseif interior == "saloon" then
		k.counter(leftX, hd - 3, hw - 2)
		k.shelf(leftX, hd - 0.9, hw - 2, math.pi)
		for i = 0, 1 do
			local z = -hd + 7 + i * 7
			k.table(leftX, z)
			k.chair(leftX - 3, z)
			k.chair(leftX + 3, z)
		end
		-- Piano + small stage
		k.box(-hw + 3, 0.5, 0, 5, 1, 10, P.Wood, "Stage")
		k.box(-hw + 2, 3, -2, 2, 4, 5, P.DarkWood, "Piano")
		k.box(-hw + 3.1, 3.6, -2, 0.3, 0.3, 4.6, P.White, "PianoKeys")
	elseif interior == "store" then
		k.counter(0, -hd + 7, w - 10)
		k.shelf(0, hd - 0.9, w - 4, math.pi)
		k.shelf(-hw + 0.9, 0, d - 8, math.pi / 2)
		k.box(hw - 3, 1.5, -2, 2.5, 3, 2.5, P.DarkWood, "Barrel")
		k.box(hw - 3, 1.2, 2, 3, 2.4, 3, P.LightWood, "Crate")
	elseif interior == "jail" then
		k.table(-hw / 2, -hd + 6)
		k.chair(-hw / 2, -hd + 9)
		-- Two cells across the back
		local cellZ = hd - 5
		for x = -hw + 1, hw - 1, 1.2 do
			k.box(x, 6, cellZ - 4.5, 0.25, 12, 0.25, P.Iron, "CellBar")
		end
		k.box(0, 6, cellZ, 0.6, 12, 9, P.Iron, "CellDivider")
		k.bed(-hw / 2, cellZ, P.Slate)
	elseif interior == "hotel" then
		k.counter(leftX, -hd + 8, 10)
		k.box(leftX, 6, -hd + 1.2, 6, 3, 0.5, P.Mustard, "KeyBoard")
		k.table(leftX, 2)
		k.chair(leftX, 5)
	elseif interior == "church" then
		for z = -hd + 6, hd - 10, 4 do
			for _, side in { -1, 1 } do
				k.box(side * 5.5, 1.2, z, 7, 0.4, 1.6, P.Wood, "Pew")
				k.box(side * 5.5, 2.4, z + 0.7, 7, 2.2, 0.3, P.Wood, "PewBack")
			end
		end
		k.box(0, 2, hd - 5, 4, 4, 2, P.DarkWood, "Pulpit")
		k.box(0, 9, hd - 1.2, 1, 6, 0.4, P.Mustard, "Cross")
		k.box(0, 10, hd - 1.2, 3.5, 1, 0.4, P.Mustard, "CrossBar")
	elseif interior == "office" then
		k.counter(0, 0, w - 8)
		k.shelf(0, hd - 0.9, w - 6, math.pi)
		k.box(-hw + 2, 2, -hd + 3, 2, 4, 2, P.DarkWood, "Mailbox")
	elseif interior == "forge" then
		k.box(-hw / 2, 2, hd - 4, 6, 4, 5, P.Stone, "Forge")
		k.box(-hw / 2, 3, hd - 4, 3, 0.4, 2, Color3.fromRGB(255, 120, 40), "Coals", { Material = Enum.Material.Neon })
		k.box(2, 1.5, 0, 1.4, 3, 1.4, P.DarkWood, "AnvilStump")
		k.box(2, 3.5, 0, 3, 1, 1.2, P.Iron, "Anvil")
		k.box(hw - 2, 1.5, -2, 2.5, 3, 2.5, P.DarkWood, "WaterBarrel")
	elseif interior == "barber" then
		k.box(0, 1.5, 0, 2.5, 3, 2.5, P.BarnRed, "BarberChair")
		k.box(0, 4, 1.2, 2.5, 3, 0.4, P.BarnRed, "BarberChairBack")
		k.box(0, 5, hd - 0.7, 4, 3, 0.2, P.Glass, "Mirror", { Material = Enum.Material.Glass, Reflectance = 0.3 })
		k.chair(-hw + 2, -hd + 4)
	elseif interior == "doctor" then
		k.bed(-hw / 2, hd - 5, P.White)
		k.table(hw / 2, 0)
		k.shelf(hw / 2, hd - 0.9, hw - 2, math.pi)
	elseif interior == "undertaker" then
		for i = 0, 2 do
			k.box(-hw + 3, 1 + i * 1.6, hd - 5, 3, 1.4, 7, P.DarkWood, "Coffin")
		end
		k.counter(2, -hd + 6, 8)
	elseif interior == "stable" or interior == "barn" then
		for z = -hd + 8, hd - 6, 8 do
			k.box(-hw + 5, 2.5, z, 9, 5, 0.6, P.DarkWood, "StallWall")
			k.box(hw - 5, 2.5, z, 9, 5, 0.6, P.DarkWood, "StallWall")
		end
		k.box(-hw + 3, 1.5, hd - 3, 4, 3, 3, P.Hay, "HayBale")
		k.box(hw - 3, 1.5, hd - 3, 4, 3, 3, P.Hay, "HayBale")
		k.box(hw - 3, 4.5, hd - 3, 4, 3, 3, P.Hay, "HayBale")
	elseif interior == "home" then
		k.bed(-hw + 3, hd - 4.5, ({ P.Rose, P.Sky, P.Sage, P.Mustard })[rng:NextInteger(1, 4)])
		k.table(0, 0)
		k.chair(-2.5, 0)
		k.chair(2.5, 0)
		k.stove(hw - 2.5, hd - 2.5)
		k.box(-hw + 1, 1.5, -hd + 3, 1.6, 3, 3, P.DarkWood, "Dresser")
	elseif interior == "shack" then
		k.bed(-hw + 2.8, hd - 4.5, P.Stone)
		k.box(hw - 2, 1, 0, 2, 2, 2, P.LightWood, "Crate")
	end
end

---------------------------------------------------------------------------
-- Shell
---------------------------------------------------------------------------
local function windowOpenings(length, floors, floorH, doorX, doorHalfWidth)
	local list = {}
	local count = math.max(1, math.floor(length / 9))
	for f = 0, floors - 1 do
		for i = 1, count do
			local x = -length / 2 + i * (length / (count + 1))
			if not (f == 0 and doorHalfWidth and math.abs(x - doorX) < doorHalfWidth + 2.5) then
				table.insert(list, { x = x, w = 4, y0 = f * floorH + 4, y1 = f * floorH + 8, glass = true })
			end
		end
	end
	return list
end

local function buildShell(m, cf, s, rng, kind)
	local w, d = s.w, s.d
	local floors = s.floors or 1
	local floorH = s.floorH or 12
	local H = floors * floorH
	local wallColor = s.wall or P.Cream
	local base = cf * CFrame.new(0, 1, 0) -- top of the floor slab

	local floor = Build.box(m, cf * CFrame.new(0, 0.5, 0), Vector3.new(w, 1, d), P.LightWood, "Floor")
	m.PrimaryPart = floor

	-- Front wall with the door (and balcony door upstairs)
	local doorW = s.wideDoor and 10 or DOOR_W
	local doorH = s.wideDoor and 12 or DOOR_H
	local doorX = 0
	local frontOpenings = windowOpenings(w - 2 * T, floors, floorH, doorX, doorW / 2)
	table.insert(frontOpenings, { x = doorX, w = doorW, y0 = 0, y1 = doorH })
	if s.balcony and floors > 1 then
		-- replace the upstairs window in the middle with a door to the balcony
		for i = #frontOpenings, 1, -1 do
			local o = frontOpenings[i]
			if o.y0 >= floorH and math.abs(o.x) < 5.5 then
				table.remove(frontOpenings, i)
			end
		end
		table.insert(frontOpenings, { x = 0, w = DOOR_W, y0 = floorH, y1 = floorH + DOOR_H })
	end
	local frontH = H + (s.facade and 7 or 0)
	Build.wall(m, base * CFrame.new(0, 0, -d / 2 + T / 2), w, frontH, T, frontOpenings, wallColor)

	-- Back and sides
	Build.wall(m, base * CFrame.new(0, 0, d / 2 - T / 2) * CFrame.Angles(0, math.pi, 0), w, H, T,
		windowOpenings(w - 2 * T, floors, floorH, 0, nil), wallColor)
	for _, side in { -1, 1 } do
		Build.wall(m, base * CFrame.new(side * (w / 2 - T / 2), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
			d - 2 * T, H, T, windowOpenings(d - 2 * T, floors, floorH, 0, nil), wallColor)
	end

	-- Upper floors with a stair hole on the right side
	local stairX = w / 2 - T - 2.2
	local stairZ0 = -d / 2 + T + 2.5
	local steps = floorH
	local run = 1.1
	for f = 1, floors - 1 do
		local y = f * floorH - 0.5
		local holeX0, holeX1 = stairX - 2.2, stairX + 2.2
		local holeZ0, holeZ1 = stairZ0, stairZ0 + steps * run
		local x0, x1 = -w / 2 + T, w / 2 - T
		local z0, z1 = -d / 2 + T, d / 2 - T
		local function slab(ax, bx, az, bz)
			if bx - ax > 0.1 and bz - az > 0.1 then
				Build.box(m, base * CFrame.new((ax + bx) / 2, y, (az + bz) / 2), Vector3.new(bx - ax, 1, bz - az), P.LightWood, "UpperFloor")
			end
		end
		slab(x0, holeX0, z0, z1)
		slab(holeX1, x1, z0, z1)
		slab(holeX0, holeX1, z0, holeZ0)
		slab(holeX0, holeX1, holeZ1, z1)
		-- Stairs (solid stepped blocks, 1 stud rise)
		for i = 1, steps do
			Build.box(m, base * CFrame.new(stairX, (f - 1) * floorH + i / 2, stairZ0 + (i - 0.5) * run),
				Vector3.new(4.2, i, run), P.Wood, "Stair")
		end
	end

	-- Roof
	if s.roof == "gable" then
		Build.gableRoof(m, base, w, d, H, s.adobe and P.Adobe or P.RoofRed, wallColor)
	elseif s.roof == "shed" then
		local drop = 2.5
		local len = math.sqrt(d * d + drop * drop) + 1
		Build.box(m, base * CFrame.new(0, H + 0.2, 0) * CFrame.Angles(math.atan(drop / d), 0, 0),
			Vector3.new(w + 1.5, 0.6, len), P.RoofBrown, "Roof")
	else
		Build.box(m, base * CFrame.new(0, H + 0.5, 0), Vector3.new(w + 0.6, 1, d + 0.6), s.adobe and P.Adobe or P.RoofBrown, "Roof")
		if s.adobe then
			-- vigas (log beams poking out)
			for x = -w / 2 + 2, w / 2 - 2, 3 do
				Build.box(m, base * CFrame.new(x, H - 1, -d / 2 - 0.8), Vector3.new(0.7, 0.7, 2), P.DarkWood, "Viga")
			end
		end
	end

	-- False front with a painted sign
	local signText = s.sign
	if kind == "Shop" then
		signText = Buildings.ShopNames[rng:NextInteger(1, #Buildings.ShopNames)]
	end
	if s.facade then
		Build.box(m, base * CFrame.new(0, frontH + 0.4, -d / 2 + T / 2), Vector3.new(w + 0.8, 0.8, T + 0.6), P.DarkWood, "FacadeTrim")
		Build.sign(m, base * CFrame.new(0, H + 3.5, -d / 2 - 0.3), Vector3.new(math.min(w - 4, 22), 4, 0.4), signText or kind)
	elseif signText then
		Build.sign(m, base * CFrame.new(0, (s.wideDoor and 12 or DOOR_H) + 2, -d / 2 - 0.3), Vector3.new(math.min(w - 4, 14), 2.6, 0.4), signText)
	end

	-- Porch / boardwalk (+ balcony for two-storey facades)
	if s.porch then
		local pz = -d / 2 - 3.5
		Build.box(m, cf * CFrame.new(0, 0.4, pz), Vector3.new(w, 0.8, 7), P.Wood, "Boardwalk")
		local postH = (s.balcony and floors > 1) and floorH or 9.5
		for _, x in { -w / 2 + 0.6, w / 2 - 0.6, 0 } do
			if x ~= 0 or w > 24 then
				Build.box(m, base * CFrame.new(x, postH / 2, -d / 2 - 6.4), Vector3.new(0.7, postH, 0.7), P.DarkWood, "PorchPost")
			end
		end
		if s.balcony and floors > 1 then
			Build.box(m, base * CFrame.new(0, floorH - 0.4, pz), Vector3.new(w, 0.8, 7), P.Wood, "Balcony")
			Build.box(m, base * CFrame.new(0, floorH + 1.6, -d / 2 - 6.8), Vector3.new(w, 0.4, 0.4), P.DarkWood, "Railing")
			for x = -w / 2 + 1, w / 2 - 1, 2 do
				Build.box(m, base * CFrame.new(x, floorH + 0.8, -d / 2 - 6.8), Vector3.new(0.25, 1.6, 0.25), P.DarkWood, "Baluster")
			end
		else
			Build.box(m, base * CFrame.new(0, postH + 0.3, pz) * CFrame.Angles(math.rad(-6), 0, 0), Vector3.new(w + 0.6, 0.5, 7.6), P.RoofBrown, "Awning")
		end
	end

	-- Church steeple
	if s.steeple then
		local rise = w * 0.32
		Build.box(m, base * CFrame.new(0, H + rise + 5, -d / 2 + 4), Vector3.new(6, 12, 6), P.White, "Steeple")
		Build.box(m, base * CFrame.new(0, H + rise + 13, -d / 2 + 4), Vector3.new(4, 4, 4), P.RoofRed, "SteepleCap")
		Build.box(m, base * CFrame.new(0, H + rise + 17, -d / 2 + 4), Vector3.new(0.6, 4, 0.6), P.Mustard, "SteepleCross")
		Build.box(m, base * CFrame.new(0, H + rise + 17.5, -d / 2 + 4), Vector3.new(2.4, 0.6, 0.6), P.Mustard, "SteepleCross")
	end

	furnish(m, base, s, rng, kind)

	-- Survivor spawn points inside
	Build.survivorSpawn(m, (base * CFrame.new(-w / 6, 3, d / 6)).Position, true)
	Build.survivorSpawn(m, (base * CFrame.new(w / 6, 3, -d / 6)).Position, true)
	if floors > 1 then
		Build.survivorSpawn(m, (base * CFrame.new(-w / 4, floorH + 3, 0)).Position, true)
	end
end

---------------------------------------------------------------------------
-- Special structures
---------------------------------------------------------------------------
function Buildings.windmill(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Windmill"
	local legH = 34
	for _, c in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		Build.box(m, cf * CFrame.new(c[1] * 0.6, legH / 2, c[2] * 0.6) * CFrame.Angles(math.rad(c[2] * 1.2), 0, math.rad(-c[1] * 1.2)),
			Vector3.new(0.8, legH, 0.8), P.DarkWood, "Leg")
	end
	local hub = Build.box(m, cf * CFrame.new(0, legH + 1, -1), Vector3.new(2, 2, 3), P.Iron, "Hub")
	for i = 0, 7 do
		Build.box(m, hub.CFrame * CFrame.new(0, 0, -1.8) * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 5, 0),
			Vector3.new(1.6, 8, 0.2), P.White, "Blade")
	end
	Build.box(m, cf * CFrame.new(0, legH + 1, 4), Vector3.new(0.3, 3, 6), P.BarnRed, "Tail")
	m.PrimaryPart = hub
	m.Parent = parent
	return m
end

function Buildings.waterTower(parent, cf)
	local m = Instance.new("Model")
	m.Name = "WaterTower"
	for _, c in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
		Build.box(m, cf * CFrame.new(c[1], 12, c[2]), Vector3.new(1, 24, 1), P.DarkWood, "Leg")
	end
	local tank = Build.part({ Parent = m, Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 15, 15), Color = P.Wood, Name = "Tank" })
	tank.CFrame = cf * CFrame.new(0, 30, 0) * CFrame.Angles(0, 0, math.pi / 2)
	Build.box(m, cf * CFrame.new(0, 37, 0), Vector3.new(11, 2, 11), P.RoofRed, "TankRoof")
	m.PrimaryPart = tank
	m.Parent = parent
	return m
end

function Buildings.well(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Well"
	local ring = Build.part({ Parent = m, Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 7, 7), Color = P.Stone, Name = "WellRing" })
	ring.CFrame = cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for _, x in { -3, 3 } do
		Build.box(m, cf * CFrame.new(x, 4.5, 0), Vector3.new(0.6, 6, 0.6), P.DarkWood, "Post")
	end
	Build.box(m, cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, 0), Vector3.new(8, 0.6, 5), P.RoofRed, "WellRoof")
	m.PrimaryPart = ring
	m.Parent = parent
	return m
end

function Buildings.fence(parent, fromPos, toPos, gapCentre, gapWidth)
	local dir = toPos - fromPos
	local len = dir.Magnitude
	if len < 1 then
		return
	end
	local unit = dir.Unit
	local count = math.floor(len / 6)
	for i = 0, count do
		local p = fromPos + unit * (i * len / math.max(count, 1))
		if not (gapCentre and (p - gapCentre).Magnitude < gapWidth / 2) then
			Build.box(parent, CFrame.new(p + Vector3.new(0, 2, 0)), Vector3.new(0.6, 4, 0.6), P.DarkWood, "FencePost")
		end
	end
	for _, h in { 1.6, 3.2 } do
		local segStart = fromPos
		local function rail(a, b)
			local seg = b - a
			if seg.Magnitude > 0.5 then
				local mid = (a + b) / 2 + Vector3.new(0, h, 0)
				Build.box(parent, CFrame.lookAt(mid, mid + seg), Vector3.new(0.3, 0.5, seg.Magnitude), P.Wood, "FenceRail")
			end
		end
		if gapCentre then
			local gs = gapCentre - unit * gapWidth / 2
			local ge = gapCentre + unit * gapWidth / 2
			rail(segStart, gs)
			rail(ge, toPos)
		else
			rail(segStart, toPos)
		end
	end
end

function Buildings.mine(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Mine"
	Build.box(m, cf * CFrame.new(0, 10, 12) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(40, 26, 30), P.Adobe, "Hill")
	Build.box(m, cf * CFrame.new(-18, 6, 8) * CFrame.Angles(0, 0.4, math.rad(12)), Vector3.new(16, 14, 22), P.Adobe, "Hill")
	Build.box(m, cf * CFrame.new(0, 5, -3.2), Vector3.new(9, 10, 0.5), Color3.fromRGB(20, 16, 14), "Tunnel")
	for _, x in { -5, 5 } do
		Build.box(m, cf * CFrame.new(x, 5.5, -3.8), Vector3.new(1.2, 11, 1.2), P.DarkWood, "Beam")
	end
	Build.box(m, cf * CFrame.new(0, 11.4, -3.8), Vector3.new(12, 1.2, 1.4), P.DarkWood, "Lintel")
	Build.sign(m, cf * CFrame.new(0, 13.2, -4), Vector3.new(10, 2.4, 0.4), "LUCKY STRIKE MINE")
	for i = 0, 5 do
		Build.box(m, cf * CFrame.new(0, 0.3, -6 - i * 4), Vector3.new(5, 0.4, 0.6), P.DarkWood, "Tie")
	end
	Build.box(m, cf * CFrame.new(0, 2, -12), Vector3.new(4, 3, 5), P.Iron, "OreCart")
	Build.box(m, cf * CFrame.new(0, 3.8, -12), Vector3.new(3.4, 0.8, 4.4), P.Stone, "Ore")
	Build.survivorSpawn(m, (cf * CFrame.new(0, 3, -9)).Position, false)
	m.Parent = parent
	return m
end

function Buildings.bootHill(parent, cf, rng)
	local m = Instance.new("Model")
	m.Name = "BootHill"
	Build.box(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(44, 3, 36), P.Sand, "Mound")
	for i = 1, 14 do
		local x, z = rng:NextNumber(-18, 18), rng:NextNumber(-14, 14)
		local lean = math.rad(rng:NextNumber(-12, 12))
		local g = cf * CFrame.new(x, 3, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), lean)
		Build.box(m, g * CFrame.new(0, 2, 0), Vector3.new(0.5, 4, 0.5), P.LightWood, "Grave")
		Build.box(m, g * CFrame.new(0, 3, 0), Vector3.new(2.4, 0.5, 0.5), P.LightWood, "Grave")
	end
	Buildings.fence(m, (cf * CFrame.new(-22, 3, -18)).Position, (cf * CFrame.new(22, 3, -18)).Position, (cf * CFrame.new(0, 3, -18)).Position, 6)
	m.Parent = parent
	return m
end

function Buildings.field(parent, cf, w, d, rng)
	local m = Instance.new("Model")
	m.Name = "Field"
	Build.box(m, cf * CFrame.new(0, 0.15, 0), Vector3.new(w, 0.3, d), P.Dirt, "Soil")
	local crop = ({ P.Crop, P.Hay, P.Green })[rng:NextInteger(1, 3)]
	for x = -w / 2 + 3, w / 2 - 3, 4 do
		Build.box(m, cf * CFrame.new(x, 1, 0), Vector3.new(1.6, 1.6, d - 4), crop, "CropRow")
	end
	local corners = {
		(cf * CFrame.new(-w / 2, 0, -d / 2)).Position,
		(cf * CFrame.new(w / 2, 0, -d / 2)).Position,
		(cf * CFrame.new(w / 2, 0, d / 2)).Position,
		(cf * CFrame.new(-w / 2, 0, d / 2)).Position,
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local gap = i == 1 and (a + b) / 2 or nil
		Buildings.fence(m, a, b, gap, 8)
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------
-- Returns the model. lotCF = ground centre of the building, front = LookVector.
function Buildings.build(kind, lotCF, parent, rng)
	local folder = ServerStorage:FindFirstChild(Config.Town.ModelsFolderName)
	local custom = folder and folder:FindFirstChild(kind)
	local m
	if custom and custom:IsA("Model") then
		m = custom:Clone()
		m:PivotTo(lotCF)
		local hasSpawn = false
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "SurvivorSpawn" then
				hasSpawn = true
				d.Transparency = 1
				d.CanCollide = false
				game:GetService("CollectionService"):AddTag(d, "SurvivorSpawn")
				d:SetAttribute("Indoor", true)
			end
		end
		if not hasSpawn then
			Build.survivorSpawn(m, lotCF.Position + Vector3.new(0, 4, 0), true)
		end
	else
		local s = Buildings.Specs[kind]
		assert(s, "Unknown building kind " .. tostring(kind))
		m = Instance.new("Model")
		buildShell(m, lotCF, s, rng, kind)
	end
	m.Name = kind
	m:SetAttribute("BuildingKind", kind)
	Build.tagAll(m, "Breakable")
	m.Parent = parent
	return m
end

return Buildings
