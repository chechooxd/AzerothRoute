-- SPEC-09: Gold Engine, AH Scanner, ServerTrends, GoldGuide & Appraiser Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-09: Auction Scanner, ServerTrends Percentiles, GoldGuide & Appraiser", function()
    T:It("scans auction listings, computes p_lo / p_md / p_hi percentiles, and classifies price status", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.GoldScanner:Reset()

        MockWoW.auction.replicateItems = {
            { itemID = 2447, name = "Peacebloom", count = 1, buyoutPrice = 100 },
            { itemID = 2447, name = "Peacebloom", count = 1, buyoutPrice = 200 },
            { itemID = 2447, name = "Peacebloom", count = 1, buyoutPrice = 300 },
            { itemID = 2447, name = "Peacebloom", count = 1, buyoutPrice = 400 },
            { itemID = 2447, name = "Peacebloom", count = 1, buyoutPrice = 500 },
        }

        AR.GoldScanner:RunFullScan()
        T:AssertEqual(AR.GoldScanner.state, "SS_IDLE", "Scanner must return to SS_IDLE after completing scan")

        local trend = AR.ServerTrends:GetTrend(2447)
        T:AssertTrue(trend ~= nil, "Trend for Peacebloom (2447) must be computed")
        T:AssertEqual(trend.p_lo, 100, "10th percentile should be 100")
        T:AssertEqual(trend.p_md, 300, "50th percentile (median) should be 300")
        T:AssertEqual(trend.p_hi, 500, "90th percentile should be 500")
        T:AssertEqual(AR.ServerTrends:ClassifyPrice(2447, 90), "PRICESTATUS_DUMPED", "Price below p_lo should classify as DUMPED")
        T:AssertEqual(AR.ServerTrends:ClassifyPrice(2447, 900), "PRICESTATUS_GOUGED", "Price >= 2x p_hi should classify as GOUGED")
    end)

    T:It("ranks farming guides by Gold/Hr in GoldGuide and populates AH shopping/undercut lists in Appraiser", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.GoldGuide:Reset()

        -- Set market median prices: Peacebloom (2447) = 300c, Copper Ore (2770) = 1500c
        AR.ServerTrends:SetTrend(2447, { p_lo = 100, p_md = 300, p_hi = 500 })
        AR.ServerTrends:SetTrend(2770, { p_lo = 1000, p_md = 1500, p_hi = 2200 })

        AR.GoldGuide:RegisterChore({ title = "Herb Loop", yieldsPerHour = { [2447] = 100 } }) -- 30,000c/hr
        AR.GoldGuide:RegisterChore({ title = "Mining Loop", yieldsPerHour = { [2770] = 60 } }) -- 90,000c/hr

        local chores = AR.GoldGuide:GetRankedChores()
        T:AssertEqual(chores[1].title, "Mining Loop", "Mining Loop (90,000c/hr) must rank above Herb Loop (30,000c/hr)")

        -- Appraiser shopping list from active step
        local guide = AR.Parser:ParseGuide("Prof\\Copper", [[
            step
                get 20 Copper Ore##2770
        ]])
        AR.Progression:LoadGuide(guide, 1)
        MockWoW.player.itemsInBags[2770] = 5

        local shopping = AR.Appraiser:GetShoppingListFromGuide()
        T:AssertEqual(#shopping, 1, "Appraiser must extract 1 shopping item from active step")
        T:AssertEqual(shopping[1].needed, 15, "Needs 15 Copper Ore (20 - 5 in bags)")
        T:AssertEqual(AR.Appraiser:SuggestUndercutPrice(2770, 1500), 1499, "Smart undercut should undercut lowest buyout by 1 copper")
    end)
end)
