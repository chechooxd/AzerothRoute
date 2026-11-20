-- AzerothRoute: Options mode of the Guide Center, the one settings page of the addon.
-- The minimap button, /ar options and the guide window menu all open it.
--
-- Groups of settings in the sidebar; the page lists the group's settings, each with its own
-- control on the right, Polestar-style:
--   bool   -> a check box (clicking the row toggles it too)
--   color  -> colour swatches
--   choice -> a drop-down list of the values
--   range  -> a slider with its value next to it
--   button -> an action button
-- Every change applies at once and repaints the guide window. Right-click a row to reset it.

local AR = _G.AzerothRoute
local OptionsPanel = { MODE = "options", query = "" }
AR.OptionsPanel = OptionsPanel

local ROW_H = 50
local ROWS = 7
local CONTROL_W = 170

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

local function profile()
    return (AR.db and AR.db.profile) or {}
end

local function aceDB()
    return AR.Storage and AR.Storage.aceDB
end

local function styleValues()
    local out = {}
    for name in pairs((AR.Skins and AR.Skins.styles) or { default = true }) do out[#out + 1] = name end
    table.sort(out, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a < b
    end)
    return out
end

local function bool(key, group, extra)
    local s = { key = key, group = group, kind = "bool", default = true,
        label = "OPT_" .. key:upper(), desc = "OPT_" .. key:upper() .. "_DESC" }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

-- Setting definitions. `get`/`set` override the profile key; `onChange` runs after a change.
OptionsPanel.SETTINGS = {
    { key = "accent", group = "appearance", kind = "color", default = "gold",
        values = { "gold", "sky", "emerald", "rose", "violet" },
        label = "OPT_ACCENT", desc = "OPT_ACCENT_DESC", valueKey = "OPT_ACCENT_" },
    { key = "scheme", group = "appearance", kind = "choice", default = "dusk",
        values = { "dusk", "midnight", "slate", "forest" },
        label = "OPT_SCHEME", desc = "OPT_SCHEME_DESC", valueKey = "OPT_SCHEME_" },
    { key = "style", group = "appearance", kind = "choice", default = "default", values = styleValues,
        label = "OPT_STYLE", desc = "OPT_STYLE_DESC", valueKey = "OPT_STYLE_" },
    { key = "bgalpha", group = "appearance", kind = "range", min = 0.3, max = 1, step = 0.05, default = 0.96,
        label = "OPT_BGALPHA", desc = "OPT_BGALPHA_DESC", percent = true },
    { key = "viewerscale", group = "appearance", kind = "range", min = 0.7, max = 1.5, step = 0.05, default = 1.0,
        label = "OPT_SCALE", desc = "OPT_SCALE_DESC", percent = true },

    { key = "previewsteps", group = "guide", kind = "range", min = 0, max = 4, step = 1, default = 0,
        label = "OPT_PREVIEWSTEPS", desc = "OPT_PREVIEWSTEPS_DESC" },
    bool("stepsound", "guide"),
    bool("questxp", "guide"),
    bool("spelltoasts", "guide"),
    bool("gamepad", "guide"),
    bool("loadguidesfully", "guide", { default = false }),

    bool("journey", "travel"),
    bool("keeparrow", "travel"),
    bool("corpsearrow", "travel"),
    bool("autotaxi", "travel"),
    bool("minimap", "travel", {
        get = function()
            local m = AR.db and AR.db.global and AR.db.global.minimap
            return not (m and m.hide)
        end,
        set = function(_, value)
            if not (AR.db and AR.db.global) then return end
            AR.db.global.minimap = AR.db.global.minimap or {}
            if (not AR.db.global.minimap.hide) == value then return end
            if AR.MinimapButton and AR.MinimapButton.Toggle then
                AR.MinimapButton:Toggle()
            else
                AR.db.global.minimap.hide = not value
            end
        end,
    }),

    bool("autoaccept", "quests"),
    bool("autoacceptall", "quests", { default = false }),
    bool("autoturnin", "quests"),
    bool("autoselectreward", "quests"),

    bool("autogrey", "merchant"),
    bool("autorepair", "merchant"),
    bool("autobuy", "merchant"),

    bool("targetmacro", "targeting", {
        onChange = function()
            if AR.ActionBar and AR.ActionBar.UpdateFromCurrentStep then AR.ActionBar:UpdateFromCurrentStep() end
        end,
    }),
    bool("automark", "targeting", {
        onChange = function()
            if AR.ActionBar and AR.ActionBar.UpdateFromCurrentStep then AR.ActionBar:UpdateFromCurrentStep() end
        end,
    }),

    { key = "profile", group = "profiles", kind = "choice", label = "OPT_PROFILE", desc = "OPT_PROFILE_DESC",
        noReset = true,
        values = function()
            local db = aceDB()
            local list = {}
            if db and db.GetProfiles then db:GetProfiles(list) end
            local cur = db and db.GetCurrentProfile and db:GetCurrentProfile()
            local seen = false
            for _, n in ipairs(list) do if n == cur then seen = true end end
            if cur and not seen then list[#list + 1] = cur end
            table.sort(list)
            return list
        end,
        get = function()
            local db = aceDB()
            return db and db.GetCurrentProfile and db:GetCurrentProfile() or "Default"
        end,
        set = function(_, value)
            local db = aceDB()
            if db and db.SetProfile then db:SetProfile(value) end
        end,
    },
    { key = "resetprofile", group = "profiles", kind = "button", label = "OPT_RESETPROFILE",
        desc = "OPT_RESETPROFILE_DESC", button = "UI_OPT_RESET", noReset = true,
        run = function()
            local db = aceDB()
            if db and db.ResetProfile then db:ResetProfile() end
        end,
    },
}

local GROUPS = {
    { id = "appearance", key = "OPT_GROUP_APPEARANCE" },
    { id = "guide", key = "OPT_GROUP_GUIDE" },
    { id = "travel", key = "OPT_GROUP_NAVIGATION" },
    { id = "quests", key = "OPT_GROUP_QUESTS" },
    { id = "merchant", key = "OPT_GROUP_MERCHANT" },
    { id = "targeting", key = "OPT_GROUP_TARGETING" },
    { id = "profiles", key = "OPT_GROUP_PROFILES" },
}

function OptionsPanel:Reset()
    self.query = ""
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function OptionsPanel:Find(key)
    for _, s in ipairs(self.SETTINGS) do if s.key == key then return s end end
    return nil
end

function OptionsPanel:Values(s)
    if type(s.values) == "function" then return s.values() end
    return s.values or {}
end

function OptionsPanel:Get(s)
    if s.get then return s.get(s) end
    local v = profile()[s.key]
    if v == nil then return s.default end
    return v
end

function OptionsPanel:FormatValue(s, v)
    if s.kind == "bool" then return v and L("OPT_ON", "On") or L("OPT_OFF", "Off") end
    if s.kind == "button" then return "" end
    if s.valueKey then return L(s.valueKey .. tostring(v):upper(), tostring(v)) end
    if s.percent then return string.format("%d%%", math.floor((tonumber(v) or 0) * 100 + 0.5)) end
    return tostring(v)
end

local function snap(s, v)
    v = tonumber(v) or s.default
    if v == s.default then return v end
    v = math.max(s.min, math.min(s.max, v))
    local n = math.floor((v - s.min) / s.step + 0.5)
    v = s.min + n * s.step
    -- Keep two decimals so 0.7 stays 0.7 and not 0.70000000001.
    return math.floor(v * 100 + 0.5) / 100
end

-- Writes a value (clamped and snapped for sliders) and applies it at once.
function OptionsPanel:Set(s, v)
    if s.kind == "range" then v = snap(s, v) end
    if s.set then s.set(s, v) else profile()[s.key] = v end
    if s.onChange then s.onChange(v) end
    self:Apply()
    return self:Get(s)
end

-- Row action without a pointer (row click, gamepad): toggle, next value, or run the button.
function OptionsPanel:Activate(s)
    if s.kind == "bool" then return self:Set(s, not self:Get(s)) end
    if s.kind == "button" then
        if s.run then s.run() end
        self:Apply()
        return nil
    end
    if s.kind == "range" then
        local v = self:Get(s) + s.step
        if v > s.max + 1e-6 then v = s.min end
        return self:Set(s, v)
    end
    local values, cur, idx = self:Values(s), self:Get(s), 0
    for i, v in ipairs(values) do if v == cur then idx = i end end
    if #values == 0 then return cur end
    return self:Set(s, values[idx % #values + 1])
end

-- Kept for callers of the earlier panel: same as Activate.
function OptionsPanel:Change(s) return self:Activate(s) end

function OptionsPanel:ResetSetting(s)
    if s.noReset or s.kind == "button" then return end
    self:Set(s, s.default)
end

function OptionsPanel:ResetGroup(id)
    for _, s in ipairs(self.SETTINGS) do
        if s.group == id and not s.noReset and s.kind ~= "button" then
            if s.set then s.set(s, s.default) else profile()[s.key] = s.default end
            if s.onChange then s.onChange(s.default) end
        end
    end
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
        local keep
        if q ~= "" then
            keep = L(s.label):lower():find(q, 1, true) ~= nil or L(s.desc, ""):lower():find(q, 1, true) ~= nil
        else
            keep = s.group == id
        end
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
    return L("UI_OPT_SUB", "Changes apply at once. Right-click a setting to reset it.")
end

-- Page ----------------------------------------------------------------------------------------

local Page = {}
Page.__index = Page

local function tooltip(owner, title, lines)
    local GT = _G.GameTooltip
    if not (GT and GT.SetOwner) then return end
    GT:SetOwner(owner, "ANCHOR_RIGHT")
    GT:SetText(title or "")
    for _, l in ipairs(lines) do GT:AddLine(l[1], l[2] or 1, l[3] or 1, l[4] or 1, true) end
    GT:Show()
end

local function hideTooltip()
    if _G.GameTooltip and _G.GameTooltip.Hide then _G.GameTooltip:Hide() end
end

local function anchor(region, point, rel, relPoint, x, y)
    if region.ClearAllPoints then region:ClearAllPoints() end
    region:SetPoint(point, rel, relPoint, x, y)
end

local function flatButton(parent, name, width, height)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(width, height)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0, 0, 0, 0)
    b.accent = b:CreateTexture(nil, "ARTWORK")
    b.accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.accent:SetSize(2, height)
    b.accent:Hide()
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.label:SetJustifyH("LEFT")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    b.tag = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.tag:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    b.tag:SetJustifyH("RIGHT")
    if b.tag.SetTextColor then b.tag:SetTextColor(S:RGBA("textMuted")) end
    b:SetScript("OnEnter", function(btn) if not btn._selected then S:Paint(btn.bg, "hover") end end)
    b:SetScript("OnLeave", function(btn) if not btn._selected then btn.bg:SetColorTexture(0, 0, 0, 0) end end)
    return b
end

local function setSelected(btn, on)
    local S = AR.Skins
    btn._selected = on
    if on then S:Paint(btn.bg, "selected") else btn.bg:SetColorTexture(0, 0, 0, 0) end
    S:Paint(btn.accent, "accent")
    if on then btn.accent:Show() else btn.accent:Hide() end
end

-- A small bordered button (drop-down, action buttons).
local function boxButton(parent, name, width, height)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(width, height)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    S:Paint(b.bg, "panelRaised", 1)
    S:AddBorder(b, "border")
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.label:SetJustifyH("LEFT")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    if b.label.SetWidth then b.label:SetWidth(width - 30) end
    b:SetScript("OnEnter", function(btn) S:Paint(btn.bg, "hover", 1) end)
    b:SetScript("OnLeave", function(btn) S:Paint(btn.bg, "panelRaised", 1) end)
    b:Hide()
    return b
end

function Page:BuildRow(main, prefix, i, width)
    local S = AR.Skins
    local owner = self
    local row = AR.UI:Create("Button", main, prefix .. "Row" .. i)
    row:SetSize(width, ROW_H - 4)
    row:SetPoint("TOPLEFT", main, "TOPLEFT", 8, -8 - (i - 1) * ROW_H)
    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, -2)
    row.rule:SetSize(width - 16, 1)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -8)
    row.label:SetJustifyH("LEFT")
    if row.label.SetWidth then row.label:SetWidth(width - CONTROL_W - 70) end
    if row.label.SetWordWrap then row.label:SetWordWrap(false) end
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -27)
    row.desc:SetJustifyH("LEFT")
    if row.desc.SetWidth then row.desc:SetWidth(width - CONTROL_W - 70) end
    if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")

    -- Check box.
    local check = AR.UI:Create("Button", row, prefix .. "Row" .. i .. "Check")
    check:SetSize(20, 20)
    check:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    check.bg = check:CreateTexture(nil, "BACKGROUND")
    check.bg:SetAllPoints(check)
    S:AddBorder(check, "border")
    check.mark = check:CreateTexture(nil, "OVERLAY")
    check.mark:SetPoint("CENTER", check, "CENTER", 0, 0)
    check.mark:SetSize(20, 20)
    check.mark:SetTexture(S.CHECKBOX_CHECK_ICON)
    check:SetScript("OnClick", function() owner:OnRowClick(row, "LeftButton") end)
    check:Hide()
    row.check = check

    -- Colour swatches.
    row.swatches = {}
    for k = 1, 6 do
        local sw = AR.UI:Create("Button", row, prefix .. "Row" .. i .. "Swatch" .. k)
        sw:SetSize(22, 22)
        sw.ring = sw:CreateTexture(nil, "BACKGROUND")
        sw.ring:SetPoint("CENTER", sw, "CENTER", 0, 0)
        sw.ring:SetSize(26, 26)
        sw.fill = sw:CreateTexture(nil, "ARTWORK")
        sw.fill:SetAllPoints(sw)
        sw:SetScript("OnClick", function(btn)
            if row._setting and btn._value then OptionsPanel:Set(row._setting, btn._value) end
        end)
        sw:SetScript("OnEnter", function(btn)
            if row._setting then tooltip(btn, OptionsPanel:FormatValue(row._setting, btn._value), {}) end
        end)
        sw:SetScript("OnLeave", hideTooltip)
        sw:Hide()
        row.swatches[k] = sw
    end

    -- Drop-down.
    local dd = boxButton(row, prefix .. "Row" .. i .. "Drop", CONTROL_W, 24)
    dd:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    dd.arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dd.arrow:SetPoint("RIGHT", dd, "RIGHT", -10, 0)
    dd.arrow:SetText("v")
    dd:SetScript("OnClick", function(btn) owner:OpenDropDown(row, btn) end)
    row.dropdown = dd

    -- Action button.
    local act = boxButton(row, prefix .. "Row" .. i .. "Action", 120, 24)
    act:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    anchor(act.label, "CENTER", act, "CENTER", 0, 0)
    act:SetScript("OnClick", function() owner:OnRowClick(row, "LeftButton") end)
    row.action = act

    -- Slider.
    local sl = _G.CreateFrame("Slider", prefix .. "Row" .. i .. "Slider", row)
    sl:SetSize(CONTROL_W - 50, 16)
    sl:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    if sl.SetOrientation then sl:SetOrientation("HORIZONTAL") end
    if sl.EnableMouse then sl:EnableMouse(true) end
    if sl.EnableMouseWheel then sl:EnableMouseWheel(true) end
    sl.track = sl:CreateTexture(nil, "BACKGROUND")
    sl.track:SetPoint("LEFT", sl, "LEFT", 0, 0)
    sl.track:SetSize(CONTROL_W - 50, 4)
    sl.fill = sl:CreateTexture(nil, "ARTWORK")
    sl.fill:SetPoint("LEFT", sl, "LEFT", 0, 0)
    sl.fill:SetSize(1, 4)
    sl.thumb = sl:CreateTexture(nil, "OVERLAY")
    sl.thumb:SetSize(10, 18)
    if sl.SetThumbTexture then sl:SetThumbTexture(sl.thumb) end
    sl:SetScript("OnValueChanged", function(slider, value)
        if slider._updating or not row._setting then return end
        OptionsPanel:Set(row._setting, value)
    end)
    sl:SetScript("OnMouseWheel", function(_, delta)
        local s = row._setting
        if s and s.kind == "range" then OptionsPanel:Set(s, OptionsPanel:Get(s) + delta * s.step) end
    end)
    sl:Hide()
    row.slider = sl

    row:SetScript("OnClick", function(btn, mouse) owner:OnRowClick(btn, mouse) end)
    row:SetScript("OnEnter", function(btn)
        S:Paint(btn.bg, "hover")
        local s = btn._setting
        if not s then return end
        local lines = { { L(s.desc, ""), 1, 1, 1 } }
        if not s.noReset and s.kind ~= "button" then
            lines[#lines + 1] = { L("UI_OPT_DEFAULT", "Default") .. ": " .. OptionsPanel:FormatValue(s, s.default), 0.7, 0.7, 0.7 }
            lines[#lines + 1] = { L("UI_OPT_RIGHTCLICK", "Right-click: reset to default"), 0.7, 0.7, 0.7 }
        end
        tooltip(btn, L(s.label, s.key), lines)
    end)
    row:SetScript("OnLeave", function(btn)
        btn.bg:SetColorTexture(0, 0, 0, 0)
        hideTooltip()
    end)
    row:Hide()
    return row
end

function Page:Attach(f, prefix)
    if self.side then return end
    local S = AR.Skins
    local W, H = f:GetWidth() or 720, f:GetHeight() or 480
    local level = (f.GetFrameLevel and f:GetFrameLevel() or 1) + 20
    self.prefix = prefix

    local side = AR.UI:Create("Frame", f, prefix .. "Side")
    side:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -82)
    side:SetSize(151, H - 83)
    if side.SetFrameLevel then side:SetFrameLevel(level) end
    if side.EnableMouse then side:EnableMouse(true) end
    side.bg = side:CreateTexture(nil, "BACKGROUND")
    side.bg:SetAllPoints(side)

    local MW = W - 154
    local main = AR.UI:Create("Frame", f, prefix .. "Main")
    main:SetPoint("TOPLEFT", f, "TOPLEFT", 153, -46)
    main:SetSize(MW, H - 47)
    if main.SetFrameLevel then main:SetFrameLevel(level) end
    if main.EnableMouse then main:EnableMouse(true) end
    main.bg = main:CreateTexture(nil, "BACKGROUND")
    main.bg:SetAllPoints(main)
    main.footer = main:CreateTexture(nil, "ARTWORK")
    main.footer:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 44)
    main.footer:SetSize(MW, 1)

    self.cats = {}
    for i = 1, 10 do
        local b = flatButton(side, prefix .. "Cat" .. i, 151, 28)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -4 - (i - 1) * 30)
        b:SetScript("OnClick", function(btn) self:SelectCategory(btn._id) end)
        b:Hide()
        self.cats[i] = b
    end

    self.rows = {}
    for i = 1, ROWS do self.rows[i] = self:BuildRow(main, prefix, i, MW - 16) end

    main.pageText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    main.pageText:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 60, 16)
    self.prevButton = flatButton(main, prefix .. "Prev", 36, 22)
    self.prevButton:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 12, 11)
    self.prevButton.label:SetText("<")
    self.prevButton:SetScript("OnClick", function() self:Page(-1) end)
    self.nextButton = flatButton(main, prefix .. "Next", 36, 22)
    self.nextButton:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 104, 11)
    self.nextButton.label:SetText(">")
    self.nextButton:SetScript("OnClick", function() self:Page(1) end)

    -- Footer actions (the gamepad reaches them as the details column).
    self.secondary = boxButton(main, prefix .. "Reload", 120, 26)
    self.secondary:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -14, 9)
    anchor(self.secondary.label, "CENTER", self.secondary, "CENTER", 0, 0)
    self.secondary:SetScript("OnClick", function() if _G.ReloadUI then _G.ReloadUI() end end)
    self.primary = boxButton(main, prefix .. "ResetGroup", 140, 26)
    self.primary:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -144, 9)
    anchor(self.primary.label, "CENTER", self.primary, "CENTER", 0, 0)
    self.primary:SetScript("OnClick", function()
        if self.category then OptionsPanel:ResetGroup(self.category) end
    end)
    self.list = {}

    side:Hide()
    main:Hide()
    self.side, self.main = side, main
