local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("Resume: interaction identity", function()
    T:It("requires the named merchant but still sells greys at other merchants", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Events:Reset()
        AR.Inventory._liveRegistered = false
        AR.Inventory:RegisterLiveEvents()
        AR.db.global.autogrey = true
        AR.db.global.autobuy = false
        AR.db.global.autorepair = false
        local guide = AR.Parser:ParseGuide("Test\\MerchantIdentity", [[
            step
                vendor Blacksmith Rand##2116
                confirm
        ]])
        AR.Progression:LoadGuide(guide, 1)
        MockWoW.merchant.isOpen = true
        MockWoW.player.bagSlots[0] = { { itemID = 7771, quality = 0, sellPrice = 1, count = 1 } }
        MockWoW.npc = { name = "Other vendor", guid = "Creature-0-0-0-0-9999-0000000000" }
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertFalse(guide.steps[1].goals[1].visited, "Unrelated merchant cannot complete a named vendor goal")
        T:AssertEqual(MockWoW.player.bagSlots[0][1], nil, "Ordinary junk selling still works at other vendors")
        MockWoW.npc = { name = "Localized vendor", guid = "Creature-0-0-0-0-2116-0000000000" }
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertTrue(guide.steps[1].goals[1].visited, "NPC ID is authoritative across client languages")
    end)

    T:It("learns only observed taxi nodes and does not select a similarly named destination", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Events:Reset()
        AR.db.char.taxis = {}
        AR.db.global.autotaxi = true
        AR.TaxiTracker._liveRegistered = false
        AR.TaxiTracker:RegisterLiveEvents()
        local guide = AR.Parser:ParseGuide("Test\\FlightIdentity", [[
            step
                fpath Brill
                fly Brill
                confirm
        ]])
        AR.Progression:LoadGuide(guide, 1)
        local oldCount, oldName, oldType, oldTake = _G.NumTaxiNodes, _G.TaxiNodeName, _G.TaxiNodeGetType, _G.TakeTaxiNode
        local name, nodeType, taken = "Brill Annex", "REACHABLE", nil
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeName = function() return name end
        _G.TaxiNodeGetType = function() return nodeType end
        _G.TakeTaxiNode = function(slot) taken = slot end
        MockWoW:FireEvent("TAXIMAP_OPENED")
        local wrongVisited, fabricated, wrongTaken = guide.steps[1].goals[1].visited, AR.TaxiTracker:KnowsTaxi("Brill"), taken
        name = "Brill, Tirisfal Glades"
        MockWoW:FireEvent("TAXIMAP_OPENED")
        local matchedVisited, matchedKnown, matchedTaken = guide.steps[1].goals[1].visited, AR.TaxiTracker:KnowsTaxi("Brill"), taken
        taken, nodeType = nil, "CURRENT"
        MockWoW:FireEvent("TAXIMAP_OPENED")
        _G.NumTaxiNodes, _G.TaxiNodeName, _G.TaxiNodeGetType, _G.TakeTaxiNode = oldCount, oldName, oldType, oldTake
        T:AssertFalse(wrongVisited, "Opening another flightmaster must not mark the requested node visited")
        T:AssertFalse(fabricated, "Never persist the guide's requested name as an observed taxi")
        T:AssertEqual(wrongTaken, nil, "Partial node-name matches must not fly to the wrong destination")
        T:AssertTrue(matchedVisited and matchedKnown, "Real observed node may complete discovery")
        T:AssertEqual(matchedTaken, 1, "Matching reachable destination retains automatic flight behavior")
        T:AssertEqual(taken, nil, "Never fly to the current node")
    end)
end)
