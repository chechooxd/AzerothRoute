-- AzerothRoute: the Terminal skin, a cyberpunk code terminal over AzerothRoute's layout (the top bar, the
-- tabs and the short header of Theme/Battlenet.lua stay). Near-black grounds under CRT scanlines
-- (Media/UI/scanlines, drawn by tools/fork/make_skin_art.lua), phosphor green text, a neon cyan accent
-- and edges, a magenta line for selections, HUD brackets on the windows' corners, square corners.
-- Registered through the Skin API (Theme/SkinApi.lua, Theme/SkinCheck.lua) from the core.
-- Original AzerothRoute code and art (GPL-3.0-only).

local ADDON, ns = ...
local Theme, L = ns.Theme, ns.L
if not (Theme and Theme.RegisterSkin and Theme.Battlenet and L) then return end

local ID = "terminal"
Theme.Battlenet.SQUARE[ID] = true

local SCAN = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\scanlines"
local SCAN_TILE = 64
local CYAN = { 0, 0.9, 1 }
local MAGENTA = { 1, 0.17, 0.84 }

local TOKENS = {
	bg = "#05080a", panel = "#0a1014", panelAlt = "#0f1a1f", sidebar = "#070c0f", footer = "#060a0c", sky = "#0b1418",
	text = "#8dffae", textDim = "#62d68d", textMuted = "#4fb377",
	shade = "#000000", scrim = "#05080a", onAccent = "#00161a",
	accent = "#00e5ff",
	title = "#00e5ff", buttonText = "#8dffae", tabRest = "#62d68d", navRest = "#62d68d", icon = "#62d68d", iconHover = "#00e5ff",
	border = "#00e5ff99", divider = "#00e5ff38", separator = "#00e5ff38", rowLine = "#00e5ff24",
	hover = "#00e5ff1a", selected = "#ff2bd62e",
	closeFill = "#ff2bd6", closeEdge = "#ff2bd6", closeGlyph = "#05080a",
}

-- The scanlines over a frame, tiled at their own size.
local function scanlines(frame, kit, a)
	local own = kit.store(frame)
	local t = own.scan
	if not t then
		t = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
		t:SetTexture(SCAN, "REPEAT", "REPEAT")
		if t.SetHorizTile then t:SetHorizTile(true); t:SetVertTile(true) end
		t:SetAllPoints(frame)
		own.scan = t
		if frame.HookScript then
			frame:HookScript("OnSizeChanged", function(_, w, h)
				if own.scan and w and h then own.scan:SetTexCoord(0, w / SCAN_TILE, 0, h / SCAN_TILE) end
			end)
		end
	end
	local w, h = frame:GetWidth() or SCAN_TILE, frame:GetHeight() or SCAN_TILE
	if (w or 0) > 0 and (h or 0) > 0 then t:SetTexCoord(0, w / SCAN_TILE, 0, h / SCAN_TILE) end
	t:SetVertexColor(1, 1, 1, a or 1)
	t:Show()
end

-- HUD brackets: an L of two short neon lines on each corner, `out` px outside the frame.
local CORNERS = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }
local ARM, THICK = 14, 2
local function brackets(frame, kit, out)
	local own = kit.store(frame)
	if not own.brackets then
		own.brackets = {}
		for _, c in ipairs(CORNERS) do
			local point, sx, sy = c[1], c[2], c[3]
			for k = 1, 2 do
				local t = frame:CreateTexture(nil, "OVERLAY", nil, 6)
				t:SetTexture(Theme.Media("white"))
				t:SetPoint(point, frame, point, -sx * out, -sy * out)
				if k == 1 then t:SetSize(ARM, THICK) else t:SetSize(THICK, ARM) end
				own.brackets[#own.brackets + 1] = t
			end
		end
	end
	for _, t in ipairs(own.brackets) do
		t:SetVertexColor(CYAN[1], CYAN[2], CYAN[3], 1)
		t:Show()
	end
end
local function noBrackets(frame, kit)
	local own = kit.store(frame)
	if own.brackets then for _, t in ipairs(own.brackets) do t:Hide() end end
end

local function neon(frame, kit, c, a, size)
	kit.border(frame, c[1], c[2], c[3], a or 1, nil, size)
end

local PAINT = {
	-- Windows: scanlines, a neon cyan edge and the HUD brackets (the player's window border setting
	-- turns the edge and brackets off); a card docked on the guide window and toasts keep the edge alone.
	window = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		scanlines(frame, kit, 0.8)
		if Theme.WindowBorder() and not frame.psNoBorder then
			neon(frame, kit, CYAN, 0.75)
			local card = frame.psGuide and not frame.psGuideWindow
			if card or frame.psLight then noBrackets(frame, kit) else brackets(frame, kit, 3) end
		else
			noBrackets(frame, kit)
		end
	end,
	panel = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		if frame.psMenu then
			scanlines(frame, kit, 0.6)
			neon(frame, kit, CYAN, 0.8)
		end
	end,
	sidebar = function(frame, base, kit)
		base(frame)
		scanlines(frame, kit, 0.6)
	end,
	-- Buttons: a dark key under a neon edge (a primary button is cyan through and through).
	button = function(frame, base, kit)
		base(frame)
		if frame.psBare or frame.psGhost or frame.psPrimary then return end
		kit.fill(frame):SetVertexColor(0, 0.06, 0.07, 0.9)
		neon(frame, kit, CYAN, 0.7)
	end,
	dropdown = function(frame, base, kit)
		base(frame)
		neon(frame, kit, CYAN, 0.6)
	end,
	-- Fields: black, a magenta edge (the accent while the field has the cursor).
	editbox = function(frame, base, kit)
		base(frame)
		kit.fill(frame):SetVertexColor(0, 0, 0, 0.9)
		if not frame.psFocused then neon(frame, kit, MAGENTA, 0.7) end
	end,
	checkbox = function(frame, base, kit)
		base(frame)
		local box = frame.psSkin and frame.psSkin.box
		if not box or frame.psOnWorld then return end
		kit.fill(box):SetVertexColor(0, 0, 0, 0.9)
		kit.border(box, CYAN[1], CYAN[2], CYAN[3], 0.9)
	end,
}

local PRESET = {
	["ui.style"] = "standard",
	["ui.bgOpacity"] = 0.96,
	["ui.border"] = true,
	["nav.arrowColor"] = { 0, 0.9, 1 },
}

-- Registered at login: the settings a preset names (UI/UI.lua) are not defined while Theme/ loads.
local function register()
	local ok, why = Theme.RegisterSkin(ID, {
		api = 2,
		name = L["Terminal"],
		addon = ADDON,
		author = "AzerothRoute",
		desc = L["A neon code terminal: phosphor green text on black under scanlines, cyan edges and HUD corners."],
		base = "polestar",
		tokens = TOKENS,
		font = "fira",
		textShadow = false,
		arrow = "flat",
		paint = PAINT,
		preset = PRESET,
	})
	Theme.TerminalSkin = { id = ID, ok = ok, why = why }
end
if ns.OnLogin then ns.OnLogin(register) else register() end
