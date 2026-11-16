-- AzerothRoute: Talent Grid Coordinates & Build Data Registry (SPEC-06)
-- Decouples talent build definitions from unstable Blizzard entryIDs using "posX,posY,entryIndex" coordinates.

local AR = _G.AzerothRoute
local TalentData = {
    nodesByClass = {
        PALADIN = {
            ["Benediction"] = "1,2,1",
            ["Improved Judgement"] = "2,1,1",
            ["Seal of Command"] = "3,2,1",
            ["Pursuit of Justice"] = "3,3,1",
        },
        WARRIOR = {
            ["Deflection"] = "1,2,1",
            ["Tactical Mastery"] = "2,1,1",
            ["Anger Management"] = "3,2,1",
        },
        MAGE = {
            ["Elemental Precision"] = "1,2,1",
            ["Frostbite"] = "2,1,1",
            ["Ice Shards"] = "2,2,1",
        },
    },
    buildsByClass = {},
}
AR.TalentData = TalentData

return TalentData
