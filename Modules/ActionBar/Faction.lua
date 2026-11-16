-- AzerothRoute: Reputation Standing & Threshold Calculator (SPEC-10)

local AR = _G.AzerothRoute
local Faction = {
    STANDING_THRESHOLDS = {
        [4] = 0,     -- Neutral
        [5] = 3000,  -- Friendly
        [6] = 9000,  -- Honored
        [7] = 21000, -- Revered
        [8] = 42000, -- Exalted
    },
    factions = {},
}
AR.Faction = Faction

function Faction:Reset()
    self.factions = {}
end

function Faction:UpdateFaction(name, standing, currentInStanding, maxInStanding)
    local base = self.STANDING_THRESHOLDS[standing] or 0
    self.factions[name] = {
        name = name,
        standing = standing,
        val = currentInStanding or 0,
        max = maxInStanding or 3000,
        cumulative = base + (currentInStanding or 0),
    }
end

function Faction:GetStanding(name)
    local f = self.factions[name]
    return (f and f.standing) or 4
end

function Faction:PointsToStanding(name, targetStanding)
    local f = self.factions[name]
    local currentCum = (f and f.cumulative) or 0
    local targetCum = self.STANDING_THRESHOLDS[targetStanding] or 0
    return math.max(0, targetCum - currentCum)
end

return Faction
