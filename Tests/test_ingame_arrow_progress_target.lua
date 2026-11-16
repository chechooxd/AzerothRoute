-- In-game report 2026-11-16: inverted arrow, undetected flight path / hearth progress, blocked target button.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function normAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

local function withStep(guideText, fn)
    local AR = _G.AzerothRoute
    local guide = AR.Parser:ParseGuide("Test_Crossroads", guideText)
    AR.Progression:LoadGuide(guide)
    fn(AR, AR.Progression.currentStep)
end

local CROSSROADS_GUIDE = [[
step HubSetup
    goto 1413 51.5,30.4
    talk Devrak##3615
    fpath Crossroads
    home Crossroads
]]

local function goalByAction(step, action)
    for _, g in ipairs(step.goals) do
        if g.action == action then return g end
    end
end

T:Describe("In-game fixes: arrow, flight path/hearth detection, target button", function()
    T:It("rotates the arrow counter-clockwise toward the target and colors it by alignment", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local origBearing = AR.Coords.GetBearingTo
        local origDist = AR.Coords.GetDistanceTo
        local origFacing = MockWoW.player.facing
        local ok, err = pcall(function()
            AR.Pointer:Reset()
            AR.Pointer:InitializeFrames()
            AR.Pointer.activeTarget = { map = 1413, x = 0.6, y = 0.5, title = "East" }
            AR.Coords.GetDistanceTo = function() return 100 end
            -- Coords:GetBearingTo is clockwise from north: east = +pi/2.
            AR.Coords.GetBearingTo = function() return math.pi / 2 end

            -- GetPlayerFacing is counter-clockwise from north: facing east = 3pi/2.
            MockWoW.player.facing = 3 * math.pi / 2
            AR.Pointer:UpdateArrow(0.033)
            local rot = AR.Pointer.arrowFrame.icon:GetRotation()
            T:AssertTrue(math.abs(normAngle(rot)) < 1e-6, "Walking toward the target points the arrow straight up, got " .. rot)
            local r, g = AR.Pointer:ComputeBearingColor(rot)
            T:AssertTrue(g > 0.9 and r < 0.3, "Aligned arrow must be green")

            -- Facing west, the target is behind.
            MockWoW.player.facing = math.pi / 2
            AR.Pointer:UpdateArrow(0.033)
            rot = AR.Pointer.arrowFrame.icon:GetRotation()
            T:AssertTrue(math.abs(math.abs(normAngle(rot)) - math.pi) < 1e-6, "Walking away points the arrow down, got " .. rot)
            r, g = AR.Pointer:ComputeBearingColor(rot)
            T:AssertTrue(r > 0.9 and g < 0.3, "Opposite arrow must be red")

            -- Facing north with the target east: arrow turns right (clockwise = negative rotation).
            MockWoW.player.facing = 0
            AR.Pointer:UpdateArrow(0.033)
            rot = normAngle(AR.Pointer.arrowFrame.icon:GetRotation())
            T:AssertTrue(math.abs(rot + math.pi / 2) < 1e-6, "Target on the right turns the arrow right, got " .. rot)
        end)
        AR.Coords.GetBearingTo, AR.Coords.GetDistanceTo = origBearing, origDist
        MockWoW.player.facing = origFacing
        AR.Pointer:Reset()
        if not ok then error(err, 0) end
    end)

    T:It("completes fpath on the new-flight-path message and home from the current hearth location", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.char.taxis = {}
        local origBind = _G.GetBindLocation
        local origDist = AR.Coords.GetDistanceTo
        local ok, err = pcall(function()
            withStep(CROSSROADS_GUIDE, function(_, step)
                local fpath, home = goalByAction(step, "fpath"), goalByAction(step, "home")
                _G.GetBindLocation = function() return "Orgrimmar" end
                T:AssertEqual(fpath:GetStatus(), "incomplete", "Unknown flight path starts incomplete")
                T:AssertEqual(home:GetStatus(), "incomplete", "Hearth bound elsewhere is incomplete")

                AR.TaxiTracker:OnUIInfoMessage(372, "Some other message")
                T:AssertEqual(fpath:GetStatus(), "incomplete", "Unrelated UI messages are ignored")
                AR.Coords.GetDistanceTo = function() return 900 end
                AR.TaxiTracker:OnUIInfoMessage(372, _G.ERR_NEWTAXIPATH)
                T:AssertEqual(fpath:GetStatus(), "incomplete", "A flight path discovered far from the step does not count")
                T:AssertTrue(not AR.TaxiTracker:KnowsTaxi("Crossroads"), "Nothing is learned far away")
                AR.Coords.GetDistanceTo = function() return 20 end
                AR.TaxiTracker:OnUIInfoMessage(372, _G.ERR_NEWTAXIPATH)
                T:AssertEqual(fpath:GetStatus(), "complete", "Discovering a flight path completes the step's fpath goal")
                T:AssertTrue(AR.TaxiTracker:KnowsTaxi("Crossroads"), "The discovered node is remembered")

                _G.GetBindLocation = function() return "El Cruce" end
                T:AssertEqual(home:GetStatus(), "complete", "Localized hearth location completes home")
                _G.GetBindLocation = function() return "The Crossroads" end
                T:AssertEqual(home:GetStatus(), "complete", "English hearth location completes home")
            end)
        end)
        _G.GetBindLocation = origBind
        AR.Coords.GetDistanceTo = origDist
        if not ok then error(err, 0) end
    end)

    T:It("opens the flight map from the flight master's gossip while an fpath goal is pending", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.char.taxis = {}
        local origGossip = _G.C_GossipInfo
        local selected = {}
        local ok, err = pcall(function()
            _G.C_GossipInfo = {
                GetActiveQuests = function() return {} end,
                GetAvailableQuests = function() return {} end,
                GetOptions = function()
                    return {
                        { gossipOptionID = 11, name = "Chat", icon = 132053 },
                        { gossipOptionID = 22, name = "Necesito volar", icon = 132057 },
                    }
                end,
                SelectOption = function(id) table.insert(selected, id) end,
            }
            withStep(CROSSROADS_GUIDE, function()
                AR.QuestAutoAccept:OnGossipShow()
                T:AssertEqual(selected[1], 22, "Selects the taxi gossip option")
            end)
            AR.TaxiTracker:LearnTaxi("Crossroads")
            selected = {}
            AR.QuestAutoAccept:OnGossipShow()
            T:AssertEqual(#selected, 0, "Known flight path: gossip is left alone")
        end)
        _G.C_GossipInfo = origGossip
        if not ok then error(err, 0) end
    end)

    T:It("shows passive goals neutral and visited gotos complete instead of red", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        withStep(CROSSROADS_GUIDE, function(_, step)
            local gotoGoal, talk = goalByAction(step, "goto"), goalByAction(step, "talk")
            local passive = AR.Skins:GetProp("goalPassive")
            local red = AR.Skins:GetProp("goalIncomplete")
            T:AssertTrue(passive ~= nil, "Skin defines a passive color")
            local talkLine = AR.ViewerFrame:FormatGoalLine(talk, 2, false)
            T:AssertTrue(talkLine.bgColor.r == passive.r and talkLine.bgColor.g == passive.g, "Passive talk is neutral")
            T:AssertTrue(talkLine.bgColor.r ~= red.r, "Passive talk is not red")

            gotoGoal.visited = true
            local gotoLine = AR.ViewerFrame:FormatGoalLine(gotoGoal, 1, false)
            T:AssertEqual(gotoLine.checkIcon, true, "Visited goto shows a check")
            local done = AR.Skins:GetProp("goalComplete")
            T:AssertTrue(gotoLine.bgColor.g == done.g, "Visited goto is green")
        end)
    end)

    T:It("never calls SetRaidTarget on any Forever build and uses non-toggling enemy markers", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local origToc = MockWoW.tocVersion
        local ok, err = pcall(function()
            for _, toc in ipairs({ 16000, 16001, 16002, 19999, 120000 }) do
                MockWoW.tocVersion = toc
                T:AssertEqual(AR.ActionBar:CanUseAutoRaidMark(), false, "Auto-mark disabled on toc " .. toc)
            end
            local origProject = _G.WOW_PROJECT_ID
            _G.WOW_PROJECT_ID = 2 -- Classic Era
            MockWoW.tocVersion = 11508
            T:AssertEqual(AR.ActionBar:CanUseAutoRaidMark(), true, "Classic Era keeps auto-mark")

            _G.WOW_PROJECT_ID = origProject
            MockWoW.tocVersion = 16002
            local macro = AR.ActionBar:BuildMacroForGoal({ action = "kill", target = "Zhevra" })
            T:AssertTrue(macro:find("/tm !8", 1, true) ~= nil, "Forever enemy marker must not toggle: " .. macro)
            local friendly = AR.ActionBar:BuildMacroForGoal({ action = "talk", target = "Devrak" })
            T:AssertTrue(friendly:find("/tm 1", 1, true) ~= nil, "Friendly marker unchanged: " .. friendly)

            _G.WOW_PROJECT_ID = 2
            MockWoW.tocVersion = 11508
            macro = AR.ActionBar:BuildMacroForGoal({ action = "kill", target = "Zhevra" })
            T:AssertTrue(macro:find("/tm 8", 1, true) ~= nil and not macro:find("!", 1, true), "Classic Era keeps /tm 8")
        end)
        _G.WOW_PROJECT_ID = _G.WOW_PROJECT_CAMELOT
        MockWoW.tocVersion = origToc
        if not ok then error(err, 0) end
    end)

    T:It("reports which protected function was blocked, once per function", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local printed = {}
        local origPrint = AR.Print
        AR.Print = function(_, msg) table.insert(printed, msg) end
        local ok, err = pcall(function()
            AR.blockedReported = {}
            AR:OnActionBlocked("ADDON_ACTION_BLOCKED", "AzerothRoute", "SetRaidTarget()")
            AR:OnActionBlocked("ADDON_ACTION_BLOCKED", "AzerothRoute", "SetRaidTarget()")
            AR:OnActionBlocked("ADDON_ACTION_BLOCKED", "OtherAddon", "CastSpellByName()")
            T:AssertEqual(#printed, 1, "Reported once, only for this addon")
            T:AssertTrue(printed[1]:find("SetRaidTarget()", 1, true) ~= nil, "Names the blocked function")
        end)
        AR.Print = origPrint
        if not ok then error(err, 0) end
    end)
end)
