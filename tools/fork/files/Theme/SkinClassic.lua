-- AzerothRoute: the Classic skin, the game's own buttons and frames over AzerothRoute's layout (the top
-- bar, the tabs and the short header of Theme/Battlenet.lua stay). Windows are framed by the game's
-- gold dialog border, menus and toasts by its tooltip border, buttons are its red panel buttons with
-- gold text, titles are gold, grounds near black, corners square, and the font is the game's.
-- Registered through the Skin API (Theme/SkinApi.lua, Theme/SkinCheck.lua) like any skin, from the core.
-- The art is the client's own (Interface\DialogFrame, Interface\Tooltips, Interface\Buttons), read
-- from the game, not shipped. Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...
local Theme, L = ns.Theme, ns.L
if not (Theme and Theme.RegisterSkin and Theme.Battlenet and L) then return end

local ID = "classicwow"
Theme.Battlenet.SQUARE[ID] = true

local GOLD = { 1, 0.82, 0 }          -- the game's yellow text (GameFontNormal)
local EDGE = { 0.85, 0.75, 0.55 }    -- the tooltip border's tint on menus and toasts

local TOKENS = {
	bg = "#0d0b09", panel = "#17130f", panelAlt = "#231d16", sidebar = "#110e0b", footer = "#0f0d0a", sky = "#1c1610",
	text = "#f4ecd8", textDim = "#d7caa9", textMuted = "#b9ab8c",
	shade = "#000000", scrim = "#0d0b09", onAccent = "#1a1206",
	accent = "#ffd100",
	title = "#ffd100", buttonText = "#ffd100", tabRest = "#d7caa9", navRest = "#d7caa9",
	border = "#6e5f43", divider = "#4a3f2d", separator = "#4a3f2d", rowLine = "#3a3124",
	closeFill = "#8b1a10", closeEdge = "#c9a227", closeGlyph = "#ffd100",
}

-- A backdrop of the game's art around frame f, `out` px outside it, drawn over the frame's own children
-- (a top bar's ground would cover it otherwise). Kept in the skin's store, so another look hides it.
local function edge(f, kit, file, size, out, r, g, b, a)
	local own = kit.store(f)
	local e = own.edge
	if not e then
		e = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
		e:EnableMouse(false)
		own.edge = e
	end
	if own.edgeFile ~= file then
		own.edgeFile = file
		if e.SetBackdrop then e:SetBackdrop({ edgeFile = file, edgeSize = size }) end
	end
	e:ClearAllPoints()
	e:SetPoint("TOPLEFT", f, "TOPLEFT", -out, out)
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", out, -out)
	e:SetFrameLevel((f:GetFrameLevel() or 0) + 12)
	if e.SetBackdropBorderColor then e:SetBackdropBorderColor(r, g, b, a or 1) end
	e:Show()
	return e
end

local function noEdge(f, kit)
	local own = kit.store(f)
	if own.edge then own.edge:Hide() end
end

local DIALOG = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
local TOOLTIP = "Interface\\Tooltips\\UI-Tooltip-Border"

-- A frame with the tooltip's border: menus and popups, toasts and cards.
local function tooltipLook(frame, kit)
	kit.hideBorder(frame)
	edge(frame, kit, TOOLTIP, 16, 3, EDGE[1], EDGE[2], EDGE[3], 1)
end

local PAINT = {
	-- Windows: the gold dialog border just outside the frame (the player's window border setting
	-- turns it off); a heads-up card docked on the guide window and toasts get the tooltip's.
	window = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		local card = frame.psGuide and not frame.psGuideWindow
		if frame.psLight or card then return tooltipLook(frame, kit) end
		if Theme.WindowBorder() and not frame.psNoBorder then
			kit.hideBorder(frame)
			edge(frame, kit, DIALOG, 24, 5, 1, 1, 1, 1)
		else
			noEdge(frame, kit)
		end
	end,
	panel = function(frame, base, kit)
		base(frame)
		if frame.psBare then return kit.bare(frame) end
		if frame.psMenu then tooltipLook(frame, kit) else noEdge(frame, kit) end
	end,
	-- Buttons: the game's red panel button, gold text; the house ground and edge give way to it.
	button = function(frame, base, kit)
		base(frame)
		if frame.psBare or frame.psGhost then return end
		Theme.Paint.redButton(frame)
		-- Hidden, not cleared: a primary button colours its ground after painting (Theme/Widgets.lua).
		kit.fill(frame):Hide()
		kit.hoverWash(frame):SetVertexColor(1, 1, 1, 0)
		kit.hideBorder(frame)
	end,
}

-- Primary buttons are red panel buttons too, so their words stay the game's gold, not onAccent.
local primaryText = Theme.PrimaryText
function Theme.PrimaryText()
	if Theme.SkinId() == ID then return GOLD[1], GOLD[2], GOLD[3], 1 end
	if primaryText then return primaryText() end
	return Theme.Color("onAccent")
end

local PRESET = {
	["ui.style"] = "standard",
	["ui.bgOpacity"] = 0.95,
	["ui.border"] = true,
	["ui.shadow"] = true,
	["nav.arrowColor"] = { 1, 0.82, 0 },
}

-- Registered at login: the settings a preset names (UI/UI.lua) are not defined while Theme/ loads.
local function register()
	local ok, why = Theme.RegisterSkin(ID, {
		api = 2,
		name = L["Classic"],
		addon = ADDON,
		author = "AzerothRoute",
		desc = L["The game's own red buttons, gold-trimmed dialog frames and gold titles on dark grounds."],
		base = "polestar",
		tokens = TOKENS,
		font = "game",
		textShadow = { 1, -1, 1 },
		paint = PAINT,
		preset = PRESET,
	})
	Theme.ClassicSkin = { id = ID, ok = ok, why = why }
end
if ns.OnLogin then ns.OnLogin(register) else register() end
