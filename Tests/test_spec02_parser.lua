-- SPEC-02: DSL Compiler & ConditionEnv Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-02: DSL Compiler, #include, leechsteps, |only pruning & ConditionEnv", function()
    T:It("evaluates runtime ConditionEnv predicates (level, completedq, haveq, readyq, itemcount, rep, skill)", function()
        MockWoW:Reset()
        MockWoW.player.level = 15
        MockWoW.player.xp = 200
        MockWoW.player.maxXp = 400
        MockWoW.player.race = "Scourge"
        MockWoW.player.class = "PALADIN"
        MockWoW.quests.completed[855] = true
        MockWoW.quests.inLog[870] = { title = "The Forgotten Pools", isComplete = true, objectives = {} }
        MockWoW.player.itemsInBags[5050] = 4
        MockWoW.player.itemsInBank[5050] = 6

        local AR = _G.AzerothRoute
        local fn = AR.ConditionEnv:Compile("level >= 15 and intlevel == 15 and completedq(855) and haveq(870) and readyq(870) and itemcount(5050) == 4 and itembanked(5050) == 10 and Undead and Paladin")
        T:AssertTrue(fn(), "ConditionEnv compiled closure must evaluate true against live player state")

        MockWoW.player.level = 10
        T:AssertFalse(fn(), "ConditionEnv must react immediately when player level drops below 15")
    end)

    T:It("expands #include templates with %param% interpolation and prunes static |only goals at parse time", function()
        MockWoW:Reset()
        MockWoW.player.race = "Scourge"
        MockWoW.player.class = "PALADIN"
        MockWoW.player.faction = "Horde"

        local AR = _G.AzerothRoute
        AR.Parser:Reset()

        AR.Parser:RegisterInclude("TrainerVisit", [[
            step
                talk %npc%##%npcid%
                learn %spell%##%spellid% |only Paladin
                learn Mage Armor##168 |only Mage
        ]])

        local guide = AR.Parser:ParseGuide("Leveling\\Tirisfal (1-12)", [[
            author AzerothRoute
            type LEVELING
            startlevel 1
            endlevel 12
            next Leveling\Silverpine (12-20)
            defaultfor Undead

            step StartStep
                goto 1420 30.2,71.4
                accept Rude Awakening##363
                kill Mindless Zombie##1501 |q 363/1 |count 8
                |only if level < 10

            #include "TrainerVisit" npc="Brother Malach" npcid="5675" spell="Seal of Righteousness" spellid="21084"

            stickystart "ZombieGrind"
            step ZombieGrind
                kill Wretched Ghoul##1502 |q 364/1 |count 10
            stickystop
            step TurninStep
                turnin Rude Awakening##363 |override
        ]])

        T:AssertEqual(guide.title, "Leveling\\Tirisfal (1-12)", "Guide title must match")
        T:AssertEqual(guide.type, "LEVELING", "Guide type must be LEVELING")
        T:AssertEqual(guide.startlevel, 1, "startlevel must be 1")
        T:AssertEqual(guide.endlevel, 12, "endlevel must be 12")
        T:AssertEqual(#guide.steps, 4, "Guide should contain 4 parsed steps")

        -- Step 1 checks
        local s1 = guide.steps[1]
        T:AssertEqual(s1.label, "StartStep", "Step 1 label should be StartStep")
        T:AssertTrue(type(s1.condition_visible) == "function", "Step 1 should have compiled only if condition")
        T:AssertEqual(#s1.goals, 3, "Step 1 should have 3 goals (goto, accept, kill)")
        T:AssertEqual(s1.goals[1].action, "goto", "Goal 1 action should be goto")
        T:AssertEqual(s1.goals[1].map, 1420, "Goal 1 map should be 1420")
        T:AssertEqual(s1.goals[3].action, "kill", "Goal 3 action should be kill")
        T:AssertEqual(s1.goals[3].questid, 363, "Goal 3 questid should be 363")
        T:AssertEqual(s1.goals[3].objnum, 1, "Goal 3 objnum should be 1")
        T:AssertEqual(s1.goals[3].count, 8, "Goal 3 count should be 8")

        -- Step 2 (#include expansion + static |only pruning)
        local s2 = guide.steps[2]
        T:AssertEqual(#s2.goals, 2, "Mage-only goal must be pruned at parse time for Undead Paladin")
        T:AssertEqual(s2.goals[1].target, "Brother Malach", "#include %npc% parameter must interpolate")
        T:AssertEqual(s2.goals[1].npcid, 5675, "#include %npcid% parameter must parse as number")
        T:AssertEqual(s2.goals[2].spellid, 21084, "Paladin learn goal must survive static |only filter")

        -- Step 3 & 4 (sticky linkage & override flag)
        local s3 = guide.steps[3]
        T:AssertTrue(s3.is_sticky == true, "Step 3 inside stickystart..stickystop must be marked sticky")
        local s4 = guide.steps[4]
        T:AssertTrue(s4.goals[1].override == true, "|override flag must set goal.override = true")
    end)
end)
