-- Polestar's guides (GPL-3.0-only, imported by tools/import_polestar.lua) run on AzerothRoute's engine.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local DUROTAR = "Polestar\\forever/horde/orc/01-durotar"

local function setup(race, class, faction, levelValue)
    MockWoW:Reset()
    local saved = { UnitRace = _G.UnitRace, UnitClass = _G.UnitClass, UnitFactionGroup = _G.UnitFactionGroup }
    _G.UnitRace = function() return race, race end
    _G.UnitClass = function() return class, class:upper() end
    _G.UnitFactionGroup = function() return faction, faction end
    MockWoW.player.level = levelValue or 1
    local AR = _G.AzerothRoute
    AR.Storage:Initialize()
    AR.PolestarGuides:Reset()
    return AR, function()
        for k, v in pairs(saved) do _G[k] = v end
        AR.PolestarGuides:Reset()
    end
end

local function run(race, class, faction, levelValue, fn)
    local AR, restore = setup(race, class, faction, levelValue)
    local ok, err = pcall(fn, AR)
    restore()
    if not ok then error(err, 0) end
end

T:Describe("Polestar guides", function()
    T:It("registers the shared and own-faction guides in the Guide Center, never the other faction's", function()
        run("Orc", "Warrior", "Horde", 1, function(AR)
            local n = AR.PolestarGuides:LoadAll()
            T:AssertTrue(n > 150, "Shared and Horde guides, got " .. n)
            local byType, alliance = {}, 0
            for title, g in pairs(AR.Parser.guidesByTitle) do
                if g.source == "polestar" then
                    T:AssertEqual(title:sub(1, 9), "Polestar\\", "Keyed under Polestar\\")
                    T:AssertTrue(not g.displayTitleEN:find("{", 1, true), "Title tokens resolved: " .. g.displayTitleEN)
                    byType[g.type] = (byType[g.type] or 0) + 1
                    if g.polestarId:find("/alliance/", 1, true) then alliance = alliance + 1 end
                end
            end
            T:AssertEqual(alliance, 0, "No Alliance guides for a Horde character")
            for _, t in ipairs({ "LEVELING", "PROFESSIONS", "CLASS", "REPUTATION", "COLLECTIBLES", "OTHER" }) do
                T:AssertTrue((byType[t] or 0) > 0, "Has " .. t .. " guides")
            end
            local g = AR.Parser.guidesByTitle[DUROTAR]
            T:AssertEqual(g.displayTitleEN, "Durotar", "Zone name as title")
            T:AssertEqual(g.next, "Polestar\\forever/horde/03-silverpine-forest", "Next guide keeps the prefix")
            T:AssertEqual(AR.PolestarGuides:LoadAll(), 0, "Never registered twice")

            AR.GuideMenu:Reset()
            AR.GuideMenu:Show("guides")
            AR.GuideMenu:SelectCategory("CLASS")
            local list = AR.GuideMenu:GetVisibleGuides()
            T:AssertTrue(#list > 0 and list[1].type == "CLASS", "Class category lists the class guides")
            AR.GuideMenu:Reset()
        end)
    end)

    T:It("suggests the race's starting guide and runs it: accept, kill counts, turn-in", function()
        run("Orc", "Warrior", "Horde", 1, function(AR)
            AR.PolestarGuides:LoadAll()
            local suggested = {}
            for _, g in ipairs(AR.GuideMenu:FindSuggestedGuides()) do suggested[g.title] = true end
            T:AssertTrue(suggested[DUROTAR], "Orc start suggested at level 1")
            T:AssertTrue(not suggested["Polestar\\forever/horde/tauren/01-mulgore"], "Not another race's start")

            local g = AR.Parser.guidesByTitle[DUROTAR]
            AR.Progression:LoadGuide(g, 1)
            local s1 = g.steps[1]
            local accept = s1.goals[1]
            T:AssertEqual(accept.action, "accept")
            T:AssertEqual(accept.questid, 4641)
            T:AssertEqual(accept.map, 1411)
            T:AssertTrue(math.abs(accept.x - 0.4322) < 1e-6, "Coordinates as map fractions")
            T:AssertEqual(accept:GetStatus(), "incomplete")

            -- Take every quest of step 1 and turn the first in: the step completes.
            MockWoW.quests.completed[4641] = true
            for _, q in ipairs({ 788, 97279, 1485 }) do
                MockWoW.quests.inLog[q] = { title = "q" .. q, isComplete = false,
                    objectives = { { finished = false, numFulfilled = 0, numRequired = 10 } } }
            end
            T:AssertTrue(s1:IsComplete(), "Step 1 done once its quests are taken and the first turned in")

            local kill = g.steps[2].goals[1]
            T:AssertEqual(kill.action, "kill")
            T:AssertEqual(kill.questid, 788)
            T:AssertEqual(kill.objnum, 1)
            MockWoW.quests.inLog[788].objectives[1].numFulfilled = 4
            local cur, max = kill:GetProgress()
            T:AssertEqual(cur, 4) T:AssertEqual(max, 10)
            T:AssertTrue(kill:GetText():find("(4/10)", 1, true) ~= nil, "Kill shows progress: " .. kill:GetText())
            T:AssertEqual(g.steps[2].goals[2].action, "get", "Collect goals become item goals")
            T:AssertEqual(g.steps[2].goals[3].action, "goto")
        end)
    end)

    T:It("hides steps and goals for other classes and follows `when` quest conditions", function()
        run("Orc", "Warrior", "Horde", 1, function(AR)
            AR.PolestarGuides:LoadAll()
            local g = AR.Parser.guidesByTitle[DUROTAR]
            local shown, hidden = 0, 0
            for _, goal in ipairs(g.steps[3].goals) do
                if goal.action == "accept" and goal.condition_visible then
                    if goal:IsVisible() then shown = shown + 1 else hidden = hidden + 1 end
                end
            end
            T:AssertEqual(shown, 2, "The warrior's letter and the quest every class but warlocks takes")
            T:AssertEqual(hidden, 5, "Other classes' letters hidden")

            local P = AR.PolestarGuides
            T:AssertTrue(P:When({ { k = "turnedin", q = 4641, neg = true } }, g), "Not turned in yet")
            MockWoW.quests.completed[4641] = true
            T:AssertTrue(not P:When({ { k = "turnedin", q = 4641, neg = true } }, g), "Negated once turned in")
            MockWoW.quests.inLog[788] = { isComplete = true }
            T:AssertTrue(P:When({ { k = "onquest", q = { 1, 788 } }, { k = "complete", q = 788 } }, g), "All tests must hold")
            T:AssertTrue(P:When({ { k = "level", n = 1, op = ">=" } }, g))
            T:AssertTrue(not P:When({ { k = "level", n = 10, op = ">=" } }, g))
        end)
    end)

    T:It("hides the built-in leveling and profession guides Polestar's replace, keeping dungeons, gold and open ones", function()
        run("Orc", "Warrior", "Horde", 1, function(AR)
            AR.GuidesCatalog:LoadAll()
            local GM = AR.GuideMenu
            local old = AR.Parser.guidesByTitle["Leveling\\Horde\\Durotar (1-12)"]
            local smithing = AR.Parser.guidesByTitle["Professions\\Blacksmithing (1-300)"]
            local dungeon = AR.Parser.guidesByTitle["Dungeons\\Ragefire Chasm (13-18)"]
            T:AssertTrue(old and smithing and dungeon, "Built-in guides registered")
            T:AssertTrue(not AR.PolestarGuides:Replaces(old), "Nothing replaced before Polestar's guides load")

            AR.PolestarGuides:LoadAll()
            local function listed(category, guide)
                for _, g in ipairs(GM:GetGuidesForCategory(category)) do if g == guide then return true end end
                return false
            end
            T:AssertTrue(not listed("LEVELING", old) and not listed("ALL", old), "Old Durotar hidden")
            T:AssertTrue(not listed("PROFESSIONS", smithing), "Old blacksmithing hidden")
            T:AssertTrue(listed("DUNGEONS", dungeon), "Dungeon guides stay")
            T:AssertTrue(listed("LEVELING", AR.Parser.guidesByTitle[DUROTAR]), "Polestar's Durotar listed")
            for _, g in ipairs(GM:FindSuggestedGuides()) do
                T:AssertTrue(not AR.PolestarGuides:Replaces(g), "Never suggested: " .. g.title)
            end
            for _, g in ipairs(GM:Search("Durotar")) do
                T:AssertTrue(g.source == "polestar", "Search finds Polestar's only")
            end

            -- A replaced guide already in progress keeps running.
            AR.Progression:LoadGuide(old, 1)
            T:AssertTrue(AR.Progression.currentGuide == old, "Still loads")
        end)
    end)

    T:It("maps every Polestar goal kind to a goal the engine can show and finish", function()
        local AR = _G.AzerothRoute
        local P = AR.PolestarGuides
        local step = AR.Step:New({ num = 1, goals = {} })
        local names = { ["npc:1"] = "Bob", ["area:2"] = "Razor Hill" }
        local function build(raw) return P:BuildGoal(raw, step, nil, names) end
        MockWoW:Reset()
        AR.Storage:Initialize()

        local skill = build({ t = "skill", skill = "Riding", level = 75 })
        T:AssertTrue(skill.condition_complete ~= nil and skill:GetText():find("Riding 75", 1, true) ~= nil, "Skill goal")
        local savedMoney = _G.GetMoney
        _G.GetMoney = function() return 0 end
        local money = build({ t = "money", money = 10000 })
        T:AssertEqual(money:GetStatus(), "incomplete")
        _G.GetMoney = function() return 20000 end
        T:AssertEqual(money:GetStatus(), "complete", "Money goal completes with enough gold")
        _G.GetMoney = savedMoney
        local explore = build({ t = "explore", text = "{area:2}", map = 1411, x = 50, y = 40 })
        T:AssertEqual(explore.action, "goto")
        T:AssertTrue(explore:GetText():find("Razor Hill", 1, true) ~= nil, "Explore names the place: " .. explore:GetText())
        local die = build({ t = "die", location = "Sen'jin Village", map = 1411, x = 57, y = 73 })
        T:AssertTrue(die.confirm, "Die is confirmed by hand")
        local note = build({ t = "note", text = "Talk to {npc:1}" })
        T:AssertEqual(note:GetText(), "Talk to Bob", "Note text with tokens resolved")
        T:AssertEqual(note:GetStatus(), "passive")
        local abandon = build({ t = "abandon", quest = 5, title = "Old" })
        T:AssertEqual(abandon:GetStatus(), "complete", "Abandon done when the quest is not in the log")
        local fp = build({ t = "getfp", location = "Razor Hill", npc = 1, npcName = "Bob", map = 1411, x = 1, y = 2 })
        T:AssertEqual(fp.action, "fpath") T:AssertEqual(fp.param, "Razor Hill")
        local kill = build({ t = "kill", target = "Boar", npc = 3 })
        T:AssertTrue(kill.optional, "A kill tied to no quest never blocks the step")
    end)
end)
