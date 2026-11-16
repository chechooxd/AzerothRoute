-- AzerothRoute: "ARTargeting" account macro (mirrors RXPGuides' RXPTargeting macro).
-- The player drags it to an action bar and binds a key; pressing it runs /targetexact for the
-- current step's NPCs and enemies and marks the result. Macro APIs are only touched out of combat.

local AR = _G.AzerothRoute
local TargetMacro = {
    NAME = "ARTargeting",
    ICON = "Ability_Hunter_SniperShot",
    MAX_BODY = 255,
    MAX_ACCOUNT_MACROS = 120,
    pending = false,
    lastBody = nil,
}
AR.TargetMacro = TargetMacro

local function inCombat()
    return _G.InCombatLockdown and _G.InCombatLockdown()
end

function TargetMacro:Reset()
    self.pending = false
    self.lastBody = nil
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
    -- "!" sets the skull without toggling it off on repeated presses (Forever, as RXPGuides does).
    return string.format("/tm [harm,nodead] %s\n/tm [help,nodead] 1", forever and "!8" or "8")
end

-- Later /targetexact lines win, so friendly NPCs go first and enemies last.
function TargetMacro:BuildBody(targets)
    local friendly, enemy = {}, {}
    for _, t in ipairs(targets or {}) do
        table.insert(t.enemy and enemy or friendly, "/targetexact " .. t.name)
    end
    local lines = {}
    for _, l in ipairs(friendly) do table.insert(lines, l) end
    for _, l in ipairs(enemy) do table.insert(lines, l) end

    if #lines == 0 then
        local text = (AR.L and AR.L:Get("UI_TARGET_MACRO_EMPTY")) or "No targets in the current step"
        return ("//AzerothRoute - " .. text):sub(1, self.MAX_BODY)
    end

    local markerLines = self:GetMarkerLines()
    local suffix = (markerLines ~= "") and ("\n" .. markerLines) or ""
    -- Drop the lowest-priority (first) lines until the body fits the client limit.
    while #lines > 1 and #table.concat(lines, "\n") + #suffix > self.MAX_BODY do
        table.remove(lines, 1)
    end
    return table.concat(lines, "\n") .. suffix
end

function TargetMacro:Announce()
    if not AR.db or not AR.db.global or AR.db.global.targetMacroAnnounced then return end
    AR.db.global.targetMacroAnnounced = true
    if AR.Print then
        local fmt = (AR.L and AR.L:Get("UI_TARGET_MACRO_CREATED")) or "Macro %s created: drag it to your action bar."
        AR:Print(string.format(fmt, self.NAME))
    end
end

-- Returns true when the macro holds the current step's targets, false when deferred or unavailable.
function TargetMacro:Update()
    if not self:IsEnabled() then return false end
    if inCombat() then
        self.pending = true
        return false
    end
    if not _G.GetMacroInfo or not _G.CreateMacro or not _G.EditMacro then return false end

    local targets = (AR.ActionBar and AR.ActionBar:GetStepTargets()) or {}
    local body = self:BuildBody(targets)

    local existing, _, currentBody = _G.GetMacroInfo(self.NAME)
    if not existing then
        local numAccount = _G.GetNumMacros and _G.GetNumMacros() or 0
        if numAccount >= self.MAX_ACCOUNT_MACROS then return false end
        _G.CreateMacro(self.NAME, self.ICON, body)
        self:Announce()
    elseif currentBody ~= body then
        _G.EditMacro(self.NAME, self.NAME, nil, body)
    end
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
