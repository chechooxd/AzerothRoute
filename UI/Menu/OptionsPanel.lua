-- AzerothRoute: Options mode of the Guide Center (Polestar-style settings page).
-- Groups of settings in the sidebar; each row shows its current value; the details pane explains
-- the setting with a "Change" button (toggle or next value) and "Reset". Appearance settings
-- (accent colour, guide-window opacity and scale) repaint the guide window at once; the rest of
-- the interface picks the accent up after "Reload UI".

local AR = _G.AzerothRoute
local OptionsPanel = { MODE = "options", query = "" }
AR.OptionsPanel = OptionsPanel

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

OptionsPanel.ACCENTS = {
    gold = { r = 0.957, g = 0.773, b = 0.290 },
    sky = { r = 0.47, g = 0.76, b = 0.98 },
    emerald = { r = 0.40, g = 0.82, b = 0.55 },
    rose = { r = 0.95, g = 0.52, b = 0.62 },
    violet = { r = 0.72, g = 0.60, b = 0.98 },
}

-- Colour schemes: panel, raised panel, guide-window background and the lines between them.
OptionsPanel.SCHEMES = {
    dusk = {},
    midnight = {
        panel = { r = 0.035, g = 0.04, b = 0.06, a = 0.97 }, panelRaised = { r = 0.07, g = 0.075, b = 0.10, a = 0.98 },
        bg = { r = 0.035, g = 0.04, b = 0.06, a = 0.96 }, divider = { r = 0.14, g = 0.15, b = 0.19, a = 1 },
        border = { r = 0.16, g = 0.17, b = 0.22, a = 1 }, selected = { r = 0.12, g = 0.13, b = 0.17, a = 1 },
    },
    slate = {
        panel = { r = 0.11, g = 0.12, b = 0.14, a = 0.96 }, panelRaised = { r = 0.15, g = 0.16, b = 0.19, a = 0.98 },
        bg = { r = 0.11, g = 0.12, b = 0.14, a = 0.96 }, divider = { r = 0.24, g = 0.25, b = 0.29, a = 1 },
        border = { r = 0.27, g = 0.28, b = 0.33, a = 1 }, selected = { r = 0.20, g = 0.21, b = 0.25, a = 1 },
    },
    forest = {
        panel = { r = 0.055, g = 0.10, b = 0.08, a = 0.96 }, panelRaised = { r = 0.08, g = 0.14, b = 0.11, a = 0.98 },
        bg = { r = 0.055, g = 0.10, b = 0.08, a = 0.96 }, divider = { r = 0.15, g = 0.24, b = 0.19, a = 1 },
        border = { r = 0.17, g = 0.28, b = 0.22, a = 1 }, selected = { r = 0.12, g = 0.20, b = 0.16, a = 1 },
    },
}

-- Setting definitions: profile key, group, kind ("bool" | "cycle"), values for cycles, default.
OptionsPanel.SETTINGS = {
    { key = "accent", group = "appearance", kind = "cycle", values = { "gold", "sky", "emerald", "rose", "violet" }, default = "gold",
        label = "OPT_ACCENT", desc = "OPT_ACCENT_DESC", valueKey = "OPT_ACCENT_" },
    { key = "scheme", group = "appearance", kind = "cycle", values = { "dusk", "midnight", "slate", "forest" }, default = "dusk",
        label = "OPT_SCHEME", desc = "OPT_SCHEME_DESC", valueKey = "OPT_SCHEME_" },
    { key = "bgalpha", group = "appearance", kind = "cycle", values = { 0.96, 0.85, 0.7, 0.5 }, default = 0.96,
        label = "OPT_BGALPHA", desc = "OPT_BGALPHA_DESC", percent = true },
    { key = "viewerscale", group = "appearance", kind = "cycle", values = { 1.0, 1.1, 1.2, 0.9 }, default = 1.0,
        label = "OPT_SCALE", desc = "OPT_SCALE_DESC", percent = true },
    { key = "previewsteps", group = "guide", kind = "cycle", values = { 0, 1, 2, 3, 4 }, default = 0,
        label = "OPT_PREVIEWSTEPS", desc = "OPT_PREVIEWSTEPS_DESC" },
    { key = "stepsound", group = "guide", kind = "bool", default = true, label = "OPT_STEPSOUND", desc = "OPT_STEPSOUND_DESC" },
    { key = "spelltoasts", group = "guide", kind = "bool", default = true, label = "OPT_SPELLTOASTS", desc = "OPT_SPELLTOASTS_DESC" },
    { key = "journey", group = "travel", kind = "bool", default = true, label = "OPT_JOURNEY", desc = "OPT_JOURNEY_DESC" },
    { key = "keeparrow", group = "travel", kind = "bool", default = true, label = "OPT_KEEPARROW", desc = "OPT_KEEPARROW_DESC" },
    { key = "corpsearrow", group = "travel", kind = "bool", default = true, label = "OPT_CORPSEARROW", desc = "OPT_CORPSEARROW_DESC" },
    { key = "autotaxi", group = "travel", kind = "bool", default = true, label = "OPT_AUTOTAXI", desc = "OPT_AUTOTAXI_DESC" },
    { key = "autoaccept", group = "quests", kind = "bool", default = true, label = "OPT_AUTOACCEPT", desc = "OPT_AUTOACCEPT_DESC" },
    { key = "autoturnin", group = "quests", kind = "bool", default = true, label = "OPT_AUTOTURNIN", desc = "OPT_AUTOTURNIN_DESC" },
    { key = "autoselectreward", group = "quests", kind = "bool", default = true, label = "OPT_AUTOSELECTREWARD", desc = "OPT_AUTOSELECTREWARD_DESC" },
    { key = "automark", group = "quests", kind = "bool", default = true, label = "OPT_AUTOMARK", desc = "OPT_AUTOMARK_DESC" },
}

