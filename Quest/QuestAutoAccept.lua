-- AzerothRoute: Modifier-Safe Dialog Automation & Native Event Hooks (SPEC-04 / SPEC-16)

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

function QuestAutoAccept:OnQuestDetail()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    if qid and self:ShouldAutoAccept(qid) and _G.AcceptQuest then
        _G.AcceptQuest()
    end
end

function QuestAutoAccept:OnQuestProgress()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    if qid and self:ShouldAutoTurnIn(qid) then
        if not _G.IsQuestCompletable or _G.IsQuestCompletable() then
            if _G.CompleteQuest then
                _G.CompleteQuest()
            end
        end
    end
end

function QuestAutoAccept:OnQuestComplete()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    if not qid or not self:ShouldAutoTurnIn(qid) then return end

    local numChoices = (_G.GetNumQuestChoices and _G.GetNumQuestChoices()) or 0
    if numChoices <= 1 then
        if _G.GetQuestReward then
            _G.GetQuestReward(numChoices == 1 and 1 or nil)
        end
        return
    end

    if AR.db and AR.db.global and AR.db.global.autoselectreward ~= false and AR.QuestReward and _G.GetQuestItemLink then
        local links = {}
        for i = 1, numChoices do
            table.insert(links, _G.GetQuestItemLink("choice", i) or "")
        end
        local pick = AR.QuestReward:SelectBestReward(links)
        if pick and pick.index and _G.GetQuestReward then
            _G.GetQuestReward(pick.index)
        end
    end
end

function QuestAutoAccept:RegisterLiveEvents()
    if not AR.Events then return end
    AR.Events:RegisterEvent("QUEST_DETAIL", function()
        self:OnQuestDetail()
    end)
    AR.Events:RegisterEvent("QUEST_PROGRESS", function()
        self:OnQuestProgress()
    end)
    AR.Events:RegisterEvent("QUEST_COMPLETE", function()
        self:OnQuestComplete()
    end)
end

return QuestAutoAccept
