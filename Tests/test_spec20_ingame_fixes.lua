-- SPEC-20: In-Game Screenshot Bugfixes (Coordinate Normalization, Real Arrow Texture, ViewerFrame Layout & Interactive GuideMenu)
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-20: In-Game Screenshot Fixes (557205 yd Coords, Arrow Texture, Viewer Header & Interactive GuideMenu)", function()
    T:It("normalizes DSL percentage coordinates (51.5, 30.8 -> 0.515, 0.308) so distance is realistic instead of 557205 yd", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()

        local guide = AR.Parser:ParseGuide("Test\\CoordNorm", [[
            step
                goto 1413 51.5,30.8
        ]])
        local g = guide.steps[1].goals[1]
        T:AssertEqual(g.x, 0.515, "Parser must normalize goto X 51.5 -> 0.515")
        T:AssertEqual(g.y, 0.308, "Parser must normalize goto Y 30.8 -> 0.308")
        T:AssertEqual(g:GetText(), "Go to 51.5, 30.8", "Goal:GetText() must display human-friendly 51.5, 30.8 percentage coordinates")

        MockWoW.player.mapID = 1413
        MockWoW.player.x = 0.500
        MockWoW.player.y = 0.300
        local dist = AR.Coords:GetDistanceTo(1413, g.x, g.y)
        T:AssertTrue(dist > 50 and dist < 500, "Distance between (50.0, 30.0) and (51.5, 30.8) in The Barrens must be ~160 yd, never 557205 yd")
    end)

    T:It("uses a real directional arrow texture with bearing vertex color instead of a solid blue square", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Pointer:Reset()
        local af = AR.Pointer:InitializeFrames()

        T:AssertTrue(af.icon:GetTexture() ~= nil, "Arrow icon must use SetTexture with a real WoW arrow texture, not SetColorTexture")
        T:AssertEqual(af.icon:GetColorTexture(), nil, "Arrow icon must NOT be a solid blue SetColorTexture square")

        AR.Pointer:PlaceStepPins({
            { map = 1413, x = 0.515, y = 0.308, title = "Go to 51.5, 30.8", objectiveIndex = 1 },
        })
        MockWoW.player.mapID = 1413
        MockWoW.player.x = 0.500
        MockWoW.player.y = 0.300
        AR.Pointer:UpdateArrow(0.033)

        local vc = af.icon:GetVertexColor()
        T:AssertTrue(vc ~= nil and vc.r ~= nil and vc.g ~= nil, "Arrow must dynamically color-grade vertex color (red/yellow/green) by angle")
    end)

    T:It("populates GuideMenu with interactive category tabs, guide list rows, and a working Load Guide button", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Catalog:LoadAll()
        AR.GuidesCatalog:LoadAll()
        AR.ViewerFrame:Initialize()
        AR.GuideMenu:Reset()
        AR.GuideMenu:InitializeFrame()
        AR.GuideMenu:Show()

        T:AssertTrue(#AR.GuideMenu.categoryButtons >= 5, "GuideMenu must render interactive category tab buttons")
        T:AssertTrue(#AR.GuideMenu.guideRowButtons >= 1, "GuideMenu must render clickable guide list rows")

        -- Select Alliance Elwynn Forest guide in GuideMenu and click Load Guide button
        AR.GuideMenu:SelectCategory("ALL")
        local targetRow = nil
        for _, rowBtn in ipairs(AR.GuideMenu.guideRowButtons) do
            if rowBtn:IsShown() and rowBtn._guide and rowBtn._guide.title == "Leveling\\Alliance\\Elwynn Forest (1-12)" then
                targetRow = rowBtn
                break
            end
        end
        T:AssertTrue(targetRow ~= nil, "Elwynn Forest guide row must be visible in ALL category")
        targetRow:Click("LeftButton")
        T:AssertEqual(AR.GuideMenu.selectedGuide.title, "Leveling\\Alliance\\Elwynn Forest (1-12)", "Clicking a guide row must select that guide")

        AR.GuideMenu.loadButton:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentGuide.title, "Leveling\\Alliance\\Elwynn Forest (1-12)", "Clicking Load Guide must load the selected guide into Progression")
        T:AssertFalse(AR.GuideMenu.frame:IsShown(), "Clicking Load Guide must close GuideMenu and focus ViewerFrame")
    end)

    T:It("renders non-overlapping ViewerFrame short title, step badge, and labeled [<] [>] [Menu] toolbar buttons", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.GuidesCatalog:LoadAll()
        AR.ViewerFrame:Initialize()

        local barrens = AR.Parser.guidesByTitle["Leveling\\Horde\\The Barrens (12-22)"]
        AR.Progression:LoadGuide(barrens, 1)
        AR.ViewerFrame:RefreshVisuals()

        T:AssertEqual(AR.ViewerFrame.titleText:GetText(), "The Barrens (12-22)", "ViewerFrame header should display clean short guide title without overflowing onto Step text")
        T:AssertTrue(AR.ViewerFrame.prevButton.label:GetText() == "<", "Prev button must have visible '<' label")
        T:AssertTrue(AR.ViewerFrame.nextButton.label:GetText() == ">", "Next button must have visible '>' label")
        T:AssertTrue(AR.ViewerFrame.menuButton.label:GetText() == "Guides", "Menu button must have visible 'Guides' label")
    end)
end)
