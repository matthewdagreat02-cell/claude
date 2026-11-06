-- ReplicatedStorage.WildWestShared.Filters (ModuleScript)
-- Every screen filter a player can pick from the 🎨 Filters menu.
--
-- A filter is built from Roblox's post-processing effects. Each one only
-- changes the player's own screen (it never affects other players).
--
--   ColorCorrection  ColorCorrectionEffect  Brightness, Contrast, Saturation, TintColor
--   Bloom            BloomEffect            Intensity, Size, Threshold
--   Blur             BlurEffect             Size
--   SunRays          SunRaysEffect          Intensity, Spread
--   DepthOfField     DepthOfFieldEffect     FarIntensity, NearIntensity, FocusDistance, InFocusRadius
--   ColorGrading     ColorGradingEffect     TonemapperPreset ("Default" or "Retro")
--   Atmosphere       Atmosphere             Density, Offset, Color, Decay, Glare, Haze
--   Lighting         Lighting properties    ClockTime, Brightness, ExposureCompensation,
--                                           Ambient, OutdoorAmbient, ColorShift_Top,
--                                           ColorShift_Bottom, EnvironmentDiffuseScale,
--                                           EnvironmentSpecularScale
--
-- Leave a section out and that effect stays off. To add your own filter,
-- copy any entry below, give it a new Id, and it shows up in the menu.

local Filters = {}

-- Order of the sections in the Filters menu.
Filters.Categories = { "Color", "Mood", "Time of Day", "Weather", "Camera" }

-- The filter used when a player joins.
Filters.DefaultId = "Default"

local rgb = Color3.fromRGB

