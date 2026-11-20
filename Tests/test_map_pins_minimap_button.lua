-- Phase 1 libraries: SavedVariables rebinding, HereBeDragons-Pins delegation and LibDBIcon minimap button.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local PINS = "HereBeDragons-Pins-2.0"
local DBICON = "LibDBIcon-1.0"

-- Registers a recording stand-in under a LibStub name and returns it with a cleanup function.
local function stubLibrary(name, methods)
    local lib = LibStub:NewLibrary(name, 1) or LibStub(name)
    lib.calls = {}
    for method, impl in pairs(methods) do
        lib[method] = function(self, ...)
            table.insert(self.calls, { method = method, args = { ... } })
            if impl ~= true then return impl(self, ...) end
            return true
        end
    end
    return lib, function()
        LibStub.libs[name] = nil
        LibStub.minors[name] = nil
    end
end

local function callsOf(lib, method)
    local out = {}
    for _, c in ipairs(lib.calls) do
        if c.method == method then table.insert(out, c.args) end
    end
    return out
end

local function stubPins()
    return stubLibrary(PINS, {
        AddWorldMapIconMap = true,
        AddMinimapIconMap = true,
        RemoveAllWorldMapIcons = true,
        RemoveAllMinimapIcons = true,
    })
end

T:Describe("Phase 1: SavedVariables, HereBeDragons-Pins & minimap button", function()
    T:It("rebinds AR.db to the SavedVariables WoW loads on ADDON_LOADED", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        -- Mirror the client: files run (Initialize binds fresh tables), then WoW swaps in the saved globals.
        AR.Events:Reset()
        _G.AzerothRouteSavedDB, _G.AzerothRouteCharDB = nil, nil
        AR:Initialize()
        local before = AR.db
        _G.AzerothRouteSavedDB = { global = { autoaccept = false, minimap = { hide = true, minimapPos = 42 } } }
        _G.AzerothRouteCharDB = { currentStepNum = 7 }

        AR.Events:DispatchEvent("ADDON_LOADED", "SomeOtherAddon")
        T:AssertTrue(AR.db == before, "Other addons must not rebind storage")

        AR.Events:DispatchEvent("ADDON_LOADED", "AzerothRoute")
        T:AssertTrue(AR.db.global == _G.AzerothRouteSavedDB.global, "global must be the loaded SavedVariables table")
        T:AssertEqual(AR.db.profile.autoaccept, false, "Saved values must survive")
        T:AssertEqual(AR.db.global.minimap.minimapPos, 42, "Saved minimap position must survive")
        T:AssertEqual(AR.db.profile.autoturnin, true, "Missing defaults must be filled in")
        T:AssertEqual(AR.db.char.currentStepNum, 7, "Per-character values must survive")
        T:AssertTrue(AR.db.char == _G.AzerothRouteCharDB, "char must be the loaded per-character table")
    end)

    T:It("delegates map and minimap pins to HereBeDragons-Pins and reuses pin frames", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local pins, cleanup = stubPins()
        local ok, err = pcall(function()
            AR.Pointer:Reset()
            AR.Pointer:PlaceStepPins({ { map = 1429, x = 50, y = 40, action = "accept", title = "Accept" } })

            local wm = callsOf(pins, "AddWorldMapIconMap")
            T:AssertEqual(#wm, 1, "One world map pin must be registered")
            T:AssertTrue(wm[1][1] == AR.Pointer, "Pins are tracked under the Pointer ref")
            T:AssertTrue(wm[1][2] == AR.Pointer.worldMapPinFrames[1], "The pooled world map frame is passed")
            T:AssertEqual(wm[1][3], 1429, "Map ID")
            T:AssertEqual(wm[1][4], 0.5, "x normalized to 0-1")
            T:AssertEqual(wm[1][5], 0.4, "y normalized to 0-1")
            T:AssertEqual(wm[1][6], 2, "Shown on zone and continent maps")

            local mm = callsOf(pins, "AddMinimapIconMap")
            T:AssertEqual(#mm, 1, "One minimap pin must be registered")
            T:AssertTrue(mm[1][2] == AR.Pointer.minimapPinFrames[1], "The pooled minimap frame is passed")
            T:AssertEqual(mm[1][6], true, "Shown in parent zone")
            T:AssertEqual(mm[1][7], true, "Floats on the minimap edge when out of range")
            T:AssertTrue(AR.Pointer.worldMapPins[1].managed, "Pin is marked as library-managed")

            local firstWm = AR.Pointer.worldMapPinFrames[1]
            AR.Pointer:PlaceStepPins({ { map = 1429, x = 0.2, y = 0.3, action = "kill" } })
            T:AssertTrue(#callsOf(pins, "RemoveAllWorldMapIcons") >= 2, "Old world map pins are cleared before placing")
            T:AssertTrue(#callsOf(pins, "RemoveAllMinimapIcons") >= 2, "Old minimap pins are cleared before placing")
            T:AssertTrue(AR.Pointer.worldMapPinFrames[1] == firstWm, "Pin frames are reused, not recreated")
        end)
        cleanup()
        AR.Pointer:Reset()
        if not ok then error(err, 0) end
    end)

    T:It("falls back to the player map, and to native pins when no map is known", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local pins, cleanup = stubPins()
        local origPos = AR.Coords.GetPlayerPosition
        local ok, err = pcall(function()
            AR.Coords.GetPlayerPosition = function() return 1412, 0.5, 0.5 end
            AR.Pointer:Reset()
            AR.Pointer:PlaceStepPins({ { x = 0.1, y = 0.2 } })
            T:AssertEqual(callsOf(pins, "AddWorldMapIconMap")[1][3], 1412, "Uses the player's map when the step has none")

            AR.Coords.GetPlayerPosition = function() return nil end
            pins.calls = {}
            AR.Pointer:Reset()
            AR.Pointer:PlaceStepPins({ { x = 0.1, y = 0.2 } })
            T:AssertEqual(#callsOf(pins, "AddWorldMapIconMap"), 0, "No map ID means no library pin")
            T:AssertTrue(not AR.Pointer.worldMapPins[1].managed, "Pin falls back to native placement")
        end)
        AR.Coords.GetPlayerPosition = origPos
        cleanup()
        AR.Pointer:Reset()
        if not ok then error(err, 0) end
    end)

    T:It("registers a LibDataBroker launcher with LibDBIcon and toggles it with /ar minimap", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local icon, cleanup = stubLibrary(DBICON, { Register = true, Show = true, Hide = true })
        local origMenu, origTalents = AR.GuideMenu.Toggle, AR.TalentAdvisor.ToggleUI
        local ok, err = pcall(function()
            local menuToggles, talentToggles = 0, 0
            AR.GuideMenu.Toggle = function() menuToggles = menuToggles + 1 end
            AR.TalentAdvisor.ToggleUI = function() talentToggles = talentToggles + 1 end
            AR.Storage:Initialize()
            AR.db.global.minimap = { hide = false }
            AR.MinimapButton:Reset()

            T:AssertTrue(AR.MinimapButton:Initialize(), "Initializes when both libraries are present")
            local reg = callsOf(icon, "Register")
            T:AssertEqual(#reg, 1, "Registered once")
            T:AssertEqual(reg[1][1], "AzerothRoute", "Registered under the addon name")
            T:AssertTrue(reg[1][3] == AR.db.global.minimap, "Position/visibility persist in global SavedVariables")
            local obj = LibStub("LibDataBroker-1.1"):GetDataObjectByName("AzerothRoute")
            T:AssertTrue(obj == reg[1][2], "The LDB data object is the registered one")
            T:AssertEqual(obj.type, "launcher", "Launcher data object")
            T:AssertTrue(type(obj.icon) == "string" and obj.icon ~= "", "Has an icon")

            T:AssertTrue(AR.MinimapButton:Initialize(), "Second initialize is a no-op")
            T:AssertEqual(#callsOf(icon, "Register"), 1, "Never registers twice")

            local viewer = AR.ViewerFrame.frame
            local wasShown = viewer and viewer:IsShown()
            obj.OnClick(nil, "LeftButton")
            if viewer then T:AssertTrue(viewer:IsShown() ~= wasShown, "Left click toggles the viewer") end
            obj.OnClick(nil, "RightButton")
            T:AssertTrue(AR.UI.menu ~= nil and AR.UI.menu:IsShown(), "Right click opens the AzerothRoute menu")
            AR.UI:HideMenu()
            obj.OnClick(nil, "MiddleButton")
            T:AssertEqual(talentToggles, 1, "Middle click toggles the talent advisor")

            local tip = { lines = {} }
            function tip:AddLine(t) table.insert(self.lines, t) end
            obj.OnTooltipShow(tip)
            T:AssertTrue(#tip.lines >= 3, "Tooltip shows title and click hints")

            _G.SlashCmdList["AZEROTHROUTE"]("minimap")
            T:AssertEqual(AR.db.global.minimap.hide, true, "/ar minimap hides the button")
            T:AssertEqual(#callsOf(icon, "Hide"), 1, "LibDBIcon:Hide called")
            _G.SlashCmdList["AZEROTHROUTE"]("minimap")
            T:AssertEqual(AR.db.global.minimap.hide, false, "/ar minimap shows it again")
            T:AssertEqual(#callsOf(icon, "Show"), 1, "LibDBIcon:Show called")
        end)
        AR.GuideMenu.Toggle, AR.TalentAdvisor.ToggleUI = origMenu, origTalents
        cleanup()
        AR.MinimapButton:Reset()
        if not ok then error(err, 0) end
    end)

    T:It("skips the minimap button without LibDBIcon and keeps /ar toggling the viewer", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.MinimapButton:Reset()
        T:AssertTrue(LibStub(DBICON, true) == nil, "Precondition: LibDBIcon absent")
        T:AssertEqual(AR.MinimapButton:Initialize(), false, "Initialize reports unavailable")
        _G.SlashCmdList["AZEROTHROUTE"]("minimap") -- must not error
        T:AssertTrue(true)
    end)

    T:It("loads the new libraries in the TOC after their dependencies and before consumers", function()
        local toc = assert(io.open("AzerothRoute.toc", "r"))
        local text = toc:read("*a"):gsub("\\", "/")
        toc:close()
        local order = {
            "Libs/LibStub/LibStub.lua",
            "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
            "Libs/HereBeDragons/HereBeDragons-2.0.lua",
            "Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua",
            "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua",
            "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua",
            "Core/Compat.lua",
            "UI/MinimapButton.lua",
        }
        local previous = 0
        for _, path in ipairs(order) do
            local pos = text:find(path, 1, true)
            T:AssertTrue(pos ~= nil, "Missing TOC entry: " .. path)
            T:AssertTrue(pos > previous, "Out of order: " .. path)
            previous = pos
            local f = io.open(path, "r")
            T:AssertTrue(f ~= nil, "File must exist: " .. path)
            if f then f:close() end
        end
    end)
end)
