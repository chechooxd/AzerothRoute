-- AzerothRoute: Stateless Goal Model & Fallthrough Status Evaluator (SPEC-03)
-- Invariant: Goal completion is computed live on every call (except opt-in |sticky saved goals).

local AR = _G.AzerothRoute
local Goal = AR:Class("Goal")
AR.Goal = Goal

local function getQuestLogEntry(questID)
    if not questID then return nil end
    if AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[questID] then
        return AR.QuestTracking.questsById[questID]
    end
    if _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog then
        return _G.MockWoW.quests.inLog[questID]
    end
    return nil
end

function Goal:IsVisible()
    if self.requirement and not AR.ConditionEnv:RaceClassMatch(self.requirement) then
        return false
    end
    if self.condition_visible then
        local ok, res = pcall(self.condition_visible)
        if not ok or not res then
            return false
        end
    end
    return true
end

function Goal:IsCompleteable()
    if self.force_nocomplete then return false end
    if self.force_complete or self.condition_complete or self.confirm then return true end
    if self.action == "text" or self.action == "info" or self.action == "tip" then
        return false
    end
    if self.action == "goto" then
        -- Goto is passive unless |c is set OR every visible goal in the step is goto (and this is the last one)
        local step = self.parentStep
        if not step or not step.goals then return false end
        local lastGoto = nil
        for _, g in ipairs(step.goals) do
            if g:IsVisible() then
                if g.action ~= "goto" then
                    return false
                end
                lastGoto = g
            end
        end
        return lastGoto == self
    end
    return true
end

function Goal:EvaluateLiveCompletion()
    -- 1. Opt-in saved sticky goal check
    if self.force_sticky_saved and AR.db and AR.db.char and AR.db.char.saved_sticky_goals then
        local key = string.format("%s:%d:%d", (self.parentStep and self.parentStep.parentGuide and self.parentStep.parentGuide.title) or "", (self.parentStep and self.parentStep.num) or 0, self.num or 0)
        if AR.db.char.saved_sticky_goals[key] then
            return true, true, false
        end
    end

    -- 2. Explicit complete condition expression
    if self.condition_complete then
        local ok, res = pcall(self.condition_complete)
        return ok and res == true, true, false
    end

    -- 3. Accept / Turnin quest actions
    if self.action == "accept" and self.questid then
        local completed = AR.Compat:IsQuestCompleted(self.questid)
        local inLog = getQuestLogEntry(self.questid) ~= nil
        local possible = true
        if AR.Chains and AR.Chains.IsQuestPossible and not completed and not inLog then
            possible = AR.Chains:IsQuestPossible(self.questid)
        end
        return (completed or inLog), possible, false
    elseif self.action == "turnin" and self.questid then
        local completed = AR.Compat:IsQuestCompleted(self.questid)
        if completed then
            return true, true, false
        end
        local qEntry = getQuestLogEntry(self.questid)
        if not qEntry then
            return false, false, false
        end
        if qEntry.isComplete == false then
            -- Warning (isbad): attempting to turn in a quest whose objectives are still incomplete!
            return false, true, true
        end
        return false, true, false
    end

    -- 4. Attached quest objective (|q questid/objnum)
    if self.questid then
        if AR.Compat:IsQuestCompleted(self.questid) then
            return true, true, false
        end
        local qEntry = getQuestLogEntry(self.questid)
        if not qEntry then
            if not self.future then
                return false, false, false
            end
        else
            if self.objnum and qEntry.objectives then
                local obj = qEntry.objectives[self.objnum]
                if not obj then
                    return false, true, true -- Missing objective data warning
                end
                if obj.finished or (obj.numRequired and obj.numRequired > 0 and (obj.numFulfilled or 0) >= obj.numRequired) then
                    return true, true, false
                end
                if not self.future then
                    return false, true, false
                end
            elseif qEntry.isComplete then
                return true, true, false
            end
        end
    end

    -- 5. Action-specific fallthrough handlers
    if self.action == "get" or self.action == "buy" or self.action == "collect" then
        if self.targetid then
            local needed = self.count or 1
            local have = AR.Compat:GetItemCount(self.targetid, false)
            return have >= needed, true, false
        end
    elseif self.action == "ding" then
        local playerLvl = (_G.UnitLevel and _G.UnitLevel("player")) or 1
        return playerLvl >= (self.level or 1), true, false
    elseif self.action == "learn" and self.spellid then
        local known = (_G.IsSpellKnown and _G.IsSpellKnown(self.spellid)) or false
        return known, true, false
    elseif self.action == "goto" then
        if self.visited then
            return true, true, false
        end
        if AR.Coords and self.map and self.x and self.y then
            local dist = AR.Coords:GetDistanceTo(self.map, self.x, self.y)
            if dist and dist <= (self.dist or 8) then
                self.visited = true
                return true, true, false
            end
        end
        return false, true, false
    elseif self.action == "confirm" then
        return self.confirmed == true, true, false
    end

    return false, true, false
end

function Goal:GetProgress()
    if self.questid and self.objnum then
        local qEntry = getQuestLogEntry(self.questid)
        if qEntry and qEntry.objectives and qEntry.objectives[self.objnum] then
            local obj = qEntry.objectives[self.objnum]
            return obj.numFulfilled or 0, obj.numRequired or (self.count or 1)
        end
    end
    if (self.action == "get" or self.action == "buy") and self.targetid then
        return AR.Compat:GetItemCount(self.targetid, false), self.count or 1
    end
    return nil, nil
end

function Goal:GetStatus()
    if not self:IsVisible() then
        return "hidden"
    end
    if not self:IsCompleteable() then
        return "passive"
    end
    local isComplete, isPossible, isBad = self:EvaluateLiveCompletion()
    if isComplete then
        if self.hidewhencomplete then
            return "hidden"
        end
        return "complete"
    end
    if isBad then
        return "warning"
    end
    if not isPossible then
        return "impossible"
    end
    return "incomplete"
end

function Goal:GetText()
    local cur, max = self:GetProgress()
    local suffix = ""
    if cur and max and max > 1 then
        suffix = string.format(" (%d/%d)", cur, max)
    end
    if self.action == "accept" then
        return string.format("Accept %s", self.quest or "Quest")
    elseif self.action == "turnin" then
        return string.format("Turn in %s", self.quest or "Quest")
    elseif self.action == "kill" then
        local rem = (cur and max) and math.max(0, max - cur) or (self.count or 1)
        if rem > 1 then
            return string.format("Kill %d %s%s", rem, self.target or "Mob", suffix)
        end
        return string.format("Kill %s%s", self.target or "Mob", suffix)
    elseif self.action == "get" or self.action == "buy" then
        local verb = (self.action == "buy") and "Buy" or "Collect"
        local rem = (cur and max) and math.max(0, max - cur) or (self.count or 1)
        if rem > 1 then
            return string.format("%s %d %s%s", verb, rem, self.target or "Item", suffix)
        end
        return string.format("%s %s%s", verb, self.target or "Item", suffix)
    elseif self.action == "talk" then
        return string.format("Talk to %s", self.target or "NPC")
    elseif self.action == "ding" then
        return string.format("Reach Level %d", self.level or 1)
    elseif self.action == "goto" then
        return string.format("Go to %.1f, %.1f", self.x or 0, self.y or 0)
    end
    return self.text or self.target or self.param or self.action or ""
end

return Goal
