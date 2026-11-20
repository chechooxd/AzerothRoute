-- Polestar-parity UI round: step heading, folded done goals, Then line, notes, toolbar,
-- while-here, step browser, minimap menu, guide center details, quest log cleanup.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local GUIDE = [[
step First
    talk Devrak##3615
    accept Plainstrider Menace##844
    accept Wharfmaster Dizzywig##1492
    kill 7 Plainstrider##3244 |tip They roam the hills east of the road.
step Second
    talk Gazlowe##3391
    turnin Plainstrider Menace##844
step Third
    goto 1413 50.0,50.0
]]

local function withMaps(fn)
    local orig = _G.C_Map.GetMapInfo
    _G.C_Map.GetMapInfo = function(id) if id == 1413 then return { name = "The Barrens" } end end
    local ok, err = pcall(fn)
    _G.C_Map.GetMapInfo = orig
    if not ok then error(err, 0) end
end

local function load(AR, text)
    AR.Storage:Initialize()
    AR.db.profile.previewsteps = 0
    local g = AR.Parser:ParseGuide("Parity_" .. tostring(math.random(1e9)), text or GUIDE)
    AR.Progression:LoadGuide(g, 1)
    AR.Progression.pause = true
    return g
end

local function shownTexts(AR)
    local out = {}
    for _, row in ipairs(AR.ViewerFrame.lineRows) do
        if row:IsShown() then table.insert(out, row.label:GetText()) end
    end
    return out
end

T:Describe("Polestar parity: viewer body", function()
    T:It("heads the step with the person to see, coloured, and the zone under it", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        withMaps(function()
            local g = load(AR)
            g:GetStep(1).goals[1].map = 1413
            AR.ViewerFrame:RefreshVisuals()
            local vf = AR.ViewerFrame
            T:AssertTrue(vf.headingText:IsShown(), "Heading shown")
            T:AssertEqual(vf.headingText:GetText(), "|cff8cc4f5Devrak|r", "NPC name in NPC blue")
            T:AssertEqual(vf.headingSub:GetText(), "The Barrens", "Zone under the name")
        end)
    end)

    T:It("folds two or more finished goals into one 'N done' line that unfolds on click", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        MockWoW.quests.inLog[844] = { title = "Plainstrider Menace", isComplete = false, objectives = {} }
        MockWoW.quests.inLog[1492] = { title = "Wharfmaster Dizzywig", isComplete = false, objectives = {} }
        AR.ViewerFrame:RefreshVisuals()
        local texts = table.concat(shownTexts(AR), "\n")
        T:AssertTrue(texts:find("2 done", 1, true) ~= nil, "Folded line present: " .. texts)
        T:AssertEqual(texts:find("Accepted", 1, true), nil, "Finished goals are folded away")
        local foldRow
        for _, row in ipairs(AR.ViewerFrame.lineRows) do if row._isFold and row:IsShown() then foldRow = row end end
        foldRow:GetScript("OnClick")(foldRow, "LeftButton")
        texts = table.concat(shownTexts(AR), "\n")
        T:AssertEqual(texts:find("2 done", 1, true), nil, "Unfolded")
        T:AssertTrue(texts:find("Plainstrider Menace", 1, true) ~= nil, "Finished goals visible again")
        AR.Progression:SkipStep(false)
        AR.ViewerFrame:RefreshVisuals()
        T:AssertFalse(AR.ViewerFrame.expandDone, "Unfold resets on the next step")
    end)

    T:It("previews the next step on one 'Then:' line and shows the step tip", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        local vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertTrue(vm.thenLine ~= nil, "Then line built")
        T:AssertTrue(vm.thenLine.text:find("^Then: Talk to Gazlowe") ~= nil, "Next step's first goal: " .. vm.thenLine.text)
        T:AssertEqual(vm.note, "They roam the hills east of the road.", "Tip becomes the note")
        local texts = table.concat(shownTexts(AR), "\n")
        T:AssertTrue(texts:find("› They roam", 1, true) ~= nil, "Note line shown")
        AR.db.profile.previewsteps = 2
        vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(vm.thenLine, nil, "Full preview replaces the Then line")
        AR.db.profile.previewsteps = 0
    end)
end)

