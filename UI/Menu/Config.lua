-- AzerothRoute: AceConfig options panel (Phase 2)
-- Every toggle reads/writes AR.db.profile, so switching profiles in the Profiles tab (AceDBOptions)
-- changes the live settings. The table is rebuilt on each request to follow the active locale/profile.

local AR = _G.AzerothRoute
local Config = {
    APP = "AzerothRoute",
    initialized = false,
    categoryID = nil,
}
AR.Config = Config

local function lib(name)
    return _G.LibStub and _G.LibStub(name, true) or nil
end

local function L(key)
    return (AR.L and AR.L:Get(key)) or key
end

function Config:Reset()
    self.initialized = false
    self.categoryID = nil
end

local function refreshAfterChange(key)
    if key == "targetmacro" and AR.ActionBar and AR.ActionBar.UpdateFromCurrentStep then
        AR.ActionBar:UpdateFromCurrentStep()
    end
    if AR.ViewerFrame and AR.ViewerFrame.frame and AR.ViewerFrame.RefreshVisuals then
        AR.ViewerFrame:RefreshVisuals()
    end
end

local function profileGet(info)
    return AR.db.profile[info[#info]]
end

local function profileSet(info, value)
    local key = info[#info]
    AR.db.profile[key] = value
    refreshAfterChange(key)
end

local function toggle(key, order)
    return {
        type = "toggle",
        order = order,
        width = "full",
        name = L("OPT_" .. key:upper()),
        desc = L("OPT_" .. key:upper() .. "_DESC"),
        get = profileGet,
        set = profileSet,
    }
end

local function group(nameKey, order, args)
    return { type = "group", order = order, name = L(nameKey), args = args }
end

function Config:GetStyleValues()
    local values = {}
    for name in pairs((AR.Skins and AR.Skins.styles) or { default = true }) do
        values[name] = L("OPT_STYLE_" .. name:upper())
    end
    return values
end

function Config:BuildOptions()
    local options = {
        type = "group",
        name = "AzerothRoute",
        childGroups = "tab",
        args = {
            quests = group("OPT_GROUP_QUESTS", 1, {
                autoaccept = toggle("autoaccept", 1),
                autoacceptall = toggle("autoacceptall", 2),
                autoturnin = toggle("autoturnin", 3),
                autoselectreward = toggle("autoselectreward", 4),
            }),
            navigation = group("OPT_GROUP_NAVIGATION", 2, {
                corpsearrow = toggle("corpsearrow", 1),
                autotaxi = toggle("autotaxi", 2),
                minimap = {
                    type = "toggle",
                    order = 3,
                    width = "full",
                    name = L("OPT_MINIMAP"),
                    desc = L("OPT_MINIMAP_DESC"),
                    get = function()
                        return not (AR.db.global.minimap and AR.db.global.minimap.hide)
                    end,
                    set = function(_, value)
                        AR.db.global.minimap = AR.db.global.minimap or {}
                        local shown = not AR.db.global.minimap.hide
                        if shown == value then return end
                        if AR.MinimapButton then
                            AR.MinimapButton:Toggle()
                        else
                            AR.db.global.minimap.hide = not value
                        end
                    end,
                },
            }),
            merchant = group("OPT_GROUP_MERCHANT", 3, {
                autogrey = toggle("autogrey", 1),
                autorepair = toggle("autorepair", 2),
                autobuy = toggle("autobuy", 3),
            }),
            targeting = group("OPT_GROUP_TARGETING", 4, {
                targetmacro = toggle("targetmacro", 1),
                automark = toggle("automark", 2),
            }),
            interface = group("OPT_GROUP_INTERFACE", 5, {
                style = {
                    type = "select",
                    order = 1,
                    name = L("OPT_STYLE"),
                    desc = L("OPT_STYLE_DESC"),
                    values = self:GetStyleValues(),
                    get = profileGet,
                    set = profileSet,
                },
                loadguidesfully = toggle("loadguidesfully", 2),
                stepsound = toggle("stepsound", 3),
            }),
        },
    }

    local dbOptions = lib("AceDBOptions-3.0")
    if dbOptions and AR.Storage and AR.Storage.aceDB then
        local profiles = dbOptions:GetOptionsTable(AR.Storage.aceDB)
        profiles.order = 100
        options.args.profiles = profiles
    end
    return options
end

-- Returns true when the panel is registered (now or earlier), false when AceConfig is missing.
function Config:Initialize()
    if self.initialized then return true end
    local aceConfig, dialog = lib("AceConfig-3.0"), lib("AceConfigDialog-3.0")
    if not aceConfig or not dialog or not AR.db then return false end

    aceConfig:RegisterOptionsTable(self.APP, function() return self:BuildOptions() end)
    local _, categoryID = dialog:AddToBlizOptions(self.APP, "AzerothRoute")
    self.categoryID = categoryID
    self.initialized = true
    return true
end

function Config:Open()
    if not self:Initialize() then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    lib("AceConfigDialog-3.0"):Open(self.APP)
    return true
end

return Config
