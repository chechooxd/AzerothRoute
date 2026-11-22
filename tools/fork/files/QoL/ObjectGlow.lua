-- AzerothRoute: world objects that glow, as on today's realms. When the game's interact targeting picks
-- an object near you in front (the "soft interact" target, the object the Interact Key would use), and
-- the object is one an open quest still needs (Quests/Tracker.lua: Q.ObjectivesForObject, by its id or
-- its name), or a herb or an ore vein (Core/Gather.lua), it gets a pulsing glow and an icon: gold for a
-- quest, green for a herb, copper for an ore. The game tells an addon about that one object only, never
-- every object around you, so only the nearest object in front of you glows.
--
-- The glow sits on the object's own nameplate where the client gives it one (SoftTargetNameplateInteract);
-- without it, a small card under the middle of the screen names the object and the quest.
--
-- While it is on, AzerothRoute sets the client's interact targeting (the CVars in CVARS: targeting on
-- for objects, their icon, their nameplate, the range in qol.objectGlowRange). The player's own values are
-- kept in AzerothRouteDB.objectGlowCVars and put back when the option goes off. Out of combat only.
--
-- Settings (Options > Questing > Quests > World objects): qol.objectGlow, qol.objectGlowQuest,
-- qol.objectGlowGather, qol.objectGlowRange. Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...
local Compat, L = ns.Compat, ns.L

local Glow = {}
ns.ObjectGlow = Glow

ns.RegisterDefaults("qol", { objectGlow = true, objectGlowQuest = true, objectGlowGather = true, objectGlowRange = 15 })

local HERBALISM, MINING = 182, 186
Glow.COLORS = { quest = "quest", herb = "success", ore = { 0.85, 0.55, 0.25 } }

---------------------------------------------------------------------------
-- The client's interact targeting
---------------------------------------------------------------------------

-- name -> the value while the glow is on (a function of the settings).
local CVARS = {
	SoftTargetInteract = function() return "3" end,          -- objects are picked with or without a gamepad
	SoftTargetIconGameObject = function() return "1" end,    -- the game's own icon over the picked object
	SoftTargetNameplateInteract = function() return "1" end, -- a nameplate for it, where the glow sits
	SoftTargetInteractRange = function()
		return tostring(math.floor(tonumber(ns.Get("qol.objectGlowRange")) or 15))
	end,
}
Glow.CVARS = CVARS

local function getCVar(name)
	local C = C_CVar
	local v
	if C and C.GetCVar then v = C.GetCVar(name) elseif GetCVar then v = GetCVar(name) end
	return Compat and Compat.Readable and Compat.Readable(v) or v
end

local function setCVar(name, value)
	local C = C_CVar
	local ok
	if C and C.SetCVar then ok = pcall(C.SetCVar, name, value) elseif SetCVar then ok = pcall(SetCVar, name, value) end
	return ok
end

local function store()
	local db = _G.AzerothRouteDB
	if type(db) ~= "table" then return nil end
	return db
end

local function wanted() return ns.Get("qol.objectGlow") == true end

-- The targeting set for the glow (on), or the player's own values back (off). In a fight, once it ends.
local waiting = false
local function apply()
	if InCombatLockdown and InCombatLockdown() then
		waiting = true
		return
	end
	waiting = false
	local db = store()
	if not db then return end
	if wanted() then
		db.objectGlowCVars = db.objectGlowCVars or {}
		local saved = db.objectGlowCVars
		for name, value in pairs(CVARS) do
			local now = getCVar(name)
			if now ~= nil then
				if saved[name] == nil then saved[name] = now end
				local want = value()
				if now ~= want then setCVar(name, want) end
			end
		end
	elseif db.objectGlowCVars then
		for name, value in pairs(db.objectGlowCVars) do setCVar(name, value) end
		db.objectGlowCVars = nil
	end
end
Glow.Apply = apply
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if waiting then apply() end
end)

---------------------------------------------------------------------------
-- What the picked object is
---------------------------------------------------------------------------

local function objectIdOf(guid)
	guid = Compat and Compat.Readable and Compat.Readable(guid) or guid
	return type(guid) == "string" and tonumber(guid:match("^GameObject%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")) or nil
end

local function readable(v)
	if Compat and Compat.IsSecret and Compat.IsSecret(v) then return nil end
	return v
end

