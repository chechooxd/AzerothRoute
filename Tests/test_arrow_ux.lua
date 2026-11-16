-- Package 2 (Zygor-style arrow): arrival state, ETA, distance color, other-map text, no "Go to"
-- completion while flying a taxi, and automatic move to the next waypoint.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function withArrow(dist, fn)
    local AR = _G.AzerothRoute
    local saved = {
        dist = AR.Coords.GetDistanceTo, bearing = AR.Coords.GetBearingTo,
        flying = _G.IsFlying, speed = _G.GetUnitSpeed, taxi = _G.UnitOnTaxi,
    }
    local current = { dist = dist }
    AR.Coords.GetDistanceTo = function() return current.dist end
    AR.Coords.GetBearingTo = function() return 0 end
    _G.IsFlying = function() return false end
    _G.GetUnitSpeed = function() return 0 end
    _G.UnitOnTaxi = function() return false end
    AR.Pointer:Reset()
    AR.Pointer:InitializeFrames()
    AR.Pointer.activeTarget = { map = 1413, x = 0.5, y = 0.5, title = "Devrak" }
    local ok, err = pcall(fn, AR, current)
    AR.Coords.GetDistanceTo, AR.Coords.GetBearingTo = saved.dist, saved.bearing
    _G.IsFlying, _G.GetUnitSpeed, _G.UnitOnTaxi = saved.flying, saved.speed, saved.taxi
    AR.Pointer:Reset()
    if not ok then error(err, 0) end
end

T:Describe("Package 2: arrow", function()
    T:It("switches to an arrived icon within 8 yd on foot and 15 yd while flying", function()
        MockWoW:Reset()
        withArrow(5, function(AR, current)
            local P = AR.Pointer
            P:UpdateArrow(0.033)
            T:AssertEqual(P.arrowFrame.icon:GetTexture(), P.ARRIVED_TEXTURE, "Arrived icon at 5 yd")
            T:AssertEqual(P.arrowFrame.icon:GetRotation(), 0, "Arrived icon is not rotated")
            T:AssertTrue(P.arrowFrame.sublabel:GetText():find(AR.L:Get("UI_ARRIVED"), 1, true) ~= nil, "Says arrived")

            current.dist = 12
            P:UpdateArrow(0.033)
            T:AssertEqual(P.arrowFrame.icon:GetTexture(), P.ARROW_TEXTURE, "Back to the arrow at 12 yd on foot")

            _G.IsFlying = function() return true end
            P:UpdateArrow(0.033)
            T:AssertEqual(P.arrowFrame.icon:GetTexture(), P.ARRIVED_TEXTURE, "12 yd counts as arrived while flying")
        end)
    end)

    T:It("shows distance and an ETA from the player's average speed", function()
        MockWoW:Reset()
        withArrow(70, function(AR)
            local P = AR.Pointer
            P:UpdateArrow(0.033)
            T:AssertEqual(P.arrowFrame.sublabel:GetText(), "70 yd", "No ETA while standing still")
            _G.GetUnitSpeed = function() return 7 end
            for _ = 1, 10 do P:SampleSpeed(0.2) end
            P:UpdateArrow(0.033)
            T:AssertEqual(P.arrowFrame.sublabel:GetText(), "70 yd · 0:10", "Distance plus m:ss ETA")
            T:AssertEqual(P.arrowFrame.label:GetText(), "Devrak", "Title on its own line")
        end)
    end)

    T:It("colors the distance from red to green as the player closes in", function()
        MockWoW:Reset()
        withArrow(400, function(AR, current)
            local P = AR.Pointer
            P:UpdateArrow(0.033)
            local far = P.arrowFrame.sublabel._color
            current.dist = 40
            P:UpdateArrow(0.033)
            local near = P.arrowFrame.sublabel._color
            T:AssertTrue(far.r > far.g, "Far is red-ish")
            T:AssertTrue(near.g > near.r, "Near is green-ish")
        end)
    end)

    T:It("names the target map when the distance cannot be measured", function()
        MockWoW:Reset()
        withArrow(nil, function(AR)
            local P = AR.Pointer
            local origInfo = _G.C_Map.GetMapInfo
            _G.C_Map.GetMapInfo = function() return { name = "Los Baldíos" } end
            P:UpdateArrow(0.033)
            _G.C_Map.GetMapInfo = origInfo
            T:AssertEqual(P.arrowFrame.sublabel:GetText(), "Los Baldíos", "Map name instead of yards")
        end)
    end)

    T:It("never completes a Go-to goal while on a flight path", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        withArrow(1, function()
            local g = AR.Parser:ParseGuide("Arrow_Taxi", "step A\n    goto 1413 51.5,30.4\n    goto 1413 60.0,30.0")
            AR.Progression:LoadGuide(g, 1)
            _G.UnitOnTaxi = function() return true end
            AR.Progression.currentStep:CheckVisitedGotos()
            T:AssertTrue(not g:GetStep(1).goals[1].visited, "Flying over the point does not count")
            _G.UnitOnTaxi = function() return false end
            AR.Progression.currentStep:CheckVisitedGotos()
            T:AssertEqual(g:GetStep(1).goals[1].visited, true, "Counts once on the ground")
        end)
    end)

    T:It("moves the arrow to the next waypoint as soon as one is reached", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        withArrow(200, function(_, current)
            local g = AR.Parser:ParseGuide("Arrow_Next",
                "step A\n    goto 1413 51.5,30.4\n    goto 1413 60.0,30.0\n    goto 1413 70.0,30.0")
            AR.Progression:LoadGuide(g, 1)
            AR.ViewerFrame:RefreshVisuals()
            T:AssertEqual(AR.Pointer.activeTarget.x, 0.515, "Starts at the first waypoint")
            current.dist = 2
            AR.Progression:TryToCompleteStep(false)
            current.dist = 200
            T:AssertEqual(AR.Progression:ConsumeWaypointVisited(), true, "Reports the visit once")
            T:AssertEqual(AR.Progression:ConsumeWaypointVisited(), false)
            AR.ViewerFrame:RefreshVisuals()
            T:AssertEqual(AR.Pointer.activeTarget.x, 0.6, "Arrow moved to the second waypoint")
        end)
    end)
end)
