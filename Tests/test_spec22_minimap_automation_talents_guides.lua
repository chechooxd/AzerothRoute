-- SPEC-22: Minimap Pin Fix, Live Automations (Vendor/Gossip/Taxi), Talent & Class Icons, and Zygor-Depth Leveling Guides
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-22: Minimap Green Dot Fix, Live Automations, Talent Icons & Zygor-Depth Leveling", function()
    T:It("uses valid Classic textures on minimap pins, hides cross-continent pins, and normalizes native GetWorldPosFromMapPos axes", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Coords.mapAxisCache = {}
        AR.Pointer:Reset()
        AR.Pointer:InitializeFrames()

        -- Simulate Blizzard C_Map.GetWorldPosFromMapPos returning (worldNorth, worldWest)
        local origGetWorldPos = _G.C_Map.GetWorldPosFromMapPos
        local origCreateVector2D = _G.CreateVector2D
        _G.CreateVector2D = function(x, y) return { x = x, y = y } end
        _G.C_Map.GetWorldPosFromMapPos = function(mapID, vec)
            -- Top-left (0,0) = more North (2000) and more West (-1000) than center (0.5,0.5) = (0, -2000)
            local a = 2000 - vec.y * 4000 -- worldNorth decreases going South (vec.y increases)
            local b = -1000 - vec.x * 2000 -- wait: West increases when going left -> (0,0) b > (0.5,0.5) b
            return 1, { GetXY = function() return a, b end }
        end

        local cA, wxA, wyA = AR.Coords:ToWorldYards(1413, 0.10, 0.10)
        local cB, wxB, wyB = AR.Coords:ToWorldYards(1413, 0.90, 0.90)
        T:AssertEqual(cA, 1, "Continent ID must match C_Map return")
        T:AssertTrue(wxB > wxA, "Going East (x 0.1 -> 0.9) must increase wx after North/West axis flip")
        T:AssertTrue(wyB > wyA, "Going South (y 0.1 -> 0.9) must increase wy after North/West axis flip")

        -- Restore before testing default fallback bounds
        _G.C_Map.GetWorldPosFromMapPos = origGetWorldPos
        _G.CreateVector2D = origCreateVector2D
        AR.Coords.mapAxisCache = {}

        MockWoW.player.mapID = 1413 -- Kalimdor
        MockWoW.player.x = 0.50
        MockWoW.player.y = 0.30

        AR.Pointer:PlaceStepPins({
            { map = 1413, x = 0.51, y = 0.30, title = "Waypoint", objectiveIndex = 1, action = "goto" },
            { map = 1420, x = 0.30, y = 0.70, title = "Cross Continent", objectiveIndex = 2, action = "accept" },
        })

        local mmPin1 = AR.Pointer.minimapPinFrames[1]
        local mmPin2 = AR.Pointer.minimapPinFrames[2]
        T:AssertTrue(mmPin1 ~= nil and mmPin1:IsShown(), "Same-continent minimap pin must be shown")
        local tex1 = mmPin1.tex:GetTexture()
        T:AssertTrue(tex1 ~= nil and tex1 ~= "Interface\\WorldMap\\UI-QuestPoi-NumberIcons", "Minimap default pin must NOT use missing Retail UI-QuestPoi-NumberIcons texture")
        T:AssertEqual(mmPin1.tex:GetVertexColor(), nil, "Minimap pin must not tint icon into a solid green square")
        T:AssertTrue(mmPin2 ~= nil and not mmPin2:IsShown(), "Cross-continent minimap pin must hide instead of sitting at (0,0) center on player")
        MockWoW.npc = { name = "Wrong Vendor", guid = "Creature-0-0-0-0-9999-0000000000" }
        AR.Parser:Reset()
        local gNegVendor = AR.Parser:ParseGuide("Test\\NegVendor", [[
            step OnlyRand
                vendor Blacksmith Rand##2116
        ]])
        AR.Progression:LoadGuide(gNegVendor, 1)
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertFalse(gNegVendor.steps[1]:IsComplete(), "Unrelated merchant must NOT complete named vendor goal")

        -- Negative fpath check: opening Flight Master with only Brill must NOT complete fpath Undercity
        local gNegTaxi = AR.Parser:ParseGuide("Test\\NegTaxi", [[
            step NeedUC
                fpath Undercity
        ]])
        AR.Progression:LoadGuide(gNegTaxi, 1)
        if AR.db and AR.db.char and AR.db.char.taxis then AR.db.char.taxis["Undercity"] = nil end
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeGetType = function() return "CURRENT" end
        _G.TaxiNodeName = function() return "Rémol, Claros de Tirisfal" end
        MockWoW:FireEvent("TAXIMAP_OPENED")
        T:AssertFalse(gNegTaxi.steps[1]:IsComplete(), "Opening an unrelated Flight Master must NOT falsely mark fpath Undercity complete")
    end)

    T:It("executes MERCHANT_SHOW (grey auto-sell/repair/buy), GOSSIP_SHOW, QUEST_GREETING, and TAXIMAP_OPENED automations", function()
        MockWoW:Reset()
        MockWoW.locale = "esMX"
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Events:Reset()
        AR.Inventory._liveRegistered = false
        AR.QuestAutoAccept:Reset()
        AR.TaxiTracker._liveRegistered = false
        AR.Inventory:RegisterLiveEvents()
        AR.QuestAutoAccept:RegisterLiveEvents()
        AR.TaxiTracker:RegisterLiveEvents()

        local guide = AR.Parser:ParseGuide("Test\\AutoStep", [[
            step Step1
                vendor Blacksmith Rand##2116
                buy 5 Empty Vial##3371
            step Step2
                accept Rude Awakening##363
            step Step3
                fpath Brill
        ]])
        AR.Progression:LoadGuide(guide, 1)

        -- 1. MERCHANT_SHOW with nil sellPrice (real WoW 16001 C_Container shape) + Repair + Buy
        local repaired, boughtSlot, boughtQty = false, nil, nil
        MockWoW.merchant.isOpen = true
        MockWoW.npc = { name = "Blacksmith Rand", guid = "Creature-0-0-0-0-2116-0000000000" }
        MockWoW.player.bagSlots[0] = {
            [1] = { itemID = 7771, quality = 0, hasNoValue = false, hyperlink = "item:7771" },
            [2] = { itemID = 7772, quality = 0, hasNoValue = true, hyperlink = "item:7772" },
        }
        _G.GetItemInfo = function(ref)
            if tostring(ref):find("7771", 1, true) then
                return "Cracked Bill", nil, 0, 1, 1, nil, nil, nil, nil, nil, 15
            end
        end
        _G.CanMerchantRepair = function() return true end
        _G.GetRepairAllCost = function() return 40 end
        _G.RepairAllItems = function() repaired = true end
        _G.GetMerchantNumItems = function() return 1 end
        _G.GetMerchantItemLink = function(i) return "|Hitem:3371:0:0:0|h[Vial]|h" end
        _G.BuyMerchantItem = function(i, qty)
            boughtSlot, boughtQty = i, qty
            MockWoW.player.itemsInBags[3371] = (MockWoW.player.itemsInBags[3371] or 0) + qty
        end

        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertEqual(MockWoW.player.bagSlots[0][1], nil, "MERCHANT_SHOW must sell quality=0 grey item without requiring info.sellPrice")
        T:AssertTrue(MockWoW.player.bagSlots[0][2] ~= nil, "MERCHANT_SHOW must skip hasNoValue grey items")
        T:AssertTrue(repaired, "MERCHANT_SHOW must auto-repair gear")
        T:AssertEqual(boughtSlot, 1, "MERCHANT_SHOW must auto-buy required guide reagents")
        T:AssertEqual(boughtQty, 5, "MERCHANT_SHOW must buy exact missing count (5)")
        T:AssertTrue(guide.steps[1]:IsComplete(), "MERCHANT_SHOW + auto-buy must complete vendor/buy step")

        -- 2. GOSSIP_SHOW & QUEST_GREETING auto-select
        AR.Progression:LoadGuide(guide, 2)
        local gossipSelected, greetingSelected = nil, nil
        _G.C_GossipInfo = {
            GetActiveQuests = function() return {} end,
            GetAvailableQuests = function() return { { questID = 363, title = "Despertar abrupto" } } end,
            SelectAvailableQuest = function(qid) gossipSelected = qid end,
        }
        MockWoW:FireEvent("GOSSIP_SHOW")
        T:AssertEqual(gossipSelected, 363, "GOSSIP_SHOW must auto-select available quest matching step")

        _G.GetNumActiveQuests = function() return 0 end
        _G.GetNumAvailableQuests = function() return 1 end
        _G.GetAvailableTitle = function(i) return "Despertar abrupto" end
        _G.GetAvailableQuestInfo = function(i) return false, 0, false, false, 363 end
        _G.SelectAvailableQuest = function(i) greetingSelected = i end
        MockWoW:FireEvent("QUEST_GREETING")
        T:AssertEqual(greetingSelected, 1, "QUEST_GREETING must auto-select available quest matching step")

        -- 3. TAXIMAP_OPENED flight learning, fpath completion & TaxiButton highlighting
        AR.Progression:LoadGuide(guide, 3)
        _G.TaxiFrame = _G.CreateFrame("Frame", "TaxiFrame", _G.UIParent)
        _G.TaxiButton1 = _G.CreateFrame("Button", "TaxiButton1", _G.TaxiFrame)
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeGetType = function(i) return "REACHABLE" end
        _G.TaxiNodeName = function(i) return "Rémol, Claros de Tirisfal" end
        MockWoW:FireEvent("TAXIMAP_OPENED")

        T:AssertTrue(AR.TaxiTracker:KnowsTaxi("Brill"), "TAXIMAP_OPENED must canonicalize and learn Spanish node 'Rémol' as 'Brill'")
        T:AssertTrue(guide.steps[3]:IsComplete(), "TAXIMAP_OPENED must complete fpath Brill goal")
        T:AssertTrue(AR.Pointer == nil or AR.TaxiTracker.highlightFrame:IsShown(), "TaxiTracker highlight frame must light up destination TaxiButton")
        MockWoW.npc = { name = "Wrong Vendor", guid = "Creature-0-0-0-0-9999-0000000000" }
        AR.Parser:Reset()
        local gNegVendor = AR.Parser:ParseGuide("Test\\NegVendor", [[
            step OnlyRand
                vendor Blacksmith Rand##2116
        ]])
        AR.Progression:LoadGuide(gNegVendor, 1)
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertFalse(gNegVendor.steps[1]:IsComplete(), "Unrelated merchant must NOT complete named vendor goal")

        -- Negative fpath check: opening Flight Master with only Brill must NOT complete fpath Undercity
        local gNegTaxi = AR.Parser:ParseGuide("Test\\NegTaxi", [[
            step NeedUC
                fpath Undercity
        ]])
        AR.Progression:LoadGuide(gNegTaxi, 1)
        if AR.db and AR.db.char and AR.db.char.taxis then AR.db.char.taxis["Undercity"] = nil end
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeGetType = function() return "CURRENT" end
        _G.TaxiNodeName = function() return "Rémol, Claros de Tirisfal" end
        MockWoW:FireEvent("TAXIMAP_OPENED")
        T:AssertFalse(gNegTaxi.steps[1]:IsComplete(), "Opening an unrelated Flight Master must NOT falsely mark fpath Undercity complete")
    end)

    T:It("renders talent spell icons and translates 100% of all 27 builds' talents to Spanish", function()
        MockWoW:Reset()
        MockWoW.locale = "esMX"
        local AR = _G.AzerothRoute
        AR.TalentAdvisor:Reset()
        AR.TalentAdvisor:LoadDefaultBuilds()
        AR.Storage:Initialize()
        AR.GuideMenu:Reset()
        AR.TalentAdvisor:ShowUI()

        -- Verify 100% of all talents in all 27 builds have Spanish translations & valid icons
        for _, cls in ipairs(AR.TalentAdvisor.CLASS_ORDER) do
            for _, build in ipairs(AR.TalentAdvisor:GetClassBuilds(cls)) do
                for _, tName in ipairs(build.orderedNames) do
                    local hasEntry = AR.TalentData.talentNamesES and AR.TalentData.talentNamesES[tName] ~= nil
                    local es = AR.TalentAdvisor:GetLocalizedTalentName(tName)
                    T:AssertTrue(hasEntry and es ~= nil and es ~= "", "Talent '" .. tName .. "' in " .. build.ident .. " must have a Spanish entry in talentNamesES")
                    local icon = AR.TalentAdvisor:GetTalentIcon(tName, cls)
                    T:AssertTrue(icon ~= nil and icon:find("^Interface\\"), "Talent '" .. tName .. "' must map to a valid WoW icon texture")
                end
            end
        end

        local TP = AR.TalentsPanel
        T:AssertTrue(TP.panel.lastRows[1].text:find("|T", 1, true) ~= nil, "Pick rows show the talent icon")
        AR.GuideMenu:Reset()
        MockWoW.npc = { name = "Wrong Vendor", guid = "Creature-0-0-0-0-9999-0000000000" }
        AR.Parser:Reset()
        local gNegVendor = AR.Parser:ParseGuide("Test\\NegVendor", [[
            step OnlyRand
                vendor Blacksmith Rand##2116
        ]])
        AR.Progression:LoadGuide(gNegVendor, 1)
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertFalse(gNegVendor.steps[1]:IsComplete(), "Unrelated merchant must NOT complete named vendor goal")

        -- Negative fpath check: opening Flight Master with only Brill must NOT complete fpath Undercity
        local gNegTaxi = AR.Parser:ParseGuide("Test\\NegTaxi", [[
            step NeedUC
                fpath Undercity
        ]])
        AR.Progression:LoadGuide(gNegTaxi, 1)
        if AR.db and AR.db.char and AR.db.char.taxis then AR.db.char.taxis["Undercity"] = nil end
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeGetType = function() return "CURRENT" end
        _G.TaxiNodeName = function() return "Rémol, Claros de Tirisfal" end
        MockWoW:FireEvent("TAXIMAP_OPENED")
        T:AssertFalse(gNegTaxi.steps[1]:IsComplete(), "Opening an unrelated Flight Master must NOT falsely mark fpath Undercity complete")
    end)

    T:It("loads full Zygor-depth (18+ steps) starter/core leveling guides with non-blocking passive talk goals", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.GuidesCatalog:LoadAll()

        local starterKeys = {
            "Leveling\\Horde\\Tirisfal Glades (1-12)",
            "Leveling\\Horde\\Durotar (1-12)",
            "Leveling\\Horde\\Mulgore (1-12)",
            "Leveling\\Horde\\The Barrens (12-22)",
            "Leveling\\Alliance\\Elwynn Forest (1-12)",
            "Leveling\\Alliance\\Dun Morogh (1-12)",
            "Leveling\\Alliance\\Teldrassil (1-12)",
            "Leveling\\Alliance\\Westfall (12-20)",
        }
        for _, key in ipairs(starterKeys) do
            local g = AR.Parser.guidesByTitle[key]
            T:AssertTrue(g ~= nil, "Guide must be loaded: " .. key)
            T:AssertTrue(#g.steps >= 18, "Guide '" .. key .. "' must contain >= 18 Zygor-depth steps (got " .. tostring(#g.steps) .. ")")
        end

        -- Verify passive talk goal does NOT stall step completion once quest is accepted
        local tirisfal = AR.Parser.guidesByTitle["Leveling\\Horde\\Tirisfal Glades (1-12)"]
        local step1 = tirisfal.steps[1]
        T:AssertEqual(step1.goals[2].action, "talk", "Step 1 goal 2 should be talk")
        T:AssertEqual(step1.goals[2]:GetStatus(), "passive", "Talk goal without |q must evaluate as passive so it never blocks step completion")
        MockWoW.quests.inLog[363] = { title = "Rude Awakening", isComplete = false, objectives = {} }
        T:AssertTrue(step1:IsComplete(), "Accepting quest 363 must complete step 1 without stalling on goto/talk")
        MockWoW.npc = { name = "Wrong Vendor", guid = "Creature-0-0-0-0-9999-0000000000" }
        AR.Parser:Reset()
        local gNegVendor = AR.Parser:ParseGuide("Test\\NegVendor", [[
            step OnlyRand
                vendor Blacksmith Rand##2116
        ]])
        AR.Progression:LoadGuide(gNegVendor, 1)
        MockWoW:FireEvent("MERCHANT_SHOW")
        T:AssertFalse(gNegVendor.steps[1]:IsComplete(), "Unrelated merchant must NOT complete named vendor goal")

        -- Negative fpath check: opening Flight Master with only Brill must NOT complete fpath Undercity
        local gNegTaxi = AR.Parser:ParseGuide("Test\\NegTaxi", [[
            step NeedUC
                fpath Undercity
        ]])
        AR.Progression:LoadGuide(gNegTaxi, 1)
        if AR.db and AR.db.char and AR.db.char.taxis then AR.db.char.taxis["Undercity"] = nil end
        _G.NumTaxiNodes = function() return 1 end
        _G.TaxiNodeGetType = function() return "CURRENT" end
        _G.TaxiNodeName = function() return "Rémol, Claros de Tirisfal" end
        MockWoW:FireEvent("TAXIMAP_OPENED")
        T:AssertFalse(gNegTaxi.steps[1]:IsComplete(), "Opening an unrelated Flight Master must NOT falsely mark fpath Undercity complete")
    end)
end)
