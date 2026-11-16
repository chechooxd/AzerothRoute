-- SPEC-04: QuestTracking, QuestAutoAccept, Localizers & WhoWhere Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-04: Quest Engine, Auto-Accept/Turn-In, Localizers & WhoWhere", function()
    T:It("caches quest log entries, tracks recentlyLostQuests buffer, and marks server completion on turnin", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.QuestTracking:Reset()

        MockWoW.quests.inLog[363] = {
            title = "Rude Awakening",
            level = 1,
            isComplete = true,
            objectives = {},
        }

        AR.QuestTracking:ScanQuestLog()
        T:AssertTrue(AR.QuestTracking:IsInLog(363), "Quest 363 should be indexed in questsById")

        -- Remove from log and fire system completion message within 3.0s window
        MockWoW.quests.inLog[363] = nil
        AR.QuestTracking:ScanQuestLog()
        T:AssertTrue(AR.QuestTracking.recentlyLostQuests["Rude Awakening"] ~= nil, "Lost quest should enter 3.0s recentlyLostQuests buffer")

        AR.QuestTracking:OnSystemChatMessage("Rude Awakening completed.")
        T:AssertTrue(AR.QuestTracking:IsCompleted(363), "System chat completion message must mark lost quest 363 as completed")
    end)

    T:It("automates quest accept/turn-in when matching current step goals and aborts when Alt is held or after manual decline", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.QuestAutoAccept:Reset()

        local guide = AR.Parser:ParseGuide("Test\\AutoQuest", [[
            step
                accept Rude Awakening##363
                turnin The Mindless Ones##364
        ]])
        AR.Progression:LoadGuide(guide, 1)

        -- Alt key held -> locked out
        MockWoW.isAltKeyDown = true
        T:AssertFalse(AR.QuestAutoAccept:ShouldAutoAccept(363), "Alt key down must suppress auto-accept")

        -- Normal state -> auto-accepts 363 (in current step), ignores 999 (not in step)
        MockWoW.isAltKeyDown = false
        T:AssertTrue(AR.QuestAutoAccept:ShouldAutoAccept(363), "Quest 363 in active step should auto-accept")
        T:AssertFalse(AR.QuestAutoAccept:ShouldAutoAccept(999), "Quest 999 not in active step should not auto-accept")

        -- Manual decline locks out for 10s
        AR.QuestAutoAccept:OnManualDecline()
        T:AssertFalse(AR.QuestAutoAccept:ShouldAutoAccept(363), "Manual decline must lock out auto-accept for 10 seconds")
        MockWoW:AdvanceTime(11000)
        T:AssertTrue(AR.QuestAutoAccept:ShouldAutoAccept(363), "Lockout must expire after 10 seconds")
    end)

    T:It("caches localized NPC/Quest names with 1800s TTL and finds nearest service NPC in WhoWhere", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Localizers:Reset()
        AR.WhoWhere:Reset()

        MockWoW.tooltips.npcs[5675] = "Hermano Malach"
        T:AssertEqual(AR.Localizers:GetTranslatedNPC(5675), "Hermano Malach", "Localizers should resolve translated NPC name")

        AR.WhoWhere:RegisterNPC(5675, { role = "trainer", class = "PALADIN", map = 1420, x = 0.32, y = 0.70 })
        AR.WhoWhere:RegisterNPC(5676, { role = "trainer", class = "PALADIN", map = 1420, x = 0.80, y = 0.80 })

        MockWoW.player.mapID = 1420
        MockWoW.player.x = 0.30
        MockWoW.player.y = 0.71

        local nearest = AR.WhoWhere:FindNearest("trainer", "PALADIN")
        T:AssertTrue(nearest ~= nil, "WhoWhere should return nearest matching NPC")
        T:AssertEqual(nearest.npcid, 5675, "NPC 5675 at (0.32, 0.70) is closer to (0.30, 0.71) than (0.80, 0.80)")
    end)
end)
