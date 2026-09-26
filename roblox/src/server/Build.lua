-- ServerScriptService.WildWest.Build (ModuleScript)
-- Small helpers for building low-poly, flat-coloured ("anime") parts.

local CollectionService = game:GetService("CollectionService")

local Build = {}

Build.Palette = {
	Wood = Color3.fromRGB(176, 112, 64),
	DarkWood = Color3.fromRGB(110, 68, 40),
	LightWood = Color3.fromRGB(214, 164, 110),
	Cream = Color3.fromRGB(245, 226, 186),
	Teal = Color3.fromRGB(96, 180, 170),
	Sage = Color3.fromRGB(150, 186, 120),
	Mustard = Color3.fromRGB(232, 184, 72),
	BarnRed = Color3.fromRGB(190, 58, 48),
	Rose = Color3.fromRGB(226, 128, 120),
	Sky = Color3.fromRGB(120, 176, 230),
	White = Color3.fromRGB(245, 245, 240),
	Adobe = Color3.fromRGB(214, 140, 96),
	Slate = Color3.fromRGB(80, 86, 100),
	RoofRed = Color3.fromRGB(150, 50, 45),
	RoofBrown = Color3.fromRGB(96, 64, 48),
	Stone = Color3.fromRGB(150, 146, 140),
	Iron = Color3.fromRGB(60, 62, 68),
	Glass = Color3.fromRGB(170, 220, 255),
	Dirt = Color3.fromRGB(196, 150, 98),
	Sand = Color3.fromRGB(226, 196, 140),
	Crop = Color3.fromRGB(150, 190, 70),
	Hay = Color3.fromRGB(236, 200, 100),
	Green = Color3.fromRGB(80, 170, 80),
	DeadTree = Color3.fromRGB(120, 100, 86),
}

-- Create a part. props may contain any Part property plus Parent.
function Build.part(props)
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape and p:IsA("Part") then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" and k ~= "ClassName" and k ~= "Tags" then
			p[k] = v
		end
	end
	if props.Tags then
		for _, tag in props.Tags do
			CollectionService:AddTag(p, tag)
		end
	end
	p.Parent = props.Parent
	return p
end

-- Box at a world CFrame.
function Build.box(parent, cf, size, color, name, extra)
	local props = {
		Parent = parent,
		CFrame = cf,
		Size = size,
		Color = color,
		Name = name or "Part",
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return Build.part(props)
end

-- Wedge at a world CFrame.
function Build.wedge(parent, cf, size, color, name)
	return Build.part({
		ClassName = "WedgePart",
		Parent = parent,
		CFrame = cf,
		Size = size,
		Color = color,
		Name = name or "Wedge",
	})
end

-- A wall that runs along wallCF.RightVector, centred on wallCF (which sits
-- at the BOTTOM centre of the wall). openings = { {x=, w=, y0=, y1=, glass=bool} }
-- where x is measured from the wall centre.
function Build.wall(parent, wallCF, length, height, thickness, openings, color)
	openings = openings or {}
	table.sort(openings, function(a, b)
		return a.x < b.x
	end)

	local function piece(xa, xb, ya, yb)
		if xb - xa < 0.05 or yb - ya < 0.05 then
			return
		end
		Build.box(
			parent,
			wallCF * CFrame.new((xa + xb) / 2, (ya + yb) / 2, 0),
			Vector3.new(xb - xa, yb - ya, thickness),
			color,
			"Wall"
		)
	end

	local x = -length / 2
	for _, o in openings do
		local left, right = o.x - o.w / 2, o.x + o.w / 2
		piece(x, left, 0, height)
		piece(left, right, 0, o.y0)
		piece(left, right, o.y1, height)
		if o.glass then
			Build.box(
				parent,
				wallCF * CFrame.new(o.x, (o.y0 + o.y1) / 2, 0),
				Vector3.new(o.w, o.y1 - o.y0, 0.2),
				Build.Palette.Glass,
				"Window",
				{ Transparency = 0.45, Material = Enum.Material.Glass }
			)
		end
		x = right
	end
	piece(x, length / 2, 0, height)
end

-- Gable roof over a w x d rectangle whose wall tops are at height h
-- (relative to originCF). Ridge runs front-to-back (along Z).
function Build.gableRoof(parent, originCF, w, d, h, color, wallColor, pitch)
	pitch = pitch or 0.32
	local rise = w * pitch
	local half = w / 2
	local angle = math.atan(rise / half)
	local slope = math.sqrt(half * half + rise * rise) + 1.2
	for _, side in { 1, -1 } do
		Build.box(
			parent,
			originCF
				* CFrame.new(side * half / 2, h + rise / 2 + 0.4, 0)
				* CFrame.Angles(0, 0, -side * angle),
			Vector3.new(slope, 0.8, d + 2),
			color,
			"Roof"
		)
	end
	-- Triangular gable ends (front and back) from two wedges each.
	for _, zSide in { -1, 1 } do
		for _, xSide in { 1, -1 } do
			local back = Vector3.new(-xSide, 0, 0) -- vertical face points at the ridge
			local up = Vector3.new(0, 1, 0)
			local right = up:Cross(back)
			local pos = Vector3.new(xSide * half / 2, h + rise / 2, zSide * (d / 2))
			local cf = originCF * CFrame.fromMatrix(pos, right, up, back)
			Build.wedge(parent, cf, Vector3.new(0.9, rise, half), wallColor, "Gable")
		end
	end
	return rise
end

-- Invisible marker where a survivor can spawn.
function Build.survivorSpawn(parent, worldPos, indoor)
	local p = Build.part({
		Parent = parent,
		Name = "SurvivorSpawn",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(worldPos),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "SurvivorSpawn" },
	})
	p:SetAttribute("Indoor", indoor == true)
	return p
end

-- Sign with text on the front face.
function Build.sign(parent, cf, size, text, bg, fg)
	local board = Build.box(parent, cf, size, bg or Build.Palette.DarkWood, "Sign")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = fg or Build.Palette.Cream
	label.Parent = gui
	return board
end

-- Tag every part so a destruction system can find them.
function Build.tagAll(model, tag)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			CollectionService:AddTag(d, tag)
		end
	end
end

return Build
