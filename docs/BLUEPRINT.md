# AzerothRoute — Reverse Engineering Blueprint & Technical Specifications

> **Architectural Decision**: `ZygorGuidesViewerForever` (`Interface: 16001` / `WOW_PROJECT_CAMELOT`) is a reactive operating environment inside World of Warcraft composed of **14 decoupled engines**, a **stateless DSL compiler**, and a **frame-budgeted coroutine scheduler**. `AzerothRoute` implements this architecture cleanly from the ground up without legacy technical debt.

---

## 1. Global Architecture & Core Invariants

1. **Stateless Goal Completion**: Goal and step completion are never persisted in `SavedVariables` (except opt-in `|sticky saved` goals). Every `0.1s` tick evaluates live game state (`completedQuests`, `questsbyid`, `GetItemCount`, distance, reputation, profession skill).
2. **Compile-Time Pruning vs. Runtime Evaluation**: `|only Race,Class` directives on goals are evaluated at parse time and discarded before allocation if unmet. `|only if <expr>` directives compile into `ConditionEnv` closures evaluated at runtime.
3. **Skip Streak vs. Manual Pause Latch**: Manual step navigation (`PreviousStep`/`SkipStep`) engages `pause = true` to halt auto-advancement until `FocusStep` lands on an incomplete step. Auto-skipping decays `completioninterval` by `0.8x` down to `0.01s`.
4. **Frame-Budgeted Coroutines**: Heavy tasks (guide loading, multi-zone Dijkstra pathfinding, trainer scanning, dungeon loot scoring) yield via `debugprofilestop()` after `5ms` (`<40 FPS`), `10ms` (`<60 FPS`), `20ms` (`>=60 FPS`), or `1ms` (`InCombatLockdown()`).
5. **Grid-Decoupled Talent Coordinates**: Talent builds reference `"posX,posY,entryIndex"` grid coordinates instead of unstable Blizzard `entryID`s, binding dynamically when `PlayerSpellsFrame.TalentsFrame` opens.

---

## 2. Technical Specifications (`SPEC-01` .. `SPEC-14`)

| Spec ID | Subsystem | Core Modules | Key Responsibilities |
| :--- | :--- | :--- | :--- |
| **`SPEC-01`** | Kernel & Runtime | `AzerothRoute.toc`, `Core/Compat.lua`, `Core/Events.lua`, `Core/Storage.lua`, `Core/Scheduler.lua`, `Core/Init.lua` | API compatibility wrappers, FPS-budgeted coroutine scheduler (`before_guides` -> `load_guides` -> `after_guides` -> `after_all` -> `postcombat`), event multiplexer, and 3-tier `SavedVariables` (`global`, `factionrealm`, `char`). |
| **`SPEC-02`** | DSL Compiler & `ConditionEnv` | `Engine/ConditionEnv.lua`, `Engine/Parser.lua` | `#include` macro interpolation, `leechsteps` cloning, header/step/goal parsing, static `\|only` pruning, and 70+ live predicates in `ConditionEnv`. |
| **`SPEC-03`** | Reactive Progression & SIS | `Engine/Guide.lua`, `Engine/Step.lua`, `Engine/Goal.lua`, `Engine/Chains.lua`, `Engine/Progression.lua` | Stateless status evaluation (`hidden`, `passive`, `complete`, `incomplete`, `impossible`, `warning`, `obsolete`), parallel `Stickies`, `StepHistory`, `pause` latch, explicit level/postponed notices, and QuestChains Smart Injection (`FindStartingPoint`). |
| **`SPEC-04`** | Quest Engine & Localization | `Quest/QuestTracking.lua`, `Quest/QuestAutoAccept.lua`, `Quest/Localizers.lua`, `Quest/WhoWhere.lua` | Reactive quest log & server completion cache, `recentlyLostQuests` 3s buffer, Alt-safe auto-accept/turn-in, tooltip localization cache, and nearest-NPC lookup. |
| **`SPEC-05`** | Spatial & Multi-Hop Pathfinder | `Spatial/Coords.lua`, `Spatial/TaxiTracker.lua`, `Spatial/Pathfinder.lua`, `Spatial/Pointer.lua`, `Spatial/Foglight.lua`, `Spatial/Poi.lua` | Affine map coordinate projection, binary min-heap Dijkstra coroutine over walk/fly/taxi/inn/ship/zeppelin/tram/portal/hearth nodes with baked continent cache, 30 FPS arrow, corpse arrow, per-objective colored pins (GamePad-safe), spline ant trails, Foglight, and POIs. |
| **`SPEC-06`** | Talent Advisor | `Modules/TalentAdvisor/TalentData.lua`, `Modules/TalentAdvisor/TalentAdvisor.lua` | `"posX,posY,entryIndex"` grid mapping, active vs. build rank diffing (`GOOD`, `BAD`, `remainingDelta`, next-point pulse), overlay badges, and `0.1s` `C_Traits` auto-learn. |
| **`SPEC-07`** | Professions, Skills & Inventory | `Modules/Professions/Profession.lua`, `Modules/Professions/Skills.lua`, `Modules/Professions/Inventory.lua` | TradeSkill/recipe cache, 1-click `C_TradeSkillUI.CraftRecipe`, proximity/capital class trainer alerts, guide `buy` merchant automation, coroutine grey selling, auto-repair, and bank serialization. |
| **`SPEC-08`** | Gear Scoring & Upgrades | `Modules/Gear/Statweights.lua`, `Modules/Gear/ItemScore.lua`, `Modules/Gear/Upgrades.lua`, `Modules/Gear/QuestReward.lua`, `Modules/Gear/GearFinder.lua` | Stat weight evaluation, soft stat caps (50% reduction), level-40 armor transition grace (`-40` -> `0.9x` / `0.5x`), Pawn import/export, bag upgrade queue popup, quest reward best-upgrade/best-gold picker, and dungeon loot recommender. |
| **`SPEC-09`** | Gold & Auction Engine | `Modules/Gold/Scanner.lua`, `Modules/Gold/ServerTrends.lua`, `Modules/Gold/GoldGuide.lua`, `Modules/Gold/Appraiser.lua` | AH state-machine scanner, 10th/50th/90th price percentiles (`p_lo`, `p_md`, `p_hi`), 10 market health tiers, gold/hr route scoring, and AH shopping/undercut appraiser. |
| **`SPEC-10`** | Secure ActionBar & Detectors | `Modules/ActionBar/ActionBar.lua`, `Modules/ActionBar/MagicKey.lua`, `Modules/ActionBar/Faction.lua`, `Modules/ActionBar/CreatureDetector.lua` | 5 pre-allocated `SecureActionButtonTemplate` frames with combat-deferred macrotext queue, `MagicKey` binding, reputation calculator, and mount/pet guide detector. |
| **`SPEC-11`** | Party Sync & Notifications | `Modules/Sync/NotificationCenter.lua`, `Modules/Sync/PartySync.lua` | Prioritized toast/history `NotificationCenter` and `AceComm` + `LibDeflate` party synchronization (`GS`/`SD` packets and Magnetic Step Hold). |
| **`SPEC-12`** | UI Framework, Skins & Viewer | `UI/Widgets/Core.lua`, `UI/Skins/Default.lua`, `UI/Viewer/ViewerFrame.lua`, `UI/Viewer/Tabs.lua` | Skinnable widget primitives, 1-line-per-goal `ViewerFrame`, 3-stop progress gradients, 0.5s white flash, separated `Stickies` block, 7px interactive progress bar, and 30 draggable tabs. |
| **`SPEC-13`** | GuideMenu, Dashboard & Options | `UI/Menu/GuideMenu.lua`, `UI/Menu/DashboardWidgets.lua`, `UI/Menu/Options.lua` | 825x630 command center (`Home`, `Featured`, `Current`, `Recent`, `Suggested`, `Search` with `quest:<id>`, `Options`) and 6-column tile-grid dashboard widgets. |
| **`SPEC-14`** | Data Catalog & Headless Tests | `Data/*`, `Guides/*`, `Tests/*` | Multi-locale (`esMX`/`esES`/`enUS`) guide/data catalog and standalone headless Lua test runner with mock WoW API. |

