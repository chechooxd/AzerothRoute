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
