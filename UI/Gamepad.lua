-- AzerothRoute: gamepad navigation.
-- While an AzerothRoute window that takes focus is open (a popup menu or the Guide Center) and
-- a gamepad is enabled, the D-pad, A, B and the shoulders are bound to it through temporary
-- override bindings (set and cleared out of combat):
--   D-pad up/down  move within a column      D-pad left/right  move between columns
--   A              press the focused button  B                 close the menu / window
--   LB / RB        previous / next Guide Center tab
-- A gold frame marks the focused button. Outside these windows the pad is the game's again; the
-- addon's key bindings (next step, guide window, ...) can be put on pad buttons in Key Bindings.

local AR = _G.AzerothRoute
local Gamepad = {
    KEYS = {
        PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right",
        PAD1 = "a", PAD2 = "b", PADLSHOULDER = "lb", PADRSHOULDER = "rb",
    },
    active = nil,   -- "menu" | "guidecenter" | nil
    col = 1, row = 1,
    buttons = {},
}
AR.Gamepad = Gamepad

function Gamepad:Reset()
    self:Deactivate()
    self.col, self.row = 1, 1
end

function Gamepad:IsEnabled()
    if AR.db and AR.db.profile and AR.db.profile.gamepad == false then return false end
    local G = _G.C_GamePad
    return G ~= nil and G.IsEnabled ~= nil and G.IsEnabled() == true
end

local function shown(b) return b ~= nil and b.IsShown and b:IsShown() end

-- Which window should hold the pad now.
function Gamepad:Target()
    if AR.UI and shown(AR.UI.menu) then return "menu" end
    if AR.GuideMenu and shown(AR.GuideMenu.frame) then return "guidecenter" end
    return nil
end

local function visible(list)
    local out = {}
    for _, b in ipairs(list or {}) do if shown(b) then out[#out + 1] = b end end
    return out
end

-- Focusable buttons of the active window, as columns (left to right).
function Gamepad:Columns()
    if self.active == "menu" then
        local items = {}
        for _, b in ipairs((AR.UI.menu and AR.UI.menu.buttons) or {}) do
            if shown(b) and not b._disabled then items[#items + 1] = b end
        end
        return { items }
    end
    if self.active == "guidecenter" then
        local GM = AR.GuideMenu
        local module = GM:ModeModule()
        local cols = { visible(GM.modeButtons) }
        if module and module.panel then
            local p = module.panel
            cols[#cols + 1] = visible(p.cats)
            cols[#cols + 1] = visible(p.rows)
            local details = visible(p.list)
            for _, b in ipairs({ p.primary, p.secondary }) do if shown(b) then details[#details + 1] = b end end
            cols[#cols + 1] = details
        else
            cols[#cols + 1] = visible(GM.categoryButtons)
            cols[#cols + 1] = visible(GM.guideRowButtons)
            cols[#cols + 1] = visible({ GM.loadButton, GM.talentButton, GM.deleteButton, GM.importButton })
        end
        local out = {}
        for _, c in ipairs(cols) do if #c > 0 then out[#out + 1] = c end end
        return out
    end
    return {}
end

function Gamepad:Focused()
    local cols = self:Columns()
    local c = cols[math.max(1, math.min(#cols, self.col))]
    return c and c[math.max(1, math.min(#c, self.row))] or nil
end

-- Gold frame around the focused button.
function Gamepad:DrawFocus()
    local S = AR.Skins
    if not self.focus then
        self.focus = AR.UI:Create("Frame", _G.UIParent, "AzerothRoutePadFocus")
        if self.focus.SetFrameStrata then self.focus:SetFrameStrata("TOOLTIP") end
        S:AddBorder(self.focus, "accent")
    end
    local b = self:Focused()
    if not b then self.focus:Hide() return nil end
    if self.focus.ClearAllPoints then self.focus:ClearAllPoints() end
    self.focus:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    self.focus:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    self.focus:Show()
    self.focused = b
    return b
end

-- Hidden named buttons the override bindings click (one per pad key).
function Gamepad:EnsureButtons()
    for key, action in pairs(self.KEYS) do
        if not self.buttons[key] then
            local b = _G.CreateFrame("Button", "AzerothRoutePad" .. key, _G.UIParent)
            b:SetScript("OnClick", function() self:Press(action) end)
            b:Hide()
            self.buttons[key] = b
        end
    end
end

function Gamepad:Activate(target)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    self:EnsureButtons()
    self.owner = self.owner or _G.CreateFrame("Frame", "AzerothRoutePadOwner", _G.UIParent)
    if _G.ClearOverrideBindings then _G.ClearOverrideBindings(self.owner) end
    if _G.SetOverrideBindingClick then
        for key in pairs(self.KEYS) do
            _G.SetOverrideBindingClick(self.owner, true, key, "AzerothRoutePad" .. key)
        end
    end
    self.active = target
    self.col, self.row = (target == "guidecenter") and 3 or 1, 1
    self:DrawFocus()
    return true
end

function Gamepad:Deactivate()
    if self.owner and _G.ClearOverrideBindings and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
        _G.ClearOverrideBindings(self.owner)
    end
    self.active = nil
    if self.focus then self.focus:Hide() end
end

-- Called every few frames: follows which window is open.
function Gamepad:Update()
    local target = self:IsEnabled() and self:Target() or nil
    if target ~= self.active then
        if target then self:Activate(target) else self:Deactivate() end
    elseif target then
        self:DrawFocus()
    end
    return self.active
end

function Gamepad:Press(action)
    local cols = self:Columns()
    if #cols == 0 then return nil end
    self.col = math.max(1, math.min(#cols, self.col))
    local col = cols[self.col]
    if action == "up" then self.row = math.max(1, self.row - 1)
    elseif action == "down" then self.row = math.min(#col, self.row + 1)
    elseif action == "left" or action == "right" then
        self.col = math.max(1, math.min(#cols, self.col + (action == "left" and -1 or 1)))
        self.row = math.min(self.row, #cols[self.col])
    elseif action == "a" then
        local b = self:Focused()
        if b and b.Click then b:Click("LeftButton") end
    elseif action == "b" then
        if self.active == "menu" then AR.UI:HideMenu()
        elseif self.active == "guidecenter" and AR.GuideMenu.frame then AR.GuideMenu.frame:Hide() end
    elseif (action == "lb" or action == "rb") and self.active == "guidecenter" then
        local GM, idx = AR.GuideMenu, 1
        for i, m in ipairs(GM.MODES) do if m.id == GM.mode then idx = i end end
        idx = (idx - 1 + (action == "rb" and 1 or -1)) % #GM.MODES + 1
        GM:SetMode(GM.MODES[idx].id)
        self.col, self.row = 3, 1
    end
    self:Update()
    return self:Focused()
end

function Gamepad:Start()
    if self._started or not AR.Events or not AR.Events.SubscribeUpdate then return end
    self._started = true
    AR.Events:SubscribeUpdate("AzerothRouteGamepad", 0.2, function() self:Update() end)
end

return Gamepad
