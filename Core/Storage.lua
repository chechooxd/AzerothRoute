-- AzerothRoute: 3-Tier SavedVariables Storage Engine (SPEC-01)
-- Invariant: Goal and Step completion are NEVER persisted in SavedVariables (except opt-in |sticky saved goals).

local AR = _G.AzerothRoute
local Storage = {}
AR.Storage = Storage

local function deepCopyDefaults(src, dst)
    dst = dst or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = deepCopyDefaults(v, type(dst[k]) == "table" and dst[k] or {})
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

Storage.Defaults = {
    global = {
        taxitimes = {},
        skin = "default",
        style = "default",
        loadguidesfully = false,
        showstepnumbers = false,
        autoaccept = true,
        autoturnin = true,
        autoselectreward = true,
        corpsearrow = true,
        foglight = true,
        actionbar_pos = nil,
        itembar_pos = nil,
    },
    factionrealm = {
        gold_scan_data = {},
        gold_trends = {},
    },
    char = {
        currentGuideTitle = nil,
        currentStepNum = 1,
        guidestephistory = {},
        saved_sticky_goals = {},
        taxis = {},
        SkillsKnown = {},
        RecipesKnown = {},
        tabguides = {},
        bad_upgrades = {},
        bank_cache = {},
        timeperlevel = {},
        activeTalentBuild = nil,
    },
}

function Storage:Initialize()
    _G.AzerothRouteSavedDB = _G.AzerothRouteSavedDB or {}
    _G.AzerothRouteCharDB = _G.AzerothRouteCharDB or {}

    local root = _G.AzerothRouteSavedDB
    root.global = deepCopyDefaults(self.Defaults.global, root.global)
    root.factionrealms = root.factionrealms or {}

    local frKey = AR.Compat:GetFactionRealmKey()
    root.factionrealms[frKey] = deepCopyDefaults(self.Defaults.factionrealm, root.factionrealms[frKey])

    local charRoot = deepCopyDefaults(self.Defaults.char, _G.AzerothRouteCharDB)
    -- Enforce invariant: strip any accidental persisted step completion table
    charRoot.completedSteps = nil
    _G.AzerothRouteCharDB = charRoot

    AR.db = {
        global = root.global,
        factionrealm = root.factionrealms[frKey],
        char = charRoot,
    }
    return AR.db
end

return Storage
