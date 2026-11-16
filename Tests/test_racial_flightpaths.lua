-- Zygor seeds each race's capital flight path as known; AzerothRoute does it once per character.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("Racial starting flight paths", function()
    T:It("marks the race's capital flight path as known once per character", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.char.taxis = {}
        AR.db.char.taxisSeeded = nil
        local origRace = _G.UnitRace
        local ok, err = pcall(function()
            _G.UnitRace = function() return "Orco", "Orc" end
            T:AssertEqual(AR.TaxiTracker:SeedRacialStarters(), true, "Seeds on first login")
            T:AssertTrue(AR.TaxiTracker:KnowsTaxi("Orgrimmar"), "Capital known")
            T:AssertTrue(not AR.TaxiTracker:KnowsTaxi("Crossroads"), "Nothing else assumed")

            AR.db.char.taxis = {} -- e.g. the player later corrected it by opening a flight map
            T:AssertEqual(AR.TaxiTracker:SeedRacialStarters(), false, "Never seeds twice")
            T:AssertTrue(not AR.TaxiTracker:KnowsTaxi("Orgrimmar"), "Does not overwrite later data")

            AR.db.char.taxisSeeded = nil
            _G.UnitRace = function() return "Pandaren", "Pandaren" end
            T:AssertEqual(AR.TaxiTracker:SeedRacialStarters(), true, "Unknown race seeds nothing but is marked done")
            T:AssertEqual(next(AR.db.char.taxis), nil, "No flight path invented")
        end)
        _G.UnitRace = origRace
        if not ok then error(err, 0) end
    end)
end)
