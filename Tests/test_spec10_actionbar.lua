-- SPEC-10: Secure ActionBar, MagicKey, Faction & CreatureDetector Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-10: Pre-Allocated Secure ActionBar, Combat Queue, MagicKey, Faction & CreatureDetector", function()
    T:It("pre-allocates 5 SecureActionButtonTemplate frames and defers macrotext updates during combat lockdown", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.ActionBar:Initialize()

        T:AssertEqual(#AR.ActionBar.buttons, 5, "Must pre-allocate 5 secure action buttons (AzerothRouteAB1..5)")

        local guide = AR.Parser:ParseGuide("Test\\SecureBar", [[
            step
                talk Brother Malach##5675
                kill Mindless Zombie##1501 |q 363/1
        ]])
        AR.Progression:LoadGuide(guide, 1)

        -- Attempt update while InCombatLockdown() == true -> must queue without throwing taint error!
        MockWoW.inCombat = true
        AR.ActionBar:UpdateFromCurrentStep()
        T:AssertTrue(AR.ActionBar.pendingCombatUpdate == true, "Combat lockdown must defer secure attribute update")
        T:AssertEqual(AR.ActionBar.buttons[1]:GetAttribute("macrotext1"), nil, "Button attribute must not be written during combat")

        -- Leave combat -> PLAYER_REGEN_ENABLED flushes pending update
        MockWoW.inCombat = false
        AR.ActionBar:OnCombatEnd()
        T:AssertFalse(AR.ActionBar.pendingCombatUpdate, "Pending flag must clear after combat ends")
        T:AssertEqual(AR.ActionBar.buttons[1]:GetAttribute("macrotext1"), "/target Brother Malach\n/tm 8", "Button 1 must receive /target macrotext")
    end)

    T:It("calculates remaining reputation to target standing in Faction and detects mount/pet guides in CreatureDetector", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Faction:Reset()
        AR.CreatureDetector:Reset()

        -- Revered is standing 7 (starts at 21000 cumulative); currently Honored (standing 6, 3000/12000 -> cumulative 9000 + 3000 = 12000)
        AR.Faction:UpdateFaction("Undercity", 6, 3000, 12000)
        T:AssertEqual(AR.Faction:GetStanding("Undercity"), 6, "Undercity standing should be 6 (Honored)")
        T:AssertEqual(AR.Faction:PointsToStanding("Undercity", 7), 9000, "9000 rep remaining to reach Revered (7)")

        AR.CreatureDetector:RegisterMountGuide(17481, "PetsMounts\\Rivendare's Deathcharger")
        local match = AR.CreatureDetector:InspectMountSpell(17481)
        T:AssertEqual(match, "PetsMounts\\Rivendare's Deathcharger", "CreatureDetector must return acquisition guide for mount spell 17481")
    end)
end)
