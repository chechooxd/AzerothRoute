-- AzerothRoute: key binding actions (Bindings.xml calls AzerothRoute.Bindings:Run(action)).
-- Labels appear under Key Bindings > AddOns > AzerothRoute and in Quick Keybind Mode.

local AR = _G.AzerothRoute
local Bindings = {}
AR.Bindings = Bindings

local ACTIONS = {
    toggle = function() AR:ToggleViewer() end,
    hideall = function() if AR.MinimapButton then AR.MinimapButton:ToggleHideAll() end end,
    next = function() if AR.ViewerFrame then AR.ViewerFrame:OnNextClick("LeftButton") end end,
    prev = function() if AR.ViewerFrame then AR.ViewerFrame:OnPrevClick("LeftButton") end end,
    steps = function() if AR.StepBrowser then AR.StepBrowser:Toggle() end end,
    guides = function() if AR.GuideMenu then AR.GuideMenu:Toggle() end end,
}

local NAMES = {
    TOGGLE = "BIND_TOGGLE",
    HIDEALL = "BIND_HIDEALL",
    NEXT = "BIND_NEXT",
    PREV = "BIND_PREV",
    STEPS = "BIND_STEPS",
    GUIDES = "BIND_GUIDES",
}

-- Runs a binding action; returns false for an unknown action.
function Bindings:Run(action)
    local fn = ACTIONS[action]
    if not fn then return false end
    fn()
    return true
end

-- Publishes the localized binding labels the Key Bindings UI reads from globals.
function Bindings:PublishLabels()
    _G.BINDING_CATEGORY_AZEROTHROUTE = "AzerothRoute"
    _G.BINDING_HEADER_AZEROTHROUTE = "AzerothRoute"
    for suffix, key in pairs(NAMES) do
        _G["BINDING_NAME_AZEROTHROUTE_" .. suffix] = (AR.L and AR.L:Get(key)) or key
    end
end

Bindings:PublishLabels()

return Bindings
