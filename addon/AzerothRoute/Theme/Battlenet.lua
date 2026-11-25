-- AzerothRoute: the Battle.net look over the house style. Every house surface (window, panel, button,
-- dropdown, tile, edit box) is drawn with rounded corners: its ground and its hover wash take the
-- nine-slice Media/UI/round-8 art, and its square 1px border gives way to a rounded edge
-- (round-8-ring) in the same colour. Shell windows (the hub, the settings) get a bar across the top that
-- carries the theme's band (its sky and contour lines) under the gold rim, and a short flat header.
-- Every accent (primary buttons, switches, the tabs' line, selections) is the theme's own, so the scheme
-- and the accent the player picks colour all of it. Original AzerothRoute code (GPL-3.0-only).
--
--   Theme.Battlenet.Round(frame[, radius])   rounds a painted frame's ground, hover and edge

local ADDON, ns = ...
local Theme, W = ns.Theme, ns.Widgets
if not (Theme and W and Theme.Paint and Theme.Paint.house) then return end

local B = {}
Theme.Battlenet = B

B.RADIUS = { window = 10, panel = 8, button = 6, dropdown = 6, tile = 8, editbox = 6, inset = 6 }
local FILL, RING = "round-8", "round-8-ring"
local MARGIN = 8 -- the art's corner, in texels


-- A texture drawn as nine slices of the rounded art, its corners `radius` px.
local function slice(tex, art, radius)
	tex:SetTexture(Theme.Media(art))
	if tex.SetTextureSliceMargins then
		tex:SetTextureSliceMargins(MARGIN, MARGIN, MARGIN, MARGIN)
		local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
		if tex.SetTextureSliceMode then tex:SetTextureSliceMode(mode) end
	end
end

-- The skins drawn with square corners (skin id -> true: Theme/SkinClassic.lua, SkinMarble.lua). Under
-- them a surface keeps the house's square ground, hover and 1px border, and the skin frames it.
B.SQUARE = {}
local function unslice(tex)
	tex:SetTexture(Theme.Media("white"))
	if tex.SetTextureSliceMargins then tex:SetTextureSliceMargins(0, 0, 0, 0) end
end

function B.Round(f, radius)
	local d = f.psSkin
	if not d then return end
	if B.SQUARE[Theme.SkinId()] then
		if d.bg then unslice(d.bg) end
		if d.hover then unslice(d.hover) end
		if d.ring then d.ring:Hide() end
		return
	end
	radius = radius or MARGIN
	if d.bg and d.bg:GetTexture() ~= Theme.Media(FILL) then slice(d.bg, FILL, radius) end
	if d.hover and d.hover:GetTexture() ~= Theme.Media(FILL) then slice(d.hover, FILL, radius) end
	-- The square border's colour goes to the rounded edge; the border itself is hidden.
	local e = f.psBorder
	local shown = e and e[1] and e[1]:IsShown()
	if not d.ring then
		d.ring = f:CreateTexture(nil, "BORDER", nil, 7)
		d.ring:SetAllPoints(f)
		slice(d.ring, RING, radius)
	end
	if shown and not f.psPrimary then
		d.ring:SetVertexColor(e[1]:GetVertexColor())
		d.ring:Show()
	else
		d.ring:Hide()
	end
	if e then for i = 1, 4 do e[i]:Hide() end end
	-- The house window's square light and contact lines would cross the rounded corners.
	if d.edge then for i = 1, #d.edge do d.edge[i]:Hide() end end
end

-- Each house painter, then its surface rounded.
local house = Theme.Paint.house
for kind, radius in pairs(B.RADIUS) do
	local paint = house[kind]
	if paint then
		house[kind] = function(f, ...)
			paint(f, ...)
			if not f.psBare then B.Round(f, radius) end
		end
	end
end

-- Shell windows: a flat header (its band and haze go to the top bar; the gold rim stays).
local function flatten(f)
	if rawget(f, "Band") then f.Band:SetAlpha(0) end
	if rawget(f, "Haze") then f.Haze:SetAlpha(0) end
end

-- Only the divider lines of a column (plain white textures other than its ground): its emblem, name,
-- version and the like stay.
local function hideLines(frame)
	if not frame.GetRegions then return end
	local bg = frame.psSkin and frame.psSkin.bg
	for _, r in ipairs({ frame:GetRegions() }) do
		if r ~= bg and r.GetObjectType and r:GetObjectType() == "Texture" and r:GetTexture() == Theme.Media("white") then r:Hide() end
	end
end

-- The theme's band (sky and contour lines) across a top bar, cropped to it, as the header had it.
local function barBand(f, bar)
	if not Theme.Band then return end
	local band = Theme.Band(bar, "BACKGROUND", -5)
	band:SetAllPoints(bar)
	if Theme.BandCoords then band:SetTexCoord(Theme.BandCoords(f:GetWidth(), B.TOP)) end
	bar.Band = band
end
B.Flatten = flatten

-- The hub's foot: the Battle.net app's Play button, "Continue guide", which closes the hub and
-- opens the guide window (SHOW_FRAME). It takes the side column's foot, where the version was.
function B.Continue(f)
	f:Hide()
	ns.Fire("SHOW_FRAME")
end

local L = ns.L
if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Continue guide"] = "Continuar guía"
end

---------------------------------------------------------------------------
-- The top bar (a hub's rail across the top) and the short header
---------------------------------------------------------------------------

B.TOP = 52      -- the top bar's height
B.HEADER = 80   -- the header under it (the house's is 112)
local TAB_GAP, TAB_PAD, ICON = 4, 12, 16

local metric = Theme.Metric
function Theme.Metric(key, house)
	local v = metric(key, house)
	if key == "shellHeader" and v == house then return B.HEADER end
	return v
end

-- The header's title and subtitle, placed for the short header.
local function placeTitle(f)
	local SH = W.SHELL
	if not rawget(f, "Title") then return end
	f.Title:SetPoint("TOPLEFT", f.Header, "TOPLEFT", SH.pad, -18)
	f.Subtitle:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -4)
end

-- The rail becomes a bar across the window's top: the emblem and the name at its left, the sections
-- as tabs (W.ShellRail), the foot items and the search at its right. The window loses the rail's
-- width and gains the bar's height, so every pane keeps its size; the side column starts at the top.
local function topBar(f)
	local SH = W.SHELL
	local RAIL, TOP = f.psRail or 0, B.TOP
	local bar = f.Rail
	f.psTopBar = TOP
	f:SetWidth(f:GetWidth() - RAIL)
	f:SetHeight(f:GetHeight() + TOP)
	f.psRail = 0
	-- The bar: its own ground and the theme's band, no hairlines of the rail.
	hideLines(bar)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	bar:SetHeight(TOP)
	barBand(f, bar)
	-- The side column under it, its list from the top.
	f.Sidebar:ClearAllPoints()
	f.Sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1 - TOP)
	f.Sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	f.psNavTop = 12
	f.NavScroll:ClearAllPoints()
	f.NavScroll:SetPoint("TOPLEFT", f.Sidebar, "TOPLEFT", 0, -f.psNavTop)
	f.NavScroll:SetPoint("BOTTOMRIGHT", f.Sidebar, "BOTTOMRIGHT", -1, SH.footer)
	-- The window's tools at the bar's right, as in the settings: a close button there (the hub's own one
	-- moves over the details' art, where it was hard to find), the menu scale and the search.
	local close = W.IconButton(bar, "close", 28, L["Close"], function() f:Hide() end, 14)
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	f.BarClose = close
	f.Close:SetAlpha(0)
	f.Close:EnableMouse(false)
	local tools = rawget(f, "HeaderTools")
	if tools and tools.Place then
		local place = tools.Place
		tools.Place = function(...)
			place(...)
			B.HubTools(f)
		end
	end
	B.HubTools(f)
	-- The emblem and the name in the bar.
	f.Emblem:ClearAllPoints()
	f.Emblem:SetSize(32, 32)
	f.Emblem:SetPoint("LEFT", bar, "LEFT", 10, 0)
	if f.Emblem.Glow then f.Emblem.Glow:SetAlpha(0) end
	f.Wordmark:SetParent(bar)
	f.Wordmark:ClearAllPoints()
	f.Wordmark:SetPoint("LEFT", f.Emblem, "RIGHT", 4, -1)
	if rawget(f, "Tagline") then f.Tagline:SetAlpha(0) end
	if W.LayoutRim then W.LayoutRim(f) end
	if W.ShellLayout then W.ShellLayout(f) end
end
B.TopBar = topBar

-- The hub's tools right to left from the bar's close button: the menu scale (its slider and value; the
-- label is its tip) and the search. f.psToolsW: the room they take from the bar's right.
local SEARCH_W = 160
function B.HubTools(f)
	local bar, close = rawget(f, "Rail"), rawget(f, "BarClose")
	if not (bar and close) then return end
	local left, used = close, 12 + 28
	local scale = rawget(f, "HeaderTools")
	if scale then
		scale:SetParent(bar)
		scale:ClearAllPoints()
		scale:SetPoint("RIGHT", left, "LEFT", -14, 0)
		scale:Show()
		if scale.Label and scale.Label:IsShown() then
			local lw = scale.Label:GetStringWidth() or 0
			scale.Label:Hide()
			scale:SetWidth(math.max(40, (scale:GetWidth() or 0) - lw - 10))
		end
		used = used + 14 + (scale:GetWidth() or 0)
		left = scale
	end
	local search = rawget(f, "Search")
	if search then
		search:SetParent(bar)
		search:ClearAllPoints()
		search:SetPoint("RIGHT", left, "LEFT", -16, 0)
		search:SetWidth(SEARCH_W)
		used = used + 16 + SEARCH_W
	end
	f.psToolsW = used
	-- The title alone in the header.
	if rawget(f, "Title") then f.Title:SetPoint("TOPRIGHT", f.Header, "TOPRIGHT", -W.SHELL.pad, -18) end
end

local function tab(f, i)
	local b = f.railButtons[i]
	if b and b.psTop then return b end
	b = CreateFrame("Button", nil, f.Rail)
	b.psTop = true
	b:SetHeight(B.TOP - 12)
	b.Icon = b:CreateTexture(nil, "ARTWORK")
	b.Icon:SetSize(ICON, ICON)
	b.Label = W.Text(b, "label", "textDim")
	b.Under = b:CreateTexture(nil, "OVERLAY")
	b.Under:SetTexture(Theme.Media("white"))
	b.Under:SetHeight(2)
	b.Under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 0)
	b.Under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 0)
	W.Color(b.Under, "accent")
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	slice(hl, FILL, MARGIN)
	hl:SetAllPoints(b)
	hl:SetVertexColor(Theme.Wash("hover"))
	b:SetScript("OnClick", function(self) if self.psOnClick then self.psOnClick(self.psKey) end end)
	f.railButtons[i] = b
	return b
