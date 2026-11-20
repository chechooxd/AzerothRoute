-- AzerothRoute: group quests in the guide.
-- A quest counts as a group quest when the client says so (suggested group size above 1 in the
-- quest log or the quest offer) or when the database flags it (open-world elite objectives).
-- The player can skip it — its goals leave the route and the guide keeps to the solo path — or
-- keep it to do with a group. Both choices are saved per character.

local AR = _G.AzerothRoute
local GroupQuests = { _registered = false }
AR.GroupQuests = GroupQuests

local function charTable(key)
    if not AR.db or not AR.db.char then return nil end
    AR.db.char[key] = AR.db.char[key] or {}
    return AR.db.char[key]
end

local function learned()
    if not AR.db or not AR.db.global then return {} end
    AR.db.global.groupQuests = AR.db.global.groupQuests or {}
    return AR.db.global.groupQuests
end

-- Suggested group size the client reported for `questID` (quest log or offer), or 0.
function GroupQuests:SuggestedSize(questID)
    local entry = AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[questID]
    local fromLog = entry and tonumber(entry.suggestedGroup) or 0
    return math.max(fromLog, tonumber(learned()[questID]) or 0)
end

function GroupQuests:IsGroupQuest(questID)
    if not questID then return false end
    if self:SuggestedSize(questID) > 1 then return true end
    local q = AR.DB and AR.DB.GetQuest and AR.DB:GetQuest(questID)
    return q ~= nil and q.group == true
end

function GroupQuests:IsSkipped(questID)
    local t = AR.db and AR.db.char and AR.db.char.skippedQuests
    return t ~= nil and t[questID] == true
end

function GroupQuests:IsKept(questID)
    local t = AR.db and AR.db.char and AR.db.char.groupQuestsKept
    return t ~= nil and t[questID] == true
end

-- First group quest of `step` still waiting on a decision: { questID, name } or nil.
function GroupQuests:ForStep(step)
    for _, g in ipairs((step and step.goals) or {}) do
        local qid = g.questid
        if qid and not self:IsSkipped(qid) and not self:IsKept(qid) and self:IsGroupQuest(qid)
            and g:IsVisible() and g:GetStatus() ~= "complete" then
            local q = AR.DB and AR.DB:GetQuest(qid)
            local name = (q and q.name) or g.quest or ("Quest " .. qid)
            if AR.Localizers and AR.Localizers.GetTranslatedQuest then
                name = AR.Localizers:GetTranslatedQuest(qid, name) or name
            end
            return { questID = qid, name = name }
        end
    end
    return nil
end

-- Leaves the quest out of the route. When nothing else in the step remains to do, moves on.
function GroupQuests:Skip(questID)
    local t = charTable("skippedQuests")
    if not t then return false end
    t[questID] = true
    local P = AR.Progression
    if P and P.currentStep then
        local done = P:TryToCompleteStep(true)
        local step = P.currentStep
        if not done and step and step.IsComplete then
            local _, why = step:IsComplete()
            if why == "passive_only" then P:SkipStep(false) end
        end
    end
    return true
end

function GroupQuests:Keep(questID)
    local t = charTable("groupQuestsKept")
    if not t then return false end
    t[questID] = true
    return true
end

-- Undo a skip (the quest returns to the route).
function GroupQuests:Unskip(questID)
    local t = charTable("skippedQuests")
    if t then t[questID] = nil end
end

-- The quest offer window states the suggested group size before accepting.
function GroupQuests:OnQuestDetail()
    local qid = _G.GetQuestID and _G.GetQuestID()
    local n = _G.GetSuggestedGroupNum and _G.GetSuggestedGroupNum()
    if qid and qid > 0 and n and n > 1 then
        learned()[qid] = n
        if AR.ViewerFrame and AR.ViewerFrame.frame then AR.ViewerFrame:RefreshVisuals() end
    end
end

function GroupQuests:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    AR.Events:RegisterEvent("QUEST_DETAIL", function() self:OnQuestDetail() end)
end

return GroupQuests
