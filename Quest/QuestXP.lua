-- AzerothRoute: XP waiting in completed quests.
-- The client tells the reward XP of each quest in the log (GetQuestLogRewardXP). The XP of the
-- quests ready to hand in is drawn on the game's XP bar as a soft green stretch after the current
-- XP, the bar's tooltip gains "Pending quest XP" and "XP after turn-ins", and turn-in lines in the
-- guide window show "+N XP".

local AR = _G.AzerothRoute
local QuestXP = { total = 0, count = 0, byQuest = {}, _registered = false }
AR.QuestXP = QuestXP

local function enabled()
    return not (AR.db and AR.db.profile and AR.db.profile.questxp == false)
end

-- Reward XP of a quest in the log, or nil when the client cannot tell.
function QuestXP:RewardOf(questID)
    if self.byQuest[questID] then return self.byQuest[questID] end
    local fn = _G.GetQuestLogRewardXP
    if not fn then return nil end
    local ok, xp = pcall(fn, questID)
    if ok and type(xp) == "number" and xp > 0 then
        self.byQuest[questID] = xp
        return xp
    end
    return nil
end

-- Sums the reward XP of every completed quest in the log.
function QuestXP:Refresh()
    self.total, self.count = 0, 0
    self.byQuest = {}
    for qid, entry in pairs((AR.QuestTracking and AR.QuestTracking.questsById) or {}) do
        local xp = self:RewardOf(qid)
        if xp and entry.isComplete then
            self.total = self.total + xp
            self.count = self.count + 1
        end
    end
    self:Draw()
    return self.total, self.count
end

local function xpBar()
    return _G.MainMenuExpBar or (_G.MainStatusTrackingBarContainer and _G.MainStatusTrackingBarContainer.bars and _G.MainStatusTrackingBarContainer.bars[1])
end

-- Green stretch on the XP bar from the current XP to the XP after turn-ins.
function QuestXP:Draw()
    local bar = xpBar()
    if not bar or not bar.CreateTexture then return nil end
    if not self.overlay then
        self.overlay = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        self.overlay:SetColorTexture(0.36, 0.58, 0.31, 0.55)
        if bar.HookScript then
            bar:HookScript("OnEnter", function() self:AddTooltipLines(_G.GameTooltip) end)
        end
    end
    local cur = (_G.UnitXP and _G.UnitXP("player")) or 0
    local max = (_G.UnitXPMax and _G.UnitXPMax("player")) or 0
    local width = bar.GetWidth and bar:GetWidth() or 0
    if not enabled() or self.total <= 0 or max <= 0 or width <= 0 then
        self.overlay:Hide()
        return nil
    end
    local from = math.min(1, cur / max)
    local to = math.min(1, (cur + self.total) / max)
    if self.overlay.ClearAllPoints then self.overlay:ClearAllPoints() end
    self.overlay:SetPoint("TOPLEFT", bar, "TOPLEFT", width * from, 0)
    self.overlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", width * from, 0)
    self.overlay:SetWidth(math.max(1, width * (to - from)))
    self.overlay:Show()
    return from, to
end

-- Lines for the XP bar tooltip; returns how many were added.
function QuestXP:AddTooltipLines(tip)
    if not tip or not tip.AddDoubleLine or not enabled() or self.total <= 0 then return 0 end
    local L = AR.L
    local cur = (_G.UnitXP and _G.UnitXP("player")) or 0
    local max = (_G.UnitXPMax and _G.UnitXPMax("player")) or 1
    tip:AddDoubleLine((L and L:Get("UI_QXP_PENDING")) or "Pending quest XP",
        string.format("+%d (%.1f%%)", self.total, self.total / max * 100), 0.36, 0.58, 0.31, 0.36, 0.58, 0.31)
    tip:AddDoubleLine((L and L:Get("UI_QXP_COUNT")) or "Quests to hand in", tostring(self.count))
    local after = cur + self.total
    if after >= max then
        tip:AddLine((L and L:Get("UI_QXP_LEVELS")) or "Handing them in levels you up", 0.36, 0.58, 0.31)
    else
        tip:AddDoubleLine((L and L:Get("UI_QXP_AFTER")) or "XP after turn-ins",
            string.format("%d / %d (%.1f%%)", after, max, after / max * 100))
    end
    if tip.Show then tip:Show() end
    return 3
end

function QuestXP:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    for _, ev in ipairs({ "QUEST_LOG_UPDATE", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
        AR.Events:RegisterEvent(ev, function() self:Refresh() end)
    end
end

return QuestXP
