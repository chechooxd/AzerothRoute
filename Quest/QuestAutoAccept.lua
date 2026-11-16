-- AzerothRoute: Modifier-Safe Dialog Automation & Native Gossip/Greeting/Quest Hooks (SPEC-04 / SPEC-16 / SPEC-22)

local AR = _G.AzerothRoute
local QuestAutoAccept = {
    lastDeclineTime = -999,
    blacklist = {},
    _liveRegistered = false,
}
AR.QuestAutoAccept = QuestAutoAccept

function QuestAutoAccept:Reset()
    self.lastDeclineTime = -999
    self.blacklist = {}
    self._liveRegistered = false
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

local function goalMatchesQuest(g, action, questID, questTitle)
    if g.action ~= action then return false end
    if questID and g.questid == questID then
        return true
    end
    if questTitle and questTitle ~= "" then
        local lowerTitle = tostring(questTitle):lower()
        if g.quest and tostring(g.quest):lower() == lowerTitle then
            return true
        end
        if g.questid and AR.Localizers and AR.Localizers.GetTranslatedQuest then
            local loc = AR.Localizers:GetTranslatedQuest(g.questid, g.quest)
            if loc and tostring(loc):lower() == lowerTitle then
                return true
            end
        end
    end
    return false
end

function QuestAutoAccept:IsQuestInCurrentGuide(action, questID, questTitle)
    local guide = AR.Progression and AR.Progression.currentGuide
    if not guide or not guide.steps then return false, false end
    for _, step in ipairs(guide.steps) do
        for _, g in ipairs(step.goals or {}) do
            if goalMatchesQuest(g, action, questID, questTitle) then
                return true, g.noautoaccept == true
            end
        end
    end
    return false, false
end

function QuestAutoAccept:ShouldAutoAccept(questID, questTitle)
    if self:IsLockedOut(questID) then return false end
    if AR.db and AR.db.profile and AR.db.profile.autoaccept == false then
        return false
    end
    for _, g in ipairs(self:GetActiveStepAndStickyGoals()) do
        if goalMatchesQuest(g, "accept", questID, questTitle) then
            return not g.noautoaccept
        end
    end
    local inGuide, blocked = self:IsQuestInCurrentGuide("accept", questID, questTitle)
    if inGuide then
        return not blocked
    end
    if AR.db and AR.db.profile and AR.db.profile.autoacceptall == true then
        return true
    end
    return false
end

function QuestAutoAccept:ShouldAutoTurnIn(questID, questTitle)
    if self:IsLockedOut(questID) then return false end
    if AR.db and AR.db.profile and AR.db.profile.autoturnin == false then
        return false
    end
    for _, g in ipairs(self:GetActiveStepAndStickyGoals()) do
        if goalMatchesQuest(g, "turnin", questID, questTitle) then
            return not g.noautoaccept
        end
    end
    local inGuide, blocked = self:IsQuestInCurrentGuide("turnin", questID, questTitle)
    if inGuide then
        return not blocked
    end
    if AR.db and AR.db.profile and AR.db.profile.autoacceptall == true then
        return true
    end
    return false
end

function QuestAutoAccept:OnGossipShow()
    if self:IsLockedOut(nil) or not _G.C_GossipInfo then return false end
    if _G.C_GossipInfo.GetActiveQuests and _G.C_GossipInfo.SelectActiveQuest then
        for _, q in ipairs(_G.C_GossipInfo.GetActiveQuests() or {}) do
            if q and q.questID and (q.isComplete or (AR.Compat and AR.Compat.IsQuestComplete and AR.Compat:IsQuestComplete(q.questID))) then
                if self:ShouldAutoTurnIn(q.questID, q.title) then
                    _G.C_GossipInfo.SelectActiveQuest(q.questID)
                    return true
                end
            end
        end
    end
    if _G.C_GossipInfo.GetAvailableQuests and _G.C_GossipInfo.SelectAvailableQuest then
        for _, q in ipairs(_G.C_GossipInfo.GetAvailableQuests() or {}) do
            if q and q.questID and self:ShouldAutoAccept(q.questID, q.title) then
                _G.C_GossipInfo.SelectAvailableQuest(q.questID)
                return true
            end
        end
    end
    return self:SelectTaxiGossipForPendingFlightPath()
