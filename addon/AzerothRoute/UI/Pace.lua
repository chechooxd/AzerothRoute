-- AzerothRoute: the Leveling pace section of the hub. The XP tracker (QoL/XP.lua) already measures
-- XP per hour, time to the next level and each level's split; this page shows them: three figures
-- (XP per hour, to the next level, to the level cap), then every finished level as a bar of its
-- play time with its kills and quests. The time to the cap adds the XP left of this level to every
-- later level's (Levels.LEVEL_XP) at the tracker's rate, or, before there is one, at the rate of the
-- levels already played. Original AzerothRoute code (GPL-3.0-only).
--
--   Pace.Estimate(stats, levelXP, maxLevel) -> { xp, seconds, rate, fromSplits, maxed } | nil (pure)
--   Pace.Levels(splits) -> { { level, seconds, kills, quests, partial }... , total, longest } (pure)
--   Pace.Build(parent, shell), Pace.Render(), Pace.Shown()

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local L = ns.L
local format, floor, max, min = string.format, math.floor, math.max, math.min

if not (UI and W and W.SHELL) then return end

local Pace = {}
UI.Pace = Pace

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Leveling pace"] = "Ritmo de subida"
	L["How fast you level, level by level"] = "Qué tan rápido subes, nivel por nivel"
	L["XP per hour"] = "XP por hora"
	L["To level %d"] = "Para el nivel %d"
	L["To level %d, at this pace"] = "Para el nivel %d, a este ritmo"
	L["Levels played"] = "Niveles jugados"
	L["%s in %d levels"] = "%s en %d niveles"
	L["Level %d"] = "Nivel %d"
	L["%d kills, %d quests"] = "%d muertes, %d misiones"
	L["partly measured"] = "medido en parte"
	L["No level finished yet with the tracker on. Each level you finish shows here."] =
		"Aún no terminas un nivel con el medidor activo. Cada nivel que termines aparece aquí."
	L["Kill or quest a little: the pace shows once you gain XP."] = "Mata o haz misiones un poco: el ritmo aparece en cuanto ganes XP."
	L["The XP tracker is off. Turn it on to see your pace."] = "El medidor de XP está apagado. Actívalo para ver tu ritmo."
	L["Turn on the XP tracker"] = "Activar el medidor de XP"
	L["You are at the level cap."] = "Estás en el nivel máximo."
	L["Estimated from the levels you played."] = "Estimado con los niveles que jugaste."
end

---------------------------------------------------------------------------
-- The numbers (pure)
---------------------------------------------------------------------------

-- The XP rate of the finished levels (XP an hour), or nil.
local function splitsRate(splits)
	local xp, seconds = 0, 0
	for _, s in pairs(splits or {}) do
		if (s.seconds or 0) > 0 and (s.xp or 0) > 0 then xp, seconds = xp + s.xp, seconds + s.seconds end
	end
	if seconds < 60 then return nil end
	return xp / seconds * 3600
end

function Pace.Estimate(st, levelXP, maxLevel)
	if not st then return nil end
	if st.maxed or (st.level or 0) >= maxLevel then return { xp = 0, seconds = 0, rate = st.rate or 0, maxed = true } end
	local xp = st.remaining or 0
	for lvl = st.level + 1, maxLevel - 1 do xp = xp + (levelXP[lvl] or 0) end
	local rate, fromSplits = st.rate or 0, nil
	if rate <= 0 then
		rate = splitsRate(st.splits)
		fromSplits = true
	end
	if not rate or rate <= 0 then return nil end
	return { xp = xp, seconds = xp / rate * 3600, rate = rate, fromSplits = fromSplits }
end

function Pace.Levels(splits)
	local out = { total = 0, longest = 0 }
	for level, s in pairs(splits or {}) do
		if (s.seconds or 0) > 0 then
			out[#out + 1] = { level = level, seconds = s.seconds, kills = s.kills or 0, quests = s.quests or 0, partial = s.partial and true or false }
			out.total = out.total + s.seconds
			out.longest = max(out.longest, s.seconds)
		end
	end
	table.sort(out, function(a, b) return a.level < b.level end)
	return out
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local SH = W.SHELL
local PAD = SH.side or 24
local TILE_H, BAR_H, BAR_GAP = 74, 22, 6
local LABEL_W, INFO_W = 70, 190

local root, shellRef, scroll, body
local tiles, bars, heads, notes = {}, {}, {}, {}
local shown = {}

local function duration(seconds)
	local QoL = ns.QoL
	if QoL and QoL.Duration then return QoL.Duration(seconds) end
	return format("%dm", floor((seconds or 0) / 60))
end

local function short(n)
	if n >= 10000 then return format("%.1fk", n / 1000) end
	return tostring(floor(n + 0.5))
end

local function width()
	local full = shellRef and (shellRef:GetWidth() - (shellRef.psRail or 0) - (shellRef.psSidebar or SH.sidebar) - 2) or 0
	if full <= 0 then full = 878 end
	return full - PAD * 2
end

function Pace.Build(parent, shell)
	if root then return root end
	shellRef = shell
	root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	W.Fill(root, "panel")
	scroll = W.Scroll(root)
	scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -1)
	scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -4, 4)
	body = scroll.Child
	root.Turn = W.Button(body, L["Turn on the XP tracker"], function()
		ns.Set("qol.xpTracker", true)
		Pace.Render()
	end, { primary = true, height = 28 })
	root.Turn:Hide()
	return root
end

