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

function MinimapButton:HandleClick(button)
    if button == "RightButton" then
        if AR.GuideMenu and AR.GuideMenu.Toggle then AR.GuideMenu:Toggle() end
    elseif button == "MiddleButton" then
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then AR.TalentAdvisor:ToggleUI() end
    else
        AR:ToggleViewer()
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
    self.dataObject.OnClick = function(_, button) self:HandleClick(button) end
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