end

QuestAutoAccept.TAXI_GOSSIP_ICON = 132057

-- Opening the flight map at the flight master lets TAXIMAP_OPENED record known nodes, which is the
-- only way the Classic client exposes them. Mirrors RXPGuides' SelectGossipType("taxi").
function QuestAutoAccept:SelectTaxiGossipForPendingFlightPath()
    local gossip = _G.C_GossipInfo
    if not gossip or not gossip.GetOptions or not gossip.SelectOption then return false end
    if not AR.TaxiTracker or #AR.TaxiTracker:GetPendingFlightGoals() == 0 then return false end
    for _, option in ipairs(gossip.GetOptions() or {}) do
        if option.gossipOptionID and (option.type == "taxi" or option.icon == self.TAXI_GOSSIP_ICON) then
            gossip.SelectOption(option.gossipOptionID)
            return true
        end
    end
    return false
end

function QuestAutoAccept:OnQuestGreeting()
    if self:IsLockedOut(nil) then return false end
    if _G.GetNumActiveQuests and _G.SelectActiveQuest then
        for i = 1, (_G.GetNumActiveQuests() or 0) do
            local title, isComplete = _G.GetActiveTitle and _G.GetActiveTitle(i)
            local qid = _G.GetActiveQuestID and _G.GetActiveQuestID(i)
            if isComplete ~= false and self:ShouldAutoTurnIn(qid, title) then
                _G.SelectActiveQuest(i)
                return true
            end
        end
    end
    if _G.GetNumAvailableQuests and _G.SelectAvailableQuest then
        for i = 1, (_G.GetNumAvailableQuests() or 0) do
            local title = _G.GetAvailableTitle and _G.GetAvailableTitle(i)
            local qid
            if _G.GetAvailableQuestInfo then
                local _, _, _, _, id = _G.GetAvailableQuestInfo(i)
                qid = id
            end
            if self:ShouldAutoAccept(qid, title) then
                _G.SelectAvailableQuest(i)
                return true
            end
        end
    end
    return false
end

function QuestAutoAccept:OnQuestDetail()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    local qTitle = (_G.GetTitleText and _G.GetTitleText()) or nil
    if (qid or qTitle) and self:ShouldAutoAccept(qid, qTitle) and _G.AcceptQuest then
        _G.AcceptQuest()
    end
end

function QuestAutoAccept:OnQuestProgress()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    local qTitle = (_G.GetTitleText and _G.GetTitleText()) or nil
    if (qid or qTitle) and self:ShouldAutoTurnIn(qid, qTitle) then
        if not _G.IsQuestCompletable or _G.IsQuestCompletable() then
            if _G.CompleteQuest then
                _G.CompleteQuest()
            end
        end
    end
end

function QuestAutoAccept:OnQuestComplete()
    local qid = (_G.GetQuestID and _G.GetQuestID()) or nil
    local qTitle = (_G.GetTitleText and _G.GetTitleText()) or nil
    if (not qid and not qTitle) or not self:ShouldAutoTurnIn(qid, qTitle) then return end

    local numChoices = (_G.GetNumQuestChoices and _G.GetNumQuestChoices()) or 0
    if numChoices <= 1 then
        if _G.GetQuestReward then
            _G.GetQuestReward(numChoices == 1 and 1 or nil)
        end
        return
    end

    if AR.db and AR.db.profile and AR.db.profile.autoselectreward ~= false and AR.QuestReward and _G.GetQuestItemLink then
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
    if self._liveRegistered or not AR.Events then return end
    self._liveRegistered = true
    AR.Events:RegisterEvent("GOSSIP_SHOW", function()
        self:OnGossipShow()
    end)
    AR.Events:RegisterEvent("QUEST_GREETING", function()
        self:OnQuestGreeting()
    end)
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
