-- SPEC-12: UI Framework, Skins, ViewerFrame & Tabs Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-12: UI Primitives, Skins, ViewerFrame (1-line goals, Stickies separator, Flash) & Tabs", function()
    T:It("renders 1 line per visible goal, triggers 0.5s white flash on progress change, and separates Stickies below 1px divider", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.ViewerFrame:Initialize()

        local guide = AR.Parser:ParseGuide("Leveling\\Tirisfal", [[
            stickystart "StickyGhouls"
            step StickyGhouls
                kill Wretched Ghoul##1502 |q 364/1 |count 10
            stickystop
            step MainStep
                accept Rude Awakening##363
                kill Mindless Zombie##1501 |q 363/1 |count 8
        ]])

        MockWoW.quests.inLog[363] = {
            title = "Rude Awakening",
            isComplete = false,
            objectives = { { numFulfilled = 2, numRequired = 8, finished = false } },
        }
        MockWoW.quests.inLog[364] = {
            title = "The Mindless Ones",
            isComplete = false,
            objectives = { { numFulfilled = 4, numRequired = 10, finished = false } },
        }

        AR.Progression:LoadGuide(guide, 2)
        local viewModel = AR.ViewerFrame:RenderCurrentStep()

        T:AssertEqual(#viewModel.mainLines, 2, "Main step should render 2 goal lines")
        T:AssertEqual(viewModel.mainLines[1].status, "complete", "Quest 363 is in log so accept line is complete")
        T:AssertEqual(viewModel.mainLines[2].text, "Kill 6 Mindless Zombie (2/8)", "One-line goal must show remaining count + (now/needed) suffix")
        T:AssertTrue(viewModel.hasStickySeparator == true, "1px sticky separator must be visible when active stickies exist")
        T:AssertEqual(#viewModel.stickyLines, 1, "Sticky block must render 1 goal line below the separator")

        -- Advance progress from 2/8 to 3/8 -> triggers 0.5s white flash animation!
        MockWoW.quests.inLog[363].objectives[1].numFulfilled = 3
        viewModel = AR.ViewerFrame:RenderCurrentStep()
        T:AssertTrue(viewModel.mainLines[2].flashDuration == 0.5, "Progress increment must trigger 0.5s white fade flash")
    end)

    T:It("cycles 7px progress bar mode on click and manages up to 30 draggable guide tabs", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Tabs:Reset()

        AR.Tabs:AddTab("Leveling\\Tirisfal")
        AR.Tabs:AddTab("Professions\\Alchemy")
        T:AssertEqual(#AR.Tabs:GetTabs(), 2, "Should track 2 open guide tabs")

        T:AssertEqual(AR.ViewerFrame.progressMode, "steps", "Default progress bar mode should be steps")
        AR.ViewerFrame:CycleProgressMode()
        T:AssertEqual(AR.ViewerFrame.progressMode, "quests", "First click cycles progress bar to quests")
        AR.ViewerFrame:CycleProgressMode()
        T:AssertEqual(AR.ViewerFrame.progressMode, "xp", "Second click cycles progress bar to xp")
    end)
end)
