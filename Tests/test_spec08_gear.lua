-- SPEC-08: Gear Scoring, Upgrades, QuestReward Advisor & Dungeon GearFinder Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-08: ItemScore (Soft Caps, Lvl 40 Armor Grace, Pawn), Upgrades, QuestReward & GearFinder", function()
    T:It("scores items with soft stat caps and applies level-40 armor transition multipliers (0.9x grace, 0.5x post-grace)", function()
        MockWoW:Reset()
        MockWoW.player.class = "PALADIN"
        MockWoW.player.spec = 1 -- Retribution
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()

        -- Mail chest with 10 STR (weight 2.5) = base score 25
        MockWoW.tooltips.items["item:1001"] = {
            armorType = "MAIL",
            slot = "INVTYPE_CHEST",
            stats = { STR = 10 },
        }

        -- Below level 40 (level 35): no penalty on MAIL (1.0x -> 25.0)
        MockWoW.player.level = 35
        T:AssertEqual(AR.ItemScore:ScoreItem("item:1001"), 25.0, "At level 35, Paladin wearing MAIL receives full 25.0 score")

        -- Grace period (level 42, between 40 and 49): 0.9x multiplier -> 22.5
        MockWoW.player.level = 42
        T:AssertEqual(AR.ItemScore:ScoreItem("item:1001"), 22.5, "At level 42 (10-level grace period), MAIL receives 0.9x score (22.5)")

        -- Past grace period (level 52, >= 50): 0.5x multiplier -> 12.5
        MockWoW.player.level = 52
        T:AssertEqual(AR.ItemScore:ScoreItem("item:1001"), 12.5, "At level 52 (past grace), MAIL receives 0.5x score (12.5)")
    end)

    T:It("queues bag upgrades while protecting active quest items, and selects best quest reward (upgrade vs vendor money)", function()
        MockWoW:Reset()
        MockWoW.player.class = "PALADIN"
        MockWoW.player.spec = 1
        MockWoW.player.level = 20
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Upgrades:Reset()

        MockWoW.tooltips.items["item:2001"] = { armorType = "MAIL", slot = "INVTYPE_CHEST", stats = { STR = 4 } }
        MockWoW.tooltips.items["item:2002"] = { armorType = "MAIL", slot = "INVTYPE_CHEST", stats = { STR = 10 } }
        MockWoW.player.equipped["INVTYPE_CHEST"] = "item:2001"

        local delta = AR.Upgrades:EvaluateCandidate("item:2002")
        T:AssertTrue(delta ~= nil and delta.isUpgrade == true, "item:2002 (10 STR) must be detected as an upgrade over item:2001 (4 STR)")

        -- Quest reward picker: when no choice is an upgrade, picks highest vendor gold
        MockWoW.tooltips.items["item:3001"] = { armorType = "CLOTH", slot = "INVTYPE_CHEST", stats = { INT = 1 }, sellPrice = 500, count = 1 }
        MockWoW.tooltips.items["item:3002"] = { armorType = "CLOTH", slot = "INVTYPE_CHEST", stats = { INT = 1 }, sellPrice = 1800, count = 1 }

        local pick = AR.QuestReward:SelectBestReward({ "item:3001", "item:3002" })
        T:AssertEqual(pick.reason, "money", "When neither item is an upgrade, QuestReward must pick by highest vendor value")
        T:AssertEqual(pick.index, 2, "Item 2 (1800 copper) should be selected over Item 1 (500 copper)")
    end)

    T:It("recommends highest-upgrade dungeon in GearFinder", function()
        MockWoW:Reset()
        MockWoW.player.class = "PALADIN"
        MockWoW.player.spec = 1
        MockWoW.player.level = 20
        local AR = _G.AzerothRoute
        AR.GearFinder:Reset()

        MockWoW.tooltips.items["item:4001"] = { armorType = "MAIL", slot = "INVTYPE_CHEST", stats = { STR = 12 } }
        AR.GearFinder:RegisterDungeonLoot("Shadowfang Keep", 18, 26, { "item:4001" })

        local recs = AR.GearFinder:FindBestDungeonUpgrades()
        T:AssertEqual(#recs, 1, "Shadowfang Keep loot should be recommended at level 20")
        T:AssertEqual(recs[1].dungeon, "Shadowfang Keep", "Recommended dungeon must be Shadowfang Keep")
    end)
end)
