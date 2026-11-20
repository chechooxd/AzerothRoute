-- AzerothRoute: Headless Test Runner (SPEC-14A)
-- Loads the Mock WoW API, all addon modules in .toc order, and executes all SPEC test suites.

local T = {
    suites = {},
    passed = 0,
    failed = 0,
    errors = {},
}
_G.TestFramework = T
package.loaded["Tests.run_tests"] = T

function T:Describe(suiteName, fn)
    table.insert(self.suites, { name = suiteName, fn = fn })
end

function T:AssertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s | expected %s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

function T:AssertTrue(val, msg)
    if not val then
        error(string.format("%s | expected truthy value, got %s", msg or "Assertion failed", tostring(val)), 2)
    end
end

function T:AssertFalse(val, msg)
    if val then
        error(string.format("%s | expected falsy value, got %s", msg or "Assertion failed", tostring(val)), 2)
    end
end

function T:It(testName, fn)
    local ok, err = pcall(fn)
    if ok then
        self.passed = self.passed + 1
        print(string.format("  [PASS] %s", testName))
    else
        self.failed = self.failed + 1
        local report = string.format("  [FAIL] %s -> %s", testName, tostring(err))
        print(report)
        table.insert(self.errors, report)
    end
end

function T:BootstrapAddon()
    require("Tests.mock_wow_api")
    local tocFiles = {
        "Libs/LibStub/LibStub.lua",
        "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "Libs/HereBeDragons/HereBeDragons-2.0.lua",
        "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua",
        "Libs/AceDB-3.0/AceDB-3.0.lua",
        "Libs/AceConsole-3.0/AceConsole-3.0.lua",
        "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
        "Libs/AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua",
        "Libs/AceConfig-3.0/AceConfig-3.0.lua",
        "Libs/AceDBOptions-3.0/AceDBOptions-3.0.lua",
        "Core/Compat.lua",
        "Core/Locale.lua",
        "Core/Storage.lua",
        "Core/Events.lua",
        "Core/Scheduler.lua",
        "Core/Init.lua",
        "Engine/ConditionEnv.lua",
        "Engine/Parser.lua",
        "Engine/Guide.lua",
        "Engine/Step.lua",
        "Engine/Goal.lua",
        "Engine/Chains.lua",
        "Engine/Progression.lua",
        "Quest/QuestTracking.lua",
        "Quest/QuestAutoAccept.lua",
        "Quest/Localizers.lua",
        "Quest/WhoWhere.lua",
        "Quest/QuestLoot.lua",
        "Quest/GroupQuests.lua",
        "Spatial/Coords.lua",
        "Spatial/TaxiTracker.lua",
        "Spatial/Pathfinder.lua",
        "Spatial/Pointer.lua",
        "Spatial/Foglight.lua",
        "Spatial/Poi.lua",
        "Spatial/Nearby.lua",
        "Spatial/Trainers.lua",
        "Spatial/TravelData.lua",
        "Spatial/Journey.lua",
        "Modules/TalentAdvisor/TalentData.lua",
        "Modules/TalentAdvisor/TalentAdvisor.lua",
        "Modules/Professions/Profession.lua",
        "Modules/Professions/Skills.lua",
        "Modules/Professions/Inventory.lua",
        "Modules/Professions/ClassSpells.lua",
        "Modules/Gear/Statweights.lua",
        "Modules/Gear/ItemScore.lua",
        "Modules/Gear/Upgrades.lua",
        "Modules/Gear/QuestReward.lua",
        "Modules/Gear/GearFinder.lua",
        "Modules/Gold/Scanner.lua",
        "Modules/Gold/ServerTrends.lua",
        "Modules/Gold/GoldGuide.lua",
        "Modules/Gold/Appraiser.lua",
        "Modules/ActionBar/ActionBar.lua",
        "Modules/ActionBar/TargetMacro.lua",
        "Modules/ActionBar/MagicKey.lua",
        "Modules/ActionBar/Faction.lua",
        "Modules/ActionBar/CreatureDetector.lua",
        "Modules/Sync/NotificationCenter.lua",
        "Modules/Sync/PartySync.lua",
        "UI/Widgets/Core.lua",
        "UI/Skins/Default.lua",
        "UI/Viewer/Tabs.lua",
        "UI/Viewer/ViewerFrame.lua",
        "UI/Viewer/StepBrowser.lua",
        "UI/Menu/DashboardWidgets.lua",
        "UI/Menu/Options.lua",
        "UI/Menu/GuideMenu.lua",
        "UI/Menu/QuestLogCleanup.lua",
        "UI/Menu/MenuPanel.lua",
        "UI/Menu/Lookup.lua",
        "UI/Menu/Dungeons.lua",
        "UI/MinimapButton.lua",
        "UI/Bindings.lua",
        "UI/SpellToast.lua",
        "UI/Menu/Config.lua",
        "Data/Catalog.lua",
        "Guides/Autoload.lua",
        "DB/Access.lua",
        "DB/DungeonDefs.lua",
        "DB/Quests.lua",
        "DB/QuestNames.lua",
        "DB/Units.lua",
        "DB/Objects.lua",
        "DB/Items.lua",
        "DB/Names_esES.lua",
        "DB/DungeonData.lua",
    }
    for _, path in ipairs(tocFiles) do
        dofile(path)
    end