Filters.List = {
	---------------------------------------------------------------------------
	-- COLOR
	---------------------------------------------------------------------------
	{
		Id = "Default",
		Name = "Default",
		Icon = "⚪",
		Category = "Color",
		Color = rgb(200, 200, 200),
		-- no effects: the game's normal look
	},
	{
		Id = "Vibrant",
		Name = "Vibrant",
		Icon = "🌈",
		Category = "Color",
		Color = rgb(255, 90, 160),
		ColorCorrection = { Saturation = 0.45, Contrast = 0.08, Brightness = 0.02 },
	},
	{
		Id = "BlackWhite",
		Name = "Black & White",
		Icon = "🔳",
		Category = "Color",
		Color = rgb(120, 120, 120),
		ColorCorrection = { Saturation = -1 },
	},
	{
		Id = "Sepia",
		Name = "Sepia",
		Icon = "📜",
		Category = "Color",
		Color = rgb(190, 140, 80),
		ColorCorrection = { Saturation = -1, Contrast = 0.05, Brightness = 0.02, TintColor = rgb(255, 225, 180) },
	},
	{
		Id = "Vintage",
		Name = "Vintage",
		Icon = "📷",
		Category = "Color",
		Color = rgb(205, 170, 130),
		ColorCorrection = { Saturation = -0.4, Contrast = -0.12, Brightness = 0.05, TintColor = rgb(255, 238, 215) },
		ColorGrading = { TonemapperPreset = "Retro" },
	},
	{
		Id = "Pastel",
		Name = "Pastel",
		Icon = "🧁",
		Category = "Color",
		Color = rgb(250, 190, 220),
		ColorCorrection = { Saturation = -0.15, Contrast = -0.2, Brightness = 0.08, TintColor = rgb(255, 240, 250) },
		Bloom = { Intensity = 0.4, Size = 32, Threshold = 0.9 },
	},
	{
		Id = "HighContrast",
		Name = "High Contrast",
		Icon = "◐",
		Category = "Color",
		Color = rgb(40, 40, 40),
		ColorCorrection = { Contrast = 0.45, Saturation = 0.1 },
	},
	{
		Id = "Warm",
		Name = "Warm",
		Icon = "🔥",
		Category = "Color",
		Color = rgb(255, 150, 60),
		ColorCorrection = { Saturation = 0.1, TintColor = rgb(255, 228, 195) },
	},
	{
		Id = "Cool",
		Name = "Cool",
		Icon = "🧊",
		Category = "Color",
		Color = rgb(90, 170, 255),
		ColorCorrection = { Saturation = -0.05, TintColor = rgb(205, 228, 255) },
	},
	{
		Id = "Retro",
		Name = "Retro",
		Icon = "🕹️",
		Category = "Color",
		Color = rgb(255, 120, 80),
		ColorCorrection = { Saturation = -0.1, Contrast = 0.12 },
		ColorGrading = { TonemapperPreset = "Retro" },
	},

	---------------------------------------------------------------------------
	-- MOOD
	---------------------------------------------------------------------------
	{
		Id = "Anime",
		Name = "Anime",
		Icon = "🌸",
		Category = "Mood",
		Color = rgb(255, 150, 200),
		ColorCorrection = { Saturation = 0.35, Contrast = 0.12, Brightness = 0.03, TintColor = rgb(255, 248, 252) },
		Bloom = { Intensity = 0.9, Size = 30, Threshold = 0.85 },
		SunRays = { Intensity = 0.12, Spread = 0.8 },
	},
	{
		Id = "WildWest",
		Name = "Wild West",
		Icon = "🤠",
		Category = "Mood",
		Color = rgb(215, 140, 60),
		ColorCorrection = { Saturation = -0.15, Contrast = 0.15, TintColor = rgb(255, 222, 175) },
		Atmosphere = { Density = 0.32, Offset = 0.1, Color = rgb(225, 180, 125), Decay = rgb(165, 110, 70), Glare = 0.4, Haze = 1.6 },
		SunRays = { Intensity = 0.08, Spread = 0.6 },
	},
	{
		Id = "Noir",
		Name = "Noir",
		Icon = "🕵️",
		Category = "Mood",
		Color = rgb(30, 30, 30),
		ColorCorrection = { Saturation = -1, Contrast = 0.4, Brightness = -0.06 },
		Bloom = { Intensity = 0.3, Size = 20, Threshold = 1.2 },
	},
	{
		Id = "Dreamy",
		Name = "Dreamy",
		Icon = "☁️",
		Category = "Mood",
		Color = rgb(200, 170, 255),
		ColorCorrection = { Saturation = 0.1, Contrast = -0.1, Brightness = 0.06, TintColor = rgb(250, 235, 255) },
		Bloom = { Intensity = 1.2, Size = 48, Threshold = 0.7 },
		Blur = { Size = 2 },
	},
	{
		Id = "Neon",
		Name = "Neon",
		Icon = "💜",
		Category = "Mood",
		Color = rgb(170, 60, 255),
		ColorCorrection = { Saturation = 0.8, Contrast = 0.25 },
		Bloom = { Intensity = 1.6, Size = 40, Threshold = 0.6 },
	},
	{
		Id = "Horror",
		Name = "Horror",
		Icon = "💀",
		Category = "Mood",
		Color = rgb(90, 20, 20),
		ColorCorrection = { Saturation = -0.7, Contrast = 0.3, Brightness = -0.12, TintColor = rgb(255, 210, 210) },
		Atmosphere = { Density = 0.45, Offset = 0, Color = rgb(70, 60, 60), Decay = rgb(40, 30, 30), Glare = 0, Haze = 2 },
	},
	{
		Id = "Toxic",
		Name = "Toxic",
		Icon = "☢️",
		Category = "Mood",
		Color = rgb(120, 230, 40),
		ColorCorrection = { Saturation = 0.2, Contrast = 0.1, TintColor = rgb(215, 255, 185) },
		Atmosphere = { Density = 0.35, Offset = 0.1, Color = rgb(170, 220, 110), Decay = rgb(90, 130, 50), Glare = 0.2, Haze = 1.5 },
	},

	---------------------------------------------------------------------------
	-- TIME OF DAY (only on your screen; the server's clock is not changed)
	---------------------------------------------------------------------------
	{
		Id = "Sunrise",
		Name = "Sunrise",
		Icon = "🌅",
		Category = "Time of Day",
		Color = rgb(255, 160, 170),
		Lighting = { ClockTime = 6.3, ColorShift_Top = rgb(255, 190, 200) },
		ColorCorrection = { Saturation = 0.1, TintColor = rgb(255, 232, 238) },
		SunRays = { Intensity = 0.2, Spread = 0.7 },
	},
	{
		Id = "Noon",
		Name = "High Noon",
		Icon = "☀️",
		Category = "Time of Day",
		Color = rgb(255, 220, 60),
		Lighting = { ClockTime = 12, ExposureCompensation = 0.3 },
		ColorCorrection = { Saturation = 0.1, Contrast = 0.05 },
		Bloom = { Intensity = 0.6, Size = 24, Threshold = 0.9 },
	},
	{
		Id = "GoldenHour",
		Name = "Golden Hour",
		Icon = "🌇",
		Category = "Time of Day",
		Color = rgb(255, 170, 40),
		Lighting = { ClockTime = 17.6, ColorShift_Top = rgb(255, 200, 130) },
		ColorCorrection = { Saturation = 0.2, Contrast = 0.08, TintColor = rgb(255, 230, 190) },
		SunRays = { Intensity = 0.25, Spread = 0.9 },
		Bloom = { Intensity = 0.6, Size = 28, Threshold = 0.9 },
	},
	{
		Id = "Night",
		Name = "Night",
		Icon = "🌙",
		Category = "Time of Day",
		Color = rgb(40, 60, 140),
		Lighting = { ClockTime = 0, Brightness = 1, OutdoorAmbient = rgb(70, 80, 120), Ambient = rgb(40, 45, 70) },
		ColorCorrection = { Saturation = -0.25, Brightness = 0.03, TintColor = rgb(200, 215, 255) },
	},
	{
		Id = "BloodMoon",
		Name = "Blood Moon",
		Icon = "🔴",
		Category = "Time of Day",
		Color = rgb(200, 30, 30),
		Lighting = { ClockTime = 0, OutdoorAmbient = rgb(120, 40, 40), Ambient = rgb(70, 25, 25) },
		ColorCorrection = { Saturation = -0.2, Contrast = 0.15, TintColor = rgb(255, 185, 185) },
		Atmosphere = { Density = 0.4, Offset = 0, Color = rgb(150, 50, 50), Decay = rgb(80, 20, 20), Glare = 0.3, Haze = 1.8 },
	},

	---------------------------------------------------------------------------
	-- WEATHER
	---------------------------------------------------------------------------
	{
		Id = "Stormy",
		Name = "Storm Chaser",
		Icon = "🌪️",
		Category = "Weather",
		Color = rgb(90, 110, 100),
		Lighting = { ExposureCompensation = -0.4 },
		ColorCorrection = { Saturation = -0.45, Contrast = 0.2, Brightness = -0.04, TintColor = rgb(215, 235, 220) },
		Atmosphere = { Density = 0.5, Offset = 0.05, Color = rgb(120, 135, 125), Decay = rgb(70, 85, 80), Glare = 0, Haze = 2.5 },
	},
	{
		Id = "DustStorm",
		Name = "Dust Storm",
		Icon = "🏜️",
		Category = "Weather",
		Color = rgb(210, 150, 80),
		ColorCorrection = { Saturation = -0.2, Contrast = -0.05, TintColor = rgb(255, 225, 185) },
		Atmosphere = { Density = 0.6, Offset = 0.2, Color = rgb(210, 160, 100), Decay = rgb(150, 100, 60), Glare = 0.5, Haze = 3 },
	},
	{
		Id = "Fog",
		Name = "Fog",
		Icon = "🌫️",
		Category = "Weather",
		Color = rgb(180, 185, 190),
		ColorCorrection = { Saturation = -0.2, Contrast = -0.1, Brightness = 0.03 },
		Atmosphere = { Density = 0.55, Offset = 0.3, Color = rgb(200, 205, 210), Decay = rgb(160, 165, 175), Glare = 0, Haze = 2.5 },
	},
	{
		Id = "Frost",
		Name = "Frost",
		Icon = "❄️",
		Category = "Weather",
		Color = rgb(170, 220, 255),
		ColorCorrection = { Saturation = -0.3, Brightness = 0.06, TintColor = rgb(215, 235, 255) },
		Atmosphere = { Density = 0.35, Offset = 0.2, Color = rgb(220, 235, 250), Decay = rgb(170, 195, 225), Glare = 0.3, Haze = 1.5 },
		Bloom = { Intensity = 0.5, Size = 30, Threshold = 0.9 },
	},
	{
		Id = "Heatwave",
		Name = "Heatwave",
		Icon = "🥵",
		Category = "Weather",
		Color = rgb(255, 110, 40),
		Lighting = { ExposureCompensation = 0.4 },
		ColorCorrection = { Saturation = 0.15, Contrast = 0.1, TintColor = rgb(255, 215, 175) },
		Bloom = { Intensity = 1, Size = 36, Threshold = 0.75 },
		Atmosphere = { Density = 0.3, Offset = 0.1, Color = rgb(255, 210, 160), Decay = rgb(200, 130, 80), Glare = 1.5, Haze = 1.2 },
	},

	---------------------------------------------------------------------------
	-- CAMERA
	---------------------------------------------------------------------------
	{
		Id = "Cinematic",
		Name = "Cinematic",
		Icon = "🎬",
		Category = "Camera",
		Color = rgb(40, 140, 160),
		ColorCorrection = { Saturation = -0.05, Contrast = 0.18, TintColor = rgb(235, 248, 255) },
		Bloom = { Intensity = 0.5, Size = 28, Threshold = 0.9 },
		DepthOfField = { FarIntensity = 0.35, NearIntensity = 0, FocusDistance = 40, InFocusRadius = 60 },
	},
	{
		Id = "TiltShift",
		Name = "Tilt Shift",
		Icon = "🔍",
		Category = "Camera",
		Color = rgb(110, 200, 140),
		ColorCorrection = { Saturation = 0.3, Contrast = 0.1 },
		DepthOfField = { FarIntensity = 0.75, NearIntensity = 0.6, FocusDistance = 25, InFocusRadius = 18 },
	},
	{
		Id = "Blurry",
		Name = "Blurry",
		Icon = "😵‍💫",
		Category = "Camera",
		Color = rgb(150, 150, 220),
		Blur = { Size = 10 },
	},
	{
		Id = "Glow",
		Name = "Glow",
		Icon = "✨",
		Category = "Camera",
		Color = rgb(255, 235, 120),
		Bloom = { Intensity = 1.5, Size = 50, Threshold = 0.6 },
		SunRays = { Intensity = 0.3, Spread = 1 },
	},
	{
		Id = "Bright",
		Name = "Bright",
		Icon = "💡",
		Category = "Camera",
		Color = rgb(255, 250, 200),
		Lighting = { ExposureCompensation = 0.6 },
		ColorCorrection = { Brightness = 0.05 },
	},
	{
		Id = "Dark",
		Name = "Dark",
		Icon = "🌑",
		Category = "Camera",
		Color = rgb(50, 50, 70),
		Lighting = { ExposureCompensation = -0.8 },
		ColorCorrection = { Contrast = 0.1 },
	},
}

-- Look up a filter by Id.
Filters.ById = {}
for _, f in Filters.List do
	Filters.ById[f.Id] = f
end

return Filters
