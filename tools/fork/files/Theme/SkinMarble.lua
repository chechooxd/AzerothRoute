-- AzerothRoute: the Marble skin, white marble and gold over AzerothRoute's layout (the top bar, the tabs
-- and the short header of Theme/Battlenet.lua stay). Grounds are a warm white marble with beige veins
-- and gold threads (Media/UI/marble, drawn by tools/fork/make_skin_art.lua), tinted by the palette so
-- the player's ground colour and opacity still apply; windows have a gold rule with a fine gold line
-- inside it, buttons and fields a gold edge, the accent is an antique gold, text a dark ink, corners
-- square, the font the game's. Registered through the Skin API (Theme/SkinApi.lua, Theme/SkinCheck.lua)
-- from the core. Original AzerothRoute code and art (GPL-3.0-only).

local ADDON, ns = ...
local Theme, L = ns.Theme, ns.L
if not (Theme and Theme.RegisterSkin and Theme.Battlenet and L) then return end

local ID = "marble"
Theme.Battlenet.SQUARE[ID] = true

local MARBLE = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\marble"
-- The marble's mean brightness (tools/fork/make_skin_art.lua prints it): the colours are lifted by it,
-- so the stone averages the palette's ground, the colour the legibility checks read against.
local GRAIN = 0.917
local TILE = 512
local GOLD = { 0.72, 0.55, 0.24 }

local INK = "#2a241d"
local TOKENS = {
	bg = "#ece7de", panel = "#f3efe8", panelAlt = "#e0d9cc", sidebar = "#e5dfd4", footer = "#e7e1d7", sky = "#ddd3c2",
	text = "#211c16", textDim = "#3b332a", textMuted = "#4b4237",
	ink = INK, star = "#ffffff00", shade = "#5c5040", scrim = "#f8f5ef", onAccent = "#fbf8f1", shadow = "#2a1f1459",
	-- Antique gold: what you can act on and where you are.
	accent = "#7a5a1c",
	border = "#9a7b3fcc", divider = "#8a734a73", separator = "#8a734a73", rowLine = "#8a734a59",
	hover = INK .. "12", selected = INK .. "22", progress = INK .. "1f", track = INK .. "2e", toggle = INK .. "38",
	box = INK .. "66", thumb = INK .. "4d", swatch = INK .. "4d", chip = INK .. "14", watermark = INK .. "0d", mover = INK .. "14",
	-- The subjects as dark inks that read on the stone.
	success = "#1f5a2e", warning = "#5f3b00", danger = "#962222", quest = "#654200", npc = "#1c477c", item = "#553484",
	place = "#7e3c12", object = "#524026", level = "#1e1a16", skill = "#2f5a12", spell = "#105a64", faction = "#7e2c58",
	area = "#6c3f1a", achievement = "#804208", dungeon = "#45338c", experimental = "#6b2a88", rare = "#8f3414",
	title = "#3a2a10", icon = "#3b332a", iconHover = "#211c16", buttonText = "#211c16", tabRest = "#4b4237", navRest = "#3b332a",
	closeFill = "#7a5a1c", closeEdge = "#9a7b3f", closeGlyph = "#fbf8f1",
}

-- The marble over a frame's ground, tiled at its own size: the house fill goes clear and the stone
-- carries the colour.
local function stone(frame, kit, r, g, b, a)
	local own = kit.store(frame)
	local t = own.stone
	if not t then
		t = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		t:SetTexture(MARBLE, "REPEAT", "REPEAT")
		if t.SetHorizTile then t:SetHorizTile(true); t:SetVertTile(true) end
		t:SetAllPoints(frame)
		own.stone = t
		if frame.HookScript then
			frame:HookScript("OnSizeChanged", function(f, w, h)
				if own.stone and w and h then own.stone:SetTexCoord(0, w / TILE, 0, h / TILE) end
			end)
		end
	end
	local w, h = frame:GetWidth() or TILE, frame:GetHeight() or TILE
	if (w or 0) > 0 and (h or 0) > 0 then t:SetTexCoord(0, w / TILE, 0, h / TILE) end
	kit.fill(frame):SetVertexColor(r, g, b, 0)
	t:SetVertexColor(math.min(1, r / GRAIN), math.min(1, g / GRAIN), math.min(1, b / GRAIN), a or 1)
	t:Show()
end

-- A 1px gold line `inset` px inside the frame's edge.
local EDGES = {
	{ "TOPLEFT", "TOPRIGHT", 1, -1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 1, 1 },
	{ "TOPLEFT", "BOTTOMLEFT", 1, -1 }, { "TOPRIGHT", "BOTTOMRIGHT", -1, -1 },
}
local function rule(frame, kit, inset, a)
	local own = kit.store(frame)
	if not own.rule then
		own.rule = {}
		for i, e in ipairs(EDGES) do
			local t = frame:CreateTexture(nil, "BORDER", nil, 2)
			t:SetTexture(Theme.Media("white"))
			local dx, dy = e[3] * inset, e[4] * inset
			t:SetPoint(e[1], frame, e[1], dx, dy)
			t:SetPoint(e[2], frame, e[2], (i <= 2 and -dx or dx), (i <= 2 and dy or -dy))
			if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
			own.rule[i] = t
		end
	end
	for i = 1, 4 do
		own.rule[i]:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], a)
		own.rule[i]:Show()
	end
