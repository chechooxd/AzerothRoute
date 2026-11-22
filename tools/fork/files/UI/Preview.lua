-- AzerothRoute: Lookup's preview. Under a result's title, the thing itself as the game's collections show
-- it: a mount's model (C_MountJournal: the mount of the item or spell, its creature display), a piece of
-- gear tried on the player (a DressUpModel, undressed first, as the appearances collection), an NPC or a
-- rare as itself (SetCreature). Drag to turn it. Nothing for what has no model (a quest, a zone, a
-- guide). Original AzerothRoute code (GPL-3.0-only).
--
--   LookupPreview.Show(details, kind, id, y, width) -> height used (0: none)   placed at y under the pane's top
--   LookupPreview.Hide(details)
--   LookupPreview.Models { creature, dress }

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
if not (UI and Theme and W) then return end

local PV = {}
UI.LookupPreview = PV
PV.Models = {}

local HEIGHT, GAP, PAD = 200, 12, 24
local TURN = 0.012 -- radians a pixel of drag

local box

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

-- Drag to turn the model.
local function turnable(m)
	m.psFacing = 0
	m:EnableMouse(true)
	m:SetScript("OnMouseDown", function(self) self.psDragX = GetCursorPosition and GetCursorPosition() or nil end)
	m:SetScript("OnMouseUp", function(self) self.psDragX = nil end)
	m:SetScript("OnUpdate", function(self)
		if not self.psDragX or not GetCursorPosition then return end
		local x = GetCursorPosition()
		self.psFacing = (self.psFacing or 0) + (x - self.psDragX) * TURN
		self.psDragX = x
		if self.SetFacing then self:SetFacing(self.psFacing) end
	end)
end

local function build(parent)
	if box then
		if box:GetParent() ~= parent then box:SetParent(parent) end
		return box
	end
	box = CreateFrame("Frame", nil, parent)
	Theme.Skin(box, "panel")
	local creature = CreateFrame("PlayerModel", nil, box)
	creature:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	creature:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	turnable(creature)
	local dress = CreateFrame("DressUpModel", nil, box)
	dress:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	dress:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	turnable(dress)
	PV.Models.creature, PV.Models.dress = creature, dress
	box:Hide()
	return box
end

-- The creature display of the mount an item (or a spell) teaches, or nil.
local function mountDisplay(id)
	local MJ = C_MountJournal
	if not MJ then return nil end
	local mount = call(MJ.GetMountFromItem, id) or call(MJ.GetMountFromSpell, id)
	if not mount then return nil end
	local display = call(MJ.GetMountInfoExtraByID, mount)
	return display
end

local function equippable(id)
	if C_Item and C_Item.IsEquippableItem then return call(C_Item.IsEquippableItem, id) and true or false end
	if IsEquippableItem then return call(IsEquippableItem, id) and true or false end
	return false
end

function PV.Hide(details)
	if box then box:Hide() end
end

function PV.Show(details, kind, id, y, width)
	if not (details and id) then PV.Hide() return 0 end
	local b = build(details)
	local creature, dress = PV.Models.creature, PV.Models.dress
	local show
	if kind == "mount" then
		local display = mountDisplay(id)
		if display then
			creature:SetDisplayInfo(display)
			show = creature
		end
	elseif kind == "npc" or kind == "rare" then
		creature:SetCreature(id)
		show = creature
	elseif (kind == "item" or kind == "tabard") and equippable(id) then
		call(dress.SetUnit, dress, "player")
		call(dress.Undress, dress)
		dress:TryOn("item:" .. id)
		show = dress
	end
	if not show then
		PV.Hide()
		return 0
	end
	creature:SetShown(show == creature)
	dress:SetShown(show == dress)
	show.psFacing = 0
	call(show.SetFacing, show, 0)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", details, "TOPLEFT", PAD, -y)
	b:SetSize(width or 300, HEIGHT)
	b:Show()
	return HEIGHT + GAP
end
