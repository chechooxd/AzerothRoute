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
