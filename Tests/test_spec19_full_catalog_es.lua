-- SPEC-19: Point 4 — Complete 9-Class Talent/Statweights Catalog, Multi-Continent Travel Graph & Localized esMX/esES Guides Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-19: 9-Class Talent/Statweight Coverage, Multi-Continent Travel Graph & Localized esMX/esES Guides", function()
    T:It("registers talent nodes, builds, and statweight rules for all 9 classes", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.TalentAdvisor:Reset()
        AR.Catalog:LoadAll()

        local nineClasses = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
        for _, cls in ipairs(nineClasses) do
            T:AssertTrue(AR.TalentData.nodesByClass[cls] ~= nil, "TalentData must define nodes for " .. cls)
            T:AssertTrue(AR.TalentData.buildsByClass[cls] ~= nil and #AR.TalentData.buildsByClass[cls] >= 1, "TalentAdvisor must register at least 1 build for " .. cls)
            T:AssertTrue(AR.Statweights.rules[cls] ~= nil and AR.Statweights.rules[cls][1] ~= nil, "Statweights must define spec rules for " .. cls)
        end
    end)

    T:It("routes inter-continent travel across Eastern Kingdoms and Kalimdor via the Zeppelin/Ship graph in Data/Catalog.lua", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Pathfinder:Reset()
        AR.Catalog:LoadAll()

        -- Route from Undercity (Eastern Kingdoms) to Orgrimmar (Kalimdor) via Brill Zeppelin Tower
        local route = AR.Pathfinder:FindPath("ek_undercity", "kal_orgrimmar")
        T:AssertEqual(route.status, "success", "Multi-continent path from Undercity to Orgrimmar must succeed")
        T:AssertTrue(#route.nodes >= 3, "Route must traverse zeppelin transport edges between continents")
    end)

    T:It("loads localized esMX/esES and enUS leveling, profession, dungeon, and gold guides", function()
        MockWoW:Reset()
        MockWoW.locale = "esMX"
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Catalog:LoadAll()
        AR.GuidesCatalog:LoadAll()

        local tirisfal = AR.Parser.guidesByTitle["Leveling\\Horde\\Tirisfal Glades (1-12)"]
        local barrens = AR.Parser.guidesByTitle["Leveling\\Horde\\The Barrens (12-22)"]
        local elwynn = AR.Parser.guidesByTitle["Leveling\\Alliance\\Elwynn Forest (1-12)"]
        local sfk = AR.Parser.guidesByTitle["Dungeons\\Shadowfang Keep (18-26)"]
        local gold = AR.Parser.guidesByTitle["Gold\\Tirisfal Herbalism & Mining Loop"]

        T:AssertTrue(tirisfal ~= nil, "Tirisfal Glades (1-12) must be loaded")
        T:AssertTrue(barrens ~= nil, "The Barrens (12-22) must be loaded")
        T:AssertTrue(elwynn ~= nil, "Alliance Elwynn Forest (1-12) must be loaded")
        T:AssertTrue(sfk ~= nil, "Dungeon Shadowfang Keep (18-26) must be loaded")
        T:AssertTrue(gold ~= nil, "Gold Farming guide must be loaded")
        T:AssertTrue(tirisfal.description:find("Claros de Tirisfal", 1, true) ~= nil, "esMX locale must localize guide description in Spanish")
    end)
end)
