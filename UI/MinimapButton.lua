-- AzerothRoute: Minimap launcher via LibDataBroker-1.1 + LibDBIcon-1.0 (Phase 1 libraries)
-- Position and visibility persist in AR.db.global.minimap, the table LibDBIcon expects.

local AR = _G.AzerothRoute
local MinimapButton = {
    NAME = "AzerothRoute",
    ICON = "Interface\\Icons\\INV_Misc_Map_01",
    initialized = false,
}
AR.MinimapButton = MinimapButton

local function getLibs()
    local LibStub = _G.LibStub
    if not LibStub then return nil, nil end
    return LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
end

local function text(key, fallback)
    return (AR.L and AR.L:Get(key)) or fallback
end

function MinimapButton:Reset()
    self.initialized = false
    self.dataObject = nil
end

function MinimapButton:GetSettings()
    AR.db.global.minimap = AR.db.global.minimap or { hide = false }
    return AR.db.global.minimap
end

local function profile()
    return (AR.db and AR.db.profile) or {}
end

-- True when the arrow must stay hidden (its own switch, or everything hidden without "keep arrow").
function MinimapButton:IsArrowSuppressed()
    local p = profile()
    if p.hidearrow then return true end
    return p.hideall == true and p.keeparrow == false
end

local function hideFrame(f) if f and f.Hide then f:Hide() end end

-- One click hides every AzerothRoute window (guide, arrow unless kept, browsers, menus);
-- the next click brings back the guide window and the arrow.
function MinimapButton:SetHideAll(hidden)
    local p = profile()
    p.hideall = hidden == true
    if p.hideall then
        hideFrame(AR.ViewerFrame and AR.ViewerFrame.frame)
        hideFrame(AR.StepBrowser and AR.StepBrowser.frame)
        hideFrame(AR.GuideMenu and AR.GuideMenu.frame)
        hideFrame(AR.QuestLogCleanup and AR.QuestLogCleanup.frame)
        if self:IsArrowSuppressed() then hideFrame(AR.Pointer and AR.Pointer.arrowFrame) end
    else
        local vf = AR.ViewerFrame
        if vf then
            if not vf.frame then vf:Initialize() end
            vf.frame:Show()
            vf:RefreshVisuals()
        end
        if AR.Pointer and AR.Pointer.UpdateArrow then AR.Pointer:UpdateArrow(0) end
    end
    return p.hideall
end

function MinimapButton:ToggleHideAll()
    return self:SetHideAll(not profile().hideall)
end

function MinimapButton:SetArrowHidden(hidden)
    profile().hidearrow = hidden == true
    if hidden then
        hideFrame(AR.Pointer and AR.Pointer.arrowFrame)
    elseif AR.Pointer and AR.Pointer.UpdateArrow then
        AR.Pointer:UpdateArrow(0)
    end
end

function MinimapButton:BuildMenuItems()
    local p = profile()
    local vf = AR.ViewerFrame and AR.ViewerFrame.frame
    return {
        { text = text("UI_MM_GUIDE_WINDOW", "Guide window"), checked = vf ~= nil and vf:IsShown(),
            onClick = function() AR:ToggleViewer() end },
        { text = text("UI_MM_HIDE_ARROW", "Hide arrow"), checked = p.hidearrow == true,
            onClick = function() self:SetArrowHidden(not p.hidearrow) end },
        { text = p.hideall and text("UI_MM_SHOW_ALL", "Show AzerothRoute") or text("UI_MM_HIDE_ALL", "Hide AzerothRoute"),
            onClick = function() self:ToggleHideAll() end },
        { text = text("UI_MM_KEEP_ARROW", "Keep the arrow when hidden"), checked = p.keeparrow ~= false,
            onClick = function() p.keeparrow = (p.keeparrow == false) end },
        { separator = true },
        { text = text("UI_GUIDES", "Guides"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("guides") end end },
        { text = text("UI_LOOKUP", "Lookup"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("lookup") end end },
        { text = text("UI_DUNGEONS", "Dungeons"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("dungeons") end end },
        { text = text("UI_TALENTS", "Talents"), onClick = function()
            if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then AR.TalentAdvisor:ToggleUI() end end },
        { text = text("UI_MENU_OPTIONS", "Options"), onClick = function() if AR.Config then AR.Config:Open() end end },
    }
end

function MinimapButton:ShowMenu(anchor)
    return AR.UI:ShowMenu(anchor, self:BuildMenuItems(), "TOPRIGHT", "BOTTOMLEFT", 0, 0)
end

-- Left: hide/show everything · Right: menu · Middle: talents · Shift: options.
function MinimapButton:HandleClick(button, anchor)
    if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
        if AR.Config then AR.Config:Open() end
    elseif button == "RightButton" then
        self:ShowMenu(anchor)
    elseif button == "MiddleButton" then
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then AR.TalentAdvisor:ToggleUI() end
    else
        self:ToggleHideAll()
    end
end

function MinimapButton:FillTooltip(tooltip)
    tooltip:AddLine("|cffffffffAzeroth|r|cfff4bf2aRoute|r")
    local progression = AR.Progression
    local guide = progression and progression.currentGuide
    if guide and guide.title then
        tooltip:AddLine(guide.title, 1, 1, 1)
        local step = progression.currentStep
        if step and step.num then
            tooltip:AddLine(string.format(text("UI_MINIMAP_STEP_FMT", "Step %d"), step.num), 0.8, 0.8, 0.8)
        end
    end
    tooltip:AddLine(text("UI_MINIMAP_LEFT", "Left-click: show/hide guide"), 0.2, 1, 0.2)
    tooltip:AddLine(text("UI_MINIMAP_RIGHT", "Right-click: guide menu"), 0.2, 1, 0.2)
    tooltip:AddLine(text("UI_MINIMAP_MIDDLE", "Middle-click: talent advisor"), 0.2, 1, 0.2)
    tooltip:AddLine(text("UI_MINIMAP_SHIFT", "Shift-click: options"), 0.2, 1, 0.2)
end

-- Returns true when the button is registered (now or earlier), false when a library is missing.
function MinimapButton:Initialize()
    if self.initialized then return true end
    local ldb, icon = getLibs()
    if not ldb or not icon or not AR.db then return false end

    self.dataObject = ldb:GetDataObjectByName(self.NAME) or ldb:NewDataObject(self.NAME, {
        type = "launcher",
        text = self.NAME,
        icon = self.ICON,
    })
    self.dataObject.OnClick = function(owner, button) self:HandleClick(button, owner) end
    self.dataObject.OnTooltipShow = function(tooltip) self:FillTooltip(tooltip) end

    icon:Register(self.NAME, self.dataObject, self:GetSettings())
    self.initialized = true
    return true
end

function MinimapButton:Toggle()
    local _, icon = getLibs()
    if not AR.db then return end
    local settings = self:GetSettings()
    settings.hide = not settings.hide
    if not icon or not self.initialized then return end
    if settings.hide then
        icon:Hide(self.NAME)
    else
        icon:Show(self.NAME)
    end
end

return MinimapButton
