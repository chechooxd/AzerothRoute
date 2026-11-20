-- AzerothRoute: loot that starts a quest.
-- Items in the bags that begin a quest (from the generated database) are put on the item bar with
-- a glow until the quest is taken; quests already done, in the log, too high or for the other
-- faction are left out.

local AR = _G.AzerothRoute
local QuestLoot = { index = nil, _registered = false }
AR.QuestLoot = QuestLoot

function QuestLoot:Reset()
    self.index = nil
end

-- itemID -> questID for every quest that starts from an item (built once).
function QuestLoot:GetIndex()
    if self.index then return self.index end
    local idx = {}
    for qid, raw in pairs((AR.DB and AR.DB.Quests) or {}) do
        local starts = raw:match("^[^^]*%^[^^]*%^[^^]*%^([^^]*)") or ""
        for iid in starts:gmatch("I(%d+)") do idx[tonumber(iid)] = qid end
    end
    self.index = idx
    return idx
end

local function bagItemID(bag, slot)
    local C = _G.C_Container
    if C and C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then return info.itemID end
    end
    if C and C.GetContainerItemID then return C.GetContainerItemID(bag, slot) end
    if _G.GetContainerItemID then return _G.GetContainerItemID(bag, slot) end
    return nil
end

local function numSlots(bag)
    local C = _G.C_Container
    if C and C.GetContainerNumSlots then return C.GetContainerNumSlots(bag) or 0 end
    if _G.GetContainerNumSlots then return _G.GetContainerNumSlots(bag) or 0 end
    return 0
end

-- True when the player can take `quest` now (not done, not in the log, level and faction fit).
function QuestLoot:CanTake(quest)
    if not quest then return false end
    local QT = AR.QuestTracking
    if QT and (QT:IsCompleted(quest.id) or QT:IsInLog(quest.id)) then return false end
    local level = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    if level < (quest.minLevel or 0) then return false end
    return AR.DB:IsForPlayer(quest.side)
end

-- Quest-starting items in the bags: { { itemID, questID, quest = name } }, one per item.
function QuestLoot:GetStartItems()
    local idx, out, seen = self:GetIndex(), {}, {}
    for bag = 0, 4 do
        for slot = 1, numSlots(bag) do
            local iid = bagItemID(bag, slot)
            local qid = iid and idx[iid]
            if qid and not seen[iid] then
                seen[iid] = true
                local q = AR.DB:GetQuest(qid)
                if self:CanTake(q) then
                    out[#out + 1] = { itemID = iid, questID = qid, quest = q.name }
                end
            end
        end
    end
    return out
end

function QuestLoot:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    local function refresh()
        if AR.ActionBar and AR.ActionBar.UpdateFromCurrentStep then AR.ActionBar:UpdateFromCurrentStep() end
    end
    AR.Events:RegisterEvent("BAG_UPDATE_DELAYED", refresh)
    AR.Events:RegisterEvent("QUEST_LOG_UPDATE", refresh)
end

return QuestLoot
