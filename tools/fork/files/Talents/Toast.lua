-- AzerothRoute: the talent point card. After a level-up with a point waiting on the followed plan, a
-- small card at the top of the screen names the plan's next talent (its icon, "Next: Ignite 2/5",
-- the plan) with Apply (Talents/Apply.lua: spends the waiting points in the plan's order) and View
-- plan (the Talents section). It closes itself after a while unless the cursor is on it, on Close,
-- or once no point waits. Setting: talents.toast (on by default, Options > Questing > Talents).
-- Original AzerothRoute code (GPL-3.0-only).
--
--   T.Toast.Notify(c) -> true when the card shows (c: T.Refresh()'s state)
--   T.Toast.Show(c), T.Toast.Hide(), T.Toast.frame

local ADDON, ns = ...
local T = ns.Talents
local Theme, W = ns.Theme, ns.Widgets
local L = ns.L
if not (T and Theme and W) then return end

local TT = {}
T.Toast = TT

local WIDTH, HEIGHT, PAD, ICON = 360, 112, 16, 36
local SECONDS = 25

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Talent point"] = "Punto de talento"
	L["%d talent points"] = "%d puntos de talento"
	L["Next: %s (%s plan)"] = "Siguiente: %s (plan %s)"
	L["View plan"] = "Ver plan"
	L["Close"] = "Cerrar"
	L["Show a card with Apply when a point is waiting"] = "Mostrar una tarjeta con Aplicar cuando hay un punto libre"
	L["After a level-up, a card names the plan's next talent with Apply talents and View plan."] =
		"Al subir de nivel, una tarjeta muestra el siguiente talento del plan con Aplicar talentos y Ver plan."
end

ns.RegisterDefaults("talents", { toast = true })

local function spellIcon(spell)
	local TV = ns.UI and ns.UI.TalentsSection
	if TV and TV.SpellIcon then return TV.SpellIcon(spell) end
	return nil
end

local frame, hideAt

local function build()
	if frame then return frame end
	local f = CreateFrame("Frame", "AzerothRouteTalentCard", UIParent)
	frame = f
	TT.frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("TOP", UIParent, "TOP", 0, -140)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	Theme.Skin(f, "window")
	if W.Rim then W.Rim(f) end
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetSize(ICON, ICON)
	f.Icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
	f.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.Title = W.Text(f, "label", "accent")
	f.Title:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 12, 0)
	f.Text = W.Text(f, "body", "text")
	f.Text:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -4)
	f.Text:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
	f.Text:SetJustifyH("LEFT")
	f.Text:SetWordWrap(true)
	f.Apply = W.Button(f, L["Apply talents"], function() TT.Apply() end, { primary = true, height = 26, icon = "icon-learn" })
	f.Apply:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, PAD - 4)
	f.View = W.Button(f, L["View plan"], function() TT.Hide() T.Show() end, { height = 26 })
	f.View:SetPoint("RIGHT", f.Apply, "LEFT", -8, 0)
	f.Close = W.Button(f, L["Close"], function() TT.Hide() end, { ghost = true, height = 26 })
	f.Close:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD - 4)
	f:SetScript("OnUpdate", function(self)
		if hideAt and GetTime and GetTime() >= hideAt and not (self.IsMouseOver and self:IsMouseOver()) then TT.Hide() end
	end)
	f:Hide()
	return f
end

local function waiting(c)
	local s = c and (c.staged or c.state)
	if not (s and s.status == "behind" and (s.unspent or 0) > 0 and s.next) then return nil end
	return s
end

function TT.Show(c)
	local s = waiting(c)
	if not s then return false end
	local f = build()
	local n = c.data.nodes[s.next.node]
	f.Icon:SetTexture(spellIcon(n and n.spell))
	f.Title:SetText(s.unspent == 1 and L["Talent point"] or string.format(L["%d talent points"], s.unspent))
	f.Text:SetText(string.format(L["Next: %s (%s plan)"], T.PickText(c.data, s.next, c.valid), c.build.specName or ""))
	hideAt = GetTime and (GetTime() + SECONDS) or nil
	f:Show()
	return true
end

function TT.Hide()
	hideAt = nil
	if frame then frame:Hide() end
end

-- Shows the card when the setting is on and a point waits on the followed plan.
function TT.Notify(c)
	if not T.Get("toast") then return false end
	return TT.Show(c)
end

-- Apply, then show what is left (another point after a two-level jump) or close.
function TT.Apply()
	if T.Apply then T.Apply.Run() end
	local c = T.Current()
	if not TT.Show(c) then TT.Hide() end
end

-- Spent elsewhere (the talent frame, another Apply): the card goes once nothing waits.
ns.On("TALENTS_UPDATED", function()
	if frame and frame:IsShown() and not waiting((T.Current())) then TT.Hide() end
end)
