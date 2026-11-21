-- AzerothRoute: the Battle.net look over the house style. Every house surface (window, panel, button,
-- dropdown, tile, edit box) is drawn with rounded corners: its ground and its hover wash take the
-- nine-slice Media/UI/round-8 art, and its square 1px border gives way to a rounded edge
-- (round-8-ring) in the same colour. Shell windows (the hub, the settings) get a flat header: the
-- night band, its haze and the gold rim are hidden. Primary buttons are Battle.net blue with white
-- labels (Theme.PrimaryFill, read by W.Button's painter). Original AzerothRoute code (GPL-3.0-only).
--
--   Theme.Battlenet.PRIMARY { r, g, b }      the primary button's blue
--   Theme.Battlenet.Round(frame[, radius])   rounds a painted frame's ground, hover and edge

local ADDON, ns = ...
local Theme, W = ns.Theme, ns.Widgets
if not (Theme and W and Theme.Paint and Theme.Paint.house) then return end

local B = {}
Theme.Battlenet = B

B.PRIMARY = { 0.118, 0.482, 1 }         -- #1E7BFF, the Battle.net app's play button
B.PRIMARY_TEXT = { 1, 1, 1 }
B.RADIUS = { window = 10, panel = 8, button = 6, dropdown = 6, tile = 8, editbox = 6, inset = 6 }
local FILL, RING = "round-8", "round-8-ring"
local MARGIN = 8 -- the art's corner, in texels

function Theme.PrimaryFill() return B.PRIMARY[1], B.PRIMARY[2], B.PRIMARY[3] end
function Theme.PrimaryText() return B.PRIMARY_TEXT[1], B.PRIMARY_TEXT[2], B.PRIMARY_TEXT[3] end

-- A texture drawn as nine slices of the rounded art, its corners `radius` px.
local function slice(tex, art, radius)
	tex:SetTexture(Theme.Media(art))
	if tex.SetTextureSliceMargins then
		tex:SetTextureSliceMargins(MARGIN, MARGIN, MARGIN, MARGIN)
		local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0
		if tex.SetTextureSliceMode then tex:SetTextureSliceMode(mode) end
	end
end

function B.Round(f, radius)
	local d = f.psSkin
	if not d then return end
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

-- Shell windows: a flat header (no night band, haze or gold rim).
local function flatten(f)
	if rawget(f, "Band") then f.Band:SetAlpha(0) end
	if rawget(f, "Haze") then f.Haze:SetAlpha(0) end
	local rim = rawget(f, "psRim") or rawget(f, "Rim")
	if rim then rim:SetAlpha(0) end
end
B.Flatten = flatten

local shell = W.Shell
function W.Shell(name, opts)
	local f = shell(name, opts)
	flatten(f)
	f:HookScript("OnShow", flatten)
	return f
end

-- Primary buttons drop the house's edge as well (their ground is the whole button).
local button = W.Button
function W.Button(parent, text, onClick, opts)
	local b = button(parent, text, onClick, opts)
	if opts and opts.primary and b.psSkin and b.psSkin.ring then b.psSkin.ring:Hide() end
	return b
end
