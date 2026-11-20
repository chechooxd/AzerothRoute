-- AzerothRoute: the Target button. A named secure action button ("AzerothRouteTargetButton") whose
-- macrotext targets the current step's enemies and NPCs. Press it with the mouse or with its key
-- binding (Key Bindings > AzerothRoute, "CLICK AzerothRouteTargetButton:LeftButton").
--
-- It never edits account macros: the addon only sets the button's own attributes, and every
-- attribute, Show/Hide or move waits out combat lockdown (PLAYER_REGEN_ENABLED) instead of
-- touching a protected frame in a fight.

local AR = _G.AzerothRoute
local TargetMacro = {
    BUTTON_NAME = "AzerothRouteTargetButton",
    -- The account macro older versions created; rewritten once to point at the button.
    NAME = "ARTargeting",
    ICON = "Interface\\Icons\\Ability_Hunter_SniperShot",
    SIZE = 36,
    MAX_BODY = 1023,
    pending = false,
    lastBody = nil,
    button = nil,
}
AR.TargetMacro = TargetMacro

local function inCombat()
    return _G.InCombatLockdown and _G.InCombatLockdown()
end

local function L(key, fallback)
    local v = AR.L and AR.L:Get(key)
    if v == nil or v == key then return fallback end
    return v
end

function TargetMacro:Reset()
    self.pending = false
    self.lastBody = nil
    self.legacyDone = nil
end

function TargetMacro:IsEnabled()
    return not (AR.db and AR.db.profile and AR.db.profile.targetmacro == false)
end

function TargetMacro:GetMarkerLines()
    if AR.ActionBar and AR.ActionBar.raidMarkBlocked then
        return ""
    end
    if AR.db and AR.db.profile and AR.db.profile.automark == false then
        return ""
    end
    local forever = AR.ActionBar and AR.ActionBar:IsForeverClient()
    -- "!" sets the skull without toggling it off on repeated presses (Forever).
    return string.format("/tm [harm,nodead] %s\n/tm [help,nodead] 1", forever and "!8" or "8")
end

