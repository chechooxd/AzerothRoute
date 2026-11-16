-- SPEC-06: Talent Advisor Engine Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-06: Talent Advisor Grid Mapping, Diffing & C_Traits Auto-Learn", function()
    T:It("maps talent names to posX,posY,entryIndex grid coordinates, diffs active ranks, and auto-learns via C_Traits", function()
        MockWoW:Reset()
        MockWoW.player.class = "PALADIN"
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.TalentAdvisor:Reset()

        -- Register talent grid coordinates and mock Blizzard talent tree nodes
        AR.TalentAdvisor:RegisterTalentNode("PALADIN", "Benediction", "1,2,1")
        AR.TalentAdvisor:RegisterTalentNode("PALADIN", "Improved Judgement", "2,1,1")
        AR.TalentAdvisor:RegisterTalentNode("PALADIN", "Seal of Command", "3,2,1")

        AR.TalentAdvisor:RegisterBuild("PALADIN", {
            ident = "PAL_RET_LEVELING",
            name = "Retribution Leveling",
            suggested = true,
            talents = [[
                Benediction
                Benediction
                Improved Judgement
                Seal of Command
            ]],
        })

        MockWoW.player.talents.nodes[101] = { nodeID = 101, posX = 1, posY = 2, entries = { 1001 }, activeRank = 1, maxRanks = 5 }
        MockWoW.player.talents.nodes[102] = { nodeID = 102, posX = 2, posY = 1, entries = { 1002 }, activeRank = 0, maxRanks = 2 }
        MockWoW.player.talents.nodes[103] = { nodeID = 103, posX = 3, posY = 2, entries = { 1003 }, activeRank = 0, maxRanks = 1 }

        AR.TalentAdvisor:BindBlizzardTalentNodes(MockWoW.player.talents.nodes)
        local status = AR.TalentAdvisor:GetBuildStatus("PAL_RET_LEVELING", 4)

        T:AssertEqual(status.byEntry[1001].delta, 1, "Benediction has 1/2 points so delta should be 1")
        T:AssertEqual(status.byEntry[1001].isNext, true, "Benediction is the next unspent point in sequence and must pulse")
        T:AssertEqual(status.byEntry[1002].delta, 1, "Improved Judgement needs 1 point")
        T:AssertEqual(status.byEntry[1002].isNext, false, "Improved Judgement is after Benediction so isNext is false")

        -- Spend a wrong point on node 103 before 101/102 -> test LearnBuild reset + sequential auto-learn
        MockWoW.player.talents.nodes[103].activeRank = 1
        AR.TalentAdvisor:LearnBuild("PAL_RET_LEVELING", 4)

        T:AssertEqual(MockWoW.player.talents.nodes[101].activeRank, 2, "Auto-learn must purchase 2 ranks of Benediction")
        T:AssertEqual(MockWoW.player.talents.nodes[102].activeRank, 1, "Auto-learn must purchase 1 rank of Improved Judgement")
        T:AssertEqual(MockWoW.player.talents.nodes[103].activeRank, 1, "Auto-learn must purchase 1 rank of Seal of Command")
    end)
end)
