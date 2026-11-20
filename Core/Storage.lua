-- AzerothRoute: 3-Tier SavedVariables Storage Engine (SPEC-01) + AceDB-3.0 settings profiles (Phase 2)
-- Invariant: Goal and Step completion are NEVER persisted in SavedVariables (except opt-in |sticky saved goals).
-- Settings live in AceDB profiles (AzerothRouteSavedDB.profiles); account data stays in .global,
-- faction-realm data in .factionrealms and per-character data in AzerothRouteCharDB.

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
        showstepnumbers = false,
        foglight = true,
        minimap = { hide = false },
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

-- User settings, one set per AceDB profile. Bar positions have no default (nil = default anchor).
Storage.ProfileDefaults = {
    autoaccept = true,
    autoacceptall = false,
    autoturnin = true,
    autoselectreward = true,
    corpsearrow = true,
    autotaxi = true,
    automark = true,
    targetmacro = true,
    autogrey = true,
    autorepair = true,
    autobuy = true,
    loadguidesfully = false,
    style = "default",
    stepsound = true,
    previewsteps = 0,
    hidearrow = false,
    hideall = false,
    keeparrow = true,
    journey = true,
}

-- Keys that used to live in AzerothRouteSavedDB.global and now belong to the profile.
Storage.PROFILE_KEYS = {
    "autoaccept", "autoacceptall", "autoturnin", "autoselectreward", "corpsearrow", "autotaxi",
    "automark", "targetmacro", "autogrey", "autorepair", "autobuy", "loadguidesfully", "style",
    "actionbar_pos", "itembar_pos",
}

Storage.DEFAULT_PROFILE = "Default"

function Storage:ResetProfiles()
    self.aceDB = nil
    self.fallbackProfile = nil
end

-- Moves legacy settings out of root.global into the profile. Runs only for a SavedVariable that has
-- never been opened by AceDB, so a later stray global value can never override the profile.
local function migrateLegacySettings(root, profile)
    local global = root.global or {}
    for _, key in ipairs(Storage.PROFILE_KEYS) do
        if global[key] ~= nil then
            profile[key] = global[key]
            global[key] = nil
        end
    end
end

function Storage:OnProfileChanged()
    if AR.db and self.aceDB then
        AR.db.profile = self.aceDB.profile
    end
    if AR.ViewerFrame and AR.ViewerFrame.RefreshVisuals and AR.ViewerFrame.frame then
        if AR.ViewerFrame.RestorePosition then AR.ViewerFrame:RestorePosition() end
        AR.ViewerFrame:RefreshVisuals()
    end
    if AR.Events and AR.Events.SendMessage then
        AR.Events:SendMessage("AR_PROFILE_CHANGED")
    end
end

function Storage:BindProfile(root)
    local AceDB = _G.LibStub and _G.LibStub("AceDB-3.0", true)
    if not AceDB then
        -- Degraded mode: honour legacy values without moving them, so nothing is lost if AceDB returns.
        local profile = {}
        for _, key in ipairs(self.PROFILE_KEYS) do
            if root.global and root.global[key] ~= nil then profile[key] = root.global[key] end
        end
        self.aceDB = nil
        self.fallbackProfile = deepCopyDefaults(self.ProfileDefaults, profile)
        return self.fallbackProfile
    end

    if self.aceDB and self.aceDB.sv == root then
        return self.aceDB.profile
    end

    local isLegacy = root.profileKeys == nil
    local db = AceDB:New(root, { profile = self.ProfileDefaults }, self.DEFAULT_PROFILE)
    if isLegacy then
        migrateLegacySettings(root, db.profile)
    end
    local onChange = function()
        if db == self.aceDB then self:OnProfileChanged() end
    end
    db.RegisterCallback(self, "OnProfileChanged", onChange)
    db.RegisterCallback(self, "OnProfileCopied", onChange)
    db.RegisterCallback(self, "OnProfileReset", onChange)
    self.aceDB = db
    return db.profile
end

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

    local profile = self:BindProfile(root)

    AR.db = {
        global = root.global,
        factionrealm = root.factionrealms[frKey],
        char = charRoot,
        profile = profile,
    }
    return AR.db
end

return Storage