-- The button's macro: enemies first, then NPCs, the first living match wins.
-- Out of combat it starts from no target, so a target that is none of the names (the quest giver
-- just turned in to) cannot stop the chain; in combat the target is kept so swings are not cut.
-- After each name a corpse is dropped, and later names are only tried while nothing is targeted.
-- Returns nil when there is nothing to target.
function TargetMacro:BuildBody(targets)
    local order = {}
    for _, t in ipairs(targets or {}) do
        if t.enemy then order[#order + 1] = t.name end
    end
    for _, t in ipairs(targets or {}) do
        if not t.enemy then order[#order + 1] = t.name end
    end
    if #order == 0 then return nil end

    local markerLines = self:GetMarkerLines()
    local suffix = (markerLines ~= "") and ("\n" .. markerLines) or ""
    local function build(n)
        local lines = { "/cleartarget [nocombat]" }
        for i = 1, n do
            lines[#lines + 1] = (i == 1 and "/targetexact " or "/targetexact [noexists] ") .. order[i]
            lines[#lines + 1] = "/cleartarget [dead]"
        end
        return table.concat(lines, "\n") .. suffix
    end
    -- Drop the lowest-priority (last) names until the text fits.
    local n = #order
    local body = build(n)
    while n > 1 and #body > self.MAX_BODY do
        n = n - 1
        body = build(n)
    end
    return body, order
end

local function savePosition(b)
    if not (AR.db and AR.db.profile) or not b.GetPoint then return end
    local point, _, relPoint, x, y = b:GetPoint()
    if point then AR.db.profile.targetbuttonpos = { point, relPoint or point, x or 0, y or 0 } end
end

local function placeButton(b)
    if not b.ClearAllPoints then return end
    b:ClearAllPoints()
    local pos = AR.db and AR.db.profile and AR.db.profile.targetbuttonpos
    if type(pos) == "table" and pos[1] then
        b:SetPoint(pos[1], _G.UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    else
        b:SetPoint("CENTER", _G.UIParent, "CENTER", 0, -180)
    end
end

-- Creates the secure button (once). A /reload in combat may run this under lockdown: the frame
-- itself may be created then, and its attributes are applied when combat ends.
function TargetMacro:GetButton()
    if self.button then return self.button end
    if not _G.CreateFrame then return nil end
    local b = _G.CreateFrame("Button", self.BUTTON_NAME, _G.UIParent, "SecureActionButtonTemplate")
    b:SetSize(self.SIZE, self.SIZE)
    if b.SetFrameStrata then b:SetFrameStrata("MEDIUM") end
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    if b.SetMovable then b:SetMovable(true) end
    if b.SetClampedToScreen then b:SetClampedToScreen(true) end
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton") end

    if b.CreateTexture then
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        b.bg:SetColorTexture(0.06, 0.07, 0.10, 0.92)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.icon:SetSize(self.SIZE - 6, self.SIZE - 6)
        b.icon:SetTexture(self.ICON)
        if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        if AR.Skins and AR.Skins.AddBorder then AR.Skins:AddBorder(b, "border") end
    end
    if b.CreateFontString then
        b.nameText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.nameText:SetPoint("LEFT", b, "RIGHT", 6, 0)
        b.nameText:SetJustifyH("LEFT")
        b.nameText:SetText("")
        b.hotkey = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
        b.hotkey:SetText("")
    end

    -- A mouse click acts on its release: hovering sets useOnKeyDown to false (out of combat), and
    -- leaving gives the key binding back to the client's ActionButtonUseKeyDown setting.
    b:SetScript("OnEnter", function(btn)
        if not inCombat() then btn:SetAttribute("useOnKeyDown", false) end
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            _G.GameTooltip:AddLine(L("UI_TARGET_BUTTON", "Target"))
            for i, name in ipairs(btn.names or {}) do
                _G.GameTooltip:AddLine(string.format("%d. %s", i, name), 1, 1, 1)
            end
            _G.GameTooltip:AddLine(L("UI_TARGET_BUTTON_HINT", "Shift-drag to move. Bind a key in Key Bindings > AzerothRoute."), 0.7, 0.7, 0.7, true)
            _G.GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(btn)
        if not inCombat() then btn:SetAttribute("useOnKeyDown", nil) end
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    b:SetScript("OnDragStart", function(btn)
        if inCombat() then return end
        if _G.IsShiftKeyDown and not _G.IsShiftKeyDown() then return end
        if btn.StartMoving then btn:StartMoving() end
    end)
    b:SetScript("OnDragStop", function(btn)
        if btn.StopMovingOrSizing then btn:StopMovingOrSizing() end
        savePosition(btn)
    end)

    placeButton(b)
    if not inCombat() then b:Hide() end
    self.button = b
    return b
end

function TargetMacro:RefreshHotkey()
    local b = self.button
    if not (b and b.hotkey) then return end
    local key = _G.GetBindingKey and _G.GetBindingKey("CLICK " .. self.BUTTON_NAME .. ":LeftButton")
    b.hotkey:SetText(type(key) == "string" and key or "")
end

-- Older versions kept an "ARTargeting" account macro up to date. It is rewritten once to a note
-- (never again edited), so the addon stops calling macro APIs.
function TargetMacro:RetireLegacyMacro()
    if self.legacyDone or inCombat() then return end
    self.legacyDone = true
    if not (_G.GetMacroInfo and _G.EditMacro) then return end
    local name, _, body = _G.GetMacroInfo(self.NAME)
    if not name then return end
    local note = "//AzerothRoute: " .. L("UI_TARGET_MACRO_RETIRED", "use the Target button; bind it in Key Bindings > AzerothRoute")
    note = note:sub(1, 255)
    if body ~= note then _G.EditMacro(self.NAME, self.NAME, nil, note) end
end

-- Applies the current step's targets to the button. Returns true when applied, false when
-- deferred to the end of combat or unavailable.
function TargetMacro:Update()
    local b = self:GetButton()
    if inCombat() then
        self.pending = true
        return false
    end
    self:RetireLegacyMacro()
    if not b then return false end

    local body, names
    if self:IsEnabled() then
        local targets = (AR.ActionBar and AR.ActionBar:GetStepTargets()) or {}
        body, names = self:BuildBody(targets)
    end
    if b:GetAttribute("macrotext") ~= body then
        b:SetAttribute("type", body and "macro" or nil)
        b:SetAttribute("macrotext", body)
    end
    b.names = names
    if b.nameText then b.nameText:SetText((names and names[1]) or "") end
    if body then b:Show() else b:Hide() end
    self:RefreshHotkey()
    self.lastBody = body
    self.pending = false
    return true
end

function TargetMacro:OnCombatEnd()
    if self.pending then
        self:Update()
    end
end

return TargetMacro