end

-- A section's name on its tab: the short one where the hub's is long.
local SHORT = { Pace = "Pace", Routes = "Routes" }
if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Pace"] = "Ritmo"
	L["Routes"] = "Rutas"
end
B.NO_TAB = { Lookup = true }
local function tabLabel(item) return SHORT[item.key] and L[SHORT[item.key]] or item.label end
B.TabLabel = tabLabel

-- The sections as tabs from the name's right; the foot items as icons left of the window's tools. Every
-- tab is named while all fit, else the open one alone (the others an icon with its tip), so the bar
-- always says where you are. -> the number of sections shown.
local function topRail(f, items, bottom, active, onSelect)
	-- The bar's search is the global one (UI/Picker.lua opens Lookup with it): no Lookup tab.
	local kept = {}
	for _, item in ipairs(items) do if not B.NO_TAB[item.key] then kept[#kept + 1] = item end end
	items = kept
	local bar = f.Rail
	local i = 0
	local function setup(item, labelled)
		i = i + 1
		local b = tab(f, i)
		b.psKey, b.psOnClick = item.key, item.onClick or onSelect
		b.psTip = item.tip or item.label
		b.Icon:SetTexture(Theme.Media(item.icon or "compact"))
		b.Label:SetText(labelled and tabLabel(item) or "")
		b.Label:SetShown(labelled)
		b.Icon:ClearAllPoints()
		b.Label:ClearAllPoints()
		local on = item.key == active
		W.Color(b.Icon, on and "text" or "textDim")
		W.Color(b.Label, on and "text" or "textDim")
		b.Under:SetShown(on)
		local w
		if labelled then
			b.Icon:SetPoint("LEFT", b, "LEFT", TAB_PAD, 0)
			b.Label:SetPoint("LEFT", b.Icon, "RIGHT", 6, 0)
			w = TAB_PAD * 2 + ICON + 6 + math.ceil(b.Label:GetStringWidth() or 0)
		else
			b.Icon:SetPoint("CENTER", b, "CENTER", 0, 0)
			w = ICON + 16
		end
		b:SetWidth(w)
		b:ClearAllPoints()
		b:Show()
		return b, w
	end
	-- The room between the name and the foot icons.
	local left = 10 + 32 + 4 + 140 + 16
	local footW = #(bottom or {}) * (ICON + 16 + TAB_GAP)
	local room = (f:GetWidth() - 2) - left - footW - 24 - (rawget(f, "psToolsW") or 0)
	local need = 0
	for _, item in ipairs(items) do
		local probe = f.psTabProbe or W.Text(bar, "label", "textDim")
		f.psTabProbe = probe
		probe:SetText(tabLabel(item) or "")
		probe:Hide()
		need = need + TAB_PAD * 2 + ICON + 6 + math.ceil(probe:GetStringWidth() or 0) + TAB_GAP
	end
	local all = need <= room
	local x = left
	for _, item in ipairs(items) do
		local b, w = setup(item, all or item.key == active)
		b:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + w + TAB_GAP
	end
	local rx = 12 + (rawget(f, "psToolsW") or 0) + 8
	for k = #(bottom or {}), 1, -1 do
		local b, w = setup(bottom[k], false)
		b:SetPoint("RIGHT", bar, "RIGHT", -rx, 0)
		rx = rx + w + TAB_GAP
	end
	for k = i + 1, #f.railButtons do f.railButtons[k]:Hide() end
	return #items
end

-- The settings window: a bar across the top with the emblem, the name and the side list's groups as
-- tabs; the side column under it lists the open group's pages only (W.ShellNav below).
local SETTINGS = "AzerothRouteOptions"
local function groupBar(f)
	local SH = W.SHELL
	local TOP = B.TOP
	local bar = CreateFrame("Frame", nil, f)
	Theme.Skin(bar, "sidebar")
	barBand(f, bar)
	if ns.DragWindow then ns.DragWindow(bar, f) end
	f.GroupBar = bar
	f.psTopBar = TOP
	f.psGroupBar = true
	f.groupButtons = {}
	f:SetHeight(f:GetHeight() + TOP)
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	bar:SetHeight(TOP)
	local side = f.Sidebar
	-- The side column's own hairlines (the band's line) would cross its list.
	hideLines(side)
	side:ClearAllPoints()
	side:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + (f.psRail or 0), -1 - TOP)
	side:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1 + (f.psRail or 0), 1)
	f.psNavTop = 12
	f.NavScroll:ClearAllPoints()
	f.NavScroll:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -f.psNavTop)
	f.NavScroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -1, SH.footer)
	f.Emblem:SetParent(bar)
	f.Emblem:ClearAllPoints()
	f.Emblem:SetSize(32, 32)
	f.Emblem:SetPoint("LEFT", bar, "LEFT", 10, 0)
	if f.Emblem.Glow then f.Emblem.Glow:SetAlpha(0) end
	if rawget(f.Emblem, "Hot") then f.Emblem.Hot:SetParent(bar) end
	f.Wordmark:SetParent(bar)
	f.Wordmark:ClearAllPoints()
	f.Wordmark:SetPoint("LEFT", f.Emblem, "RIGHT", 4, -1)
	if rawget(f, "Tagline") then f.Tagline:SetAlpha(0) end
	-- The window's tools go over everything, at the bar's right: each time the shell places them in the
	-- header (W.HeaderScale's Place), they move to the bar, right to left from the close button.
	local tools = rawget(f, "HeaderTools")
	if tools and tools.Place then
		local place = tools.Place
		tools.Place = function(...)
			place(...)
			B.ToolsToBar(f)
		end
	end
	B.ToolsToBar(f)
	if W.ShellLayout then W.ShellLayout(f) end
end
B.GroupBar = groupBar

-- The close button, the menu scale and the header's tools (psHeadTools: search, Peek and Fold, Install)
-- right to left in the settings' bar. Where they would reach the group tabs, the scale's label goes
-- first, then Install, then the search narrows. The header keeps the page title alone.
function B.ToolsToBar(f)
	local bar = rawget(f, "GroupBar")
	if not bar then return end
	local SH = W.SHELL
	local close, scale = f.Close, rawget(f, "HeaderTools")
	close:SetParent(bar)
	close:ClearAllPoints()
	close:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
	local list = {}
	if scale then list[#list + 1] = { w = scale, gap = 14 } end
	for _, w in ipairs(rawget(f, "psHeadTools") or {}) do list[#list + 1] = { w = w, gap = rawget(w, "psHeadGap") or 16 } end
	local function lay()
		local left, used = close, 12 + (close:GetWidth() or 28)
		for _, t in ipairs(list) do
			local w = t.w
			if w:IsShown() or w == scale then
				w:SetParent(bar)
				w:ClearAllPoints()
				w:SetPoint("RIGHT", left, "LEFT", -t.gap, 0)
				if w == scale then w:Show() end
				used = used + t.gap + (w:GetWidth() or 0)
				left = w
			end
		end
		return used
	end
	local room = (f:GetWidth() or 0) - (rawget(f, "psGroupEnd") or (10 + 32 + 4 + 140 + 16)) - 16
	local used = lay()
	if used > room and scale and scale.Label and scale.Label:IsShown() then
		local lw = scale.Label:GetStringWidth() or 0
		scale.Label:Hide()
		scale:SetWidth(math.max(40, (scale:GetWidth() or 0) - lw - 10))
		used = lay()
	end
	local install = rawget(f, "Install")
	if used > room and install and install:IsShown() then
		install:Hide()
		used = lay()
	end
	local search = rawget(f, "Search")
	if used > room and search and search:IsShown() then
		search:SetWidth(math.max(160, (search:GetWidth() or 0) - (used - room)))
		lay()
	end
	-- The title alone in the header, across it.
	f.Title:SetPoint("TOPRIGHT", f.Header, "TOPRIGHT", -SH.pad, -18)
end

local function groupTab(f, i)
	local b = f.groupButtons[i]
	if b then return b end
	local was = f.railButtons
	f.railButtons = f.groupButtons
	local saved = rawget(f, "Rail")
	f.Rail = f.GroupBar
	b = tab(f, i)
	f.Rail = saved
	f.railButtons = was
	return b
end

-- The groups (items with `group`) become the bar's tabs; the side list keeps the pages of the group
-- holding the open page (else the first group's). A tab opens its group's first page. Lists without
-- groups (search results) pass through. -> the items for the side list
local function groupNav(f, items, active, onSelect)
	local groups, cur = {}, nil
	for _, it in ipairs(items) do
		if it.group then
			cur = { item = it, pages = {} }
			groups[#groups + 1] = cur
		elseif cur then
			cur.pages[#cur.pages + 1] = it
		end
	end
	for _, b in ipairs(f.groupButtons) do b:Hide() end
	if #groups == 0 then return items end
	local open = groups[1]
	for _, g in ipairs(groups) do
		for _, p in ipairs(g.pages) do if p.key == active then open = g end end
	end
	if active == nil and f.psOpenGroup then
		for _, g in ipairs(groups) do if g.item.key == f.psOpenGroup then open = g end end
	end
	f.psOpenGroup = open.item.key
	local x = 10 + 32 + 4 + 140 + 16
	for i, g in ipairs(groups) do
		local b = groupTab(f, i)
		local first = g.pages[1] and g.pages[1].key
		b.psKey = first
		b.psOnClick = function()
			f.psOpenGroup = g.item.key
			if first and onSelect then onSelect(first) end
		end
		b.psTip = g.item.label
		b.Icon:SetTexture(nil)
		b.Label:SetText(g.item.label)
		b.Label:Show()
		b.Label:ClearAllPoints()
		b.Label:SetPoint("CENTER", b, "CENTER", 0, 0)
		local on = g == open
		W.Color(b.Label, on and "text" or "textDim")
		b.Under:SetShown(on)
		local w = TAB_PAD * 2 + math.ceil(b.Label:GetStringWidth() or 0)
		b:SetWidth(w)
		b:ClearAllPoints()
		b:SetPoint("LEFT", f.GroupBar, "LEFT", x, 0)
		b:Show()
		x = x + w + TAB_GAP
	end
	-- Where the tabs end: the window's tools keep right of it (B.ToolsToBar).
	if f.psGroupEnd ~= x then
		f.psGroupEnd = x
		B.ToolsToBar(f)
	end
	local out = {}
	for _, p in ipairs(open.pages) do
		local copy = {}
		for k, v in pairs(p) do copy[k] = v end
		copy.indent = nil
		out[#out + 1] = copy
	end
	return out
end

local shell = W.Shell
function W.Shell(name, opts)
	local f = shell(name, opts)
	flatten(f)
	f:HookScript("OnShow", flatten)
	placeTitle(f)
	if opts and opts.rail and rawget(f, "Rail") then topBar(f) end
	if name == SETTINGS and not rawget(f, "psTopBar") then groupBar(f) end
	if opts and opts.rail and rawget(f, "Sidebar") then
		local SH = W.SHELL
		local c = W.Button(f.Sidebar, L["Continue guide"], function() B.Continue(f) end, { primary = true, height = 36, icon = "guides" })
		c:SetPoint("BOTTOMLEFT", f.Sidebar, "BOTTOMLEFT", SH.side, 12)
		c:SetPoint("BOTTOMRIGHT", f.Sidebar, "BOTTOMRIGHT", -SH.side, 12)
		f.Continue = c
		-- The version and stage chip give it the room.
		if rawget(f, "Status") then f.Status:SetAlpha(0) end
		if rawget(f, "Stage") then f.Stage:SetAlpha(0) end
	end
	return f
end

-- Selection as Battle.net draws it: a rounded block inset in the row, no accent bar at the edge,
-- and a rounded hover.
local function roundHover(b)
	if not b.GetRegions then return end
	for _, r in ipairs({ b:GetRegions() }) do
		if r.GetDrawLayer and r:GetDrawLayer() == "HIGHLIGHT" and r.GetTexture and r:GetTexture() ~= Theme.Media(FILL) then
			slice(r, FILL, MARGIN)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -2)
			r:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 2)
		end
	end
end

local function block(b)
	if b.psBnet then return end
	b.psBnet = true
	slice(b.Selected, FILL, MARGIN)
	W.Painter(b.Selected, function(t)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -2)
		t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 2)
		t:SetVertexColor(Theme.Wash("selected"))
	end)
	if b.Bar then b.Bar:SetAlpha(0) end
	roundHover(b)
end

local nav = W.ShellNav
function W.ShellNav(f, items, active, onSelect, ...)
	if rawget(f, "psGroupBar") and type(items) == "table" then items = groupNav(f, items, active, onSelect) end
	local a, b2, c2 = nav(f, items, active, onSelect, ...)
	for _, b in ipairs(f.navButtons or {}) do block(b) end
	return a, b2, c2
end

local rail = W.ShellRail
function W.ShellRail(f, ...)
	if rawget(f, "psTopBar") then return topRail(f, ...) end
	local n = rail(f, ...)
	for _, b in ipairs(f.railButtons or {}) do
		block(b)
		if b.Icon then b.Icon:SetSize(22, 22) end
	end
	return n
end

-- Primary buttons drop the house's edge as well (their ground is the whole button).
local button = W.Button
function W.Button(parent, text, onClick, opts)
	local b = button(parent, text, onClick, opts)
	if opts and opts.primary and b.psSkin and b.psSkin.ring then b.psSkin.ring:Hide() end
	return b
end
