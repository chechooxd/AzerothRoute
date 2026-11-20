-- The one settings page: /ar options, the minimap button and the Blizzard AddOns entry open the
-- Guide Center's Options page; the AceConfig entry keeps the AceDBOptions profiles tab.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local APP = "AzerothRoute"

local function stubDialog()
    local name = "AceConfigDialog-3.0"
    local saved = LibStub.libs[name]
    local dialog = { opened = {}, blizz = {} }
    function dialog:Open(app) table.insert(self.opened, app) end
    function dialog:AddToBlizOptions(app, title)
        table.insert(self.blizz, { app = app, title = title })
        return {}, 77
    end
    LibStub.libs[name] = dialog
    return dialog, function() LibStub.libs[name] = saved end
end

local function options()
    return LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP, "dialog", "AzerothRouteTest-1.0")
end

local function opt(path)
    local node = options()
    for _, key in ipairs(path) do node = node.args[key] end
    return node
end

local function run(fn)
    MockWoW:Reset()
    local AR = _G.AzerothRoute
    local dialog, restore = stubDialog()
    local ok, err = pcall(function()
        AR.Storage:ResetProfiles()
        AR.Storage:Initialize()
        AR.Config:Reset()
        AR.GuideMenu:Reset()
        fn(AR, dialog)
    end)
    restore()
    AR.GuideMenu:Reset()
    if not ok then error(err, 0) end
end

T:Describe("Options: one settings page", function()
    T:It("opens the Guide Center's Options page from /ar options instead of a second window", function()
        run(function(AR, dialog)
            T:AssertEqual(AR.Config:Initialize(), true, "Registered in the Blizzard AddOns options")
            T:AssertEqual(#dialog.blizz, 1, "Added once")
            T:AssertEqual(AR.Config.categoryID, 77)
            T:AssertEqual(AR.Config:Initialize(), true)
            T:AssertEqual(#dialog.blizz, 1, "Never registered twice")

            _G.SlashCmdList["AZEROTHROUTE"]("config")
            _G.SlashCmdList["AZEROTHROUTE"]("opciones")
            T:AssertEqual(#dialog.opened, 0, "No AceConfig window")
            T:AssertEqual(AR.GuideMenu.mode, "options", "Guide Center in Options mode")
            T:AssertTrue(AR.GuideMenu.frame:IsShown() and AR.OptionsPanel.panel:IsShown(), "Options page shown")

            local open = opt({ "open" })
            T:AssertEqual(open.type, "execute", "The Blizzard entry is a button")
            AR.GuideMenu.frame:Hide()
            open.func()
            T:AssertTrue(AR.GuideMenu.frame:IsShown(), "Its button opens the same page")
        end)
    end)

    T:It("reads and writes every setting through the active profile", function()
        run(function(AR)
            local OP = AR.OptionsPanel
            for _, key in ipairs({ "autoaccept", "autoacceptall", "autoturnin", "autoselectreward", "corpsearrow",
                "autotaxi", "autogrey", "autorepair", "autobuy", "targetmacro", "automark", "loadguidesfully",
                "stepsound", "journey", "keeparrow", "questxp", "spelltoasts", "gamepad" }) do
                local s = OP:Find(key)
                T:AssertTrue(s ~= nil and s.kind == "bool", key .. " is a check box")
                local current = OP:Get(s)
                OP:Set(s, not current)
                T:AssertEqual(AR.db.profile[key], not current, key .. " written to the profile")
                OP:ResetSetting(s)
                T:AssertEqual(AR.db.profile[key], s.default, key .. " reset to default")
            end
            local style = OP:Find("style")
            T:AssertEqual(style.kind, "choice")
            local found = false
            for _, v in ipairs(OP:Values(style)) do if v == "starlight" then found = true end end
            T:AssertTrue(found, "Offers registered skin styles")
            OP:Set(style, "starlight")
            T:AssertEqual(AR.db.profile.style, "starlight")
            OP:ResetSetting(style)
        end)
    end)

    T:It("toggles the minimap button through the account setting", function()
        run(function(AR)
            AR.db.global.minimap = { hide = false }
            local s = AR.OptionsPanel:Find("minimap")
            T:AssertEqual(AR.OptionsPanel:Get(s), true, "Shown by default")
            AR.OptionsPanel:Set(s, false)
            T:AssertEqual(AR.db.global.minimap.hide, true, "Unchecking hides the button")
            AR.OptionsPanel:Set(s, true)
            T:AssertEqual(AR.db.global.minimap.hide, false)
        end)
    end)

    T:It("keeps an AceDBOptions profiles tab and switches profiles from the page", function()
        run(function(AR)
            AR.Config:Initialize()
            local profiles = opt({ "profiles" })
            T:AssertEqual(profiles.type, "group", "Profiles tab present")
            T:AssertTrue(profiles.handler and profiles.handler.db == AR.Storage.aceDB, "Bound to the AceDB object")

            local OP = AR.OptionsPanel
            local s = OP:Find("profile")
            local start = OP:Get(s)
            OP:Set(s, "Alt")
            T:AssertEqual(AR.Storage.aceDB:GetCurrentProfile(), "Alt", "Switched profile")
            local listed = false
            for _, v in ipairs(OP:Values(s)) do if v == start then listed = true end end
            T:AssertTrue(listed, "Earlier profile still listed")
            AR.db.profile.autobuy = false
            OP:Activate(OP:Find("resetprofile"))
            T:AssertEqual(AR.db.profile.autobuy, true, "Reset profile restores defaults")
            OP:Set(s, start)
        end)
    end)

    T:It("localizes the Blizzard entry to the client language", function()
        local origLocale = _G.GetLocale
        local ok, err = pcall(run, function(AR)
            AR.Config:Initialize()
            _G.GetLocale = function() return "esMX" end
            T:AssertEqual(opt({ "open" }).name, "Abrir opciones de AzerothRoute")
            _G.GetLocale = function() return "enUS" end
            T:AssertEqual(opt({ "open" }).name, "Open AzerothRoute options")
        end)
        _G.GetLocale = origLocale
        if not ok then error(err, 0) end
    end)

    T:It("still opens the Options page without AceConfig", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local saved = LibStub.libs["AceConfig-3.0"]
        LibStub.libs["AceConfig-3.0"] = nil
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.Config:Reset()
            AR.GuideMenu:Reset()
            T:AssertEqual(AR.Config:Initialize(), false)
            _G.SlashCmdList["AZEROTHROUTE"]("config")
            T:AssertEqual(AR.GuideMenu.mode, "options")
        end)
        LibStub.libs["AceConfig-3.0"] = saved
        AR.Config:Reset()
        AR.GuideMenu:Reset()
        if not ok then error(err, 0) end
    end)
end)
