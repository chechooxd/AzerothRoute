-- Phase 2: settings stored in AceDB-3.0 profiles, migrated once from AzerothRouteSavedDB.global.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function freshStorage(saved, charSaved)
    local AR = _G.AzerothRoute
    _G.AzerothRouteSavedDB = saved
    _G.AzerothRouteCharDB = charSaved
    AR.Storage:ResetProfiles()
    AR.Storage:Initialize()
    return AR
end

T:Describe("Phase 2: AceDB profiles", function()
    T:It("moves existing settings from global into the Default profile once, keeping data in global", function()
        MockWoW:Reset()
        local legacy = {
            global = {
                autoaccept = false,
                autoacceptall = true,
                actionbar_pos = { point = "TOP", x = 5, y = -7 },
                taxitimes = { Crossroads = 42 },
                minimap = { hide = true, minimapPos = 200 },
                targetMacroAnnounced = true,
            },
            factionrealms = { [_G.AzerothRoute.Compat:GetFactionRealmKey()] = { gold_trends = { a = 1 } } },
        }
        local AR = freshStorage(legacy, { currentStepNum = 9 })
        local root = _G.AzerothRouteSavedDB

        T:AssertEqual(AR.db.profile.autoaccept, false, "User choice kept")
        T:AssertEqual(AR.db.profile.autoacceptall, true, "User choice kept")
        T:AssertEqual(AR.db.profile.actionbar_pos.point, "TOP", "Bar position kept")
        T:AssertEqual(AR.db.profile.autoturnin, true, "Unset settings use defaults")
        T:AssertEqual(AR.db.profile.style, "default", "Unset settings use defaults")
        T:AssertEqual(root.global.autoaccept, nil, "Setting removed from global after the move")
        T:AssertEqual(root.global.actionbar_pos, nil, "Position removed from global after the move")
        T:AssertEqual(AR.db.global.taxitimes.Crossroads, 42, "Data stays in global")
        T:AssertEqual(AR.db.global.minimap.minimapPos, 200, "Minimap button stays per account")
        T:AssertEqual(AR.db.global.targetMacroAnnounced, true, "Flags stay in global")
        T:AssertEqual(AR.db.factionrealm.gold_trends.a, 1, "Faction-realm data untouched")
        T:AssertEqual(AR.db.char.currentStepNum, 9, "Per-character data untouched")
        T:AssertTrue(root.profileKeys ~= nil and root.profiles ~= nil, "AceDB profile tables live in the same SavedVariable")
    end)

    T:It("does not migrate again or reset the profile on later loads", function()
        MockWoW:Reset()
        local AR = freshStorage({ global = { autoaccept = false } }, {})
        AR.db.profile.autoaccept = true
        local root = _G.AzerothRouteSavedDB
        root.global.autoaccept = false -- stray legacy value must not override the profile again

        AR.Storage:ResetProfiles() -- simulates the next session: same SavedVariable, new AceDB object
        AR.Storage:Initialize()
        T:AssertEqual(AR.db.profile.autoaccept, true, "Profile value survives reloads")

        AR.Storage:Initialize() -- same session re-init (ADDON_LOADED after file load)
        T:AssertEqual(AR.db.profile.autoaccept, true, "Re-init with the same table keeps the profile")
    end)

    T:It("switches the live settings when the profile changes", function()
        MockWoW:Reset()
        local AR = freshStorage({ global = { autoaccept = false } }, {})
        local adb = AR.Storage.aceDB
        T:AssertTrue(adb ~= nil, "AceDB object available")
        adb:SetProfile("Alt")
        T:AssertEqual(AR.db.profile.autoaccept, true, "New profile starts from defaults")
        AR.db.profile.autoturnin = false
        adb:SetProfile("Default")
        T:AssertEqual(AR.db.profile.autoaccept, false, "Back to the migrated profile")
        T:AssertEqual(AR.db.profile.autoturnin, true, "Profiles are independent")
        adb:ResetProfile()
        T:AssertEqual(AR.db.profile.autoaccept, true, "Reset restores defaults")
    end)

    T:It("makes the addon read settings from the active profile", function()
        MockWoW:Reset()
        local AR = freshStorage({}, {})
        AR.db.profile.targetmacro = false
        T:AssertEqual(AR.TargetMacro:IsEnabled(), false, "Target macro follows the profile")
        AR.db.profile.targetmacro = true
        AR.db.global.targetmacro = false
        T:AssertEqual(AR.TargetMacro:IsEnabled(), true, "Global no longer decides")
        AR.db.profile.corpsearrow = false
        T:AssertEqual(AR.Pointer:CheckCorpseArrow(), false, "Corpse arrow follows the profile")
        AR.db.profile.style = "starlight"
        T:AssertEqual(AR.Skins:GetProp("goalPassive").r, 0.14, "Skin style follows the profile")
    end)

    T:It("falls back to plain default settings when AceDB is not available", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local lib = LibStub.libs["AceDB-3.0"]
        LibStub.libs["AceDB-3.0"] = nil
        local ok, err = pcall(function()
            freshStorage({ global = { autoaccept = false } }, {})
            T:AssertTrue(AR.Storage.aceDB == nil, "No AceDB object")
            T:AssertEqual(AR.db.profile.autoaccept, false, "Legacy value still honoured")
            T:AssertEqual(AR.db.profile.autoturnin, true, "Defaults still apply")
        end)
        LibStub.libs["AceDB-3.0"] = lib
        freshStorage({}, {})
        if not ok then error(err, 0) end
    end)
end)