end
local function noRule(frame, kit)
	local own = kit.store(frame)
	if own.rule then for i = 1, 4 do own.rule[i]:Hide() end end
end

local function goldEdge(frame, kit, a, size)
	kit.border(frame, GOLD[1], GOLD[2], GOLD[3], a or 1, nil, size)
end

-- A window's ground colour: its own (frame.psBgColor) or the palette's.
local function ground(frame, token)
	local c = frame.psBgColor
	if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2], c[3] end
	return Theme.Color(token)
end

local PAINT = {
	-- Windows: the stone, a 2px gold rule and a fine gold line inside it (the player's window border
	-- setting turns them off); a heads-up card docked on the guide window keeps the outer rule alone.
	window = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		local r, g, b = ground(frame, "bg")
		stone(frame, kit, r, g, b, frame.psBgAlpha or Theme.GroundAlpha())
		local card = frame.psGuide and not frame.psGuideWindow
		if Theme.WindowBorder() and not frame.psNoBorder then
			goldEdge(frame, kit, 1, 2)
			if card or frame.psLight then noRule(frame, kit) else rule(frame, kit, 5, 0.7) end
		else
			noRule(frame, kit)
		end
	end,
	-- Menus and popups: a lighter stone under a gold edge.
	panel = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		local r, g, b, a = Theme.Color(frame.psMenu and "menuBg" or "panel")
		stone(frame, kit, r, g, b, a)
		if frame.psMenu then goldEdge(frame, kit, 0.9) end
	end,
	sidebar = function(frame, base, kit)
		base(frame)
		local r, g, b, a = Theme.Color("sidebar")
		stone(frame, kit, r, g, b, a)
	end,
	-- Wells: the stone a shade darker, no edge.
	inset = function(frame, base, kit)
		base(frame)
		local r, g, b = Theme.Color("shade")
		kit.fill(frame):SetVertexColor(r, g, b, 0.08)
	end,
	-- Buttons and lists of choices: a gold edge (a primary button is gold through and through).
	button = function(frame, base, kit)
		base(frame)
		if frame.psBare or frame.psGhost or frame.psPrimary then return end
		goldEdge(frame, kit, 0.85)
	end,
	dropdown = function(frame, base, kit)
		base(frame)
		goldEdge(frame, kit, 0.85)
	end,
	-- Fields: a lighter sheet under a gold edge (the accent while the field has the cursor).
	editbox = function(frame, base, kit)
		base(frame)
		kit.fill(frame):SetVertexColor(Theme.Color("scrim"))
		if not frame.psFocused then goldEdge(frame, kit, 0.8) end
	end,
	-- Check boxes ruled in ink on the stone, their inside clear (the tick is the accent).
	checkbox = function(frame, base, kit)
		base(frame)
		local box = frame.psSkin and frame.psSkin.box
		if not box or frame.psOnWorld then return end
		kit.fill(box):SetVertexColor(0, 0, 0, 0)
		local r, g, b = Theme.Color("ink")
		kit.border(box, r, g, b, 0.85)
	end,
}

-- The layout that reads as stone, offered on the Theme page, never applied behind the player's back.
local PRESET = {
	["ui.style"] = "standard",
	["ui.bgOpacity"] = 1,
	["ui.band"] = true, ["ui.border"] = true, ["ui.borderSize"] = 1, ["ui.shadow"] = true,
	["guideWindow.rules"] = true,
	["ui.backing"] = "soft", ["guideWindow.outline"] = "shadow",
	["nav.arrowBacking"] = true, ["nav.arrowBackingAlpha"] = 0.55,
	["nav.arrowColor"] = { 0.86, 0.68, 0.3 },
}

-- Registered at login: the settings a preset names (UI/UI.lua) are not defined while Theme/ loads.
local function register()
	local ok, why = Theme.RegisterSkin(ID, {
		api = 2,
		name = L["Marble"],
		addon = ADDON,
		author = "AzerothRoute",
		desc = L["White marble with beige veins and gold threads, gold trim and dark ink."],
		base = "polestar",
		tokens = TOKENS,
		font = "game",
		textShadow = false,
		arrow = "halo",
		paint = PAINT,
		preset = PRESET,
	})
	Theme.MarbleSkin = { id = ID, ok = ok, why = why }
end
if ns.OnLogin then ns.OnLogin(register) else register() end