T:Describe("Polestar parity: toolbar and footer", function()
    T:It("skips with the Skip button and opens the map on the waypoint", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(AR.ViewerFrame.skipButton.label:GetText(), AR.L:Get("UI_SKIP"))
        AR.ViewerFrame.skipButton:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentStep.num, 2, "Skip advances one step")
        AR.Pointer.activeTarget = { type = "waypoint", map = 1413, x = 0.5, y = 0.5 }
        _G.WorldMapFrame._mapID = nil
        AR.ViewerFrame.mapButton:Click("LeftButton")
        AR.UI:FindMenuItem(AR.L:Get("UI_MAP_MENU_WAYPOINT")):Click("LeftButton")
        T:AssertEqual(_G.WorldMapFrame:GetMapID(), 1413, "World map on the waypoint zone")
    end)

    T:It("opens the ... menu with steps, quest log, guides, talents, options and hide", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.moreButton:Click("LeftButton")
        T:AssertTrue(AR.UI.menu:IsShown(), "Menu open")
        for _, key in ipairs({ "UI_MENU_STEPS", "UI_MENU_QUESTLOG", "UI_GUIDES", "UI_TALENTS", "UI_MENU_OPTIONS", "UI_MENU_HIDE" }) do
            T:AssertTrue(AR.UI:FindMenuItem(AR.L:Get(key)) ~= nil, key .. " present")
        end
        AR.UI:FindMenuItem(AR.L:Get("UI_MENU_HIDE")):Click("LeftButton")
        T:AssertFalse(AR.ViewerFrame.frame:IsShown(), "Hide closes the guide window")
        T:AssertFalse(AR.UI.menu:IsShown(), "Menu closes after a pick")
        AR.ViewerFrame.frame:Show()
    end)

    T:It("shows XP per hour and time to level once enough XP was earned", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:ResetXPTracker()
        MockWoW.player.xp, MockWoW.player.maxXp = 100, 1000
        AR.ViewerFrame:RefreshVisuals()
        T:AssertFalse(AR.ViewerFrame.xpText:IsShown(), "No rate yet")
        MockWoW:AdvanceTime(60000)
        MockWoW.player.xp = 400
        local vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(vm.xpLine, "18.0k XP/h · 2m to level", "300 XP in 60 s; 600 left")
        T:AssertTrue(AR.ViewerFrame.xpText:IsShown(), "Line shown")
        -- Level up: rest of the old bar plus the new progress counts.
        MockWoW.player.xp, MockWoW.player.maxXp = 50, 1200
        AR.ViewerFrame:SampleXP()
        T:AssertEqual(AR.ViewerFrame.xp.gained, 950, "300 + 600 + 50")
        AR.ViewerFrame:ResetXPTracker()
    end)
end)

T:Describe("Polestar parity: while you're here", function()
    T:It("shows each sticky goal's distance and dismisses it with ×", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR, [[
step Main
    talk Devrak##3615
stickystart
step Side
    kill 5 Plainstrider##3244
    goto 1413 52.0,48.0
stickystop
step After
    talk Gazlowe##3391
]])
        local origStickies = AR.Progression.GetActiveStickies
        AR.Progression.GetActiveStickies = function() return { g:GetStep(2) } end
        local origDist = AR.Coords.GetDistanceTo
        AR.Coords.GetDistanceTo = function() return 134.6 end
        local ok, err = pcall(function()
            local kill = g:GetStep(2).goals[1]
            kill.map, kill.x, kill.y = 1413, 0.52, 0.48
            AR.ViewerFrame:RefreshVisuals()
            local row
            for _, r in ipairs(AR.ViewerFrame.lineRows) do if r._goal == kill and r:IsShown() then row = r end end
            T:AssertTrue(row ~= nil, "Sticky kill row")
            T:AssertEqual(row.dist:GetText(), "135 yd", "Distance in yards")
            T:AssertTrue(row.dismiss:IsShown(), "Dismiss button")
            T:AssertFalse(row.check:IsShown(), "No check box in the block")
            row.dismiss:Click("LeftButton")
            T:AssertTrue(kill.dismissed, "Dismissed for the session")
            local still = false
            for _, r in ipairs(AR.ViewerFrame.lineRows) do if r._goal == kill and r:IsShown() then still = true end end
            T:AssertFalse(still, "Row gone after ×")
        end)
        AR.Progression.GetActiveStickies = origStickies
        AR.Coords.GetDistanceTo = origDist
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Polestar parity: all steps", function()
    T:It("lists every step as a card with done ticks and jumps on click", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.StepBrowser:Reset()
        local g = load(AR)
        MockWoW.quests.inLog[844] = { title = "Plainstrider Menace", isComplete = false, objectives = {} }
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.stepsButton:Click("LeftButton")
        local SB = AR.StepBrowser
        T:AssertTrue(SB.frame:IsShown(), "Opened from the step counter")
        T:AssertEqual(SB.visibleCount, 3, "One card per step")
        local first = SB.cards[1]
        T:AssertEqual(first.header:GetText():sub(1, 1), "1", "Card header starts with the step number")
        T:AssertTrue(first.accent:IsShown(), "Current step marked")
        T:AssertEqual(first.icons[2]:GetTexture(), AR.Skins.CHECK_ICON, "Accepted quest ticked")
        SB.cards[3]:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentStep.num, 3, "Jumped to step 3")
        T:AssertFalse(SB.frame:IsShown(), "Browser closes after the jump")
    end)

    T:It("folds long steps into '+N more' and scrolls by step", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.StepBrowser:Reset()
        local lines = { "step Big" }
        for i = 1, 9 do table.insert(lines, "    talk Npc" .. i .. "##" .. (5000 + i)) end
        table.insert(lines, "step Small")
        table.insert(lines, "    talk Gazlowe##3391")
        load(AR, table.concat(lines, "\n"))
        local SB = AR.StepBrowser
        SB:Show()
        local model = SB.cards[1]._model
        T:AssertEqual(model.more, 3, "9 goals: 6 shown, 3 folded")
        T:AssertEqual(SB.cards[1].lines[7]:GetText(), "+3 more")
        SB:Scroll(1)
        T:AssertEqual(SB.cards[1]._step.num, 2, "Wheel moves one step")
        SB.frame:Hide()
    end)
