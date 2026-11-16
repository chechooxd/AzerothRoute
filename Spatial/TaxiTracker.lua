-- AzerothRoute: Flight Master & Trip Duration Tracker (TaxiTracker) (SPEC-05)

local AR = _G.AzerothRoute
local TaxiTracker = {
    RACIAL_STARTERS = {
        Scourge = { "Undercity" },
        Undead = { "Undercity" },
        Orc = { "Orgrimmar" },
        Troll = { "Orgrimmar" },
        Tauren = { "Thunder Bluff" },
        BloodElf = { "Silvermoon City" },
        Human = { "Stormwind" },
        Dwarf = { "Ironforge" },
        Gnome = { "Ironforge" },
        NightElf = { "Rut'theran Village" },
        Draenei = { "The Exodar" },
    },
}
AR.TaxiTracker = TaxiTracker

function TaxiTracker:InitializeForRace(race)
    if not AR.db or not AR.db.char then return end
    AR.db.char.taxis = AR.db.char.taxis or {}
    local starters = self.RACIAL_STARTERS[race or "Scourge"] or {}
    for _, nodeName in ipairs(starters) do
        AR.db.char.taxis[nodeName] = true
    end
end

function TaxiTracker:KnowsTaxi(nodeName)
    if not AR.db or not AR.db.char or not AR.db.char.taxis then return false end
    return AR.db.char.taxis[nodeName] == true
end

function TaxiTracker:LearnTaxi(nodeName, defaultTripSeconds)
    if not AR.db or not AR.db.char then return end
    AR.db.char.taxis[nodeName] = true
    if defaultTripSeconds and AR.db.global then
        AR.db.global.taxitimes[nodeName] = defaultTripSeconds
    end
end

function TaxiTracker:RecordTripTime(srcName, dstName, seconds)
    if not AR.db or not AR.db.global then return end
    local key = string.format("%s->%s", tostring(srcName), tostring(dstName))
    AR.db.global.taxitimes[key] = seconds
end

function TaxiTracker:GetTripTime(srcName, dstName)
    if AR.db and AR.db.global and AR.db.global.taxitimes then
        local key = string.format("%s->%s", tostring(srcName), tostring(dstName))
        if AR.db.global.taxitimes[key] then
            return AR.db.global.taxitimes[key]
        end
        if AR.db.global.taxitimes[dstName] then
            return AR.db.global.taxitimes[dstName]
        end
    end
    return 60
end

return TaxiTracker
