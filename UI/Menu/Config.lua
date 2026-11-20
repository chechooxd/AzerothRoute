-- AzerothRoute: the addon's entry in the Blizzard AddOns options (AceConfig) with the profiles tab.
-- Every other setting lives on the Guide Center's Options page (UI/Menu/OptionsPanel.lua), which
-- the minimap button, /ar options and this entry's button open.

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

-- The Blizzard AddOns entry: a button that opens the Guide Center's Options page (the one settings
-- page of the addon) and the AceDBOptions profiles tab.
function Config:BuildOptions()
    local options = {
        type = "group",
        name = "AzerothRoute",
        args = {
            open = {
                type = "execute",
                order = 1,
                width = "double",
                name = L("UI_OPT_OPEN"),
                desc = L("UI_OPT_SUB"),
                func = function()
                    if _G.HideUIPanel and _G.SettingsPanel then _G.HideUIPanel(_G.SettingsPanel) end
                    if _G.HideUIPanel and _G.InterfaceOptionsFrame then _G.HideUIPanel(_G.InterfaceOptionsFrame) end
                    Config:Open()
                end,
            },
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

-- Opens the Guide Center on its Options page.
function Config:Open()
    if not (AR.GuideMenu and AR.GuideMenu.Show) then return false end
    AR.GuideMenu:Show("options")
    return true
end

return Config
