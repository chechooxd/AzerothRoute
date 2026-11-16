-- SPEC-13: GuideMenu, Global Search (quest:<id>), 6-Column Home Dashboard Widgets & Options Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-13: GuideMenu (Suggested, Search quest:<id>), 6-Col Dashboard Widgets & Options", function()
    T:It("evaluates Suggested guides dynamically and supports full-text + quest:<id> search", function()
        MockWoW:Reset()
        MockWoW.player.level = 14
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()

        AR.Parser:ParseGuide("Leveling\\Tirisfal (1-12)", [[
            type LEVELING
            startlevel 1
            endlevel 12
            condition_suggested level >= 1 and level <= 12
            step
                accept Rude Awakening##363
        ]])
        AR.Parser:ParseGuide("Leveling\\The Barrens (12-22)", [[
            type LEVELING
            startlevel 12
            endlevel 22
            condition_suggested level >= 12 and level <= 22
            step
                accept Centaur Bracers##855
        ]])

        local suggested = AR.GuideMenu:FindSuggestedGuides()
        T:AssertEqual(#suggested, 1, "Only The Barrens (12-22) should be suggested at level 14")
        T:AssertEqual(suggested[1].title, "Leveling\\The Barrens (12-22)", "Suggested guide must match The Barrens")

        local byQuest = AR.GuideMenu:Search("quest:855")
        T:AssertEqual(#byQuest, 1, "Search 'quest:855' must locate The Barrens guide containing quest 855")
        T:AssertEqual(byQuest[1].title, "Leveling\\The Barrens (12-22)", "Quest search result must be The Barrens")
    end)

    T:It("places tiles in the 6-column Home Dashboard grid and manages Option groups", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.DashboardWidgets:Reset()
        AR.Options:Reset()

        AR.DashboardWidgets:RegisterTile("guidehistory", { col = 1, row = 1, widthCols = 3, heightRows = 2 })
        AR.DashboardWidgets:RegisterTile("gold", { col = 4, row = 1, widthCols = 3, heightRows = 2 })
        T:AssertEqual(#AR.DashboardWidgets:GetLayout(), 2, "6-column dashboard should hold 2 registered tiles")

        AR.Options:RegisterGroup("travelsystem", "Travel System", {
            { key = "corpsearrow", type = "toggle", default = true },
        })
        T:AssertTrue(AR.Options:GetGroup("travelsystem") ~= nil, "Options group travelsystem must be registered")
    end)
end)
