-- Package 3 (Zygor-style viewer): per-action icons, check icon when done, past-tense text,
-- next-step preview and a window that grows with its lines.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local GUIDE = [[
step First
    accept Plainstrider Menace##844
    kill 7 Plainstrider##3244
    talk Devrak##3615
    ding 1
step Second
    turnin Plainstrider Menace##844
    fpath Crossroads
step Third
    home Crossroads
step Fourth
    goto 1413 50.0,50.0
]]

local function load(AR)
    AR.Storage:Initialize()
    AR.db.profile.previewsteps = 0
    local g = AR.Parser:ParseGuide("Viewer_UX", GUIDE)
    AR.Progression:LoadGuide(g, 1)
    AR.Progression.pause = true -- keep step 1 on screen even though "ding 1" is done
    return g
end

local function rowFor(AR, goal)
    for _, row in ipairs(AR.ViewerFrame.lineRows) do
        if row._goal == goal and row:IsShown() then return row end
    end
end

T:Describe("Package 3: viewer", function()
    T:It("shows an icon per action and a check once the goal is done", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        AR.ViewerFrame:RefreshVisuals()
        local step = g:GetStep(1)
        for _, goal in ipairs(step.goals) do
            local row = rowFor(AR, goal)
            T:AssertTrue(row ~= nil and row.icon ~= nil, goal.action .. " row has an icon")
            local expected = goal.action == "ding" and AR.Skins.CHECK_ICON or AR.Skins:GetActionIcon(goal.action)
            T:AssertEqual(row.icon:GetTexture(), expected, goal.action .. " icon")
        end
        T:AssertTrue(AR.Skins:GetActionIcon("accept") ~= AR.Skins:GetActionIcon("kill"), "Actions are distinguishable")
    end)

    T:It("switches goal text to past tense when complete", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        local origLocale = _G.GetLocale
        local ok, err = pcall(function()
            local accept = g:GetStep(1).goals[1]
            _G.GetLocale = function() return "enUS" end
            T:AssertEqual(accept:GetText(), "Accept Plainstrider Menace", "Present while pending")
            T:AssertEqual(accept:GetText(true), "Accepted Plainstrider Menace", "Past once done")
            _G.GetLocale = function() return "esMX" end
            T:AssertTrue(accept:GetText(true):find("^Aceptada ") ~= nil, "Spanish past tense: " .. accept:GetText(true))
            local confirm = AR.Parser:ParseGuide("Viewer_Confirm", "step A\n    confirm"):GetStep(1).goals[1]
            T:AssertEqual(confirm:GetText(true), confirm:GetText(), "Goals without a past form keep their text")

            _G.GetLocale = function() return "enUS" end
            AR.ViewerFrame:RefreshVisuals()
            local ding = rowFor(AR, g:GetStep(1).goals[4])
            T:AssertEqual(ding.label:GetText(), "Reached level 1", "Viewer shows the past form for done goals")
        end)
        _G.GetLocale = origLocale
        if not ok then error(err, 0) end
    end)

    T:It("previews the next steps dimmed when enabled, without map pins", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local g = load(AR)
        local vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(#vm.previewLines, 0, "No preview by default")

        AR.db.profile.previewsteps = 2
        vm = AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(vm.previewLines[1].isHeader, true, "Each previewed step starts with a header")
        T:AssertTrue(vm.previewLines[1].text:find("2", 1, true) ~= nil, "Header names the step number")
        local goals = {}
        for _, line in ipairs(vm.previewLines) do
            if line.goal then goals[line.goal] = true end
        end
        T:AssertTrue(goals[g:GetStep(2).goals[1]] and goals[g:GetStep(3).goals[1]], "Steps 2 and 3 previewed")
        T:AssertTrue(not goals[g:GetStep(4).goals[1]], "Only two steps")
        for _, pin in ipairs(AR.Pointer.worldMapPins) do
            T:AssertTrue(pin.x ~= 0.5, "Preview goals do not add map pins")
        end
        AR.db.profile.previewsteps = 0
    end)

    T:It("grows the window to fit its lines", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        load(AR)
        AR.ViewerFrame:RefreshVisuals()
        local base = AR.ViewerFrame.frame._height
        AR.db.profile.previewsteps = 4
        AR.ViewerFrame:RefreshVisuals()
        local grown = AR.ViewerFrame.frame._height
        T:AssertTrue(base >= AR.ViewerFrame.HEIGHT, "Never smaller than the default height")
        T:AssertTrue(grown > base, "Taller with the preview lines")
        AR.db.profile.previewsteps = 0
    end)

    T:It("offers the preview count in the options panel", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        local opts = AR.Config:BuildOptions()
        local node = opts.args.interface.args.previewsteps
        T:AssertEqual(node.type, "range", "Slider")
        T:AssertEqual(node.min, 0)
        T:AssertEqual(node.max, 4)
        node.set({ "interface", "previewsteps" }, 3)
        T:AssertEqual(AR.db.profile.previewsteps, 3)
        AR.db.profile.previewsteps = 0
    end)
end)
