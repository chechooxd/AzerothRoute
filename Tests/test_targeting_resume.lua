local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function setup()
    MockWoW:Reset()
    local AR = _G.AzerothRoute
    AR.Storage:Initialize()
    AR.Events:Reset()
    AR.Parser:Reset()
    AR.Localizers:Reset()
    AR.ActionBar.buttons = {}
    AR.ActionBar.pendingCombatUpdate = false
    AR.Progression.currentStep = nil
    AR.ActionBar:Initialize()
    AR.ActionBar:RegisterLiveEvents()
    return AR
end

T:Describe("Resume: visible localized secure targets", function()
    T:It("anchors click buttons, reuses them across world entries, and localizes both NPC identity fields", function()
        local AR = setup()
        MockWoW.locale = "esMX"
        MockWoW.tooltips.npcs[5675] = "Hermano Malach"
        MockWoW.tooltips.npcs[1501] = "Zombi descerebrado"
        local guide = AR.Parser:ParseGuide("Test\\Targets", [[
            step
                talk Brother Malach##5675
                kill Mindless Zombie##1501
        ]])
        AR.Progression:LoadGuide(guide, 1)
        local button = AR.ActionBar.buttons[1]
        T:AssertTrue(button._point and button.icon and button.label, "Target action needs an anchor, icon and label")
        T:AssertEqual(button._clickButtons[1], "AnyUp")
        T:AssertEqual(button._clickButtons[2], "AnyDown")
        T:AssertEqual(button:GetAttribute("macrotext1"), "/cleartarget\n/targetexact Hermano Malach\n/tm 1")
        T:AssertEqual(AR.ActionBar.buttons[2]:GetAttribute("macrotext1"), "/cleartarget\n/targetexact Zombi descerebrado\n/cleartarget [dead]\n/tm 8")
        T:AssertTrue(button.label:GetText():find("Hermano Malach", 1, true))
        T:AssertEqual(AR.ActionBar:Initialize()[1], button, "Reentry must not recreate globally named protected frames")
        local count = #AR.Events.eventHandlers.PLAYER_REGEN_ENABLED
        AR.ActionBar:RegisterLiveEvents()
        T:AssertEqual(#AR.Events.eventHandlers.PLAYER_REGEN_ENABLED, count, "Reentry must not duplicate callbacks")
        T:AssertEqual(#MockWoW.macroExecutions, 0, "Refresh must not execute actions without a player click")
    end)

    T:It("refreshes completed and newly translated goals, but freezes protected buttons during combat", function()
        local AR = setup()
        local guide = AR.Parser:ParseGuide("Test\\RefreshTargets", [[
            step
                kill Mindless Zombie##1501
                confirm
        ]])
        AR.Progression:LoadGuide(guide, 1)
        local goal = guide.steps[1].goals[1]
        local button = AR.ActionBar.buttons[1]
        local oldMacro = button:GetAttribute("macrotext1")
        MockWoW.inCombat = true
        MockWoW.tooltips.npcs[1501] = "Localized enemy"
        MockWoW:TickFrames(0.2)
        T:AssertEqual(button:GetAttribute("macrotext1"), oldMacro)
        T:AssertTrue(AR.ActionBar.pendingCombatUpdate)
        T:AssertEqual(AR.ActionBar:Initialize()[1], button)
        MockWoW.inCombat = false
        MockWoW:FireEvent("PLAYER_REGEN_ENABLED")
        T:AssertTrue(button:GetAttribute("macrotext1"):find("Localized enemy", 1, true))
        goal.condition_complete = function() return true end
        MockWoW:TickFrames(0.2)
        T:AssertEqual(button:GetAttribute("macrotext1"), nil)
        T:AssertFalse(button:IsShown(), "Completed target must disappear without requiring a step change")
    end)

    T:It("defers first creation during combat and preserves existing item/spell actions", function()
        local AR = setup()
        AR.ActionBar.buttons = {}
        MockWoW.inCombat = true
        local count = #MockWoW.frames
        AR.ActionBar:Initialize()
        T:AssertEqual(#MockWoW.frames, count, "No protected frames may be created during combat")
        MockWoW.inCombat = false
        MockWoW:FireEvent("PLAYER_REGEN_ENABLED")
        T:AssertEqual(#AR.ActionBar.buttons, 5)
        for _, action in ipairs({ "use", "cast", "equip" }) do
            T:AssertEqual(AR.ActionBar:BuildMacroForGoal({ action = action, target = "Existing action" }), "/" .. action .. " Existing action")
        end
        T:AssertEqual(AR.ActionBar:BuildMacroForGoal({ action = "kill", target = "Enemy\n/run injected()" }), nil)
        T:AssertEqual(AR.ActionBar:BuildMacroForGoal({ action = "talk", target = "[mouseover]" }), nil)
        T:AssertEqual(AR.ActionBar:BuildMacroForGoal({ action = "click", target = "Chest" }), nil, "World objects must not become NPC targets")
        for _, action in ipairs({ "vendor", "trainer", "from" }) do
            T:AssertTrue(AR.ActionBar:BuildMacroForGoal({ action = action, target = "NPC" }))
        end
        T:AssertEqual(AR.MagicKey:GetPrimaryHint(), nil, "Hidden empty buttons have no action hint")
    end)

    T:It("auto-marks matching step enemies (Skull=8) and friendly NPCs (Star=1) on target/mouseover with group & dead guards", function()
        local AR = setup()
        MockWoW.locale = "esMX"
        MockWoW.tooltips.npcs[1501] = "Zombi descerebrado"
        MockWoW.tooltips.npcs[5675] = "Hermano Malach"
        local guide = AR.Parser:ParseGuide("Test\\AutoMark", [[
            step
                talk Brother Malach##5675
                kill Mindless Zombie##1501
        ]])
        AR.Progression:LoadGuide(guide, 1)

        -- Enemy target matching creature ID -> Skull (8)
        MockWoW.units.target = { name = "Zombi descerebrado", guid = "Creature-0-0-0-0-1501-0", dead = false }
        MockWoW:FireEvent("PLAYER_TARGET_CHANGED")
        T:AssertEqual(_G.GetRaidTargetIndex("target"), 8, "Matching live enemy target must be marked with Skull (8)")

        -- Friendly NPC on mouseover -> Star (1)
        MockWoW.units.mouseover = { name = "Hermano Malach", guid = "Creature-0-0-0-0-5675-0", dead = false }
        MockWoW:FireEvent("UPDATE_MOUSEOVER_UNIT")
        T:AssertEqual(_G.GetRaidTargetIndex("mouseover"), 1, "Matching friendly NPC mouseover must be marked with Star (1)")

        -- Does not overwrite existing raid marker, skip dead mobs, and skip non-leader group members
        MockWoW.raidTargets.target = 3
        MockWoW:FireEvent("PLAYER_TARGET_CHANGED")
        T:AssertEqual(_G.GetRaidTargetIndex("target"), 3, "Must preserve existing raid icon on target")

        MockWoW.raidTargets.target = nil
        MockWoW.units.target.dead = true
        MockWoW:FireEvent("PLAYER_TARGET_CHANGED")
        T:AssertEqual(_G.GetRaidTargetIndex("target"), nil, "Must not mark dead units")

        MockWoW.units.target.dead = false
        MockWoW.inGroup = true
        MockWoW.isLeader = false
        MockWoW:FireEvent("PLAYER_TARGET_CHANGED")
        T:AssertEqual(_G.GetRaidTargetIndex("target"), nil, "Non-leader/non-assistant in group must not attempt SetRaidTarget")
    end)
end)
