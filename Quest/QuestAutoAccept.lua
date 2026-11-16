-- AzerothRoute: Modifier-Safe Dialog Automation (SPEC-04)

local AR = _G.AzerothRoute
local QuestAutoAccept = {
    lastDeclineTime = -999,
    blacklist = {},
}
AR.QuestAutoAccept = QuestAutoAccept

function QuestAutoAccept:Reset()
    self.lastDeclineTime = -999
    self.blacklist = {}
end

function QuestAutoAccept:OnManualDecline()
    self.lastDeclineTime = (_G.GetTime and _G.GetTime()) or 0
end

function QuestAutoAccept:IsLockedOut(questID)
    if _G.IsAltKeyDown and _G.IsAltKeyDown() then
        return true
    end
    local now = (_G.GetTime and _G.GetTime()) or 0
    if (now - self.lastDeclineTime) < 10.0 then
        return true
    end
    if questID and self.blacklist[questID] then
        return true
    end
    return false
end

function QuestAutoAccept:GetActiveStepAndStickyGoals()
    local goals = {}
    if not AR.Progression or not AR.Progression.currentStep then
        return goals
    end
    for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
        table.insert(goals, g)
    end
    for _, stickyStep in ipairs(AR.Progression:GetActiveStickies()) do
        for _, g in ipairs(stickyStep.goals or {}) do
            table.insert(goals, g)
        end
    end
    return goals
end

function QuestAutoAccept:ShouldAutoAccept(questID)
    if self:IsLockedOut(questID) then return false end
    if AR.db and AR.db.global and AR.db.global.autoaccept == false then
        return false
    end
    for _, g in ipairs(self:GetActiveStepAndStickyGoals()) do
        if g.action == "accept" and g.questid == questID and not g.noautoaccept then
            return true
        end
    end
    return false
end

function QuestAutoAccept:ShouldAutoTurnIn(questID)
    if self:IsLockedOut(questID) then return false end
    if AR.db and AR.db.global and AR.db.global.autoturnin == false then
        return false
    end
    for _, g in ipairs(self:GetActiveStepAndStickyGoals()) do
        if g.action == "turnin" and g.questid == questID and not g.noautoaccept then
            return true
        end
    end
    return false
end

return QuestAutoAccept
