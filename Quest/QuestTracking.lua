-- AzerothRoute: Reactive Quest Log & Server Completion Cache (SPEC-04)

local AR = _G.AzerothRoute
local QuestTracking = {
    questsById = {},
    recentlyLostQuests = {}, -- { [title] = { id = qid, timestamp = sec } }
    explicitCompleted = {},
}
AR.QuestTracking = QuestTracking

function QuestTracking:Reset()
    self.questsById = {}
    self.recentlyLostQuests = {}
    self.explicitCompleted = {}
end

function QuestTracking:IsCompleted(questID)
    questID = tonumber(questID) or 0
    if self.explicitCompleted[questID] then
        return true
    end
    return AR.Compat:IsQuestCompleted(questID)
end

function QuestTracking:IsInLog(questID)
    return self.questsById[tonumber(questID) or 0] ~= nil
end

function QuestTracking:ScanQuestLog()
    local now = (_G.GetTime and _G.GetTime()) or 0
    local previous = self.questsById
    local current = {}

    local mockLog = _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog
    if mockLog then
        for qid, qData in pairs(mockLog) do
            current[qid] = {
                id = qid,
                title = qData.title or ("Quest " .. tostring(qid)),
                level = qData.level or 1,
                isComplete = qData.isComplete == true,
                objectives = qData.objectives or {},
                inlog = true,
            }
        end
    end

    -- Detect quests removed since last scan and store in 3.0s recentlyLostQuests buffer
    for qid, oldEntry in pairs(previous) do
        if not current[qid] and oldEntry.title then
            self.recentlyLostQuests[oldEntry.title] = {
                id = qid,
                timestamp = now,
            }
        end
    end

    -- Prune expired entries older than 3.0s
    for title, lost in pairs(self.recentlyLostQuests) do
        if (now - lost.timestamp) > 3.0 then
            self.recentlyLostQuests[title] = nil
        end
    end

    self.questsById = current
    return current
end

function QuestTracking:OnSystemChatMessage(msg)
    if not msg then return end
    local now = (_G.GetTime and _G.GetTime()) or 0
    for title, lost in pairs(self.recentlyLostQuests) do
        if (now - lost.timestamp) <= 3.0 and msg:find(title, 1, true) then
            self.explicitCompleted[lost.id] = true
            if _G.MockWoW and _G.MockWoW.quests then
                _G.MockWoW.quests.completed[lost.id] = true
            end
            self.recentlyLostQuests[title] = nil
            if AR.Progression then
                AR.Progression:TryToCompleteStep(true)
            end
        end
    end
end

return QuestTracking
