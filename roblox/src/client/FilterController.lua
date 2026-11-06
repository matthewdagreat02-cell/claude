-- StarterPlayerScripts.WildWestClient.FilterController (ModuleScript)
-- Applies the screen filters from WildWestShared.Filters.
--
-- Everything here runs on the player's own machine, so a filter only
-- changes that player's screen. Effects fade in and out, and Lighting /
-- Atmosphere values the game already had are put back when a filter that
-- changed them is switched off.
--
--   FilterController.apply(id, strength)  -- strength 0..1 (default: current)
--   FilterController.getId()
--   FilterController.getStrength()
--   FilterController.Changed              -- fires (id, strength)

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Filters = require(ReplicatedStorage:WaitForChild("WildWestShared"):WaitForChild("Filters"))

local WHITE = Color3.new(1, 1, 1)
local FADE = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Post-processing effects. Defaults = Roblox's own default value, used when
-- a filter leaves a property out. Off = the value where the effect is
-- invisible; Strength fades each property between Off and the filter value.
local EFFECTS = {
	{
		Key = "ColorCorrection",
		Class = "ColorCorrectionEffect",
		Defaults = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE },
		Off = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE },
	},
	{
		Key = "Bloom",
		Class = "BloomEffect",
		Defaults = { Intensity = 0.4, Size = 24, Threshold = 0.95 },
		Off = { Intensity = 0 },
	},
	{
		Key = "Blur",
		Class = "BlurEffect",
		Defaults = { Size = 24 },
		Off = { Size = 0 },
	},
	{
		Key = "SunRays",
		Class = "SunRaysEffect",
		Defaults = { Intensity = 0.25, Spread = 1 },
		Off = { Intensity = 0 },
	},
	{
		Key = "DepthOfField",
		Class = "DepthOfFieldEffect",
		Defaults = { FarIntensity = 0.75, NearIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10 },
		Off = { FarIntensity = 0, NearIntensity = 0 },
	},
	{
		-- Tone mapping. Newer Roblox class: skipped quietly if it doesn't exist.
		Key = "ColorGrading",
		Class = "ColorGradingEffect",
		Defaults = {},
		Off = {},
		Enums = { TonemapperPreset = "TonemapperPreset" },
	},
}

local LIGHTING_PROPS = {
	"ClockTime",
	"Brightness",
	"ExposureCompensation",
	"Ambient",
	"OutdoorAmbient",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
}
-- These jump straight to the filter's value instead of being scaled by
-- Strength (half of "Night" should not be 7 in the morning).
local NO_STRENGTH = { ClockTime = true }

local ATMOSPHERE_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }
-- Starting values for an Atmosphere we add ourselves (when the game has none).
local OWN_ATMOSPHERE_OFF = {
	Density = 0,
	Offset = 0,
	Glare = 0,
	Haze = 0,
	Color = Color3.fromRGB(199, 170, 107),
	Decay = Color3.fromRGB(92, 60, 13),
}

---------------------------------------------------------------------------

local FilterController = {}

local changedEvent = Instance.new("BindableEvent")
FilterController.Changed = changedEvent.Event

local currentId = Filters.DefaultId
local currentStrength = 1

local effects = {} -- Key -> effect instance we created
local tweens = {} -- instance -> the tween currently running on it
local lightingBase = {} -- property -> the game's value, while a filter overrides it
local atmosphereBase = {} -- same, for the game's own Atmosphere
local atmosphereBaseOwner = nil -- which Atmosphere atmosphereBase belongs to
local ownAtmosphere = nil -- Atmosphere we created, if the game has none

local function lerp(a, b, t)
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return a:Lerp(b, t)
	elseif type(a) == "number" and type(b) == "number" then
		return a + (b - a) * t
	end
	return b
end

-- Tween `inst` to `goal`, replacing any tween already running on it.
-- onDone runs only if this tween finishes (not if a newer one replaces it).
local function play(inst, goal, onDone)
	local old = tweens[inst]
	tweens[inst] = nil
	if old then
		old:Cancel()
	end
	if next(goal) == nil then
		if onDone then
			onDone()
		end
		return
	end
	local tween = TweenService:Create(inst, FADE, goal)
	tweens[inst] = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and tweens[inst] == tween then
			tweens[inst] = nil
			if onDone then
				onDone()
			end
		end
	end)
	tween:Play()
end

