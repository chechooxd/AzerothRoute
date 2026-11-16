-- AzerothRoute: Dynamic Tooltip Localization Cache (SPEC-04)

local AR = _G.AzerothRoute
local Localizers = {
    npcCache = {},
    questCache = {}, -- { [questID] = { title = ..., timestamp = ... } }
    TTL_SECONDS = 1800,
}
AR.Localizers = Localizers

function Localizers:Reset()
    self.npcCache = {}
    self.questCache = {}
end

function Localizers:GetTranslatedNPC(npcID)
    npcID = tonumber(npcID)
    if not npcID then return nil end
    if self.npcCache[npcID] then
        return self.npcCache[npcID]
    end
    local mockTooltip = _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.npcs and _G.MockWoW.tooltips.npcs[npcID]
    if mockTooltip then
        self.npcCache[npcID] = mockTooltip
        AR.Events:SendMessage("AR_NPC_TRANSLATED", npcID, mockTooltip)
        return mockTooltip
    end
    return nil
end

function Localizers:GetQuestData(questID)
    questID = tonumber(questID)
    if not questID then return nil end
    local now = (_G.GetTime and _G.GetTime()) or 0
    local cached = self.questCache[questID]
    if cached and (now - cached.timestamp) <= self.TTL_SECONDS then
        return cached
    end
    local mockQuest = _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.quests and _G.MockWoW.tooltips.quests[questID]
    if mockQuest then
        local entry = { title = mockQuest.title, timestamp = now }
        self.questCache[questID] = entry
        return entry
    end
    return nil
end

function Localizers:PruneExpiredQuests()
    local now = (_G.GetTime and _G.GetTime()) or 0
    for qid, entry in pairs(self.questCache) do
        local inLog = AR.QuestTracking and AR.QuestTracking:IsInLog(qid)
        if not inLog and (now - entry.timestamp) > self.TTL_SECONDS then
            self.questCache[qid] = nil
        end
    end
end

return Localizers
