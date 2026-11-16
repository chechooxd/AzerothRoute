-- AzerothRoute: Stateless Step Model (SPEC-03)

local AR = _G.AzerothRoute
local Step = AR:Class("Step")
AR.Step = Step

function Step:IsVisible()
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

function Step:CanBeSticky()
    if not self.is_sticky then return false end
    if not self.goals then return false end
    for _, g in ipairs(self.goals) do
        if g.questid and g.action ~= "accept" then
            local inLog = (AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[g.questid] ~= nil)
                or (_G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog and _G.MockWoW.quests.inLog[g.questid] ~= nil)
            if not inLog and not g.future then
                return false
            end
        end
    end
    return true
end

function Step:CheckVisitedGotos()
    if not self.goals then return false end
    -- Flying over a waypoint on a taxi never counts as visiting it (Zygor rule).
    if _G.UnitOnTaxi and _G.UnitOnTaxi("player") then return false end
    local changed = false
    for _, g in ipairs(self.goals) do
        if g.action == "goto" and not g.visited and g:IsVisible() then
            if AR.Coords and g.map and g.x and g.y then
                local dist = AR.Coords:GetDistanceTo(g.map, g.x, g.y)
                if dist and dist <= (g.dist or 8) then
                    g.visited = true
                    changed = true
                end
            end
            break -- Check sequential inline gotos one at a time
        end
    end
    return changed
end

function Step:IsComplete()
    if not self:IsVisible() then
        return true, "hidden"
    end
    if not self.goals or #self.goals == 0 then
        return true, "empty"
    end

    local hasCompletable = false
    local allCompletableDone = true
    local hasPossible = false

    for _, g in ipairs(self.goals) do
        local status = g:GetStatus()
        if status ~= "hidden" and status ~= "passive" then
            hasCompletable = true
            if g.override and status == "complete" then
                return true, "override"
            end
            if g.confirm and status == "complete" then
                return true, "confirm"
            end
            if status ~= "complete" and not g.optional then
                allCompletableDone = false
                if status ~= "impossible" then
                    hasPossible = true
                end
            else
                hasPossible = true
            end
        end
    end

    if not hasCompletable then
        return false, "passive_only"
    end
    return allCompletableDone, hasPossible and "possible" or "impossible"
end

return Step
