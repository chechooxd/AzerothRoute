-- Nearby services and multi-leg journeys.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

-- A tiny fake world: maps 9001/9002 share continent 1 (9002 lies 5000 yd east), 9101 is on continent 2.
local ORIGIN = { [9001] = { 1, 0, 0 }, [9002] = { 1, 5000, 0 }, [9101] = { 2, 0, 0 } }
local function withWorld(player, fn)
    local AR = _G.AzerothRoute
    local C, TD, TT = AR.Coords, AR.TravelData, AR.TaxiTracker
    local saved = { C.ToWorldYards, C.GetPlayerPosition, C.GetDistanceTo, C.GetBearingTo, TD.TAXI_NODES, TD.TRANSPORTS, TT.KnowsTaxi }
    C.ToWorldYards = function(_, map, x, y)
        local o = ORIGIN[map]
        if not o then return nil end
        return o[1], o[2] + x * 1000, o[3] + y * 1000
    end
    C.GetPlayerPosition = function() return player.map, player.x, player.y end
    C.GetDistanceTo = function(self, map, x, y)
        local c1, x1, y1 = self:ToWorldYards(player.map, player.x, player.y)
        local c2, x2, y2 = self:ToWorldYards(map, x, y)
        if not c1 or c1 ~= c2 then return nil end
        return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    end
    C.GetBearingTo = function() return 0 end
    TD.TAXI_NODES = {
        { name = "West Field", side = "B", map = 9001, x = 50, y = 50 },
        { name = "East Field", side = "B", map = 9002, x = 50, y = 50 },
    }
    TD.TRANSPORTS = {
        { mode = "boat", side = "B", seconds = 150,
            a = { name = "East Docks", map = 9002, x = 90, y = 50 }, b = { name = "Far Shore", map = 9101, x = 10, y = 50 } },
    }
    TT.KnowsTaxi = function() return true end
    AR.Journey:Reset()
    local ok, err = pcall(fn, AR)
    C.ToWorldYards, C.GetPlayerPosition, C.GetDistanceTo, C.GetBearingTo = saved[1], saved[2], saved[3], saved[4]
    TD.TAXI_NODES, TD.TRANSPORTS, TT.KnowsTaxi = saved[5], saved[6], saved[7]
    AR.Journey:Reset()
    AR.Pointer:Reset()
    if not ok then error(err, 0) end
end

