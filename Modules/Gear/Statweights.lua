-- AzerothRoute: 9-Class Spec Stat Weights & Armor Transition Rules (SPEC-08 / SPEC-19)

local AR = _G.AzerothRoute
local Statweights = {
    rules = {
        WARRIOR = {
            [1] = {
                name = "Arms / Fury Leveling",
                itemtypes = { CLOTH = -1, LEATHER = -40, MAIL = -40, PLATE = 40 },
                stats = { STR = 2.5, AGI = 1.5, STA = 1.2, CRIT = 1.8, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        PALADIN = {
            [1] = {
                name = "Retribution",
                itemtypes = { CLOTH = -40, LEATHER = -40, MAIL = -40, PLATE = 40 },
                stats = { STR = 2.5, AGI = 1.2, STA = 1.0, CRIT = 1.5, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        HUNTER = {
            [1] = {
                name = "Beast Mastery",
                itemtypes = { CLOTH = -1, LEATHER = -40, MAIL = 40 },
                stats = { AGI = 2.6, STA = 1.1, INT = 0.8, CRIT = 1.6, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        ROGUE = {
            [1] = {
                name = "Combat Swords",
                itemtypes = { CLOTH = -1, LEATHER = 1 },
                stats = { AGI = 2.5, STR = 1.1, STA = 1.0, CRIT = 1.7, HIT = 2.2, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        PRIEST = {
            [1] = {
                name = "Shadow / Wand Leveling",
                itemtypes = { CLOTH = 1 },
                stats = { SPI = 2.2, INT = 2.0, SP = 2.4, STA = 1.0, HIT_SPELL = 1.8 },
                caps = { HIT_SPELL = 160 },
            },
        },
        SHAMAN = {
            [1] = {
                name = "Enhancement",
                itemtypes = { CLOTH = -40, LEATHER = -40, MAIL = 40 },
                stats = { STR = 2.2, AGI = 1.8, STA = 1.2, INT = 1.0, CRIT = 1.6, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
            },
        },
        MAGE = {
            [1] = {
                name = "Frost Leveling",
                itemtypes = { CLOTH = 1 },
                stats = { INT = 2.2, SP = 2.5, STA = 1.0, CRIT_SPELL = 1.4, HIT_SPELL = 2.0 },
                caps = { HIT_SPELL = 160 },
            },
        },
        WARLOCK = {
            [1] = {
                name = "Affliction / Drain Tank",
                itemtypes = { CLOTH = 1 },
                stats = { SP = 2.6, STA = 1.5, INT = 1.8, SPI = 1.0, HIT_SPELL = 2.0 },
                caps = { HIT_SPELL = 160 },
            },
        },
        DRUID = {
            [1] = {
                name = "Feral Combat",
                itemtypes = { CLOTH = -1, LEATHER = 1 },
                stats = { AGI = 2.4, STR = 2.2, STA = 1.3, INT = 1.0, CRIT = 1.6, HIT = 2.0, AP = 1.0 },
                caps = { HIT = 90 },
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