local GROUPS = {
    { id = "appearance", key = "OPT_GROUP_APPEARANCE" },
    { id = "guide", key = "OPT_GROUP_GUIDE" },
    { id = "travel", key = "OPT_GROUP_NAVIGATION" },
    { id = "quests", key = "OPT_GROUP_QUESTS" },
}

local function profile()
    return (AR.db and AR.db.profile) or {}
end

function OptionsPanel:Reset()
    self.query = ""
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function OptionsPanel:Get(s)
    local v = profile()[s.key]
    if v == nil then return s.default end
    return v
end

function OptionsPanel:FormatValue(s, v)
    if s.kind == "bool" then return v and L("OPT_ON", "On") or L("OPT_OFF", "Off") end
    if s.valueKey then return L(s.valueKey .. tostring(v):upper(), tostring(v)) end
    if s.percent then return string.format("%d%%", math.floor(v * 100 + 0.5)) end
    return tostring(v)
end

-- Toggles a switch or moves a cycle to its next value; applies appearance changes at once.
function OptionsPanel:Change(s)
    local p = profile()
    if s.kind == "bool" then
        p[s.key] = not self:Get(s)
    else
        local cur, idx = self:Get(s), 1
        for i, v in ipairs(s.values) do if v == cur then idx = i end end
        p[s.key] = s.values[idx % #s.values + 1]
    end
    self:Apply()
    return p[s.key]
end

function OptionsPanel:ResetSetting(s)
    profile()[s.key] = s.default
    self:Apply()
end

function OptionsPanel:Apply()
    if AR.ViewerFrame and AR.ViewerFrame.frame then AR.ViewerFrame:RefreshVisuals() end
    if self.panel then self.panel:Render() end
end

-- Panel data ----------------------------------------------------------------------------------

function OptionsPanel:SetQuery(q)
    self.query = tostring(q or "")
    if self.panel then
        self.panel.page = 0
        self.panel:Render()
    end
end

function OptionsPanel:GetCategories()
    local out = {}
    for _, g in ipairs(GROUPS) do out[#out + 1] = { id = g.id, label = L(g.key, g.id) } end
    return out
end

function OptionsPanel:List(id)
    local q = (self.query or ""):lower()
    local out = {}
    for _, s in ipairs(self.SETTINGS) do
        local keep = q ~= "" and L(s.label):lower():find(q, 1, true) ~= nil or (q == "" and s.group == id)
        if keep then out[#out + 1] = s end
    end
    return out
end

function OptionsPanel:CountCategory(id)
    local n = 0
    for _, s in ipairs(self.SETTINGS) do if s.group == id then n = n + 1 end end
    return n
end

function OptionsPanel:GetRows(id)
    local rows = {}
    for _, s in ipairs(self:List(id)) do
        rows[#rows + 1] = { text = L(s.label, s.key), tag = self:FormatValue(s, self:Get(s)), data = s }
    end
    return rows
end

function OptionsPanel:HeaderTitle() return L("UI_MENU_OPTIONS", "Options") end

function OptionsPanel:HeaderSub()
    return L("UI_OPT_SUB", "Changes apply at once; Reload UI repaints every window with a new accent.")
end

function OptionsPanel:Describe(row)
    local s = row and row.data
    if not s then return {} end
    local value = self:Get(s)
    return {
        title = L(s.label, s.key),
        subtitle = L(s.desc, ""),
        chips = { { text = self:FormatValue(s, value), accent = true } },
        info = { { L("UI_OPT_DEFAULT", "Default"), self:FormatValue(s, s.default) } },
        primary = { text = L("UI_OPT_CHANGE", "Change"), onClick = function() self:Change(s) end },
        secondary = s.group == "appearance"
            and { text = L("UI_OPT_RELOAD", "Reload UI"), onClick = function() if _G.ReloadUI then _G.ReloadUI() end end }
            or { text = L("UI_OPT_RESET", "Reset"), onClick = function() self:ResetSetting(s) end },
    }
end

function OptionsPanel:Attach(frame)
    if self.panel then return self.panel end
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteOptions")
    return self.panel
end

return OptionsPanel
