-- AzerothRoute: quest reward preview.
-- The database has no rewards, so they are recorded from the client: the quest offer window
-- (QUEST_DETAIL) and the quest log (for quests already taken). Records are shared by every
-- character in AR.db.global.questRewards[questID] = { choice = { itemIDs }, reward = { itemIDs } }.
-- The preview names the reward the guide would pick (the best upgrade, else the most valuable
-- choice, via AR.QuestReward) and marks upgrades as "new".

local AR = _G.AzerothRoute
local QuestRewards = { _registered = false }
AR.QuestRewards = QuestRewards

local function store()
    if not AR.db or not AR.db.global then return nil end
    AR.db.global.questRewards = AR.db.global.questRewards or {}
    return AR.db.global.questRewards
end

local function itemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function collect(count, linkOf)
    local ids = {}
    for i = 1, count or 0 do
        local id = itemIDFromLink(linkOf(i))
        if id then ids[#ids + 1] = id end
    end
    return ids
end

function QuestRewards:Get(questID)
    local db = store()
    return db and db[questID] or nil
end

function QuestRewards:Save(questID, choice, reward)
    local db = store()
    if not db or not questID or questID <= 0 then return nil end
    if #choice == 0 and #reward == 0 then return nil end
    db[questID] = { choice = choice, reward = reward }
    return db[questID]
end

-- Quest offer window: rewards are listed before accepting.
function QuestRewards:OnQuestDetail()
    local qid = _G.GetQuestID and _G.GetQuestID()
    if not qid or qid <= 0 or not _G.GetQuestItemLink then return nil end
    local choice = collect(_G.GetNumQuestChoices and _G.GetNumQuestChoices(), function(i) return _G.GetQuestItemLink("choice", i) end)
    local reward = collect(_G.GetNumQuestRewards and _G.GetNumQuestRewards(), function(i) return _G.GetQuestItemLink("reward", i) end)
    return self:Save(qid, choice, reward)
end

-- Quest log: reads rewards of quests taken without a recorded offer. The log selection is
-- restored afterwards so the open quest log does not jump.
function QuestRewards:ScanLog()
    local QT = AR.QuestTracking
    if not QT or not QT.questsById or not _G.SelectQuestLogEntry or not _G.GetQuestLogItemLink then return 0 end
    local db = store()
    if not db then return 0 end
    local previous = _G.GetQuestLogSelection and _G.GetQuestLogSelection() or 0
    local n = 0
    for qid, entry in pairs(QT.questsById) do
        if not db[qid] then
            local idx = entry.logIndex or (_G.GetQuestLogIndexByID and _G.GetQuestLogIndexByID(qid))
            if idx and idx > 0 then
                _G.SelectQuestLogEntry(idx)
                local choice = collect(_G.GetNumQuestLogChoices and _G.GetNumQuestLogChoices(), function(i) return _G.GetQuestLogItemLink("choice", i) end)
                local reward = collect(_G.GetNumQuestLogRewards and _G.GetNumQuestLogRewards(), function(i) return _G.GetQuestLogItemLink("reward", i) end)
                if self:Save(qid, choice, reward) then n = n + 1 end
            end
        end
    end
    _G.SelectQuestLogEntry(previous)
    return n
end

local function itemName(id)
    if _G.GetItemInfo then
        local name = _G.GetItemInfo(id)
        if name then return name end
    end
    local rec = AR.DB and AR.DB.GetItem and AR.DB:GetItem(id)
    return (rec and rec.name) or ("item:" .. id)
end

-- The reward the guide would take: { itemID, name, isUpgrade } or nil when nothing is known.
function QuestRewards:Preview(questID)
    local r = self:Get(questID)
    if not r then return nil end
    if #r.choice > 0 then
        local links = {}
        for i, id in ipairs(r.choice) do links[i] = "item:" .. id end
        local pick = AR.QuestReward and AR.QuestReward:SelectBestReward(links)
        local id = r.choice[(pick and pick.index) or 1]
        return { itemID = id, name = itemName(id), isUpgrade = pick ~= nil and pick.reason == "upgrade" }
    end
    if #r.reward > 0 then
        local id = r.reward[1]
        local eval = AR.Upgrades and AR.Upgrades.EvaluateCandidate and AR.Upgrades:EvaluateCandidate("item:" .. id)
        return { itemID = id, name = itemName(id), isUpgrade = eval ~= nil and eval.isUpgrade == true }
    end
    return nil
end

function QuestRewards:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    AR.Events:RegisterEvent("QUEST_DETAIL", function() self:OnQuestDetail() end)
    AR.Events:RegisterEvent("QUEST_ACCEPTED", function()
        if AR.QuestTracking and AR.QuestTracking.ScanQuestLog then AR.QuestTracking:ScanQuestLog() end
        self:ScanLog()
    end)
    AR.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:ScanLog() end)
end

return QuestRewards
