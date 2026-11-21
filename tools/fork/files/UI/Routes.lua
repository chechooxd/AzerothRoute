-- AzerothRoute: the Gathering routes section of the hub. For each gathering skill the character has
-- (Herbalism, Mining), the zones with most spots of the nodes that still teach it (Core/Routes.lua):
-- the zone, its spots and loop length, the herbs or ores, and Start, which holds the arrow on the
-- nearest spot and moves on around the loop. While one is followed, the page shows it first with
-- Skip spot and Stop. Original AzerothRoute code (GPL-3.0-only).
--
--   Routes view: UI.Routes.Build(parent, shell), .Render(), .StartRow(i), .StopActive(), .Shown()

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local L = ns.L
local format, floor, min, max = string.format, math.floor, math.min, math.max
if not (UI and W and W.SHELL) then return end

local RV = {}
UI.Routes = RV

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Gathering routes"] = "Rutas de recolección"
	L["Loops of herb and ore spots for your skill, followed with the arrow"] = "Circuitos de hierbas y vetas para tu habilidad, siguiendo la flecha"
	L["%s %d/%d"] = "%s %d/%d"
	L["%d spots, %s loop"] = "%d puntos, circuito de %s"
	L["From level %d"] = "Desde nivel %d"
	L["Start"] = "Empezar"
	L["Skip spot"] = "Saltar punto"
	L["Stop"] = "Detener"
	L["Following: %s, spot %d of %d"] = "Siguiendo: %s, punto %d de %d"
	L["Learn Herbalism or Mining to get gathering routes."] = "Aprende Herboristería o Minería para tener rutas de recolección."
	L["No zone has enough spots of the nodes that still teach your skill. Train it further or try another skill."] =
		"Ninguna zona tiene suficientes puntos de los nodos que aún enseñan tu habilidad. Súbela más o prueba otra habilidad."
	L["A spot is where a node can spawn, not a promise one is up. Find Herbs or Find Minerals on the minimap shows the ones that are."] =
		"Un punto es donde puede aparecer un nodo, no una promesa de que esté ahí. Buscar hierbas o Buscar minerales en el minimapa muestra los que están."
	L["Herbalism"] = "Herboristería"
	L["Mining"] = "Minería"
end

local LINE_NAME = { [182] = "Herbalism", [186] = "Mining" }

local SH = W.SHELL
local PAD = SH.side or 24
local ROW_H = 58

local root, shellRef, scroll, body
local rows, heads, notes = {}, {}, {}
local shown = {}
local offered = {} -- the rows on show: { route args } by row index

local function R() return ns.Routes end

local function zoneName(map)
	local C = ns.Compat
	local name = C and (C.GetMapName and C.GetMapName(map) or (C.MapName and C.MapName(map)))
	return name or format("Zone %d", map)
end

local function kmText(yards)
	return format("%.1f km", (yards or 0) * 0.9144 / 1000)
end

local function width()
	local full = shellRef and (shellRef:GetWidth() - (shellRef.psRail or 0) - (shellRef.psSidebar or SH.sidebar) - 2) or 0
	if full <= 0 then full = 878 end
	return full - PAD * 2
end

function RV.Build(parent, shell)
	if root then return root end
	shellRef = shell
	root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	W.Fill(root, "panel")
	scroll = W.Scroll(root)
	scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -1)
	scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -4, 4)
	body = scroll.Child
	-- The route being followed.
	root.Now = CreateFrame("Frame", nil, body)
	root.Now:SetHeight(ROW_H)
	Theme.Skin(root.Now, "panel")
	root.Now.Text = W.Text(root.Now, "body", "accent")
	root.Now.Text:SetPoint("LEFT", root.Now, "LEFT", 14, 0)
	root.Now.Stop = W.Button(root.Now, L["Stop"], function() RV.StopActive() end, { height = 26 })
	root.Now.Stop:SetPoint("RIGHT", root.Now, "RIGHT", -12, 0)
	root.Now.Skip = W.Button(root.Now, L["Skip spot"], function() local r = R() if r then r.Skip() end RV.Render() end, { height = 26 })
	root.Now.Skip:SetPoint("RIGHT", root.Now.Stop, "LEFT", -8, 0)
	root.Now:Hide()
	return root
end

