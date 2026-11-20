-- AzerothRoute: "What's new" card, shown once per set of release notes (not per character).
-- The notes id below changes whenever the list changes; AR.db.global.whatsNewSeen remembers it.

local AR = _G.AzerothRoute
local WhatsNew = {
    NOTES_ID = "2026-11-polestar-round",
    NOTES = {
        "WN_1", "WN_2", "WN_3", "WN_4", "WN_5", "WN_6", "WN_7",
    },
    WIDTH = 420,
    frame = nil,
}
AR.WhatsNew = WhatsNew

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function WhatsNew:Reset()
    if self.frame then self.frame:Hide() end
    self.frame = nil
end

function WhatsNew:IsSeen()
    return AR.db and AR.db.global and AR.db.global.whatsNewSeen == self.NOTES_ID
end

function WhatsNew:MarkSeen()
    if AR.db and AR.db.global then AR.db.global.whatsNewSeen = self.NOTES_ID end
end

function WhatsNew:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local W = self.WIDTH
    local H = 96 + #self.NOTES * 20
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteWhatsNew")
    f:SetSize(W, H)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 80)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.EnableMouse then f:EnableMouse(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    S:Paint(f.bg, "panel", 0.98)
    S:AddBorder(f, "border")
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.bar:SetSize(3, H)
    S:Paint(f.bar, "accent")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -14)
    if f.title.SetTextColor then f.title:SetTextColor(S:RGBA("text")) end
    f.lines = {}
    for i = 1, #self.NOTES do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -44 - (i - 1) * 20)
        if fs.SetWidth then fs:SetWidth(W - 44) end
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetJustifyH("LEFT")
        f.lines[i] = fs
    end
    local ok = AR.UI:Create("Button", f, "AzerothRouteWhatsNewOk")
    ok:SetSize(120, 28)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    ok.bg = ok:CreateTexture(nil, "BACKGROUND")
    ok.bg:SetAllPoints(ok)
    S:Paint(ok.bg, "accent", 1)
    ok.label = ok:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ok.label:SetPoint("CENTER", ok, "CENTER", 0, 0)
    if ok.label.SetTextColor then ok.label:SetTextColor(0.10, 0.09, 0.07, 1) end
    ok:SetScript("OnClick", function()
        self:MarkSeen()
        f:Hide()
    end)
    self.okButton = ok
    f:Hide()
    self.frame = f
    return f
end

function WhatsNew:Show()
    local f = self:InitializeFrame()
    f.title:SetText(L("WN_TITLE", "What's new in AzerothRoute"))
    for i, key in ipairs(self.NOTES) do
        f.lines[i]:SetText("|cfff4c54a•|r " .. L(key, key))
    end
    self.okButton.label:SetText(L("WN_OK", "Got it"))
    f:Show()
    return f
end

-- At login: shows the card once for these notes.
function WhatsNew:ShowIfNew()
    if self:IsSeen() then return false end
    self:Show()
    return true
end

return WhatsNew
