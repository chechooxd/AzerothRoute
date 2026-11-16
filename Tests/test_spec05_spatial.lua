-- SPEC-05: Spatial Engine, Multi-Hop Pathfinder, TaxiTracker, Pointer, Foglight & POI Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-05: Spatial Coords, Multi-Hop Dijkstra Pathfinder, TaxiTracker, Pointer & Foglight", function()
    T:It("computes distance and bearing in Spatial/Coords.lua", function()
        MockWoW:Reset()
        MockWoW.player.mapID = 1420
        MockWoW.player.x = 0.30
        MockWoW.player.y = 0.70

        local AR = _G.AzerothRoute
        local dist = AR.Coords:GetDistanceTo(1420, 0.33, 0.74)
        T:AssertTrue(dist ~= nil and dist > 0, "Distance on same map must be positive")
        local angle = AR.Coords:GetBearingTo(1420, 0.30, 0.60)
        T:AssertTrue(angle ~= nil, "Bearing angle must be computed")
    end)

    T:It("seeds racial flight paths and learns new nodes on TAXIMAP_OPENED in TaxiTracker", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.TaxiTracker:InitializeForRace("Scourge")

        T:AssertTrue(AR.TaxiTracker:KnowsTaxi("Undercity"), "Undead should start knowing Undercity flight path")
        T:AssertFalse(AR.TaxiTracker:KnowsTaxi("The Sepulcher"), "The Sepulcher should not be known initially")

        AR.TaxiTracker:LearnTaxi("The Sepulcher", 68)
        T:AssertTrue(AR.TaxiTracker:KnowsTaxi("The Sepulcher"), "LearnTaxi must persist known flight node in char.taxis")
        T:AssertEqual(AR.TaxiTracker:GetTripTime("Undercity", "The Sepulcher"), 68, "Recorded flight duration must be returned")
    end)

    T:It("finds cheapest multi-hop path (walk -> taxi -> walk) via binary min-heap Dijkstra coroutine", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Pathfinder:Reset()
        AR.TaxiTracker:LearnTaxi("Undercity", 45)
        AR.TaxiTracker:LearnTaxi("The Sepulcher", 45)

        -- Add two taxi nodes connected by a fast flight edge (45s), vs walking across zone border (600s)
        local nStart = AR.Pathfinder:AddNode({ id = "start", type = "walk", map = 1420, x = 0.60, y = 0.60 })
        local nUC = AR.Pathfinder:AddNode({ id = "taxi_uc", type = "taxi", taxiName = "Undercity", map = 1420, x = 0.62, y = 0.62 })
        local nSep = AR.Pathfinder:AddNode({ id = "taxi_sep", type = "taxi", taxiName = "The Sepulcher", map = 1421, x = 0.44, y = 0.42 })
        local nBorder = AR.Pathfinder:AddNode({ id = "border_walk", type = "border", map = 1421, x = 0.50, y = 0.10 })
        local nGoal = AR.Pathfinder:AddNode({ id = "goal", type = "walk", map = 1421, x = 0.45, y = 0.45 })

        AR.Pathfinder:AddEdge(nStart.id, nUC.id, "walk", 15)
        AR.Pathfinder:AddEdge(nUC.id, nSep.id, "taxi", 45)
        AR.Pathfinder:AddEdge(nSep.id, nGoal.id, "walk", 12)
        AR.Pathfinder:AddEdge(nStart.id, nBorder.id, "walk", 350)
        AR.Pathfinder:AddEdge(nBorder.id, nGoal.id, "walk", 300)

        local route = AR.Pathfinder:FindPath("start", "goal")
        T:AssertTrue(route ~= nil and route.status == "success", "Dijkstra pathfinder must return a valid route")
        T:AssertEqual(#route.nodes, 4, "Optimal path should be start -> taxi_uc -> taxi_sep -> goal (4 nodes)")
        T:AssertEqual(route.nodes[2].id, "taxi_uc", "Second hop must use Undercity flight master")
        T:AssertEqual(route.nodes[3].id, "taxi_sep", "Third hop must land at The Sepulcher")
    end)

    T:It("renders map/minimap pins even when GamePad CVar is enabled, switches to Corpse Arrow on death, and computes Foglight", function()
        MockWoW:Reset()
        MockWoW.cvars.InputDeviceInterfaceStyle = "1" -- GamePad enabled!
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Pointer:Reset()

        AR.Pointer:PlaceStepPins({
            { map = 1420, x = 0.32, y = 0.70, title = "Objective 1", objectiveIndex = 1 },
            { map = 1420, x = 0.36, y = 0.74, title = "Objective 2", objectiveIndex = 2 },
        })

        T:AssertEqual(#AR.Pointer.worldMapPins, 2, "WorldMap pins must NEVER be suppressed when GamePad CVar is enabled")
        T:AssertEqual(#AR.Pointer.minimapPins, 2, "Minimap pins must NEVER be suppressed when GamePad CVar is enabled")
        T:AssertTrue(AR.Pointer.worldMapPins[1].color ~= AR.Pointer.worldMapPins[2].color, "Per-objective pins must receive distinct palette colors")

        -- Death activates Corpse Arrow
        MockWoW.player.isDead = true
        MockWoW.player.corpseMapID = 1420
        MockWoW.player.corpseX = 0.40
        MockWoW.player.corpseY = 0.50
        AR.Pointer:UpdateArrow(0.033)
        T:AssertEqual(AR.Pointer.activeTarget.type, "corpse", "Pointer must preempt guide waypoint with Corpse Arrow while player is dead")

        -- Foglight subtracts explored overlays from full zone table
        AR.Foglight:RegisterZoneOverlays(1420, { "Deathknell", "Brill", "ScarletMonastery" })
        MockWoW.exploredOverlays[1420] = { ["Deathknell"] = true }
        local unexplored = AR.Foglight:GetUnexploredOverlays(1420)
        T:AssertEqual(#unexplored, 2, "Foglight must return the 2 unexplored subzone overlays")
    end)
end)