T:Describe("Journey", function()
    T:It("walks to a known flight path, flies, then walks to the target", function()
        MockWoW:Reset()
        withWorld({ map = 9001, x = 0.45, y = 0.5 }, function(AR)
            AR.Storage:Initialize()
            local plan = AR.Journey:Plan({ map = 9002, x = 0.6, y = 0.5, title = "Quest giver" })
            local modes = {}
            for _, l in ipairs(plan.legs) do modes[#modes + 1] = l.mode end
            T:AssertEqual(table.concat(modes, ","), "walk,fly,walk", "Three legs")
            T:AssertEqual(plan.legs[1].name, "West Field")
            T:AssertEqual(plan.legs[2].label, AR.L:Format("UI_LEG_FLY", "East Field"))
            T:AssertTrue(plan.legs[3].final, "Last leg reaches the target")
            T:AssertTrue(math.abs(plan.legs[1].seconds - 50 / 7) < 0.01, "50 yd on foot at run speed")
            T:AssertTrue(math.abs(plan.legs[2].seconds - (5000 / 24 + 15)) < 0.01, "Flight estimate")
        end)
    end)

    T:It("takes the boat to another continent and walks straight when flying saves nothing", function()
        MockWoW:Reset()
        withWorld({ map = 9002, x = 0.6, y = 0.5 }, function(AR)
            AR.Storage:Initialize()
            local plan = AR.Journey:Plan({ map = 9101, x = 0.2, y = 0.5, title = "Over the sea" })
            local modes = {}
            for _, l in ipairs(plan.legs) do modes[#modes + 1] = l.mode end
            T:AssertEqual(table.concat(modes, ","), "walk,boat,walk", "Boat across")
            T:AssertEqual(plan.legs[1].name, "East Docks")
            local near = AR.Journey:Plan({ map = 9002, x = 0.7, y = 0.5, title = "Close" })
            T:AssertEqual(#near.legs, 1, "Short trip is one walk")
            T:AssertEqual(AR.Journey:Plan({ map = 9999, x = 0.5, y = 0.5 }), nil, "Unknown map: no plan")
        end)
    end)

    T:It("steers the arrow to the first leg and lists the legs in the guide window", function()
        MockWoW:Reset()
        withWorld({ map = 9001, x = 0.45, y = 0.5 }, function(AR)
            AR.Storage:Initialize()
            AR.db.profile.previewsteps = 0
            local g = AR.Parser:ParseGuide("JourneyGuide", "step One\n    talk Devrak##3615\n")
            AR.Progression:LoadGuide(g, 1)
            AR.Progression.pause = true
            AR.Pointer:Reset()
            AR.Pointer:SetManualTarget(9002, 0.6, 0.5, "Quest giver")
            T:AssertEqual(AR.Pointer.arrowFrame.label:GetText(), AR.L:Format("UI_LEG_WALK", "West Field"), "Arrow names the first leg")
            T:AssertTrue(AR.Pointer.arrowFrame.etaLabel:GetText():find(AR.Journey:FormatDuration(AR.Pointer.steering.plan.seconds), 1, true) ~= nil, "Total time under the arrow")
            local vm = AR.ViewerFrame:RefreshVisuals()
            T:AssertEqual(#vm.journey.legs, 3)
            local texts = {}
            for _, row in ipairs(AR.ViewerFrame.lineRows) do
                if row:IsShown() then texts[#texts + 1] = row.label:GetText() end
            end
            local all = table.concat(texts, "\n")
            T:AssertTrue(all:find(AR.L:Get("UI_JOURNEY"), 1, true) ~= nil, "Journey header")
            T:AssertTrue(all:find("2. " .. AR.L:Format("UI_LEG_FLY", "East Field"), 1, true) ~= nil, "Numbered legs")
            AR.db.profile.journey = false
            AR.Pointer:UpdateArrow(0)
            T:AssertEqual(AR.Pointer.arrowFrame.label:GetText(), "Quest giver", "Journey off: straight to the target")
            AR.db.profile.journey = true
        end)
    end)
end)

T:Describe("Nearby services", function()
    T:It("finds the nearest service of each kind for the player's faction", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Nearby:Reset()
        MockWoW.player.faction = "Alliance"
        local C = AR.Coords
        local savedPos, savedDist = C.GetPlayerPosition, C.GetDistanceTo
        local savedSteer = AR.Journey.GetSteering
        -- Stand on Thor, Sentinel Hill's flight master (Westfall 56.6, 52.6).
        C.GetPlayerPosition = function() return 1436, 0.566, 0.526 end
        C.GetDistanceTo = function(_, map, x, y)
            if map ~= 1436 then return nil end
            return math.sqrt(((x - 0.566) * 1000) ^ 2 + ((y - 0.526) * 1000) ^ 2)
        end
        local ok, err = pcall(function()
            local fm, d = AR.Nearby:FindNearest("f")
            T:AssertEqual(fm.name, "Thor", "Nearest flight master")
            T:AssertTrue(d < 1, "Standing on it")
            local list = AR.Nearby:List()
            T:AssertEqual(#list, 8, "Eight service kinds")
            AR.ViewerFrame:RefreshVisuals()
            AR.ViewerFrame.mapButton:Click("LeftButton")
            local item = AR.UI:FindMenuItem(string.format("%s · %d yd", AR.L:Get("UI_SV_F"), 0))
            T:AssertTrue(item ~= nil, "Map menu lists the flight master with its distance")
            AR.Journey.GetSteering = function() return nil end -- direct to the service
            item:Click("LeftButton")
            T:AssertEqual(AR.Pointer.activeTarget.title, "Thor", "Arrow to the service (reached at once: we stand on it)")
        end)
        C.GetPlayerPosition, C.GetDistanceTo = savedPos, savedDist
        AR.Journey.GetSteering = savedSteer
        AR.Pointer:Reset()
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Journey: hearthstone", function()
    local function withHearth(cooldownLeft, fn)
        local AR = _G.AzerothRoute
        local saved = { _G.GetBindLocation, AR.Compat.GetItemCount, _G.GetItemCooldown, _G.C_Container }
        _G.GetBindLocation = function() return "Far Inn" end
        AR.Compat.GetItemCount = function(_, id) return id == 6948 and 1 or 0 end
        _G.C_Container = nil
        _G.GetItemCooldown = function()
            if cooldownLeft == 0 then return 0, 0 end
            return _G.GetTime() - (3600 - cooldownLeft), 3600
        end
        local ok, err = pcall(fn, AR)
        _G.GetBindLocation, AR.Compat.GetItemCount, _G.GetItemCooldown, _G.C_Container = saved[1], saved[2], saved[3], saved[4]
        if not ok then error(err, 0) end
    end

    T:It("records where the stone is set and hearths there when it is the fastest way", function()
        MockWoW:Reset()
        local player = { map = 9101, x = 0.5, y = 0.5 }
        withWorld(player, function(AR)
            AR.Storage:Initialize()
            withHearth(0, function()
                -- Bind at the inn on the far continent, then travel back home.
                local rec = AR.TaxiTracker:RecordHearth()
                T:AssertEqual(rec.name, "Far Inn")
                T:AssertEqual(rec.map, 9101)
                player.map, player.x, player.y = 9001, 0.1, 0.5
                local plan = AR.Journey:Plan({ map = 9101, x = 0.55, y = 0.5, title = "Next to the inn" })
                local modes = {}
                for _, l in ipairs(plan.legs) do modes[#modes + 1] = l.mode end
                T:AssertEqual(table.concat(modes, ","), "hearth,walk", "Hearth then a short walk")
                T:AssertEqual(plan.legs[1].label, AR.L:Format("UI_LEG_HEARTH", "Far Inn"))
                T:AssertTrue(math.abs(plan.legs[1].seconds - 10) < 0.01, "10 s cast when ready")
            end)
        end)
    end)

    T:It("counts the cooldown and forgets a bind position once the stone is set elsewhere", function()
        MockWoW:Reset()
        local player = { map = 9101, x = 0.5, y = 0.5 }
        withWorld(player, function(AR)
            AR.Storage:Initialize()
            withHearth(300, function()
                AR.TaxiTracker:RecordHearth()
                player.map, player.x, player.y = 9001, 0.1, 0.5
                local plan = AR.Journey:Plan({ map = 9101, x = 0.55, y = 0.5, title = "Next to the inn" })
                T:AssertEqual(plan.legs[1].mode, "hearth", "Still the fastest despite the wait")
                T:AssertTrue(math.abs(plan.legs[1].seconds - 310) < 0.5, "5 minutes left plus the cast")
                _G.GetBindLocation = function() return "Somewhere Else" end
                T:AssertEqual(AR.TaxiTracker:GetHearthLocation(), nil, "Old position no longer applies")
                local noHearth = AR.Journey:Plan({ map = 9101, x = 0.55, y = 0.5, title = "Next to the inn" })
                for _, l in ipairs(noHearth.legs) do T:AssertTrue(l.mode ~= "hearth", "No hearth leg") end
            end)
        end)
    end)
end)

T:Describe("Journey: hearthstone on cooldown", function()
    T:It("prefers flying and the boat when the stone is far from ready", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local player = { map = 9101, x = 0.5, y = 0.5 }
        withWorld(player, function()
            AR.Storage:Initialize()
            local saved = { _G.GetBindLocation, AR.Compat.GetItemCount, _G.GetItemCooldown, _G.C_Container }
            _G.GetBindLocation = function() return "Far Inn" end
            AR.Compat.GetItemCount = function() return 1 end
            _G.C_Container = nil
            _G.GetItemCooldown = function() return _G.GetTime() - 600, 3600 end -- 50 minutes left
            local ok, err = pcall(function()
                AR.TaxiTracker:RecordHearth()
                player.map, player.x, player.y = 9001, 0.1, 0.5
                local plan = AR.Journey:Plan({ map = 9101, x = 0.55, y = 0.5, title = "Next to the inn" })
                T:AssertTrue(plan.legs[1].mode ~= "hearth", "Long cooldown loses to travelling")
            end)
            _G.GetBindLocation, AR.Compat.GetItemCount, _G.GetItemCooldown, _G.C_Container = saved[1], saved[2], saved[3], saved[4]
            if not ok then error(err, 0) end
        end)
    end)
end)
