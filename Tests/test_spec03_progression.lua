-- SPEC-03: Stateless Reactive Progression Engine, Stickies & SIS Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-03: Stateless Goal/Step Evaluation, Pause Latch, Skip Streak, Stickies & SIS", function()
    T:It("evaluates Goal:GetStatus() statelessly and un-completes when items or quests are lost", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()

        local guide = AR.Parser:ParseGuide("Test\\Stateless", [[
            step
                goto 1420 30.0,71.0
                get 5 Centaur Bracers##5010 |q 855/1
                turnin Centaur Bracers##855
        ]])

        local step = guide.steps[1]
        local gotoGoal = step.goals[1]
        local getGoal = step.goals[2]
        local turninGoal = step.goals[3]

        -- Goto goal alongside completable goals is passive unless |c is set
        T:AssertEqual(gotoGoal:GetStatus(), "passive", "Goto goal in mixed step should be passive")

        -- Quest 855 not in log yet -> getGoal is impossible
        T:AssertEqual(getGoal:GetStatus(), "impossible", "Quest objective without quest in log and without |future is impossible")

        -- Put Quest 855 in log with 2/5 progress
        MockWoW.quests.inLog[855] = {
            title = "Centaur Bracers",
            isComplete = false,
            objectives = { { text = "Centaur Bracers: 2/5", numFulfilled = 2, numRequired = 5, finished = false } },
        }
        MockWoW.player.itemsInBags[5010] = 2

        T:AssertEqual(getGoal:GetStatus(), "incomplete", "Quest objective in log with 2/5 should be incomplete")
        T:AssertEqual(turninGoal:GetStatus(), "warning", "Turnin goal while quest objectives are incomplete should warn (isbad)")

        -- Complete objective 5/5
        MockWoW.quests.inLog[855].isComplete = true
        MockWoW.quests.inLog[855].objectives[1].numFulfilled = 5
        MockWoW.quests.inLog[855].objectives[1].finished = true
        MockWoW.player.itemsInBags[5010] = 5

        T:AssertEqual(getGoal:GetStatus(), "complete", "Quest objective at 5/5 should be complete")
        T:AssertEqual(turninGoal:GetStatus(), "incomplete", "Turnin goal when quest is ready should be incomplete (possible)")

        -- Drop an item / un-complete objective -> immediately un-completes live!
        MockWoW.quests.inLog[855].isComplete = false
        MockWoW.quests.inLog[855].objectives[1].numFulfilled = 4
        MockWoW.quests.inLog[855].objectives[1].finished = false
        MockWoW.player.itemsInBags[5010] = 4

        T:AssertEqual(getGoal:GetStatus(), "incomplete", "Goal must dynamically un-complete when live count drops")
    end)

    T:It("respects Manual Pause Latch on navigation, decays interval on Skip Streak, and surfaces postponed/level notices", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()

        MockWoW.quests.completed[100] = true
        MockWoW.quests.completed[101] = true
        MockWoW.player.level = 10

        local guide = AR.Parser:ParseGuide("Test\\Progression", [[
            step Step1
                accept QuestA##100
            step Step2
                turnin QuestA##100
            stickystart "BgTask"
            step BgTask
                kill Bristleback##200 |q 105/1 |count 10
            stickystop
            step Step3
                accept QuestB##102
            step Step4
                ding 12
        ]])

        MockWoW.quests.inLog[105] = {
            title = "Background Hunt",
            isComplete = false,
            objectives = { { numFulfilled = 3, numRequired = 10, finished = false } },
        }

        AR.Progression:LoadGuide(guide, 1)
        -- Step 1 & Step 2 are already completed (quest 100 is completed), Step 3 is BgTask (sticky), Step 4 is Step3 (incomplete)
        AR.Progression:TryToCompleteStep(true)
        AR.Progression:TryToCompleteStep(true)

        T:AssertEqual(AR.Progression.currentStep.label, "Step3", "Auto-skip streak should advance past completed steps and sticky definition onto Step3")
        T:AssertTrue(AR.Progression.completionInterval < 1.0, "Skip streak must decay completionInterval below 1.0s")

        -- Verify active sticky is returned alongside Step3
        local stickies = AR.Progression:GetActiveStickies()
        T:AssertEqual(#stickies, 1, "BgTask should be returned as an active sticky while quest 105 is in log and incomplete")
        T:AssertEqual(stickies[1].label, "BgTask", "Active sticky label must be BgTask")

        -- Manual navigation backward engages pause latch
        AR.Progression:PreviousStep()
        T:AssertEqual(AR.Progression.pause, true, "Manual PreviousStep onto a completed step must latch pause = true")
        local heldStepNum = AR.Progression.currentStep.num
        AR.Progression:TryToCompleteStep(true)
        T:AssertEqual(AR.Progression.currentStep.num, heldStepNum, "TryToCompleteStep must not auto-advance while pause latch is engaged")

        -- Navigating onto incomplete Step4 ("ding 12" while player is level 10) clears pause and surfaces waiting-for-level notice
        AR.Progression:FocusStep(5)
        T:AssertEqual(AR.Progression.pause, nil, "Landing on an incomplete step must clear pause latch")
        local notice = AR.Progression:GetStepNotice(AR.Progression.currentStep)
        T:AssertEqual(notice.type, "level_gate", "Step with unmet ding goal must surface explicit level_gate notice")
        T:AssertEqual(notice.requiredLevel, 12, "Level gate notice must report required level 12")
    end)

    T:It("computes QuestChains prerequisites and finds the optimal SIS starting step", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Chains:Reset()
        AR.Chains:RegisterChain(364, { prereqs = { 363 } })
        AR.Chains:RegisterChain(365, { prereqs = { 364 } })

        T:AssertFalse(AR.Chains:IsQuestPossible(364), "Quest 364 requires 363 completed")
        MockWoW.quests.completed[363] = true
        T:AssertTrue(AR.Chains:IsQuestPossible(364), "Quest 364 becomes possible once 363 is completed")
        T:AssertFalse(AR.Chains:IsQuestPossible(365), "Quest 365 still requires 364")

        local guide = AR.Parser:ParseGuide("Test\\SIS", [[
            step S1
                accept First##363
                turnin First##363
            step S2
                accept Second##364
            step S3
                accept Third##365
        ]])

        local startStepNum = AR.Chains:FindStartingPoint(guide)
        T:AssertEqual(startStepNum, 2, "SIS FindStartingPoint must skip completed S1 and land on S2")
    end)
end)
