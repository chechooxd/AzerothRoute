-- AzerothRoute: QuestChains Graph & Smart Injection System (SIS) (SPEC-03)

local AR = _G.AzerothRoute
local Chains = {
    prereqs = {},      -- { [questID] = { prereqID1, ... } }
    followups = {},    -- { [questID] = { nextID1, ... } }
    breadcrumbs = {},  -- { [questID] = { invalidatingQuestID1, ... } }
    siblings = {},     -- { [questID] = { exclusiveQuestID1, ... } }
}
AR.Chains = Chains

function Chains:Reset()
    self.prereqs = {}
    self.followups = {}
    self.breadcrumbs = {}
    self.siblings = {}
end

function Chains:RegisterChain(questID, spec)
    questID = tonumber(questID)
    if not questID or not spec then return end
    if spec.prereqs then
        self.prereqs[questID] = spec.prereqs
        for _, pre in ipairs(spec.prereqs) do
            self.followups[pre] = self.followups[pre] or {}
            table.insert(self.followups[pre], questID)
        end
    end
    if spec.breadcrumbs then
        self.breadcrumbs[questID] = spec.breadcrumbs
    end
    if spec.siblings then
        self.siblings[questID] = spec.siblings
    end
end

function Chains:IsQuestPossible(questID)
    questID = tonumber(questID)
    if not questID then return false end
    -- Check mutually exclusive siblings
    local sibs = self.siblings[questID]
    if sibs then
        for _, s in ipairs(sibs) do
            if AR.Compat:IsQuestCompleted(s) then
                return false
            end
        end
    end
    -- Check breadcrumbs invalidated by later quests
    local bcs = self.breadcrumbs[questID]
    if bcs then
        for _, b in ipairs(bcs) do
            if AR.Compat:IsQuestCompleted(b) then
                return false
            end
        end
    end
    -- Check prerequisites
    local reqs = self.prereqs[questID]
    if reqs then
        for _, req in ipairs(reqs) do
            if not AR.Compat:IsQuestCompleted(req) then
                return false
            end
        end
    end
    return true
end

function Chains:FindStartingPoint(guide)
    if not guide or not guide.steps then return 1 end
    for _, step in ipairs(guide.steps) do
        if not step.is_sticky and step:IsVisible() then
            local done = step:IsComplete()
            if not done then
                return step.num
            end
        end
    end
    return #guide.steps
end

return Chains
