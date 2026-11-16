-- SPEC-18: Point 3 — Continent/World-Yard Coordinate Projection & Native C_ChatInfo AddonComm Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-18: World-Yard Continent Projection, Pin Positioning & Native C_ChatInfo AddonComm", function()
    T:It("projects zone normalized coordinates to continent world yards and computes accurate cross-zone distances on the same continent", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute

        -- Tirisfal Glades (1420) and Silverpine Forest (1421) are both on Eastern Kingdoms (continent 0)
        local c1, wx1, wy1 = AR.Coords:ToWorldYards(1420, 0.50, 0.90)
        local c2, wx2, wy2 = AR.Coords:ToWorldYards(1421, 0.50, 0.10)
        T:AssertEqual(c1, 0, "Tirisfal Glades (1420) must belong to Eastern Kingdoms (continent 0)")
        T:AssertEqual(c2, 0, "Silverpine Forest (1421) must belong to Eastern Kingdoms (continent 0)")

        local crossZoneDist = AR.Coords:GetDistanceBetween(1420, 0.50, 0.90, 1421, 0.50, 0.10)
        T:AssertTrue(crossZoneDist ~= nil and crossZoneDist > 0 and crossZoneDist < 2000, "Cross-zone distance between south Tirisfal and north Silverpine must be computed in continuous world yards")

        -- Cross-continent (Tirisfal 1420 on EK vs Durotar 1411 on Kalimdor) returns nil for direct yard distance
        local crossCont = AR.Coords:GetDistanceBetween(1420, 0.50, 0.50, 1411, 0.50, 0.50)
        T:AssertEqual(crossCont, nil, "Direct yard distance across different continents must return nil so Pathfinder takes boat/zeppelin")
    end)

    T:It("positions WorldMap and Minimap pin frames using normalized and radar-clamped offsets", function()
        MockWoW:Reset()
        MockWoW.player.mapID = 1420
        MockWoW.player.x = 0.30
        MockWoW.player.y = 0.70

        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Pointer:Reset()
        AR.Pointer:InitializeFrames()

        AR.Pointer:PlaceStepPins({
            { map = 1420, x = 0.32, y = 0.72, title = "Deathknell Pin", objectiveIndex = 1 },
        })

        local wmPin = AR.Pointer.worldMapPinFrames[1]
        local mmPin = AR.Pointer.minimapPinFrames[1]
        T:AssertTrue(wmPin._point ~= nil, "WorldMap pin frame must have SetPoint called with projected canvas offsets")
        T:AssertTrue(mmPin._point ~= nil, "Minimap pin frame must have SetPoint called with radar yard offsets")
    end)

    T:It("registers ARSync1 prefix via C_ChatInfo, broadcasts GS packets, and updates PartySync peers on CHAT_MSG_ADDON", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Events:Reset()
        AR.PartySync:Reset()

        local registeredPrefix = nil
        local sentPayload = nil
        _G.C_ChatInfo = {
            RegisterAddonMessagePrefix = function(prefix)
                registeredPrefix = prefix
                return true
            end,
            SendAddonMessage = function(prefix, text, channel)
                sentPayload = { prefix = prefix, text = text, channel = channel }
                return true
            end,
        }

        AR.PartySync:RegisterLiveEvents()
        T:AssertEqual(registeredPrefix, "ARSync1", "PartySync must register ARSync1 prefix with C_ChatInfo")

        AR.PartySync:BroadcastStepStatus("Leveling\\Horde\\Tirisfal Glades (1-12)", 3, false)
        T:AssertTrue(sentPayload ~= nil, "BroadcastStepStatus must call C_ChatInfo.SendAddonMessage")
        T:AssertEqual(sentPayload.prefix, "ARSync1", "Addon message prefix must be ARSync1")

        AR.PartySync.magneticHold = true
        MockWoW:FireEvent("CHAT_MSG_ADDON", "ARSync1", "GS:Leveling\\Horde\\Tirisfal Glades (1-12):3:0", "PARTY", "Thrall")
        T:AssertFalse(AR.PartySync:CanPartyAdvanceStep(3), "CHAT_MSG_ADDON must update Thrall peer status and engage Magnetic Step Hold")

        MockWoW:FireEvent("CHAT_MSG_ADDON", "ARSync1", "GS:Leveling\\Horde\\Tirisfal Glades (1-12):3:1", "PARTY", "Thrall")
        T:AssertTrue(AR.PartySync:CanPartyAdvanceStep(3), "CHAT_MSG_ADDON completion packet must release Magnetic Step Hold")

        _G.C_ChatInfo = nil
    end)
end)