end

function Page:IsShown()
    return self.main ~= nil and self.main:IsShown()
end

function Page:SetShown(shown)
    if not self.side then return end
    if shown then
        self.side:Show()
        self.main:Show()
        self:Render()
    else
        self.side:Hide()
        self.main:Hide()
        if AR.UI and AR.UI.HideMenu then AR.UI:HideMenu() end
    end
end

function Page:SelectCategory(id)
    self.category = id
    self.page = 0
    self:Render()
end

function Page:Page(delta)
    local total = #(self.lastRows or {})
    local maxPage = math.max(0, math.ceil(total / ROWS) - 1)
    local nextPage = math.max(0, math.min(maxPage, self.page + delta))
    if nextPage ~= self.page then
        self.page = nextPage
        self:Render()
    end
end

-- Row click: toggles a check box, runs a button, steps a choice; right-click resets.
function Page:OnRowClick(row, mouse)
    local s = row._setting
    if not s then return end
    if mouse == "RightButton" then
        OptionsPanel:ResetSetting(s)
    elseif s.kind == "choice" then
        self:OpenDropDown(row, row.dropdown)
    else
        OptionsPanel:Activate(s)
    end
end

function Page:OpenDropDown(row, btn)
    local s = row._setting
    if not (s and AR.UI and AR.UI.ShowMenu) then return end
    local cur = OptionsPanel:Get(s)
    local items = {}
    for _, v in ipairs(OptionsPanel:Values(s)) do
        items[#items + 1] = {
            text = OptionsPanel:FormatValue(s, v),
            checked = v == cur,
            onClick = function() OptionsPanel:Set(s, v) end,
        }
    end
    AR.UI:ShowMenu(btn, items, "TOPRIGHT", "BOTTOMRIGHT", 0, -2)