-- The open quest objectives object `id` (or named `name`) still serves: { objective, ... } or nil.
local function questNeeds(id, name)
	local Q = ns.QuestDB
	if not Q then return nil end
	local list = (id and Q.ObjectivesForObject and Q.ObjectivesForObject(id))
		or (name and Q.ObjectivesForObjectName and Q.ObjectivesForObjectName(name))
	if type(list) ~= "table" then return nil end
	local open
	for i = 1, #list do
		local o = list[i]
		if type(o) == "table" and not o.done then
			open = open or {}
			open[#open + 1] = o
		end
	end
	return open
end

-- What object `id` / `name` is to the glow: "quest", "herb", "ore" (the settings asked for it), or nil.
-- -> kind, the quest objectives (quest)
function Glow.Classify(id, name)
	if ns.Get("qol.objectGlowQuest") then
		local open = questNeeds(id, name)
		if open then return "quest", open end
	end
	if ns.Get("qol.objectGlowGather") and id then
		local G = ns.Gather
		local k = G and G.KindOf and G.KindOf(id)
		local kind = k and G.Kind(k)
		if kind and kind.line == HERBALISM then return "herb" end
		if kind and kind.line == MINING then return "ore" end
	end
	return nil
end

---------------------------------------------------------------------------
-- The glow
---------------------------------------------------------------------------

local function colorOf(kind)
	local c = Glow.COLORS[kind]
	if type(c) == "table" then return c[1], c[2], c[3] end
	local T = ns.Theme
	if T and T.Color then return T.Color(c) end
	return 1, 0.82, 0
end

-- The quest mark is AzerothRoute's own map icon; herbs and ores the game's own item icons.
local ICONS = {
	quest = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Map\\icon-quest-available",
	herb = "Interface\\Icons\\INV_Misc_Herb_07",
	ore = "Interface\\Icons\\INV_Ore_Copper_01",
}
Glow.ICONS = ICONS
local function iconOf(kind) return ICONS[kind] end

-- One glow, moved onto whatever it marks: a pulsing halo, an icon, and the words under it.
local glow
local function makeGlow()
	if glow then return glow end
	local f = CreateFrame("Frame", "AzerothRouteObjectGlow", UIParent)
	f:SetSize(110, 110)
	f:SetFrameStrata("BACKGROUND")
	f:EnableMouse(false)
	f:Hide()
	local halo = f:CreateTexture(nil, "BACKGROUND")
	halo:SetTexture(ns.Theme and ns.Theme.Media and ns.Theme.Media("glow") or "Interface\\Cooldown\\star4")
	halo:SetBlendMode("ADD")
	halo:SetAllPoints(f)
	f.Halo = halo
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(22, 22)
	icon:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.Icon = icon
	local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("TOP", f, "CENTER", 0, -16)
	f.Name = name
	local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetPoint("TOP", name, "BOTTOM", 0, -2)
	f.Note = note
	-- The pulse: the halo breathes between dim and bright.
	local ag = halo.CreateAnimationGroup and halo:CreateAnimationGroup()
	if ag then
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetFromAlpha(0.35)
		a:SetToAlpha(1)
		a:SetDuration(0.7)
		if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
		f.Pulse = ag
	end
	glow = f
	return f
end

local current = { id = nil, name = nil, kind = nil } -- the picked object and what it is to the glow

local function plateOf()
	local N = C_NamePlate
	local plate = N and N.GetNamePlateForUnit and N.GetNamePlateForUnit("softinteract")
	return readable(plate)
end

-- The words under the icon: the object's name and, for a quest, the quest and its progress.
local function noteOf(kind, open)
	if kind == "herb" then return L["Herb"] end
	if kind == "ore" then return L["Ore"] end
	local o = open and open[1]
	if not o then return L["Quest"] end
	local Q = ns.QuestDB
	local title = Q and Q.GetQuestTitle and Q.GetQuestTitle(o.q)
	local progress = Q and Q.ProgressText and Q.ProgressText(o)
	if title and progress then return title .. "  " .. progress end
	return title or L["Quest"]
end

-- Show the glow for what is picked now, or hide it.
function Glow.Refresh()
	local f = glow
	if not wanted() or not (current.id or current.name) then
		current.kind = nil
		if f then
			if f.Pulse then f.Pulse:Stop() end
			f:Hide()
		end
		return
	end
	local kind, open = Glow.Classify(current.id, current.name)
	current.kind = kind
	if not kind then
		if f then
			if f.Pulse then f.Pulse:Stop() end
			f:Hide()
		end
		return
	end
	f = makeGlow()
	local r, g, b = colorOf(kind)
	f.Halo:SetVertexColor(r, g, b, 1)
	f.Icon:SetTexture(iconOf(kind))
	f.Name:SetText(current.name or "")
	f.Name:SetTextColor(r, g, b)
	f.Note:SetText(noteOf(kind, open))
	f:ClearAllPoints()
	local plate = plateOf()
	if plate then
		f:SetParent(plate)
		f:SetPoint("CENTER", plate, "CENTER", 0, 0)
		f.onPlate = true
	else
		f:SetParent(UIParent)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
		f.onPlate = false
	end
	f:Show()
	if f.Pulse and not f.Pulse:IsPlaying() then f.Pulse:Play() end
end

-- The object picked now: (id, name) | nil, and what it is to the glow.
function Glow.Current() return current.id, current.name, current.kind end
function Glow.Frame() return glow end

ns.RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", function(_, _, guid)
	current.id = objectIdOf(guid)
	local name = UnitName and UnitName("softinteract")
	current.name = type(readable(name)) == "string" and name ~= "" and name or nil
	if not current.id then current.name = nil end
	Glow.Refresh()
end)

ns.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
	if unit == "softinteract" and current.id then Glow.Refresh() end
end)

ns.RegisterEvent("QUEST_LOG_UPDATE", function()
	if current.id then Glow.Refresh() end
end)

if ns.On then
	ns.On("SETTING_CHANGED", function(path)
		if path == "qol.objectGlow" or path == "qol.objectGlowRange" or path == "qol" or path == "" then apply() end
		if type(path) == "string" and (path:find("^qol%.objectGlow") or path == "qol" or path == "") then Glow.Refresh() end
	end)
end
if ns.OnLogin then ns.OnLogin(apply) end
