-- SPEC-17: Live WoW Visual Frame Rendering (ViewerFrame, Pointer Arrow/Map Pins, GuideMenu & /ar Slash Command) Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-17: Live WoW Visual Frames (ViewerFrame Rows, Pointer Arrow/Pins, GuideMenu & /ar Command)", function()
    T:It("builds visual StepLine frames, updates FontStrings/ColorTextures on RefreshVisuals, and navigates via Prev/Next buttons", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.ViewerFrame:Initialize()

        local guide = AR.Parser:ParseGuide("Test\\VisualViewer", [[
            stickystart "StickyTask"
            step StickyTask
                kill Wretched Ghoul##1502 |q 364/2 |count 8
            stickystop
            step StepOne
                goto 1420 30.2,71.4
                accept Rude Awakening##363
            step StepTwo
                turnin Rude Awakening##363
        ]])

        MockWoW.quests.inLog[364] = {
            title = "The Mindless Ones",
            isComplete = false,
            objectives = {
                { numFulfilled = 0, numRequired = 8, finished = false },
                { numFulfilled = 2, numRequired = 8, finished = false },
            },
        }

        AR.Progression:LoadGuide(guide, 2)
        AR.ViewerFrame:RefreshVisuals()

        T:AssertEqual(#AR.ViewerFrame.lineRows, 20, "ViewerFrame must pre-allocate 20 visual StepLine row frames")
        T:AssertTrue(AR.ViewerFrame.lineRows[1]:IsShown(), "Row 1 (goto) must be shown")
        T:AssertTrue(AR.ViewerFrame.lineRows[2]:IsShown(), "Row 2 (accept) must be shown")
        T:AssertEqual(AR.ViewerFrame.lineRows[2].label:GetText(), "Accept Rude Awakening", "Row 2 FontString must display goal text")
        T:AssertTrue(AR.ViewerFrame.stickySeparator:IsShown(), "1px sticky separator texture must be shown when active sticky exists")

        -- Click Next button on ViewerFrame toolbar -> advances to StepTwo (step 3)
        AR.ViewerFrame.nextButton:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentStep.label, "StepTwo", "Clicking Next button on ViewerFrame must advance to StepTwo")
        T:AssertEqual(AR.ViewerFrame.lineRows[1].label:GetText(), "Turn in Rude Awakening", "ViewerFrame visual row 1 must update to StepTwo goal")
    end)

    T:It("creates real Pointer Arrow frame + WorldMap/Minimap pin frames and registers /ar slash commands", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Pointer:InitializeFrames()

        AR.Pointer:PlaceStepPins({
            { map = 1420, x = 0.30, y = 0.70, title = "Wake Up", objectiveIndex = 1 },
        })
        AR.Pointer:UpdateArrow(0.033)

        T:AssertTrue(AR.Pointer.arrowFrame ~= nil and AR.Pointer.arrowFrame:IsShown(), "On-screen directional arrow frame must be created and shown")
        T:AssertEqual(#AR.Pointer.worldMapPinFrames, 1, "Must create visual WorldMap pin frame")
        T:AssertEqual(#AR.Pointer.minimapPinFrames, 1, "Must create visual Minimap pin frame")

        -- Slash command /ar menu toggles GuideMenu frame
        AR.GuideMenu:InitializeFrame()
        AR.GuideMenu.frame:Hide()
        _G.SlashCmdList["AZEROTHROUTE"]("menu")
        T:AssertTrue(AR.GuideMenu.frame:IsShown(), "/ar menu slash command must open GuideMenu window")
    end)
end)