end)

T:Describe("Polestar parity: minimap menu", function()
    T:It("hides everything in one click and brings it back on the next", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.frame:Show()
        AR.Pointer:InitializeFrames()
        AR.Pointer.activeTarget = { type = "waypoint", map = 1413, x = 0.5, y = 0.5 }
        AR.db.profile.keeparrow = false
        AR.MinimapButton:HandleClick("LeftButton")
        T:AssertTrue(AR.db.profile.hideall, "Hidden flag stored")
        T:AssertFalse(AR.ViewerFrame.frame:IsShown(), "Guide window hidden")
        AR.Pointer:UpdateArrow(0.033)
        T:AssertFalse(AR.Pointer.arrowFrame:IsShown(), "Arrow hidden too")
        AR.MinimapButton:HandleClick("LeftButton")
        T:AssertFalse(AR.db.profile.hideall)
        T:AssertTrue(AR.ViewerFrame.frame:IsShown(), "Guide window back")
        AR.Pointer.activeTarget = { type = "waypoint", map = 1413, x = 0.5, y = 0.5 }
        AR.Pointer:UpdateArrow(0.033)
        T:AssertTrue(AR.Pointer.arrowFrame:IsShown(), "Arrow back")
        AR.db.profile.keeparrow = true
        AR.MinimapButton:SetHideAll(true)
        AR.Pointer:UpdateArrow(0.033)
        T:AssertTrue(AR.Pointer.arrowFrame:IsShown(), "Kept arrow survives hide-all")
        AR.MinimapButton:SetHideAll(false)
    end)

    T:It("right-click opens the menu with the guide window ticked and Hide arrow working", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.frame:Show()
        AR.MinimapButton:HandleClick("RightButton")
        local item = AR.UI:FindMenuItem(AR.L:Get("UI_MM_GUIDE_WINDOW"))
        T:AssertTrue(item ~= nil and item.check:IsShown(), "Guide window ticked")
        AR.UI:FindMenuItem(AR.L:Get("UI_MM_HIDE_ARROW")):Click("LeftButton")
        T:AssertTrue(AR.db.profile.hidearrow, "Arrow switch stored")
        T:AssertTrue(AR.MinimapButton:IsArrowSuppressed())
        AR.MinimapButton:SetArrowHidden(false)
    end)
end)