end

local function hideControls(row)
    row.check:Hide()
    row.dropdown:Hide()
    row.action:Hide()
    row.slider:Hide()
    row.value:Hide()
    for _, sw in ipairs(row.swatches) do sw:Hide() end
end

function Page:RenderRow(row, s)
    local S = AR.Skins
    row._setting = s
    hideControls(row)
    row.label:SetText(L(s.label, s.key))
    row.desc:SetText(L(s.desc, ""))
    if row.desc.SetTextColor then row.desc:SetTextColor(S:RGBA("textMuted")) end
    if row.label.SetTextColor then row.label:SetTextColor(S:RGBA("text")) end
    if row.value.SetTextColor then row.value:SetTextColor(S:RGBA("text")) end
    S:Paint(row.rule, "divider")
    local v = OptionsPanel:Get(s)

    if s.kind == "bool" then
        if v then S:Paint(row.check.bg, "accent", 0.25) else S:Paint(row.check.bg, "panelRaised", 1) end
        if row.check.mark.SetVertexColor then row.check.mark:SetVertexColor(S:RGBA("accent")) end
        if v then row.check.mark:Show() else row.check.mark:Hide() end
        row.check._on = v and true or false
        row.check:Show()
    elseif s.kind == "color" then
        local values = OptionsPanel:Values(s)
        local x = -14
        for k = #row.swatches, 1, -1 do
            local sw = row.swatches[k]
            local value = values[k]
            if value then
                local c = OptionsPanel.ACCENTS[value] or { r = 1, g = 1, b = 1 }
                sw._value = value
                sw.fill:SetColorTexture(c.r, c.g, c.b, 1)
                if value == v then sw.ring:SetColorTexture(1, 1, 1, 0.9) else sw.ring:SetColorTexture(0, 0, 0, 0) end
                sw._selected = value == v
                anchor(sw, "RIGHT", row, "RIGHT", x, 0)
                x = x - 30
                sw:Show()
            end
        end
        anchor(row.value, "RIGHT", row, "RIGHT", x - 4, 0)
        row.value:SetText(OptionsPanel:FormatValue(s, v))
        row.value:Show()
    elseif s.kind == "choice" then
        row.dropdown.label:SetText(OptionsPanel:FormatValue(s, v))
        row.dropdown:Show()
    elseif s.kind == "range" then
        local sl = row.slider
        sl._updating = true
        if sl.SetMinMaxValues then sl:SetMinMaxValues(s.min, s.max) end
        if sl.SetValueStep then sl:SetValueStep(s.step) end
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        if sl.SetValue then sl:SetValue(v) end
        sl._value = v
        sl._updating = false
        S:Paint(sl.track, "border", 1)
        S:Paint(sl.fill, "accent", 1)
        S:Paint(sl.thumb, "accent", 1)
        local frac = (s.max > s.min) and (v - s.min) / (s.max - s.min) or 0
        sl.fill:SetSize(math.max(1, math.floor((CONTROL_W - 50) * frac + 0.5)), 4)
        sl:Show()
        anchor(row.value, "RIGHT", row, "RIGHT", -14, 0)
        if row.value.SetWidth then row.value:SetWidth(44) end
        row.value:SetText(OptionsPanel:FormatValue(s, v))
        row.value:Show()
    elseif s.kind == "button" then
        row.action.label:SetText(L(s.button, "Run"))
        row.action:Show()
    end
    row:Show()