local function row(i)
	local r = rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, body)
	r:SetHeight(ROW_H)
	r.Title = W.Text(r, "body", "text")
	r.Title:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -8)
	r.Sub = W.Text(r, "small", "textMuted")
	r.Sub:SetPoint("TOPLEFT", r.Title, "BOTTOMLEFT", 0, -4)
	r.Sub:SetJustifyH("LEFT")
	r.Go = W.Button(r, L["Start"], function() RV.StartRow(r.psIndex) end, { primary = true, height = 26, icon = "icon-goto" })
	r.Go:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.Rule = W.Divider(r, false, 0.6)
	r.Rule:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	r.Rule:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
	rows[i] = r
	return r
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
		n:SetWidth(min(640, w.width))
		n:SetText(text)
		n:Show()
		w.y = w.y - 6 - n:GetStringHeight() - 10
	end
	return w
end

local function hideAll()
	for _, t in ipairs({ rows, heads, notes }) do
		for _, f in ipairs(t) do f:Hide() end
	end
	if root then root.Now:Hide() end
end

local function level()
	local lv = UnitLevel and UnitLevel("player")
	return ns.Compat and ns.Compat.Readable and ns.Compat.Readable(lv) or lv or 60
end

function RV.Render()
	if not root then return end
	hideAll()
	for k in pairs(shown) do shown[k] = nil end
	for k in pairs(offered) do offered[k] = nil end
	if shellRef then W.ShellTitle(shellRef, L["Gathering routes"], L["Loops of herb and ore spots for your skill, followed with the arrow"]) end
	body:SetWidth(width() + PAD * 2)
	local w = writer()
	local Routes, G, C = R(), ns.Gather, ns.Compat
	-- The route being followed, first.
	local active = Routes and Routes.Active()
	if active then
		local now = root.Now
		now:ClearAllPoints()
		now:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y)
		now:SetWidth(w.width)
		now.Text:SetText(format(L["Following: %s, spot %d of %d"], zoneName(active.map), Routes.Index() or 1, #active.points))
		now:Show()
		w.y = w.y - ROW_H - 16
		shown.active = true
	end
	local skills, n = 0, 0
	for _, line in ipairs(Routes and Routes.LINES or {}) do
		local rank, maxRank = C.GetSkillRank(line)
		if rank then
			skills = skills + 1
			w.head(format(L["%s %d/%d"], L[LINE_NAME[line]], rank, maxRank or rank))
			local cands = Routes.Candidates(line, rank, level())
			if #cands == 0 then w.note(L["No zone has enough spots of the nodes that still teach your skill. Train it further or try another skill."]) end
			for _, c in ipairs(cands) do
				local route = Routes.Build(c.map, c.kinds, line)
				if route then
					n = n + 1
					offered[n] = route
					local r = row(n)
					r.psIndex = n
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, w.y)
					r:SetWidth(w.width)
					local names = {}
					for _, k in ipairs(c.kinds) do names[#names + 1] = G.Kind(k).name end
					r.Title:SetText(zoneName(c.map) .. (c.minLevel and ("  \194\183  " .. format(L["From level %d"], c.minLevel)) or ""))
					r.Sub:SetText(format(L["%d spots, %s loop"], #route.points, kmText(route.length)) .. "  \194\183  " .. table.concat(names, ", "))
					r.Sub:SetWidth(max(80, w.width - 140))
					r:Show()
					w.y = w.y - ROW_H
				end
			end
			w.y = w.y - 8
		end
	end
	if skills == 0 then
		w.note(L["Learn Herbalism or Mining to get gathering routes."])
		shown.none = true
	else
		w.note(L["A spot is where a node can spawn, not a promise one is up. Find Herbs or Find Minerals on the minimap shows the ones that are."], "textMuted")
	end
	shown.skills, shown.rows = skills, n
	W.SetScrollContent(scroll, -w.y + 24)
end

function RV.StartRow(i)
	local route, Routes = offered[i], R()
	if not (route and Routes) then return end
	Routes.Start(route)
	RV.Render()
end

function RV.StopActive()
	local Routes = R()
	if Routes then Routes.Stop() end
	RV.Render()
end

function RV.Shown() return shown end

ns.On("ROUTE_CHANGED", function() if root and root:IsVisible() then RV.Render() end end)

if UI.RegisterSection then
	UI.RegisterSection({
		key = "Routes", label = L["Gathering routes"], icon = "icon-collect", order = 46,
		build = RV.Build, render = RV.Render,
	})
end
