-- AzerothRoute: Class Skill Trainer Advisor (SPEC-07)

local AR = _G.AzerothRoute
local Skills = {
    catalogByClass = {},
}
AR.Skills = Skills

function Skills:Reset()
    self.catalogByClass = {}
end

function Skills:RegisterSkill(className, skillSpec)
    self.catalogByClass[className] = self.catalogByClass[className] or {}
    table.insert(self.catalogByClass[className], skillSpec)
end

function Skills:GetLearnableSkills()
    local pClass = (_G.UnitClass and _G.UnitClass("player")) or "PALADIN"
    local pLevel = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    local list = self.catalogByClass[pClass] or {}

    local normal = {}
    local optional = {}
    local future = {}

    for _, sk in ipairs(list) do
        local known = (_G.IsSpellKnown and _G.IsSpellKnown(sk.spellID)) or false
        if not known then
            if sk.level <= pLevel then
                if sk.optional then
                    table.insert(optional, sk)
                else
                    table.insert(normal, sk)
                end
            elseif sk.level <= (pLevel + 3) then
                table.insert(future, sk)
            end
        end
    end

    return {
        normal = normal,
        optional = optional,
        future = future,
    }
end

return Skills