end

function Page:Render()
    if not self.side then return end
    local S = AR.Skins
    local m = self.module
    S:Paint(self.side.bg, "panelRaised", 1)
    S:Paint(self.main.bg, "panel", 1)
    S:Paint(self.main.footer, "divider")
    if self.main.pageText.SetTextColor then self.main.pageText:SetTextColor(S:RGBA("textMuted")) end

    local cats = m:GetCategories()
    local known = false
    for _, c in ipairs(cats) do if c.id == self.category then known = true end end
    if not known then self.category = cats[1] and cats[1].id end
    local searching = (m.query or "") ~= ""
    for i, b in ipairs(self.cats) do
        local c = cats[i]
        if c then
            b._id = c.id
            b.label:SetText(c.label)
            b.tag:SetText(tostring(m:CountCategory(c.id)))
            setSelected(b, not searching and c.id == self.category)
            b:Show()
        else
            b:Hide()
        end
    end

    local rows = m:GetRows(self.category) or {}
    self.lastRows = rows
    local maxPage = math.max(0, math.ceil(#rows / ROWS) - 1)
    self.page = math.max(0, math.min(self.page or 0, maxPage))
    for i, row in ipairs(self.rows) do
        local r = rows[self.page * ROWS + i]
        row._row = r
        if r then
            self:RenderRow(row, r.data)
        else
            row._setting = nil
            row:Hide()
        end
    end
    self.main.pageText:SetText(string.format("%d / %d", self.page + 1, maxPage + 1))
    local paged = maxPage > 0
    for _, region in ipairs({ self.prevButton, self.nextButton, self.main.pageText }) do
        if paged then region:Show() else region:Hide() end
    end

    self.primary.label:SetText(L("UI_OPT_RESET_GROUP", "Reset group"))
    if searching or self.category == "profiles" then self.primary:Hide() else self.primary:Show() end
    self.secondary.label:SetText(L("UI_OPT_RELOAD", "Reload UI"))
    self.secondary:Show()

    local menu = AR.GuideMenu
    if menu and menu.headerText then menu.headerText:SetText(m:HeaderTitle()) end
    if menu and menu.headerSub then menu.headerSub:SetText(m:HeaderSub(#rows)) end
end

-- The row showing setting `key` on the current page (tests and gamepad).
function Page:RowFor(key)
    for _, row in ipairs(self.rows) do
        if row:IsShown() and row._setting and row._setting.key == key then return row end
    end
    return nil
end

function OptionsPanel:Attach(frame)
    if self.panel then return self.panel end
    self.panel = setmetatable({ module = self, category = nil, page = 0, rows = {}, cats = {} }, Page)
    self.panel:Attach(frame, "AzerothRouteOptions")
    return self.panel
end

return OptionsPanel
