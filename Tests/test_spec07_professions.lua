-- SPEC-07: Professions, Class Skills Trainer & Inventory Engine Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-07: Professions Recipe Cache/Craft, Class Skills Trainer & Inventory/Vendor/Bank", function()
    T:It("caches known skills/recipes and executes C_TradeSkillUI.CraftRecipe for create goals", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Professions:Reset()

        AR.Professions:OnConsoleSkillMessage("Skill 171 increased from 1 to 15")
        T:AssertEqual(AR.Professions:GetSkillLevel("Alchemy"), 15, "Console message parser must update Alchemy (171) skill level")

        MockWoW.player.recipesKnown[2330] = {
            recipeID = 2330,
            name = "Minor Healing Potion",
            skillLineID = 171,
            learned = true,
            numAvailable = 5,
        }
        AR.Professions:CacheRecipes()
        T:AssertTrue(AR.db.char.RecipesKnown[171][2330] ~= nil, "Recipe 2330 must be cached under Alchemy (171)")

        MockWoW.player.itemsInBags[118] = 2 -- already have 2 Minor Healing Potions
        AR.Professions:PerformTradeSkillGoal({ recipeid = 2330, targetid = 118, count = 5 })
        T:AssertEqual(#MockWoW.craftedLog, 1, "CraftRecipe should be invoked once")
        T:AssertEqual(MockWoW.craftedLog[1].count, 3, "Should craft remaining 3 potions (5 needed - 2 in bags)")
    end)

    T:It("partitions learnable class skills into normal, optional, and future (next 3 levels)", function()
        MockWoW:Reset()
        MockWoW.player.class = "PALADIN"
        MockWoW.player.level = 4
        local AR = _G.AzerothRoute
        AR.Skills:Reset()

        AR.Skills:RegisterSkill("PALADIN", { spellID = 20271, name = "Judgement", level = 4, optional = false })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 19740, name = "Blessing of Wisdom", level = 4, optional = true })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 639, name = "Holy Light (Rank 2)", level = 6, optional = false })

        local res = AR.Skills:GetLearnableSkills()
        T:AssertEqual(#res.normal, 1, "Level 4 mandatory skill Judgement should be in normal")
        T:AssertEqual(#res.optional, 1, "Level 4 optional skill should be in optional")
        T:AssertEqual(#res.future, 1, "Level 6 skill (within +3 levels) should be in future")
    end)

    T:It("computes guide merchant auto-buy quantities, sells grey items, and serializes bank cache", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()

        local guide = AR.Parser:ParseGuide("Prof\\Alch", [[
            step
                buy 10 Empty Vial##3371
        ]])
        AR.Progression:LoadGuide(guide, 1)
        MockWoW.player.itemsInBags[3371] = 3

        local toBuy = AR.Inventory:FindItemsToBuy()
        T:AssertEqual(#toBuy, 1, "Should detect 1 item to buy from current step")
        T:AssertEqual(toBuy[1].neededCount, 7, "Should need 7 Empty Vials (10 - 3 in bags)")

        -- Sell grey items
        MockWoW.merchant.isOpen = true
        MockWoW.player.money = 100
        MockWoW.player.bagSlots[0] = {
            [1] = { itemID = 9001, quality = 0, count = 2, sellPrice = 25 }, -- Grey item worth 50 copper
            [2] = { itemID = 9002, quality = 1, count = 1, sellPrice = 100 }, -- White item (keep)
        }
        local soldCount = AR.Inventory:SellGreyItems()
        T:AssertEqual(soldCount, 1, "Should sell only quality=0 grey item")
        T:AssertEqual(MockWoW.player.money, 150, "Player money should increase by 2 * 25 = 50 copper")

        -- Bank cache serialization
        AR.Inventory:RecordBank({ { itemID = 5050, bag = -1, slot = 1, count = 20 } })
        T:AssertEqual(AR.Inventory:GetBankedCount(5050), 20, "Bank cache must report 20 items of ID 5050")
    end)
end)
