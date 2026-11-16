-- SPEC-01 Kernel & Runtime Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-01: Kernel, Compat, Storage, Events & Coroutine Scheduler", function()
    T:It("initializes 3-tier SavedVariables (global, factionrealm, char) without persisting step completion", function()
        MockWoW:Reset()
        _G.AzerothRouteSavedDB = nil
        _G.AzerothRouteCharDB = nil

        local AR = _G.AzerothRoute
        T:AssertTrue(AR ~= nil, "AzerothRoute global table must exist")
        AR.Storage:Initialize()

        T:AssertTrue(AR.db ~= nil, "AR.db must be initialized")
        T:AssertTrue(AR.db.global ~= nil, "AR.db.global must exist")
        T:AssertTrue(AR.db.factionrealm ~= nil, "AR.db.factionrealm must exist")
        T:AssertTrue(AR.db.char ~= nil, "AR.db.char must exist")
        T:AssertEqual(AR.db.char.completedSteps, nil, "Step completion must never be persisted in char DB")
        T:AssertTrue(type(AR.db.char.guidestephistory) == "table", "guidestephistory table must exist")
        T:AssertTrue(type(AR.db.char.saved_sticky_goals) == "table", "saved_sticky_goals table must exist")
    end)

    T:It("computes FPS-adaptive frame budgets (5ms / 10ms / 20ms / 1ms in combat)", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute

        MockWoW.inCombat = false
        MockWoW.fps = 30
        T:AssertEqual(AR.Scheduler:GetFrameBudgetMs(), 5, "FPS < 40 should budget 5ms")

        MockWoW.fps = 50
        T:AssertEqual(AR.Scheduler:GetFrameBudgetMs(), 10, "40 <= FPS < 60 should budget 10ms")

        MockWoW.fps = 75
        T:AssertEqual(AR.Scheduler:GetFrameBudgetMs(), 20, "FPS >= 60 should budget 20ms")

        MockWoW.inCombat = true
        T:AssertEqual(AR.Scheduler:GetFrameBudgetMs(), 1, "Combat lockdown should throttle budget to 1ms")
    end)

    T:It("executes startup phases in order and yields across frames when budget is exceeded", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Scheduler:Reset()

        local log = {}
        AR.Scheduler:RegisterPhaseTask("before_guides", "task_b", function()
            table.insert(log, "before_guides_1")
            MockWoW:AdvanceTime(15) -- exceed 10ms budget
            AR.Scheduler:YieldIfNeeded()
            table.insert(log, "before_guides_2")
        end)
        AR.Scheduler:RegisterPhaseTask("load_guides", "task_l", function()
            table.insert(log, "load_guides")
        end)
        AR.Scheduler:RegisterPhaseTask("after_guides", "task_ag", function()
            table.insert(log, "after_guides")
        end)
        AR.Scheduler:RegisterPhaseTask("after_all", "task_aa", function()
            table.insert(log, "after_all")
        end)
        AR.Scheduler:RegisterPhaseTask("postcombat", "task_pc", function()
            table.insert(log, "postcombat")
        end)

        MockWoW.fps = 50 -- 10ms budget
        MockWoW.inCombat = false

        -- Frame 1: runs before_guides_1, then yields because 15ms > 10ms
        AR.Scheduler:StepFrame()
        T:AssertEqual(#log, 1, "Should have yielded after first heavy step")
        T:AssertEqual(log[1], "before_guides_1", "First entry should be before_guides_1")

        -- Frame 2: player enters combat before postcombat phase -> finishes before_guides_2, load_guides, after_guides, after_all (5 entries), then waits out of combat
        MockWoW.inCombat = true
        AR.Scheduler:StepFrame()
        T:AssertEqual(#log, 5, "Should stop before postcombat while inCombat is true")
        T:AssertEqual(log[5], "after_all", "Fifth entry should be after_all")
        T:AssertFalse(AR.Scheduler:IsStartupComplete(), "Startup should wait for combat to end before postcombat")

        -- Frame 3: combat ends, postcombat runs
        MockWoW.inCombat = false
        AR.Scheduler:StepFrame()
        T:AssertEqual(#log, 6, "Should run postcombat once out of combat")
        T:AssertEqual(log[6], "postcombat", "Sixth entry should be postcombat")
        T:AssertTrue(AR.Scheduler:IsStartupComplete(), "Startup should mark complete after postcombat")
    end)

    T:It("multiplexes WoW events and internal messages through Core/Events.lua", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Events:Reset()

        local receivedQuestUpdate = 0
        local receivedCustomMsg = nil

        AR.Events:RegisterEvent("QUEST_LOG_UPDATE", function()
            receivedQuestUpdate = receivedQuestUpdate + 1
        end)
        AR.Events:RegisterMessage("AR_STEP_CHANGED", function(_, stepNum)
            receivedCustomMsg = stepNum
        end)

        MockWoW:FireEvent("QUEST_LOG_UPDATE")
        AR.Events:SendMessage("AR_STEP_CHANGED", 7)

        T:AssertEqual(receivedQuestUpdate, 1, "Event listener should fire once on QUEST_LOG_UPDATE")
        T:AssertEqual(receivedCustomMsg, 7, "Message listener should receive payload 7")
    end)
end)
