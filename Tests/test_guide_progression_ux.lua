-- Package 1 (Zygor-style guide flow): resume on login, next guide at the end, step-complete
-- feedback, and Next/Prev button shortcuts.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function parse(title, body)
    return _G.AzerothRoute.Parser:ParseGuide(title, body)
end

-- Five confirm-steps: a step completes only when its confirm goal is clicked.
local function confirmGuide(title, nextTitle)
    local lines = {}
    if nextTitle then table.insert(lines, "next " .. nextTitle) end
    for i = 1, 5 do
        table.insert(lines, "step S" .. i)
        table.insert(lines, "    confirm")
    end
    return parse(title, table.concat(lines, "\n"))
end

local function confirmStep(step)
    for _, g in ipairs(step.goals) do g.confirmed = true end
end

local function capturePrints(AR)
    local printed = {}
    local orig = AR.Print
    AR.Print = function(_, msg) table.insert(printed, msg) end
    return printed, function() AR.Print = orig end
end

T:Describe("Package 1: guide flow", function()
    T:It("resumes the saved guide and step on login instead of the first suggested guide", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local g = confirmGuide("UX_Resume")
        AR.db.char.currentGuideTitle = "UX_Resume"
        AR.db.char.currentStepNum = 4
        AR.Progression.currentGuide = nil
        T:AssertEqual(AR.Progression:RestoreSaved(), true, "Saved guide restored")
        T:AssertTrue(AR.Progression.currentGuide == g, "Same guide object")
        T:AssertEqual(AR.Progression.currentStep.num, 4, "Same step")

        AR.db.char.currentGuideTitle = "UX_DoesNotExist"
        AR.Progression.currentGuide = nil
        T:AssertEqual(AR.Progression:RestoreSaved(), false, "Unknown guide is not restored")

        AR.db.char.currentGuideTitle = "UX_Resume"
        AR.db.char.currentStepNum = 99
        T:AssertEqual(AR.Progression:RestoreSaved(), true)
        T:AssertEqual(AR.Progression.currentStep.num, 5, "Out-of-range step clamps to the last step")
    end)

    T:It("loads the guide's next guide when the last step completes and announces it", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local printed, restore = capturePrints(AR)
        local ok, err = pcall(function()
            local nextGuide = confirmGuide("UX_B")
            local g = confirmGuide("UX_A", "UX_B")
            AR.Progression:LoadGuide(g, 5)
            confirmStep(AR.Progression.currentStep)
            AR.Progression:TryToCompleteStep(false)
            T:AssertTrue(AR.Progression.currentGuide == nextGuide, "Next guide loaded")
            T:AssertEqual(AR.Progression.currentStep.num, 1, "Starts at its first step")
            T:AssertEqual(AR.db.char.currentGuideTitle, "UX_B", "Saved as the current guide")
            T:AssertTrue(#printed >= 1 and printed[#printed]:find("UX_B", 1, true) ~= nil, "Chat names the new guide")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("marks the guide complete once when there is no next guide", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local printed, restore = capturePrints(AR)
        local ok, err = pcall(function()
            local g = confirmGuide("UX_End")
            AR.Progression:LoadGuide(g, 5)
            confirmStep(AR.Progression.currentStep)
            AR.Progression:TryToCompleteStep(false)
            AR.Progression:TryToCompleteStep(false)
            AR.Progression:TryToCompleteStep(false)
            T:AssertEqual(AR.Progression.guideComplete, true, "Guide flagged complete")
            T:AssertTrue(AR.Progression.currentGuide == g, "Stays on the finished guide")
            T:AssertEqual(#printed, 1, "Announced once, not every tick")
            local vm = AR.ViewerFrame:RefreshVisuals()
            T:AssertEqual(vm.guideComplete, true, "Viewer shows the guide as complete")

            AR.Progression:LoadGuide(confirmGuide("UX_Other"))
            T:AssertTrue(not AR.Progression.guideComplete, "Loading another guide clears the flag")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("plays a sound and flashes the viewer once when the current step completes", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local sounds = {}
        local origPlay = _G.PlaySound
        _G.PlaySound = function(id) table.insert(sounds, id) end
        local ok, err = pcall(function()
            AR.ViewerFrame:RefreshVisuals()
            local g = confirmGuide("UX_Sound")
            AR.Progression:LoadGuide(g, 1)
            AR.ViewerFrame.borderFlashCount = 0
            confirmStep(AR.Progression.currentStep)
            -- Steps 2 and 3 are already done: they fast-forward silently.
            confirmStep(g:GetStep(2))
            confirmStep(g:GetStep(3))
            for _ = 1, 4 do AR.Progression:TryToCompleteStep(false) end
            T:AssertEqual(AR.Progression.currentStep.num, 4, "Fast-forwarded to the first open step")
            T:AssertEqual(#sounds, 1, "One sound for the step the player finished")
            T:AssertEqual(sounds[1], AR.Progression.STEP_COMPLETE_SOUND, "Map ping sound")
            T:AssertEqual(AR.ViewerFrame.borderFlashCount, 1, "One viewer flash")

            AR.db.profile.stepsound = false
            confirmStep(AR.Progression.currentStep)
            AR.Progression:TryToCompleteStep(false)
            T:AssertEqual(#sounds, 1, "Sound can be turned off")
            T:AssertEqual(AR.ViewerFrame.borderFlashCount, 2, "Flash still shows")
        end)
        AR.db.profile.stepsound = true
        _G.PlaySound = origPlay
        if not ok then error(err, 0) end
    end)

    T:It("supports Next right-click (next open step), Shift (+10) and Prev Ctrl-click (step 1)", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local lines = {}
        for i = 1, 15 do
            table.insert(lines, "step S" .. i)
            table.insert(lines, "    confirm")
        end
        local g = parse("UX_Nav", table.concat(lines, "\n"))
        AR.Progression:LoadGuide(g, 1)
        confirmStep(g:GetStep(2))
        confirmStep(g:GetStep(3))

        AR.ViewerFrame:RefreshVisuals()
        local next, prev = AR.ViewerFrame.nextButton, AR.ViewerFrame.prevButton
        local origShift, origCtrl = _G.IsShiftKeyDown, _G.IsControlKeyDown
        local ok, err = pcall(function()
            _G.IsShiftKeyDown = function() return false end
            _G.IsControlKeyDown = function() return false end
            next:GetScript("OnClick")(next, "LeftButton")
            T:AssertEqual(AR.Progression.currentStep.num, 2, "Left click: one step")

            next:GetScript("OnClick")(next, "RightButton")
            T:AssertEqual(AR.Progression.currentStep.num, 4, "Right click: next unfinished step")

            _G.IsShiftKeyDown = function() return true end
            next:GetScript("OnClick")(next, "LeftButton")
            T:AssertEqual(AR.Progression.currentStep.num, 14, "Shift: ten steps")
            next:GetScript("OnClick")(next, "LeftButton")
            T:AssertEqual(AR.Progression.currentStep.num, 15, "Shift clamps to the last step")

            _G.IsShiftKeyDown = function() return false end
            _G.IsControlKeyDown = function() return true end
            confirmStep(g:GetStep(1))
            prev:GetScript("OnClick")(prev, "LeftButton")
            T:AssertEqual(AR.Progression.currentStep.num, 1, "Ctrl+Prev: first step")
            T:AssertEqual(AR.Progression.pause, true, "Landing on a finished step pauses auto-advance")
            AR.Progression:TryToCompleteStep(false)
            T:AssertEqual(AR.Progression.currentStep.num, 1, "Stays where the player went back to")
        end)
        _G.IsShiftKeyDown, _G.IsControlKeyDown = origShift, origCtrl
        if not ok then error(err, 0) end
    end)
end)
