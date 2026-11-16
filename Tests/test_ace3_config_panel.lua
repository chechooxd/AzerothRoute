-- Phase 2: AceConfig options panel bound to the AceDB profile, with an AceDBOptions profiles tab.
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

local function info(path)
    local i = {}
    for idx, key in ipairs(path) do i[idx] = key end
    return i
end

T:Describe("Phase 2: options panel", function()
    T:It("registers a valid options table, adds it to the Blizzard options and opens with /ar config", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local dialog, restore = stubDialog()
        local ok, err = pcall(function()
            AR.Storage:ResetProfiles()
            AR.Storage:Initialize()
            AR.Config:Reset()
            T:AssertEqual(AR.Config:Initialize(), true, "Initializes with AceConfig available")
            T:AssertTrue(options() ~= nil, "AceConfigRegistry validates the table")
            T:AssertEqual(#dialog.blizz, 1, "Added to the Blizzard options once")
            T:AssertEqual(AR.Config.categoryID, 77, "Keeps the category ID for Settings.OpenToCategory")
            T:AssertEqual(AR.Config:Initialize(), true)
            T:AssertEqual(#dialog.blizz, 1, "Never registered twice")

            _G.SlashCmdList["AZEROTHROUTE"]("config")
            _G.SlashCmdList["AZEROTHROUTE"]("opciones")
            T:AssertEqual(#dialog.opened, 2, "/ar config and /ar opciones open the panel")
            T:AssertEqual(dialog.opened[1], APP)
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("reads and writes every setting through the active profile", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local _, restore = stubDialog()
        local ok, err = pcall(function()
            AR.Storage:ResetProfiles()
            AR.Storage:Initialize()
            AR.Config:Reset()
            AR.Config:Initialize()
            local toggles = {
                { "quests", "autoaccept" }, { "quests", "autoacceptall" }, { "quests", "autoturnin" },
                { "quests", "autoselectreward" }, { "navigation", "corpsearrow" }, { "navigation", "autotaxi" },
                { "merchant", "autogrey" }, { "merchant", "autorepair" }, { "merchant", "autobuy" },
                { "targeting", "targetmacro" }, { "interface", "loadguidesfully" },
            }
            for _, path in ipairs(toggles) do
                local node = opt(path)
                T:AssertEqual(node.type, "toggle", path[2] .. " is a toggle")
                local key = path[2]
                local current = AR.db.profile[key]
                T:AssertEqual(node.get(info(path)), current, key .. " get reflects the profile")
                node.set(info(path), not current)
                T:AssertEqual(AR.db.profile[key], not current, key .. " set writes the profile")
            end
            local style = opt({ "interface", "style" })
            T:AssertEqual(style.type, "select")
            T:AssertTrue(style.values.starlight ~= nil, "Offers registered skin styles")
            style.set(info({ "interface", "style" }), "starlight")
            T:AssertEqual(AR.db.profile.style, "starlight")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("toggles the minimap button through the account setting", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local _, restore = stubDialog()
        local ok, err = pcall(function()
            AR.Storage:ResetProfiles()
            AR.Storage:Initialize()
            AR.db.global.minimap = { hide = false }
            AR.Config:Reset()
            AR.Config:Initialize()
            local node = opt({ "navigation", "minimap" })
            T:AssertEqual(node.get(info({ "navigation", "minimap" })), true, "Shown by default")
            node.set(info({ "navigation", "minimap" }), false)
            T:AssertEqual(AR.db.global.minimap.hide, true, "Unchecking hides the button")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("exposes an AceDBOptions profiles tab bound to the settings database", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local _, restore = stubDialog()
        local ok, err = pcall(function()
            AR.Storage:ResetProfiles()
            AR.Storage:Initialize()
            AR.Config:Reset()
            AR.Config:Initialize()
            local profiles = opt({ "profiles" })
            T:AssertEqual(profiles.type, "group", "Profiles tab present")
            T:AssertTrue(profiles.handler and profiles.handler.db == AR.Storage.aceDB, "Bound to the AceDB object")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("localizes labels to the client language", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local _, restore = stubDialog()
        local origLocale = _G.GetLocale
        local ok, err = pcall(function()
            AR.Storage:ResetProfiles()
            AR.Storage:Initialize()
            AR.Config:Reset()
            AR.Config:Initialize()
            _G.GetLocale = function() return "esMX" end
            T:AssertEqual(opt({ "quests", "autoaccept" }).name, "Aceptar misiones automáticamente")
            _G.GetLocale = function() return "enUS" end
            T:AssertEqual(opt({ "quests", "autoaccept" }).name, "Auto-accept quests")
        end)
        _G.GetLocale = origLocale
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("reports unavailable without AceConfig", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local saved = LibStub.libs["AceConfig-3.0"]
        LibStub.libs["AceConfig-3.0"] = nil
        local ok, err = pcall(function()
            AR.Config:Reset()
            T:AssertEqual(AR.Config:Initialize(), false)
            _G.SlashCmdList["AZEROTHROUTE"]("config") -- must not error
        end)
        LibStub.libs["AceConfig-3.0"] = saved
        AR.Config:Reset()
        if not ok then error(err, 0) end
    end)
end)