end

function T:RunAll()
    self:BootstrapAddon()
    local specSuites = {
        "Tests/test_spec01_kernel.lua",
        "Tests/test_spec02_parser.lua",
        "Tests/test_spec03_progression.lua",
        "Tests/test_spec04_quest.lua",
        "Tests/test_spec05_spatial.lua",
        "Tests/test_spec12_viewer.lua",
        "Tests/test_spec06_talents.lua",
        "Tests/test_spec07_professions.lua",
        "Tests/test_spec08_gear.lua",
        "Tests/test_spec10_actionbar.lua",
        "Tests/test_spec09_gold.lua",
        "Tests/test_spec13_menu.lua",
        "Tests/test_spec11_14_sync_catalog.lua",
        "Tests/test_spec16_live_events.lua",
        "Tests/test_spec17_live_ui.lua",
        "Tests/test_spec18_world_coords_comm.lua",
        "Tests/test_spec19_full_catalog_es.lua",
        "Tests/test_spec20_ingame_fixes.lua",
        "Tests/test_spec21_localization_map_talents.lua",
        "Tests/test_spec22_minimap_automation_talents_guides.lua",
        "Tests/test_targeting_resume.lua",
        "Tests/test_interaction_identity.lua",
        "Tests/test_map_libraries.lua",
        "Tests/test_map_pins_minimap_button.lua",
        "Tests/test_ingame_arrow_progress_target.lua",
        "Tests/test_target_macro.lua",
        "Tests/test_ace3_profiles.lua",
        "Tests/test_ace3_config_panel.lua",
        "Tests/test_guide_progression_ux.lua",
        "Tests/test_arrow_ux.lua",
        "Tests/test_viewer_ux.lua",
        "Tests/test_polestar_parity.lua",
        "Tests/test_lookup_dungeons.lua",
        "Tests/test_nearby_journey.lua",
        "Tests/test_racial_flightpaths.lua",
        "Tests/test_live_ux_gaps.lua",
    }
    for _, suitePath in ipairs(specSuites) do
        dofile(suitePath)
    end

    self.passed = 0
    self.failed = 0
    self.errors = {}
    for _, suite in ipairs(self.suites) do
        print(string.format("=== Suite: %s ===", suite.name))
        suite.fn(self)
    end
    print(string.format("\nSummary: %d passed, %d failed", self.passed, self.failed))
    if self.failed > 0 then
        os.exit(1)
    end
    return true
end

if arg and arg[0] and arg[0]:find("run_tests%.lua") then
    T:RunAll()
end

return T
