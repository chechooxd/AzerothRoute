-- AzerothRoute: TradeSkill & Recipe Cache + Crafting Executor (SPEC-07)

local AR = _G.AzerothRoute
local Professions = {
    SKILL_ID_BY_NAME = {
        Alchemy = 171,
        Blacksmithing = 164,
        Enchanting = 333,
        Engineering = 202,
        Herbalism = 182,
        Leatherworking = 165,
        Mining = 186,
        Skinning = 393,
        Tailoring = 197,
        Cooking = 185,
        FirstAid = 129,
        Fishing = 356,
    },
    NAME_BY_SKILL_ID = {},
}
for name, id in pairs(Professions.SKILL_ID_BY_NAME) do
    Professions.NAME_BY_SKILL_ID[id] = name
end
AR.Professions = Professions

function Professions:Reset()
    if AR.db and AR.db.char then
        AR.db.char.SkillsKnown = {}
        AR.db.char.RecipesKnown = {}
    end
end

function Professions:SetSkillLevel(skillNameOrID, rank, maxRank)
    if not AR.db or not AR.db.char then return end
    local name = tonumber(skillNameOrID) and self.NAME_BY_SKILL_ID[tonumber(skillNameOrID)] or tostring(skillNameOrID)
    AR.db.char.SkillsKnown[name] = {
        rank = tonumber(rank) or 0,
        maxRank = tonumber(maxRank) or 300,
    }
end

function Professions:GetSkillLevel(skillNameOrID)
    if not AR.db or not AR.db.char or not AR.db.char.SkillsKnown then return 0 end
    local name = tonumber(skillNameOrID) and self.NAME_BY_SKILL_ID[tonumber(skillNameOrID)] or tostring(skillNameOrID)
    local info = AR.db.char.SkillsKnown[name]
    return (info and info.rank) or 0
end

function Professions:OnConsoleSkillMessage(msg)
    if not msg then return end
    local skillIDStr, _, newRankStr = msg:match("Skill (%d+) increased from (%d+) to (%d+)")
    if skillIDStr and newRankStr then
        self:SetSkillLevel(tonumber(skillIDStr), tonumber(newRankStr), 300)
    end
end

function Professions:CacheRecipes()
    if not AR.db or not AR.db.char or not _G.C_TradeSkillUI then return end
    local ids = _G.C_TradeSkillUI.GetAllRecipeIDs and _G.C_TradeSkillUI.GetAllRecipeIDs() or {}
    for _, recipeID in ipairs(ids) do
        local info = _G.C_TradeSkillUI.GetRecipeInfo and _G.C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info then
            local skillID = info.skillLineID or 0
            AR.db.char.RecipesKnown[skillID] = AR.db.char.RecipesKnown[skillID] or {}
            AR.db.char.RecipesKnown[skillID][recipeID] = {
                recipeID = recipeID,
                name = info.name,
                learned = info.learned == true,
                numAvailable = info.numAvailable or 0,
            }
        end
    end
end

function Professions:PerformTradeSkillGoal(goal)
    if not goal or not goal.recipeid or not _G.C_TradeSkillUI then return false end
    local needed = goal.count or 1
    if goal.targetid then
        local have = AR.Compat:GetItemCount(goal.targetid, false)
        needed = math.max(0, needed - have)
    end
    if needed <= 0 then return false end
    if _G.C_TradeSkillUI.CraftRecipe then
        return _G.C_TradeSkillUI.CraftRecipe(goal.recipeid, needed)
    end
    return false
end

return Professions
