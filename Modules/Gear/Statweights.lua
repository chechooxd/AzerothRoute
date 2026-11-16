-- AzerothRoute: Class/Spec Stat Weights & Armor Transition Rules (SPEC-08)

local AR = _G.AzerothRoute
local Statweights = {
    rules = {
        PALADIN = {
            [1] = { -- Retribution
                name = "Retribution",
                itemtypes = { CLOTH = -40, LEATHER = -40, MAIL = -40, PLATE = 40 },
                stats = { STR = 2.5, AGI = 1.2, STA = 1.0, CRIT = 1.5, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        WARRIOR = {
            [1] = { -- Arms/Fury
                name = "Arms",
                itemtypes = { CLOTH = -1, LEATHER = -40, MAIL = -40, PLATE = 40 },
                stats = { STR = 2.5, AGI = 1.5, STA = 1.2, CRIT = 1.8, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        MAGE = {
            [1] = { -- Frost/Fire
                name = "Frost",
                itemtypes = { CLOTH = 1 },
                stats = { INT = 2.2, SP = 2.5, STA = 1.0, CRIT_SPELL = 1.4, HIT_SPELL = 2.0 },
                caps = { HIT_SPELL = 160 },
            },
        },
    },
}
AR.Statweights = Statweights

function Statweights:GetActiveRule()
    local pClass = (_G.UnitClass and _G.UnitClass("player")) or "PALADIN"
    local pSpec = (_G.MockWoW and _G.MockWoW.player and _G.MockWoW.player.spec) or 1
    local classRules = self.rules[pClass] or self.rules.PALADIN
    return classRules[pSpec] or classRules[1]
end

return Statweights