local function getEffect(spec)
	local inst = effects[spec.Key]
	if inst and inst.Parent then
		return inst
	end
	local ok, created = pcall(Instance.new, spec.Class)
	if not ok then
		return nil -- class not available in this Roblox version
	end
	created.Name = "WWFilter_" .. spec.Key
	for p, v in spec.Defaults do
		created[p] = v
	end
	for p, v in spec.Off do
		created[p] = v
	end
	created.Enabled = false
	created.Parent = Lighting
	effects[spec.Key] = created
	return created
end

local function applyEffect(spec, cfg, t)
	if cfg and t > 0 then
		local inst = getEffect(spec)
		if not inst then
			return
		end
		local goal = {}
		for p, default in spec.Defaults do
			local full = cfg[p]
			if full == nil then
				full = default
			end
			local off = spec.Off[p]
			goal[p] = if off ~= nil then lerp(off, full, t) else full
		end
		for p, enumName in spec.Enums or {} do
			local value = cfg[p]
			if value ~= nil then
				pcall(function()
					inst[p] = (Enum :: any)[enumName][value]
				end)
			end
		end
		inst.Enabled = true
		play(inst, goal)
	else
		local inst = effects[spec.Key]
		if inst and inst.Parent then
			play(inst, spec.Off, function()
				inst.Enabled = false
			end)
		end
	end
end

-- Fade the listed properties of `inst` toward the filter's values, or back
-- to the game's own values (remembered in `base`) when the filter doesn't
-- set them.
local function applyOverrides(inst, props, cfg, base, t)
	local goal, restoring = {}, {}
	for _, p in props do
		local want = cfg and cfg[p]
		if want ~= nil and t > 0 then
			if base[p] == nil then
				base[p] = (inst :: any)[p]
			end
			goal[p] = if NO_STRENGTH[p] then want else lerp(base[p], want, t)
		elseif base[p] ~= nil then
			goal[p] = base[p]
			table.insert(restoring, p)
		end
	end
	play(inst, goal, function()
		for _, p in restoring do
			base[p] = nil
		end
	end)
end

local function findGameAtmosphere()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= ownAtmosphere then
			return child
		end
	end
	return nil
end

local function applyAtmosphere(cfg, t)
	local gameAtmosphere = findGameAtmosphere()
	if gameAtmosphere then
		if ownAtmosphere then
			ownAtmosphere:Destroy()
			ownAtmosphere = nil
		end
		if atmosphereBaseOwner ~= gameAtmosphere then
			atmosphereBase = {}
			atmosphereBaseOwner = gameAtmosphere
		end
		applyOverrides(gameAtmosphere, ATMOSPHERE_PROPS, cfg, atmosphereBase, t)
	elseif cfg and t > 0 then
		if not ownAtmosphere then
			local a = Instance.new("Atmosphere")
			a.Name = "WWFilter_Atmosphere"
			for p, v in OWN_ATMOSPHERE_OFF do
				(a :: any)[p] = v
			end
			a.Parent = Lighting
			ownAtmosphere = a
		end
		local goal = {}
		for _, p in ATMOSPHERE_PROPS do
			local off = OWN_ATMOSPHERE_OFF[p]
			local full = cfg[p]
			goal[p] = if full ~= nil then lerp(off, full, t) else off
		end
		play(ownAtmosphere, goal)
	elseif ownAtmosphere then
		local a = ownAtmosphere
		play(a, OWN_ATMOSPHERE_OFF, function()
			if ownAtmosphere == a then
				a:Destroy()
				ownAtmosphere = nil
			end
		end)
	end
end

function FilterController.apply(id, strength)
	local filter = Filters.ById[id] or Filters.ById[Filters.DefaultId] or {}
	currentId = filter.Id or Filters.DefaultId
	currentStrength = math.clamp(strength or currentStrength, 0, 1)
	local t = currentStrength

	for _, spec in EFFECTS do
		local ok, err = pcall(applyEffect, spec, filter[spec.Key], t)
		if not ok then
			warn("[Filters] " .. spec.Key .. ": " .. tostring(err))
		end
	end
	local ok, err = pcall(applyOverrides, Lighting, LIGHTING_PROPS, filter.Lighting, lightingBase, t)
	if not ok then
		warn("[Filters] Lighting: " .. tostring(err))
	end
	ok, err = pcall(applyAtmosphere, filter.Atmosphere, t)
	if not ok then
		warn("[Filters] Atmosphere: " .. tostring(err))
	end

	changedEvent:Fire(currentId, currentStrength)
end

function FilterController.getId()
	return currentId
end

function FilterController.getStrength()
	return currentStrength
end

return FilterController
