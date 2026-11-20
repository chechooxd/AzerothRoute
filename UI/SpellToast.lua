-- AzerothRoute: "new spells to train" card shown on level-up above the guide window.
-- Lists the spells the class trainer teaches at the new level (recorded by ClassSpells), their
-- total cost and whether the player can pay; buttons: go to the trainer, later, turn these off.

local AR = _G.AzerothRoute
local SpellToast = { WIDTH = 360, MAX_ICONS = 8, frame = nil }
AR.SpellToast = SpellToast

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function SpellToast:Reset()
    if self.frame then self.frame:Hide() end
    self.frame = nil
end

local function textButton(parent, name, width)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(width, 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0, 0, 0, 0)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    if b.label.SetTextColor then b.label:SetTextColor(S:RGBA("text")) end
    b:SetScript("OnEnter", function(btn) S:Paint(btn.bg, "hover", 1) end)
    b:SetScript("OnLeave", function(btn) btn.bg:SetColorTexture(0, 0, 0, 0) end)
    return b
end

function SpellToast:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteSpellToast")
    f:SetSize(self.WIDTH, 132)
    if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
    if f.EnableMouse then f:EnableMouse(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    S:Paint(f.bg, "panel", 0.97)
    S:AddBorder(f, "border")
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.bar:SetSize(3, 132)
    S:Paint(f.bar, "check")

    f.kicker = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.kicker:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
    if f.kicker.SetTextColor then f.kicker:SetTextColor(S:RGBA("check")) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -26)
    f.cost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.cost:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -48)
    if f.cost.SetWidth then f.cost:SetWidth(self.WIDTH - 28) end
    f.cost:SetJustifyH("LEFT")

    f.icons = {}
    for i = 1, self.MAX_ICONS do
        local ic = f:CreateTexture(nil, "ARTWORK")
        ic:SetSize(26, 26)
        ic:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 30, -66)
        ic:Hide()
        f.icons[i] = ic
    end

    f.close = textButton(f, "AzerothRouteSpellToastClose", 22)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    f.close.label:SetText("×")
    f.close:SetScript("OnClick", function() f:Hide() end)

    f.go = textButton(f, "AzerothRouteSpellToastGo", 120)
    f.go:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.go:SetScript("OnClick", function()
        self:GoToTrainer()
        f:Hide()
    end)
    f.later = textButton(f, "AzerothRouteSpellToastLater", 80)
    f.later:SetPoint("LEFT", f.go, "RIGHT", 6, 0)
    f.later:SetScript("OnClick", function() f:Hide() end)
    f.off = textButton(f, "AzerothRouteSpellToastOff", 120)
    f.off:SetPoint("LEFT", f.later, "RIGHT", 6, 0)
    f.off:SetScript("OnClick", function()
        if AR.db and AR.db.profile then AR.db.profile.spelltoasts = false end
        f:Hide()
    end)

    f:Hide()
    self.frame = f
    return f
end

-- Sits on top of the guide window when it is shown, else near the top of the screen.
function SpellToast:Anchor()
    local f = self.frame
    if f.ClearAllPoints then f:ClearAllPoints() end
    local viewer = AR.ViewerFrame and AR.ViewerFrame.frame
    if viewer and viewer.IsShown and viewer:IsShown() then
        f:SetPoint("BOTTOMLEFT", viewer, "TOPLEFT", 0, 6)
    else
        f:SetPoint("TOP", _G.UIParent, "TOP", 0, -140)
    end
end

-- Builds the card model for `level`: kicker, title, cost line, cost colour key, icons.
function SpellToast:Build(level)
    local CS = AR.ClassSpells
    local className = (_G.UnitClass and _G.UnitClass("player")) or ""
    local kicker = string.format(L("UI_SPELLS_KICKER_FMT", "Level %d · %s"), level, className):upper()
    if not CS or not CS:HasData() then
        return { kicker = kicker, title = L("UI_SPELLS_UNKNOWN"), cost = L("UI_SPELLS_VISIT"), costKey = "textMuted", spells = {} }
    end
    local spells = CS:ForLevel(level)
    if #spells == 0 then return nil end
    local total = CS:TotalCost(spells)
    local money = (_G.GetMoney and _G.GetMoney()) or 0
    local cost, key
    if money >= total then
        cost, key = string.format(L("UI_SPELLS_CAN_PAY_FMT", "Cost %s: you can pay for all of them."), CS:FormatMoney(total)), "check"
    else
        cost, key = string.format(L("UI_SPELLS_SHORT_FMT", "Cost %s: you are %s short."), CS:FormatMoney(total), CS:FormatMoney(total - money)), "warn"
    end
    return {
        kicker = kicker,
        title = string.format(L("UI_SPELLS_TITLE_FMT", "%d new spells to train"), #spells),
        cost = cost, costKey = key, spells = spells,
    }
end

function SpellToast:OnLevelUp(level)
    if not level then return nil end
    if AR.db and AR.db.profile and AR.db.profile.spelltoasts == false then return nil end
    local model = self:Build(level)
    if not model then return nil end
    return self:Show(model)
end

function SpellToast:Show(model)
    local S = AR.Skins
    local f = self:InitializeFrame()
    f.kicker:SetText(model.kicker)
    f.title:SetText(model.title)
    f.cost:SetText(model.cost)
    if f.cost.SetTextColor then f.cost:SetTextColor(S:RGBA(model.costKey or "text")) end
    for i, ic in ipairs(f.icons) do
        local s = model.spells[i]
        if s and s.icon then ic:SetTexture(s.icon); ic:Show() else ic:Hide() end
    end
    f.go.label:SetText(L("UI_SPELLS_GO", "Go to trainer"))
    f.later.label:SetText(L("UI_SPELLS_LATER", "Later"))
    f.off.label:SetText(L("UI_SPELLS_OFF", "Turn these off"))
    local hasTrainer = self:FindTrainer() ~= nil
    if hasTrainer then f.go:Show() else f.go:Hide() end
    self:Anchor()
    f:Show()
    self.model = model
    return model
end

function SpellToast:FindTrainer()
    if not AR.Trainers then return nil end
    local myClass
    if _G.UnitClass then myClass = select(2, _G.UnitClass("player")) end
    return AR.Trainers:FindNearest(function(t) return t.kind == "class" and t.class == myClass end)
end

-- Points the arrow at the nearest known trainer of the player's class.
function SpellToast:GoToTrainer()
    local rec = self:FindTrainer()
    if not rec or not AR.Pointer then return nil end
    AR.Pointer:SetManualTarget(rec.map, rec.x / 100, rec.y / 100, rec.name)
    return rec
end

return SpellToast
