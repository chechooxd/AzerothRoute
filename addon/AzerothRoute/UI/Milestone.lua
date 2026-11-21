-- AzerothRoute: the milestone card. At levels 20, 30, 40, 50 and 60, a card sums up the ten levels
-- just played from the XP tracker's splits (QoL/XP.lua: time, kills, quests, and the deaths
-- AzerothRoute counts per level): "Levels 20-29: 4h 12m, 18m faster than Jaina", "412 kills,
-- 96 quests, 3 deaths". At 60 it sums up the whole measured run. The comparison is with the fastest
-- other character on the account whose same ten levels were all fully measured (UI/Pace.lua's store).
-- View pace opens the Leveling pace page. Setting: qol.milestoneCard (on).
-- Original AzerothRoute code (GPL-3.0-only).
--
--   Milestone.Summary(splits, from, to) -> { seconds, kills, quests, deaths, levels, complete } (pure, levels from..to-1)
--   Milestone.Best(store, myKey, from, to) -> { name, seconds } | nil (pure)
--   Milestone.Notify(level, stats) -> true when the card shows
--   Milestone.Hide(), Milestone.frame

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local L = ns.L
local format, floor = string.format, math.floor
if not (UI and Theme and W) then return end

local Ms = {}
UI.Milestone = Ms

local WIDTH, HEIGHT, PAD = 400, 132, 16
local SECONDS = 45
local STEP, FIRST, CAP = 10, 20, 60

ns.RegisterDefaults("qol", { milestoneCard = true })

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Level %d!"] = "¡Nivel %d!"
	L["Levels %d-%d: %s"] = "Niveles %d-%d: %s"
	L["Your whole run, levels %d-%d: %s"] = "Toda tu subida, niveles %d-%d: %s"
	L["%s faster than %s"] = "%s más rápido que %s"
	L["%s slower than %s"] = "%s más lento que %s"
	L["%d kills, %d quests, %d deaths"] = "%d enemigos, %d misiones, %d muertes"
	L["Partly measured: %d of %d levels."] = "Medido en parte: %d de %d niveles."
	L["View pace"] = "Ver ritmo"
	L["Close"] = "Cerrar"
	L["Milestone card every 10 levels"] = "Tarjeta de hito cada 10 niveles"
	L["At levels 20, 30, 40, 50 and 60, a card with those ten levels' time, kills, quests and deaths, against your best other character."] =
		"En los niveles 20, 30, 40, 50 y 60, una tarjeta con el tiempo, enemigos, misiones y muertes de esos diez niveles, contra tu mejor otro personaje."
end

---------------------------------------------------------------------------
-- The numbers (pure)
---------------------------------------------------------------------------

function Ms.Summary(splits, from, to)
	local out = { seconds = 0, kills = 0, quests = 0, deaths = 0, levels = 0, complete = true }
	for level = from, to - 1 do
		local s = splits and splits[level]
		if s and (s.seconds or 0) > 0 then
			out.seconds = out.seconds + s.seconds
			out.kills = out.kills + (s.kills or 0)
			out.quests = out.quests + (s.quests or 0)
			out.deaths = out.deaths + (s.deaths or 0)
			out.levels = out.levels + 1
			if s.partial then out.complete = false end
		else
			out.complete = false
		end
	end
	return out
end

function Ms.Best(store, key, from, to)
	local best
	for other, c in pairs(store and store.chars or {}) do
		if other ~= key then
			local sum = Ms.Summary(c.splits, from, to)
			if sum.complete and (not best or sum.seconds < best.seconds) then best = { name = c.name or other, seconds = sum.seconds } end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------

local frame, hideAt

local function duration(seconds)
	local QoL = ns.QoL
	if QoL and QoL.Duration then return QoL.Duration(seconds) end
	return format("%dm", floor((seconds or 0) / 60))
end

local function build()
	if frame then return frame end
	local f = CreateFrame("Frame", "AzerothRouteMilestoneCard", UIParent)
	frame = f
	Ms.frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("TOP", UIParent, "TOP", 0, -110)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	Theme.Skin(f, "window")
	if W.Rim then W.Rim(f) end
	f.Glyph = W.Tex(f, "ARTWORK", "emblem", "accent")
	f.Glyph:SetSize(40, 40)
	f.Glyph:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
	f.Title = W.Text(f, "display", "accent")
	f.Title:SetPoint("TOPLEFT", f.Glyph, "TOPRIGHT", 12, -2)
	f.Text = W.Text(f, "body", "text")
	f.Text:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -6)
	f.Text:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
	f.Text:SetJustifyH("LEFT")
	f.Text:SetWordWrap(true)
	f.View = W.Button(f, L["View pace"], function()
		Ms.Hide()
		if UI.ShowPicker then UI.ShowPicker() end
		local P = UI.Picker
		if P and P.ShowSection then P.ShowSection("Pace") end
	end, { primary = true, height = 26, icon = "hourglass" })
	f.View:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD - 4)
	f.Close = W.Button(f, L["Close"], function() Ms.Hide() end, { ghost = true, height = 26 })
	f.Close:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD - 4)
	f:SetScript("OnUpdate", function(self)
		if hideAt and GetTime and GetTime() >= hideAt and not (self.IsMouseOver and self:IsMouseOver()) then Ms.Hide() end
	end)
	f:Hide()
	return f
end

local function myKey()
	local Alts = ns.Alts
	return Alts and Alts.Key and Alts.Key() or nil
end

-- The card for reaching `level`: the ten levels before it, or the whole measured run at the cap.
function Ms.Notify(level, st)
	if not ns.Get("qol.milestoneCard") then return false end
	if not (level and level >= FIRST and level <= CAP and level % STEP == 0 and st and st.splits) then return false end
	local from = level - STEP
	if level >= CAP then
		from = level
		for l in pairs(st.splits) do if l < from then from = l end end
	end
	local sum = Ms.Summary(st.splits, from, level)
	if sum.levels == 0 then return false end
	local lines = {}
	local head = level >= CAP and L["Your whole run, levels %d-%d: %s"] or L["Levels %d-%d: %s"]
	local first = format(head, from, level - 1, duration(sum.seconds))
	local Pace = UI.Pace
	local best = sum.complete and Pace and Pace.Store and Ms.Best(Pace.Store(), myKey(), from, level)
	if best then
		local delta = sum.seconds - best.seconds
		first = first .. ", " .. format(delta <= 0 and L["%s faster than %s"] or L["%s slower than %s"], duration(math.abs(delta)), best.name)
	end
	lines[#lines + 1] = first
	lines[#lines + 1] = format(L["%d kills, %d quests, %d deaths"], sum.kills, sum.quests, sum.deaths)
	if not sum.complete then lines[#lines + 1] = format(L["Partly measured: %d of %d levels."], sum.levels, level - from) end
	local f = build()
	f.Title:SetText(format(L["Level %d!"], level))
	f.Text:SetText(table.concat(lines, "\n"))
	hideAt = GetTime and (GetTime() + SECONDS) or nil
	f:Show()
	return true
end

function Ms.Hide()
	hideAt = nil
	if frame then frame:Hide() end
end

-- After a level-up, once the XP tracker has closed the level (a moment later).
ns.RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
	local function show()
		local QoL = ns.QoL
		local st = QoL and QoL.GetXPStats and QoL.GetXPStats()
		if st then Ms.Notify(tonumber(level) or st.level, st) end
	end
	if C_Timer and C_Timer.After then ns.After(2, show) else show() end
end)
