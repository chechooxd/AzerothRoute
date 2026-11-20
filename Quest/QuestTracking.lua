-- AzerothRoute: Reactive Quest Log & Server Completion Cache (SPEC-04 / SPEC-16)
-- Supports both native WoW C_QuestLog / GetQuestLogTitle APIs and headless MockWoW.quests.inLog.

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

local function parseLeaderboardText(text, finished)
    if not text then return 0, 1 end
    local curStr, reqStr = text:match(":%s*(%d+)%s*/%s*(%d+)%s*$")
    if not curStr then
        curStr, reqStr = text:match("(%d+)%s*/%s*(%d+)")
    end
    if curStr and reqStr then
        return tonumber(curStr) or 0, tonumber(reqStr) or 1
    end
    return finished and 1 or 0, 1
end

function QuestTracking:ScanNativeQuestLog(current)
    -- 1. Classic / Forever GetNumQuestLogEntries + GetQuestLogTitle path
    if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
        local numEntries = _G.GetNumQuestLogEntries() or 0
        for i = 1, numEntries do
            local title, level, suggestedGroup, isHeader, _, isComplete, _, questID = _G.GetQuestLogTitle(i)
            if not isHeader and questID and questID > 0 then
                local objs = {}
                local numObj = (_G.GetNumQuestLeaderBoards and _G.GetNumQuestLeaderBoards(i)) or 0
                for o = 1, numObj do
                    local desc, objType, done = _G.GetQuestLogLeaderBoard(o, i)
                    local cur, req = parseLeaderboardText(desc, done)
                    table.insert(objs, {
                        text = desc or "",
                        type = objType or "item",
                        finished = (done == true or done == 1),
                        numFulfilled = cur,
                        numRequired = req,
                    })
                end
                current[questID] = {
                    id = questID,
                    title = title or ("Quest " .. tostring(questID)),
                    level = level or 1,
                    isComplete = (isComplete == 1 or isComplete == true or (#objs > 0 and objs[1].finished)),
                    objectives = objs,
                    logIndex = i,
                    suggestedGroup = tonumber(suggestedGroup) or 0,
                    inlog = true,
                }
            end
        end
        return
    end

    -- 2. Modern C_QuestLog.GetInfo path
    if _G.C_QuestLog and _G.C_QuestLog.GetNumQuestLogEntries and _G.C_QuestLog.GetInfo then
        local numEntries = _G.C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, numEntries do
            local info = _G.C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                local rawObjs = (_G.C_QuestLog.GetQuestObjectives and _G.C_QuestLog.GetQuestObjectives(info.questID)) or {}
                local objs = {}
                for _, ro in ipairs(rawObjs) do
                    table.insert(objs, {
                        text = ro.text or "",
                        type = ro.type or "item",
                        finished = ro.finished == true,
                        numFulfilled = ro.numFulfilled or 0,
                        numRequired = ro.numRequired or 1,
                    })
                end
                local complete = (_G.C_QuestLog.IsComplete and _G.C_QuestLog.IsComplete(info.questID)) or false
                current[info.questID] = {
                    id = info.questID,
                    title = info.title or ("Quest " .. tostring(info.questID)),
                    level = info.level or 1,
                    isComplete = complete,
                    objectives = objs,
                    logIndex = i,
                    inlog = true,
                }
            end
        end
    end
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
    else
        self:ScanNativeQuestLog(current)
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
            if _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.completed then
                _G.MockWoW.quests.completed[lost.id] = true
            end
            self.recentlyLostQuests[title] = nil
            if AR.Progression then
                AR.Progression:TryToCompleteStep(true)
            end
        end
    end
end

function QuestTracking:RegisterLiveEvents()
    if not AR.Events then return end
    AR.Events:RegisterEvent("QUEST_LOG_UPDATE", function()
        self:ScanQuestLog()
        if AR.Progression then
            AR.Progression:TryToCompleteStep(false)
        end
        if AR.ViewerFrame and AR.ViewerFrame.RefreshVisuals then
            AR.ViewerFrame:RefreshVisuals()
        end
    end)
    AR.Events:RegisterEvent("QUEST_WATCH_LIST_CHANGED", function()
        self:ScanQuestLog()
    end)
    AR.Events:RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg)
        self:OnSystemChatMessage(msg)
    end)
end

return QuestTracking
