-- AzerothRoute: "Import a guide" window (Polestar-style dialog).
-- A title field, a multi-line editor for the guide text, the format in one line of help, and
-- Import / Cancel. Errors are shown in place; a successful import opens the guide in the Guide
-- Center so it can be loaded like any other.

local AR = _G.AzerothRoute
local ImportWindow = { WIDTH = 540, HEIGHT = 440, frame = nil }
AR.ImportWindow = ImportWindow

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function ImportWindow:Reset()
    if self.frame then self.frame:Hide() end
    self.frame = nil
end

local function button(parent, name, width, primary)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(width, 30)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    if primary then S:Paint(b.bg, "accent", 1) else S:Paint(b.bg, "panelRaised", 1); S:AddBorder(b, "border") end
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    if b.label.SetTextColor then
        if primary then b.label:SetTextColor(0.10, 0.09, 0.07, 1) else b.label:SetTextColor(S:RGBA("text")) end
    end
    return b
end

local function editBox(parent, name, multi)
    local S = AR.Skins
    local e = _G.CreateFrame("EditBox", name, parent)
    if e.SetAutoFocus then e:SetAutoFocus(false) end
    if e.SetFontObject then e:SetFontObject("GameFontHighlightSmall") end
    if e.SetTextInsets then e:SetTextInsets(8, 8, 4, 4) end
    if multi and e.SetMultiLine then e:SetMultiLine(true) end
    if e.SetMaxLetters then e:SetMaxLetters(0) end
    e:SetScript("OnEscapePressed", function(box) if box.ClearFocus then box:ClearFocus() end end)
    if not multi and e.CreateTexture then
        e.bg = e:CreateTexture(nil, "BACKGROUND")
        e.bg:SetAllPoints(e)
        S:Paint(e.bg, "panel", 1)
        S:AddBorder(e, "border")
    end
    return e
end

function ImportWindow:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local W, H = self.WIDTH, self.HEIGHT
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteImportWindow")
    f:SetSize(W, H)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 20)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame) if frame.StartMoving then frame:StartMoving() end end)
    f:SetScript("OnDragStop", function(frame) if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end end)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    S:Paint(f.bg, "panel", 0.98)
    f.band = f:CreateTexture(nil, "BACKGROUND")
    f.band:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.band:SetSize(W - 2, 48)
    S:Paint(f.band, "panelRaised", 1)
    S:AddBorder(f, "border")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    if f.title.SetTextColor then f.title:SetTextColor(S:RGBA("text")) end
    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.help:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
    if f.help.SetWidth then f.help:SetWidth(W - 40) end
    f.help:SetJustifyH("LEFT")
    if f.help.SetTextColor then f.help:SetTextColor(S:RGBA("textMuted")) end

    f.titleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.titleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -98)
    if f.titleLabel.SetTextColor then f.titleLabel:SetTextColor(S:RGBA("textMuted")) end
    self.titleBox = editBox(f, "AzerothRouteImportTitle", false)
    self.titleBox:SetSize(W - 140, 22)
    self.titleBox:SetPoint("TOPLEFT", f, "TOPLEFT", 110, -94)

    -- Multi-line editor inside a scroll frame, on a bordered panel.
    f.editBg = f:CreateTexture(nil, "BACKGROUND")
    f.editBg:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -126)
    f.editBg:SetSize(W - 40, H - 216)
    S:Paint(f.editBg, "panelRaised", 1)
    local scroll = _G.CreateFrame("ScrollFrame", "AzerothRouteImportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -130)
    scroll:SetSize(W - 70, H - 224)
    self.bodyBox = editBox(scroll, "AzerothRouteImportBody", true)
    self.bodyBox:SetSize(W - 70, H - 224)
    if scroll.SetScrollChild then scroll:SetScrollChild(self.bodyBox) end
    self.scroll = scroll

    self.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 58)
    if self.status.SetWidth then self.status:SetWidth(W - 40) end
    self.status:SetJustifyH("LEFT")

    self.importButton = button(f, "AzerothRouteImportDo", 160, true)
    self.importButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
    self.importButton:SetScript("OnClick", function()
        self:Submit(self.bodyBox.GetText and self.bodyBox:GetText() or "", self.titleBox.GetText and self.titleBox:GetText() or "")
    end)
    self.cancelButton = button(f, "AzerothRouteImportCancel", 110, false)
    self.cancelButton:SetPoint("RIGHT", self.importButton, "LEFT", -8, 0)
    self.cancelButton:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    self.frame = f
    return f
end

function ImportWindow:SetStatus(text, isError)
    if not self.status then return end
    self.status:SetText(text or "")
    if self.status.SetTextColor then
        if isError then self.status:SetTextColor(0.94, 0.45, 0.42, 1) else self.status:SetTextColor(AR.Skins:RGBA("check")) end
    end
end

-- Imports `text`; on success opens the guide in the Guide Center. Returns the guide or nil.
function ImportWindow:Submit(text, title)
    local guide, err = AR.GuideImport:Import(text, title)
    if not guide then
        self:SetStatus(L(err, err), true)
        return nil
    end
    self:SetStatus(string.format(L("UI_IMPORT_DONE_FMT", "Imported \"%s\" with %d steps."), guide.displayTitleEN, #guide.steps), false)
    if self.frame then self.frame:Hide() end
    if AR.GuideMenu then
        AR.GuideMenu:Show("guides")
        AR.GuideMenu:SetSearch(guide.displayTitleEN)
        AR.GuideMenu:SelectGuide(guide)
    end
    return guide
end

function ImportWindow:Show()
    local f = self:InitializeFrame()
    f.title:SetText(L("UI_IMPORT_TITLE", "Import a guide"))
    f.help:SetText(L("UI_IMPORT_HELP"))
    f.titleLabel:SetText(L("UI_IMPORT_NAME", "Guide name"))
    self.importButton.label:SetText(L("UI_IMPORT_DO", "Import"))
    self.cancelButton.label:SetText(L("UI_IMPORT_CANCEL", "Cancel"))
    self:SetStatus("", false)
    f:Show()
    return f
end

return ImportWindow