---

## 3. Execution Roadmap & Gantt Planner

| Order | Phase | Task | Spec ID | Deliverable | Timeline (S1–S14) |
| :---: | :--- | :---: | :---: | :--- | :--- |
| 1 | F1: Core | `T1` | `SPEC-01..14` | Architectural Blueprint & Planner (`docs/BLUEPRINT.md`) | `█░░░░░░░░░░░░░` |
| 2 | F1: Core | `T2` | `SPEC-01`, `SPEC-14A` | Kernel, `.toc`, Scheduler, Events, Storage + Headless WoW Mock Runner | `██░░░░░░░░░░░░` |
| 3 | F1: Core | `T3` | `SPEC-02` | DSL Compiler (`#include`, `leechsteps`, `\|only`, `ConditionEnv`) | `░██░░░░░░░░░░░` |
| 4 | F1: Core | `T4` | `SPEC-03` | Stateless Progression Engine, `Stickies`, `Pause Latch`, `SIS` (`Chains`) | `░░██░░░░░░░░░░` |
| 5 | F2: MVP | `T5` | `SPEC-04` | `QuestTracking`, `QuestAutoAccept`, `Localizers`, `WhoWhere` | `░░░█░░░░░░░░░░` |
| 6 | F2: MVP | `T6` | `SPEC-05` | `Coords`, `Pathfinder` (Dijkstra + Baked Cache), `TaxiTracker`, `Pointer`, `Foglight`, `Poi` | `░░░██░░░░░░░░░` |
| 7 | F2: MVP | `T7` | `SPEC-12` | `ViewerFrame`, `StepLine`, `Stickies` Separator, `Tabs`, `Skins` | `░░░░░█░░░░░░░░` |
| 8 | F3: Advisors | `T8` | `SPEC-06` | `TalentAdvisor` (Grid Mapping, Diff Engine, Badges, Auto-Learn) | `░░░░░░█░░░░░░░` |
| 9 | F3: Advisors | `T9` | `SPEC-07` | `Professions` (Recipes/Craft), `Skills` Trainer, `Inventory` (Buy/Sell/Bank) | `░░░░░░░█░░░░░░` |
| 10 | F3: Advisors | `T10` | `SPEC-08` | `ItemScore`, `Statweights`, `Upgrades`, `QuestReward`, `GearFinder` | `░░░░░░░░█░░░░░` |
| 11 | F4: Action/Gold | `T11` | `SPEC-10` | `Secure ActionBar`, `MagicKey`, `Faction`, `CreatureDetector` | `░░░░░░░░░█░░░░` |
| 12 | F4: Action/Gold | `T12` | `SPEC-09` | `Gold` Scanner, `ServerTrends`, `GoldGuide`, `Auctiontools` Appraiser | `░░░░░░░░░░█░░░` |
| 13 | F5: Hub/Sync | `T13` | `SPEC-13` | `GuideMenu`, Global Search, 6-Col Home Dashboard Widgets, `Options` | `░░░░░░░░░░░█░░` |
| 14 | F5/F6: Release | `T14` | `SPEC-11`, `SPEC-14B` | `PartySync`, `NotificationCenter`, Full `Data/` & `Guides/` Catalog + E2E Suite | `░░░░░░░░░░░░██` |