T:Describe("Polestar parity: guide center", function()
    T:It("filters the list as you type and clears the search on a category click", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.GuideMenu:Reset()
        AR.GuideMenu:Show()
        local all = #AR.GuideMenu:GetVisibleGuides()
        local box = AR.GuideMenu.searchBox
        box.GetText = function() return "parity" end
        box:GetScript("OnTextChanged")(box)
        local hits = AR.GuideMenu:GetVisibleGuides()
        T:AssertTrue(#hits >= 1 and #hits < all, "Search narrows the list (" .. #hits .. " of " .. all .. ")")
        T:AssertTrue(AR.GuideMenu.guideRowButtons[1]._guide.title:lower():find("parity", 1, true) ~= nil, "First row matches")
        AR.GuideMenu:SelectCategory("ALL")
        T:AssertEqual(AR.GuideMenu.searchQuery, "", "Category click clears the search")
        AR.GuideMenu:Reset()
    end)

    T:It("details show level chips, progress on the loaded guide and stats", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        g.startlevel, g.endlevel, g.type = 1, 10, "LEVELING"
        MockWoW.player.level = 5
        AR.GuideMenu:Reset()
        AR.GuideMenu:InitializeFrame()
        AR.GuideMenu:SelectGuide(g)
        local d = AR.GuideMenu.details
        T:AssertEqual(d.chips[1].text, AR.L:Format("UI_LEVELS_FMT", 1, 10), "Level chip")
        T:AssertEqual(d.chips[2].text, AR.L:Get("UI_YOUR_LEVEL"), "Your level chip")
        T:AssertEqual(d.status, AR.L:Format("UI_STATUS_STEP_FMT", 1, 3), "Loaded guide shows its step")
        T:AssertEqual(d.steps, 3)
        T:AssertEqual(d.quests, 2, "Two distinct accepted quests")
        T:AssertTrue(AR.GuideMenu.chips[1]:IsShown() and AR.GuideMenu.detailFill:IsShown(), "Chips and bar drawn")
        T:AssertEqual(AR.GuideMenu.statRows[2].value:GetText(), "2")
        AR.GuideMenu:Reset()
    end)
end)

T:Describe("Polestar parity: quest log cleanup", function()
    T:It("lists quests the route never hands in and opens the game's abandon confirmation", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.QuestLogCleanup:Reset()
        load(AR)
        MockWoW.quests.inLog[844] = { title = "Plainstrider Menace", isComplete = false, objectives = {} }
        MockWoW.quests.inLog[9999] = { title = "Dwarven Outfitters", isComplete = false, objectives = {} }
        local calls = {}
        local saved = { _G.SelectQuestLogEntry, _G.SetAbandonQuest, _G.StaticPopup_Show, _G.GetQuestLogIndexByID }
        _G.SelectQuestLogEntry = function(i) table.insert(calls, "select:" .. i) end
        _G.SetAbandonQuest = function() table.insert(calls, "set") end
        _G.StaticPopup_Show = function(which, name) table.insert(calls, which .. ":" .. tostring(name)) end
        _G.GetQuestLogIndexByID = function(id) return id == 9999 and 3 or 0 end
        local ok, err = pcall(function()
            AR.QuestLogCleanup:Show()
            local list = AR.QuestLogCleanup.candidates
            T:AssertEqual(#list, 1, "Only the off-route quest")
            T:AssertEqual(list[1].id, 9999)
            local row = AR.QuestLogCleanup.rows[1]
            T:AssertTrue(row:IsShown(), "Row drawn")
            T:AssertEqual(row.title:GetText(), "Dwarven Outfitters")
            row.abandon:Click("LeftButton")
            T:AssertEqual(table.concat(calls, ","), "select:3,set,ABANDON_QUEST:Dwarven Outfitters", "Select, mark, then the game's confirmation")
            T:AssertTrue(MockWoW.quests.inLog[9999] ~= nil, "Nothing is abandoned without the player's confirmation")
        end)
        _G.SelectQuestLogEntry, _G.SetAbandonQuest, _G.StaticPopup_Show, _G.GetQuestLogIndexByID = saved[1], saved[2], saved[3], saved[4]
        AR.QuestLogCleanup:Reset()
        if not ok then error(err, 0) end
    end)

    T:It("lists nothing when no guide is loaded", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local orig = AR.Progression.currentGuide
        AR.Progression.currentGuide = nil
        local n = #AR.QuestLogCleanup:GetCandidates()
        AR.Progression.currentGuide = orig
        T:AssertEqual(n, 0)
    end)
end)

T:Describe("Polestar parity: key bindings", function()
    T:It("declares every binding in Bindings.xml with a label and a working action", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:RefreshVisuals()
        local fh = assert(io.open("Bindings.xml", "r"))
        local xml = fh:read("*a")
        fh:close()
        local count = 0
        for name, action in xml:gmatch('<Binding name="AZEROTHROUTE_(%u+)"[^>]*>%s*AzerothRoute%.Bindings:Run%("(%l+)"%)') do
            count = count + 1
            local label = _G["BINDING_NAME_AZEROTHROUTE_" .. name]
            T:AssertTrue(type(label) == "string" and not label:find("^BIND_"), name .. " has a label")
            T:AssertTrue(AR.Bindings.Run ~= nil and action ~= "", name .. " has an action")
        end
        T:AssertEqual(count, 6, "Six bindings")
        AR.Bindings:Run("next")
        T:AssertEqual(AR.Progression.currentStep.num, 2, "Next step binding")
        AR.Bindings:Run("prev")
        T:AssertEqual(AR.Progression.currentStep.num, 1, "Previous step binding")
        T:AssertFalse(AR.Bindings:Run("nope"), "Unknown action refused")
    end)
end)

T:Describe("Polestar parity: guide tabs", function()
    T:It("keeps open guides as tabs, switches between them at their step and closes them", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.profile.previewsteps = 0
        AR.db.char.tabguides, AR.db.char.tabsteps = {}, {}
        local a = AR.Parser:ParseGuide("Tabs Alpha", "step A1\n    talk Devrak##3615\nstep A2\n    talk Gazlowe##3391\nstep A3\n    talk Thrall##4949\n")
        local b = AR.Parser:ParseGuide("Tabs Beta", "step B1\n    talk Gazlowe##3391\n")
        AR.Progression:LoadGuide(a, 2)
        AR.Progression.pause = true
        AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(#AR.ViewerFrame.visibleTabs, 1, "One tab")
        T:AssertFalse(AR.ViewerFrame.tabCloseButtons[1]:IsShown(), "A lone tab cannot be closed")
        T:AssertTrue(AR.ViewerFrame.addTabButton:IsShown(), "+ button")
        AR.ViewerFrame:SwitchToGuide("Tabs Beta")
        T:AssertEqual(AR.Progression.currentGuide, b)
        T:AssertEqual(#AR.ViewerFrame.visibleTabs, 2, "Two tabs")
        local other = AR.ViewerFrame.tabButtons[1]
        T:AssertEqual(other._title, "Tabs Alpha", "Inactive tab is the first guide")
        other:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentGuide, a, "Back to the first guide")
        T:AssertEqual(AR.Progression.currentStep.num, 2, "At the step it was left on")
        AR.ViewerFrame:CloseTab("Tabs Alpha")
        T:AssertEqual(AR.Progression.currentGuide, b, "Closing the active tab opens the remaining one")
        T:AssertEqual(#AR.Tabs:GetTabs(), 1)
        AR.ViewerFrame.addTabButton:Click("LeftButton")
        T:AssertTrue(AR.GuideMenu.frame:IsShown() and AR.GuideMenu.mode == "guides", "+ opens the guide list")
        AR.GuideMenu:Reset()
        AR.db.char.tabguides, AR.db.char.tabsteps = {}, {}
    end)
end)

T:Describe("Polestar parity: group quests", function()
    local GUIDE = [[
step Take
    talk Marshal Dughan##240
    accept Wanted: "Hogger"##176
    accept A Fishy Peril##40
step Hunt
    kill Hogger##448 |q 176/1
step Back
    turnin Wanted: "Hogger"##176
step Next
    talk Gazlowe##3391
]]

    local function setup(AR)
        AR.Storage:Initialize()
        AR.db.profile.previewsteps = 0
        AR.db.char.skippedQuests, AR.db.char.groupQuestsKept = {}, {}
        AR.db.global.groupQuests = {}
        MockWoW.player.faction = "Alliance"
        local g = AR.Parser:ParseGuide("GroupGuide", GUIDE)
        AR.Progression:LoadGuide(g, 1)
        return g
    end

    T:It("warns about a group quest and keeps it when the player chooses a group", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        setup(AR)
        local vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(vm.groupQuest.questID, 176, "Hogger is a group quest (database flag)")
        local vf = AR.ViewerFrame
        T:AssertTrue(vf.groupTitle:IsShown() and vf.groupSkip:IsShown() and vf.groupKeep:IsShown(), "Banner with both choices")
        T:AssertTrue(vf.groupTitle:GetText():find("Hogger", 1, true) ~= nil, "Names the quest")
        vf.groupKeep:Click("LeftButton")
        T:AssertTrue(AR.GroupQuests:IsKept(176), "Kept")
        T:AssertFalse(vf.groupTitle:IsShown(), "Banner gone")
        T:AssertEqual(AR.GroupQuests:ForStep(AR.Progression.currentStep), nil, "No longer asked")
    end)

    T:It("skipping drops the quest's accept, kill and turn-in from the route", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = setup(AR)
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.groupSkip:Click("LeftButton")
        T:AssertTrue(AR.GroupQuests:IsSkipped(176), "Skipped")
        T:AssertEqual(g:GetStep(1).goals[2]:GetStatus(), "hidden", "Accept hidden")
        T:AssertTrue(g:GetStep(1).goals[3]:GetStatus() ~= "hidden", "The solo quest stays")
        local hunt, back = g:GetStep(2), g:GetStep(3)
        T:AssertEqual(hunt.goals[1]:GetStatus(), "hidden", "Kill hidden")
        T:AssertEqual(back.goals[1]:GetStatus(), "hidden", "Turn-in hidden")
        AR.Progression:FocusStep(2)
        AR.GroupQuests:Skip(176)
        T:AssertEqual(AR.Progression.currentStep.num >= 3, true, "A step left with nothing to do moves on")
    end)

    T:It("learns group size from the quest offer and the quest log", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        setup(AR)
        T:AssertFalse(AR.GroupQuests:IsGroupQuest(40), "A Fishy Peril is solo")
        local saved = { _G.GetQuestID, _G.GetSuggestedGroupNum }
        _G.GetQuestID = function() return 40 end
        _G.GetSuggestedGroupNum = function() return 3 end
        AR.GroupQuests:OnQuestDetail()
        _G.GetQuestID, _G.GetSuggestedGroupNum = saved[1], saved[2]
        T:AssertTrue(AR.GroupQuests:IsGroupQuest(40), "Offer said 3 players")
        AR.db.global.groupQuests = {}
        AR.QuestTracking.questsById[40] = { id = 40, title = "A Fishy Peril", suggestedGroup = 2 }
        T:AssertTrue(AR.GroupQuests:IsGroupQuest(40), "Quest log said 2 players")
        AR.QuestTracking.questsById[40] = nil
    end)
end)

T:Describe("Polestar parity: reward preview", function()
    local function stubAll(AR, t)
        local names = {}
        for k in pairs(t) do names[#names + 1] = k end
        local saved = {}
        for _, k in ipairs(names) do saved[k] = _G[k]; _G[k] = t[k] end
        return function() for _, k in ipairs(names) do _G[k] = saved[k] end end
    end

    T:It("records rewards from the quest offer and previews the pick the guide would make", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.questRewards = {}
        local links = { choice = { "|cff1eff00|Hitem:2232:0:0:0|h[Dark Leather Belt]|h|r", "|cff1eff00|Hitem:2233:0:0:0|h[Shadow Weaver Leggings]|h|r" } }
        local restore = stubAll(AR, {
            GetQuestID = function() return 176 end,
            GetNumQuestChoices = function() return 2 end,
            GetNumQuestRewards = function() return 0 end,
            GetQuestItemLink = function(kind, i) return links[kind] and links[kind][i] end,
            GetItemInfo = function(link)
                local id = tonumber(tostring(link):match("item:(%d+)"))
                return ({ [2232] = "Dark Leather Belt", [2233] = "Shadow Weaver Leggings" })[id]
            end,
        })
        local origPick = AR.QuestReward.SelectBestReward
        AR.QuestReward.SelectBestReward = function(_, l) return { index = 2, itemLink = l[2], reason = "upgrade" } end
        local ok, err = pcall(function()
            local rec = AR.QuestRewards:OnQuestDetail()
            T:AssertEqual(table.concat(rec.choice, ","), "2232,2233", "Both choices recorded")
            local p = AR.QuestRewards:Preview(176)
            T:AssertEqual(p.itemID, 2233)
            T:AssertEqual(p.name, "Shadow Weaver Leggings")
            T:AssertTrue(p.isUpgrade, "Upgrade marked")

            AR.db.profile.previewsteps = 0
            local g = AR.Parser:ParseGuide("RewardGuide", 'step Take\n    accept Wanted: "Hogger"##176\n')
            AR.Progression:LoadGuide(g, 1)
            AR.Progression.pause = true
            AR.db.char.groupQuestsKept = { [176] = true }
            AR.ViewerFrame:RefreshVisuals()
            local found
            for _, row in ipairs(AR.ViewerFrame.lineRows) do
                if row:IsShown() and row.label:GetText():find("Shadow Weaver Leggings", 1, true) then found = row.label:GetText() end
            end
            T:AssertTrue(found ~= nil, "Reward line under the accept")
            T:AssertTrue(found:find(AR.L:Get("UI_REWARD_NEW"), 1, true) ~= nil, "Marked new")
            T:AssertTrue(found:find(AR.L:Get("UI_REWARD_AT_TURNIN"), 1, true) ~= nil, "Says at turn-in")
        end)
        restore()
        AR.QuestReward.SelectBestReward = origPick
        AR.db.char.groupQuestsKept = {}
        if not ok then error(err, 0) end
    end)

    T:It("reads rewards of quests already in the log and restores the log selection", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.questRewards = {}
        local selected = 7
        local calls = {}
        local restore = stubAll(AR, {
            GetQuestLogSelection = function() return selected end,
            SelectQuestLogEntry = function(i) selected = i; calls[#calls + 1] = i end,
            GetNumQuestLogChoices = function() return 0 end,
            GetNumQuestLogRewards = function() return selected == 3 and 1 or 0 end,
            GetQuestLogItemLink = function(kind, i) if kind == "reward" and selected == 3 then return "item:1931" end end,
        })
        local origLog = AR.QuestTracking.questsById
        AR.QuestTracking.questsById = { [40] = { id = 40, title = "A Fishy Peril", logIndex = 3 } }
        local ok, err = pcall(function()
            T:AssertEqual(AR.QuestRewards:ScanLog(), 1, "One quest read")
            T:AssertEqual(AR.QuestRewards:Get(40).reward[1], 1931)
            T:AssertEqual(selected, 7, "Selection restored")
            T:AssertEqual(AR.QuestRewards:ScanLog(), 0, "Known quests are not read again")
            T:AssertEqual(AR.QuestRewards:Preview(999), nil, "Unknown quest: no preview")
        end)
        AR.QuestTracking.questsById = origLog
        restore()
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Polestar parity: talent window", function()
    T:It("uses the sidebar, spec underline, next-point card and ticked roadmap", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local TA = AR.TalentAdvisor
        TA:ShowUI()
        TA:SelectClass("MAGE")
        local mage
        for _, b in ipairs(TA.classButtons) do if b._classToken == "MAGE" then mage = b end end
        T:AssertTrue(mage.accent:IsShown(), "Selected class carries the gold bar")
        T:AssertEqual(mage.label:GetText(), TA:GetClassFullName("MAGE"), "Full class name in the sidebar")
        T:AssertTrue(TA.frame.specUnderline:IsShown(), "Selected spec underlined")
        T:AssertTrue(TA.headerSub:GetText():find(TA:GetClassFullName("MAGE"), 1, true) ~= nil, "Header names class and build")
        local origSpent = TA.GetSpentPointsCount
        TA.GetSpentPointsCount = function() return 3 end
        TA:RefreshUI()
        T:AssertTrue(TA.roadmapRows[1].check:IsShown(), "Spent points ticked")
        T:AssertTrue(TA.roadmapRows[4].accent:IsShown(), "Next point highlighted")
        T:AssertTrue(TA.frame.fill:IsShown(), "Points progress bar")
        TA.GetSpentPointsCount = origSpent
        TA.frame:GetScript("OnMouseWheel")(TA.frame, -1)
        T:AssertEqual(TA.scrollOffset, 3, "Mouse wheel scrolls the roadmap")
        TA.frame:Hide()
    end)
end)

T:Describe("Polestar parity: Guide Center home", function()
    T:It("opens on Home with the guide in progress first and Continue resumes it", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.char.tabguides = {}
        local g = AR.Parser:ParseGuide("HomeGuide", "step One\n    talk Devrak##3615\nstep Two\n    talk Gazlowe##3391\n")
        AR.Progression:LoadGuide(g, 2)
        AR.Progression.pause = true
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame.frame:Hide()
        AR.GuideMenu:Reset()
        AR.GuideMenu:Show()
        T:AssertEqual(AR.GuideMenu.activeCategory, "HOME")
        T:AssertEqual(AR.GuideMenu.guideRowButtons[1]._guide, g, "Guide in progress first")
        T:AssertEqual(AR.GuideMenu.loadButton.label:GetText(), AR.L:Get("UI_CONTINUE"))
        AR.GuideMenu.loadButton:Click("LeftButton")
        T:AssertEqual(AR.Progression.currentStep.num, 2, "Continue keeps the step")
        T:AssertTrue(AR.ViewerFrame.frame:IsShown(), "Guide window back")
        T:AssertFalse(AR.GuideMenu.frame:IsShown(), "Guide Center closes")
        AR.GuideMenu:Reset()
    end)
end)

T:Describe("Polestar parity: gear tooltip", function()
    T:It("adds an upgrade line to item tooltips and compares against the real equipped item", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Upgrades:Reset()
        MockWoW.player.class = MockWoW.player.class or "WARRIOR"
        MockWoW.tooltips.items["item:2001"] = { armorType = "MAIL", slot = "INVTYPE_CHEST", stats = { STR = 4 } }
        MockWoW.tooltips.items["item:2002"] = { armorType = "MAIL", slot = "INVTYPE_CHEST", stats = { STR = 10 } }
        MockWoW.player.equipped["INVTYPE_CHEST"] = "item:2001"
        local lines = {}
        local tip = { GetItem = function() return "Chest", "item:2002" end, AddLine = function(_, t) lines[#lines + 1] = t end }
        local line = AR.GearTooltip:OnTooltipSetItem(tip)
        T:AssertTrue(line ~= nil and line:find("%+%d+%%") ~= nil, "Upgrade with percentage: " .. tostring(line))
        T:AssertEqual(lines[1], line, "Line added to the tooltip")
        tip.GetItem = function() return "Chest", "item:2001" end
        T:AssertEqual(AR.GearTooltip:OnTooltipSetItem(tip), nil, "The equipped item is no upgrade")

        -- Live client path: no mock table; the equipped item comes from GetInventoryItemLink.
        local savedEquipped, savedInv = MockWoW.player.equipped, _G.GetInventoryItemLink
        MockWoW.player.equipped = nil
        _G.GetInventoryItemLink = function(_, slot) if slot == 5 then return "item:2002" end end
        local ok, err = pcall(function()
            T:AssertEqual(AR.Upgrades:EquippedLinkFor("INVTYPE_CHEST"), "item:2002", "Chest slot 5 read from the client")
            local eval = AR.Upgrades:EvaluateCandidate("item:2001")
            T:AssertFalse(eval.isUpgrade, "A weaker chest is not an upgrade over what is worn")
        end)
        MockWoW.player.equipped, _G.GetInventoryItemLink = savedEquipped, savedInv
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Polestar parity: bags and what's new", function()
    T:It("warns in the guide window when the bags are almost full", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local g = AR.Parser:ParseGuide("BagGuide", "step One\n    talk Devrak##3615\n")
        AR.Progression:LoadGuide(g, 1)
        AR.Progression.pause = true
        local saved = _G.C_Container.GetContainerNumFreeSlots
        local free = 10
        _G.C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and free or 0 end
        local ok, err = pcall(function()
            local vm = AR.ViewerFrame:RefreshVisuals()
            T:AssertEqual(vm.notice, nil, "Plenty of room")
            free = 1
            AR.ViewerFrame._tick = 99
            AR.ViewerFrame:OnTick(0)
            T:AssertTrue(AR.ViewerFrame.noticeText:IsShown(), "Band shown when the bags fill up")
            T:AssertEqual(AR.ViewerFrame.noticeText:GetText(), AR.L:Format("UI_BAGS_FULL_FMT", 1))
        end)
        _G.C_Container.GetContainerNumFreeSlots = saved
        AR.ViewerFrame._bagLow = false
        if not ok then error(err, 0) end
    end)

    T:It("shows the what's new card once for these notes", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.whatsNewSeen = nil
        AR.WhatsNew:Reset()
        T:AssertTrue(AR.WhatsNew:ShowIfNew(), "Shown the first time")
        T:AssertTrue(AR.WhatsNew.frame.lines[1]:GetText():find(AR.L:Get("WN_1"), 1, true) ~= nil, "Lists the notes")
        AR.WhatsNew.okButton:Click("LeftButton")
        T:AssertFalse(AR.WhatsNew.frame:IsShown(), "Closed")
        T:AssertFalse(AR.WhatsNew:ShowIfNew(), "Not again")
        AR.WhatsNew:Reset()
    end)
end)

T:Describe("Polestar parity: quest XP", function()
    T:It("sums finished quests' XP on the XP bar, its tooltip and turn-in lines", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.profile.previewsteps = 0
        local savedFn, savedBar = _G.GetQuestLogRewardXP, _G.MainMenuExpBar
        _G.GetQuestLogRewardXP = function(id) return ({ [176] = 1350, [40] = 600 })[id] end
        _G.MainMenuExpBar = CreateFrame("StatusBar", "MainMenuExpBar")
        _G.MainMenuExpBar.GetWidth = function() return 1000 end
        MockWoW.player.xp, MockWoW.player.maxXp = 1000, 10000
        local ok, err = pcall(function()
            MockWoW.quests.inLog[176] = { title = "Wanted: Hogger", isComplete = true, objectives = {} }
            MockWoW.quests.inLog[40] = { title = "A Fishy Peril", isComplete = false, objectives = {} }
            AR.QuestTracking:ScanQuestLog()
            local total, count = AR.QuestXP:Refresh()
            T:AssertEqual(total, 1350, "Only finished quests count")
            T:AssertEqual(count, 1)
            local from, to = AR.QuestXP:Draw()
            T:AssertEqual(from, 0.1); T:AssertEqual(to, 0.235)
            T:AssertTrue(AR.QuestXP.overlay:IsShown(), "Stretch drawn on the XP bar")
            local lines = {}
            local tip = { AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. "=" .. b end, AddLine = function(_, a) lines[#lines + 1] = a end }
            AR.QuestXP:AddTooltipLines(tip)
            T:AssertTrue(lines[1]:find("+1350", 1, true) ~= nil, "Pending XP in the bar tooltip")
            local g = AR.Parser:ParseGuide("XPGuide", 'step Back\n    turnin Wanted: "Hogger"##176\n')
            AR.Progression:LoadGuide(g, 1)
            AR.Progression.pause = true
            local vm = AR.ViewerFrame:RefreshVisuals()
            T:AssertTrue(vm.mainLines[1].richText:find("+1350 XP", 1, true) ~= nil, "Turn-in line shows its XP")
            AR.db.profile.questxp = false
            AR.QuestXP:Draw()
            T:AssertFalse(AR.QuestXP.overlay:IsShown(), "Off in Options hides it")
            AR.db.profile.questxp = true
        end)
        _G.GetQuestLogRewardXP, _G.MainMenuExpBar = savedFn, savedBar
        AR.QuestXP.overlay = nil
        MockWoW.quests.inLog[176], MockWoW.quests.inLog[40] = nil, nil
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Polestar parity: zone art", function()
    T:It("paints the zone's map tiles from the client behind the details title", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local savedLayers, savedTex = _G.C_Map.GetMapArtLayers, _G.C_Map.GetMapArtLayerTextures
        _G.C_Map.GetMapArtLayers = function(id)
            if id == 1436 then return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
        end
        _G.C_Map.GetMapArtLayerTextures = function(id) if id == 1436 then local t = {} for i = 1, 12 do t[i] = 700000 + i end return t end end
        local ok, err = pcall(function()
            local lay = AR.ZoneArt:Layout(1436)
            T:AssertEqual(lay.cols, 4); T:AssertEqual(lay.rows, 3)
            local band = AR.ZoneArt:Create(_G.UIParent, 250, 50, "TestArtBand")
            T:AssertTrue(AR.ZoneArt:Paint(band, 1436, 0.5), "Painted")
            T:AssertEqual(#band.tiles, 12, "One texture per tile")
            T:AssertEqual(band.tiles[1]:GetTexture(), 700001, "Client file ids")
            T:AssertTrue(band.fade:IsShown(), "Fade into the panel")
            T:AssertFalse(AR.ZoneArt:Paint(band, 9999), "Unknown map: nothing painted")
            T:AssertFalse(band.fade:IsShown())
            T:AssertFalse(band.tiles[1]:IsShown(), "Old tiles cleared")

            MockWoW.player.level, MockWoW.player.faction = 20, "Alliance"
            AR.GuideMenu:Reset()
            AR.GuideMenu:Show("dungeons")
            local panel = AR.Dungeons.panel
            panel:SelectCategory("all")
            for _, r in ipairs(panel.lastRows) do if r.data.key == "DM" then panel:SelectRow(r) end end
            T:AssertEqual(panel.art.mapID, 1436, "Deadmines details painted with Westfall")
            AR.GuideMenu:Reset()
        end)
        _G.C_Map.GetMapArtLayers, _G.C_Map.GetMapArtLayerTextures = savedLayers, savedTex
        if not ok then error(err, 0) end
    end)
end)
