-- AzerothRoute: 9-Class Talent Grid Coordinates & Build Data Registry (SPEC-06 / SPEC-19)
-- Decouples talent build definitions from unstable Blizzard entryIDs using "posX,posY,entryIndex" coordinates.

local AR = _G.AzerothRoute
local TalentData = {
    nodesByClass = {
        WARRIOR = {
            ["Deflection"] = "1,2,1",
            ["Tactical Mastery"] = "2,1,1",
            ["Anger Management"] = "3,2,1",
            ["Mortal Strike"] = "7,2,1",
            ["Cruelty"] = "1,3,1",
        },
        PALADIN = {
            ["Benediction"] = "1,2,1",
            ["Improved Judgement"] = "2,1,1",
            ["Seal of Command"] = "3,2,1",
            ["Pursuit of Justice"] = "3,3,1",
            ["Crusader Strike"] = "7,2,1",
        },
        HUNTER = {
            ["Improved Aspect of the Hawk"] = "1,2,1",
            ["Endurance Training"] = "1,3,1",
            ["Thick Hide"] = "2,3,1",
            ["Bestial Wrath"] = "5,2,1",
        },
        ROGUE = {
            ["Malice"] = "1,3,1",
            ["Improved Sinister Strike"] = "1,2,1",
            ["Precision"] = "2,2,1",
            ["Blade Flurry"] = "5,2,1",
        },
        PRIEST = {
            ["Wand Specialization"] = "1,3,1",
            ["Spirit Tap"] = "1,2,1",
            ["Shadow Focus"] = "2,3,1",
            ["Shadowform"] = "7,2,1",
        },
        SHAMAN = {
            ["Ancestral Knowledge"] = "1,2,1",
            ["Thundering Strikes"] = "2,2,1",
            ["Flurry"] = "4,2,1",
            ["Stormstrike"] = "7,2,1",
        },
        MAGE = {
            ["Elemental Precision"] = "1,2,1",
            ["Improved Frostbolt"] = "1,3,1",
            ["Frostbite"] = "2,1,1",
            ["Ice Shards"] = "2,2,1",
            ["Ice Barrier"] = "7,2,1",
        },
        WARLOCK = {
            ["Suppression"] = "1,2,1",
            ["Improved Corruption"] = "1,3,1",
            ["Fel Concentration"] = "2,2,1",
            ["Siphon Life"] = "5,2,1",
        },
        DRUID = {
            ["Ferocity"] = "1,2,1",
            ["Feral Instinct"] = "2,1,1",
            ["Feline Swiftness"] = "3,1,1",
            ["Leader of the Pack"] = "7,2,1",
        },
    },
    buildsByClass = {},
}
AR.TalentData = TalentData

return TalentData