local function tile(i)
	local t = tiles[i]
	if t then return t end
	t = CreateFrame("Frame", nil, body)
	t:SetHeight(TILE_H)
	Theme.Skin(t, "panel")
	t.Value = W.Text(t, "display", "text")
	t.Value:SetPoint("TOPLEFT", t, "TOPLEFT", 14, -12)
	t.Label = W.Text(t, "small", "textMuted")
	t.Label:SetPoint("TOPLEFT", t.Value, "BOTTOMLEFT", 0, -6)
	t.Label:SetPoint("RIGHT", t, "RIGHT", -10, 0)
	t.Label:SetJustifyH("LEFT")
	tiles[i] = t
	return t
end

local function bar(i)
	local b = bars[i]
	if b then return b end
	b = CreateFrame("Frame", nil, body)
	b:SetHeight(BAR_H)
	b.Label = W.Text(b, "label", "textDim")
	b.Label:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.Fill = b:CreateTexture(nil, "ARTWORK")
	b.Fill:SetTexture(Theme.Media("white"))
	b.Fill:SetPoint("LEFT", b, "LEFT", LABEL_W, 0)
	b.Fill:SetHeight(BAR_H - 8)
	b.Time = W.Text(b, "number", "text")
	b.Time:SetPoint("LEFT", b.Fill, "RIGHT", 8, 0)
	b.Info = W.Text(b, "small", "textMuted")
	b.Info:SetJustifyH("RIGHT")
	b.Info:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	bars[i] = b
	return b
end

local function writer()
	local w = { y = -24, h = 0, n = 0, width = width() }
	function w.head(text, count)
		w.h = w.h + 1
		local h = heads[w.h] or W.SectionHeader(body)
		heads[w.h] = h
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y)
		h:SetWidth(w.width)
		W.SetSection(h, text, count)
		h:Show()
		w.y = w.y - 46
	end
	function w.note(text, color)
		w.n = w.n + 1
		local n = notes[w.n]
		if not n then
			n = W.Text(body, "note", "textDim")
			n:SetWordWrap(true)
			n:SetJustifyH("LEFT")
			notes[w.n] = n
		end
		W.Color(n, color or "textDim")
		n:ClearAllPoints()
		n:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y - 6)
		n:SetWidth(min(620, w.width))
		n:SetText(text)
		n:Show()
		w.y = w.y - 6 - n:GetStringHeight() - 10
	end
	return w
end

local function hideAll()
	for _, t in ipairs({ tiles, bars, heads, notes }) do
		for _, f in ipairs(t) do f:Hide() end
	end
	if root then root.Turn:Hide() end
end

function Pace.Render()
	if not root then return end
	hideAll()
	for k in pairs(shown) do shown[k] = nil end
	if shellRef then W.ShellTitle(shellRef, L["Leveling pace"], L["How fast you level, level by level"]) end
	body:SetWidth(width() + PAD * 2)
	local w = writer()
	local QoL = ns.QoL
	local st = QoL and QoL.GetXPStats and QoL.GetXPStats()
	if not st then
		w.note(L["The XP tracker is off. Turn it on to see your pace."])
		root.Turn:ClearAllPoints()
		root.Turn:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y - 4)
		root.Turn:Show()
		shown.off = true
		W.SetScrollContent(scroll, -w.y + 60)
		return
	end
	local Levels = ns.Levels
	local cap = (Levels and Levels.MAX_LEVEL) or 60
	local est = Pace.Estimate(st, (Levels and Levels.LEVEL_XP) or {}, cap)
	-- Three figures.
	local figures = {
		{ st.rate and st.rate > 0 and short(st.rate) or "-", L["XP per hour"] },
		{ st.maxed and "-" or duration(st.timeToLevel), format(L["To level %d"], min(cap, (st.level or 0) + 1)) },
		{ est and (est.maxed and "-" or duration(est.seconds)) or "-", format(L["To level %d, at this pace"], cap) },
	}
	local gap = 12
	local tw = floor((w.width - gap * 2) / 3)
	for i, fig in ipairs(figures) do
		local t = tile(i)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + (i - 1) * (tw + gap), w.y)
		t:SetWidth(tw)
		t.Value:SetText(fig[1])
		t.Label:SetText(fig[2])
		t:Show()
	end
	shown.tiles = #figures
	shown.toCap = est and est.seconds or nil
	w.y = w.y - TILE_H - 12
	if st.maxed then w.note(L["You are at the level cap."], "success")
	elseif not est then w.note(L["Kill or quest a little: the pace shows once you gain XP."])
	elseif est.fromSplits then w.note(L["Estimated from the levels you played."]) end
	-- Every finished level as a bar of its play time.
	local lv = Pace.Levels(st.splits)
	w.head(L["Levels played"], #lv > 0 and format(L["%s in %d levels"], duration(lv.total), #lv) or nil)
	if #lv == 0 then w.note(L["No level finished yet with the tracker on. Each level you finish shows here."]) end
	local track = max(40, w.width - LABEL_W - INFO_W - 70)
	for i, l in ipairs(lv) do
		local b = bar(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y)
		b:SetWidth(w.width)
		b.Label:SetText(format(L["Level %d"], l.level))
		b.Fill:SetWidth(max(2, floor(track * l.seconds / max(1, lv.longest))))
		W.Color(b.Fill, l.partial and "textMuted" or "accent")
		b.Time:SetText(duration(l.seconds))
		b.Info:SetText(format(L["%d kills, %d quests"], l.kills, l.quests) .. (l.partial and ("  \194\183  " .. L["partly measured"]) or ""))
		b:Show()
		w.y = w.y - BAR_H - BAR_GAP
	end
	shown.bars = #lv
	W.SetScrollContent(scroll, -w.y + 24)
end

function Pace.Shown() return shown end

ns.On("QOL_XP_UPDATED", function() if root and root:IsVisible() then Pace.Render() end end)

if UI.RegisterSection then
	UI.RegisterSection({
		key = "Pace", label = L["Leveling pace"], icon = "hourglass", order = 45,
		build = Pace.Build, render = Pace.Render,
	})
end
