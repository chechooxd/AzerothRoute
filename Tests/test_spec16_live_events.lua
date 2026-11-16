-- SPEC-16: Live WoW Client API & Event Bridge Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-16: Live WoW Client Event & Native API Bridge", function()
    T:It("scans native C_QuestLog / GetQuestLogTitle APIs when MockWoW.quests.inLog is empty and reacts to QUEST_LOG_UPDATE + CHAT_MSG_SYSTEM", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Events:Reset()
        AR.QuestTracking:Reset()
        AR.QuestTracking:RegisterLiveEvents()

        -- Simulate a real WoW client where MockWoW.quests.inLog is not used directly, but native GetNumQuestLogEntries/GetQuestLogTitle are provided
        MockWoW.quests.inLog = nil
        _G.GetNumQuestLogEntries = function() return 1, 1 end
        _G.GetQuestLogTitle = function(index)
            if index == 1 then
                -- title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
                return "Vital Supplies", 5, 0, false, false, 1, 1, 1470
            end
        end
        _G.GetNumQuestLeaderBoards = function(index) return 1 end
        _G.GetQuestLogLeaderBoard = function(objIdx, qIdx)
            return "Crate Delivered: 1/1", "item", true
        end

        MockWoW:FireEvent("QUEST_LOG_UPDATE")
        T:AssertTrue(AR.QuestTracking:IsInLog(1470), "QUEST_LOG_UPDATE must scan native GetQuestLogTitle and populate quest 1470")
        T:AssertEqual(AR.QuestTracking.questsById[1470].objectives[1].numFulfilled, 1, "Must parse 'Crate Delivered: 1/1' leaderboard string")

        -- Now simulate quest removal + CHAT_MSG_SYSTEM completion
        _G.GetNumQuestLogEntries = function() return 0, 0 end
        MockWoW:FireEvent("QUEST_LOG_UPDATE")
        MockWoW:FireEvent("CHAT_MSG_SYSTEM", "Vital Supplies completed.")
        T:AssertTrue(AR.QuestTracking:IsCompleted(1470), "CHAT_MSG_SYSTEM event must mark removed quest 1470 as completed")

        _G.GetNumQuestLogEntries = nil
        _G.GetQuestLogTitle = nil
        _G.GetNumQuestLeaderBoards = nil
        _G.GetQuestLogLeaderBoard = nil
    end)

    T:It("executes native AcceptQuest, CompleteQuest, and GetQuestReward on dialog events", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Events:Reset()
        AR.Parser:Reset()
        AR.QuestAutoAccept:Reset()
        AR.QuestAutoAccept:RegisterLiveEvents()

        local guide = AR.Parser:ParseGuide("Test\\LiveDialog", [[
            step
                accept Rude Awakening##363
                turnin Rude Awakening##363
        ]])
        AR.Progression:LoadGuide(guide, 1)

        local acceptedCount = 0
        local completedCount = 0
        local chosenRewardIdx = nil

        _G.GetQuestID = function() return 363 end
        _G.AcceptQuest = function() acceptedCount = acceptedCount + 1 end
        _G.IsQuestCompletable = function() return true end
        _G.CompleteQuest = function() completedCount = completedCount + 1 end
        _G.GetNumQuestChoices = function() return 2 end
        _G.GetQuestItemLink = function(qType, idx)
            return (idx == 1) and "item:3001" or "item:3002"
        end
        _G.GetQuestReward = function(idx) chosenRewardIdx = idx end

        MockWoW.tooltips.items["item:3001"] = { armorType = "CLOTH", slot = "INVTYPE_CHEST", stats = { INT = 1 }, sellPrice = 100, count = 1 }
        MockWoW.tooltips.items["item:3002"] = { armorType = "CLOTH", slot = "INVTYPE_CHEST", stats = { INT = 1 }, sellPrice = 950, count = 1 }

        MockWoW:FireEvent("QUEST_DETAIL")
        T:AssertEqual(acceptedCount, 1, "QUEST_DETAIL must call native AcceptQuest() for step goal 363")

        MockWoW:FireEvent("QUEST_PROGRESS")
        T:AssertEqual(completedCount, 1, "QUEST_PROGRESS must call native CompleteQuest() when completable")

        MockWoW:FireEvent("QUEST_COMPLETE")
        T:AssertEqual(chosenRewardIdx, 2, "QUEST_COMPLETE must call native GetQuestReward(2) using QuestReward advisor")

        _G.GetQuestID = nil
        _G.AcceptQuest = nil
        _G.IsQuestCompletable = nil
        _G.CompleteQuest = nil
        _G.GetNumQuestChoices = nil
        _G.GetQuestItemLink = nil
        _G.GetQuestReward = nil
    end)

    T:It("flushes queued Secure ActionBar updates automatically when PLAYER_REGEN_ENABLED fires", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Events:Reset()
        AR.Parser:Reset()
        AR.ActionBar:Initialize()
        AR.ActionBar:RegisterLiveEvents()

        local guide = AR.Parser:ParseGuide("Test\\LiveCombatBar", [[
            step
                talk Executor Arren##1569
        ]])
        AR.Progression:LoadGuide(guide, 1)

        MockWoW.inCombat = true
        AR.ActionBar:UpdateFromCurrentStep()
        T:AssertTrue(AR.ActionBar.pendingCombatUpdate == true, "Should queue update during combat")

        MockWoW.inCombat = false
        MockWoW:FireEvent("PLAYER_REGEN_ENABLED")
        T:AssertFalse(AR.ActionBar.pendingCombatUpdate, "PLAYER_REGEN_ENABLED must flush queued secure action bar update")
        T:AssertEqual(AR.ActionBar.buttons[1]:GetAttribute("macrotext1"), "/cleartarget\n/targetexact Executor Arren\n/tm 1", "Button 1 macro must be populated after event")
    end)
end)
