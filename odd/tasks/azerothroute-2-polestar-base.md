# AzerothRoute 2: Polestar's engine as the base
Objective: reach Polestar 0.4.1.1's experience by adopting its GPL-3.0 code as AzerothRoute's base (renamed, credited), not by re-implementing it.
Branch: claude/azerothroute-2 (per phase) · Delivery: work-unit commits, merged into master each round · Runner: headless harness (`luajit Tests/run_tests.lua`) plus in-game rounds.

## Specs
User stories (HU). Each lists what the player sees; "Polestar module" names the code it comes from.

### E0 Foundation
- S1 / HU-01 Fork and rename. AzerothRoute 2 is Polestar 0.4.1.1's code under AzerothRoute's name: addon folders `AzerothRoute`, `AzerothRoute_Guides`, `AzerothRoute_Options`, `AzerothRoute_Nav`..., global table, SavedVariables (`AzerothRouteDB`, `AzerothRouteCharDB`), slash commands `/ar` and `/azerothroute` (plus `/way`), logo and window titles. Every file keeps Polestar's copyright and GPL notice and states it was changed; an About/credits page names Polestar, Shortest Path Forever, the translators and data sources. Done when the renamed addon loads in WoW Forever with no Polestar addon installed and with Polestar installed side by side (no global, frame-name or binding clash).
- S2 / HU-02 Upstream sync. `tools/sync_polestar` takes a Polestar release folder and produces AzerothRoute's folders: copies, applies the rename rules, re-applies AzerothRoute's own changes, excludes the left-out parts, and reports what it could not apply. Done when re-running it on 0.4.1.1 reproduces the committed tree byte for byte.
- S3 / HU-03 Left out. Not shipped: `Polestar_Guides_<Race>/Legs.lua` (Leffe's maps, permission given to Polestar's author only), `Polestar_Arcade` (Doom), Polestar Recorder links, Polestar's Discord/founder emblems. The guide window falls back to the live walking router where baked legs were used.
- S4 / HU-04 Quest data provenance. Polestar_QuestDB, _Codex and _Experimental include facts from QuestieDB, whose maintainers ask to treat it as all rights reserved. Decision D2 picks: ship as Polestar does (removable on request) or rebuild those packs without QuestieDB.
- S5 / HU-05 Moving from AzerothRoute 1. A player who updates keeps: the open guides and step (mapped to the same Polestar guide), auto-accept/turn-in/reward choices, minimap button position, target button binding. AzerothRoute 1's SavedVariables are read once and left untouched.
- S6 / HU-06 Checks. The headless harness loads every renamed file in .toc order with the mock API, builds every guide for both factions, opens each hub section and runs the slash commands without errors. In-game rounds use a checklist per epic.

### E1 First run
- S7 / HU-10 Setup wizard. On first login a 7-page setup (Welcome, Quests, Targeting, Groups, Your route, Your look, All set) with live previews; every page applies at once; "Skip setup" leaves defaults; reopened with `/ar install`. (Polestar UI/Install*)

### E2 Guide window
- S8 / HU-20 Step card: NPC and zone header, goals with icons, live counts and checks, collapsible notes, tabs for open guides, `<` `>` step pager, Skip, map pin, target, search and menu buttons. (UI/GuideFrame*)
- S9 / HU-21 Journey ("Trayecto"): numbered legs (walk, fly, zeppelin, boat) with times, average waits and total time and yards; follows flights the player knows. (Nav/Journey, QoL/Flight)
- S10 / HU-22 "While you are here": quests of later steps that can be turned in or taken within a few yards, dismissible. (Quests/)
- S11 / HU-23 Level pace: "On pace for level X at step N" or "N levels behind: farm until level Y at step Z", with the guide's progress bar.
- S12 / HU-24 Class quest and new-weapon cards in the window and as toasts ("Ready: Moonsilver Blade · Open in a new tab / Later").
- S13 / HU-25 One-time tips ("Open any flight master's map once...").

### E3 Navigation
- S14 / HU-30 Arrow with distance and ETA that walks real paths (around mountains, through gates) from the continent walking maps. (Polestar_Nav, Nav/)
- S15 / HU-31 Route line on the world map and minimap (Line, Dots, Sparkles) and route style (Fastest, Balanced, Roads), never through enemy cities or zones far above your level. (Maps/RouteLines)
- S16 / HU-32 Flights: line on the flight map, in-flight timer bar, learned flight times. (QoL/Flight, UI/JourneyPanel)
- S17 / HU-33 `/way` waypoints and map pins for services, trainers and quest givers. (Maps/)

### E4 Hub (Guide Center)
- S18 / HU-40 Guides: Home (Continue cards with step and %, Suggested for you), Explore, Open, Recent; categories with counts (All, Leveling, Class, Professions, Reputation, Exploration, Legacy, Collectibles, Miscellaneous, Favorites); guide page with level/group/faction chips, rewards, why, warning, steps, quests, zones, Continue. (UI/GuideFrameMenu, Core/Guides)
- S19 / HU-41 Search across guides, items, NPCs and quests. (Lookup/)
- S20 / HU-42 Dungeons by level band and raids; dungeon page with quests (faction filter), bosses and map; "Guide me to the entrance", "Nothing to pick up". (Dungeons/)
- S21 / HU-43 Talents: a plan per spec for every class, follow plan or follow my spec, marks on the talent frame. (Talents/)
- S22 / HU-44 Rares and treasures by zone with loot, location and distance, Set waypoint, Silence alerts, Seen list, rare alerts while playing. (Rares/)
- S23 / HU-45 Characters (alts) with gold, guide and rested XP. (Alts/)
- S24 / HU-46 Import community guides. (UI import)
- S25 / HU-47 Menu scale slider and favorites.

### E5 Quests and targeting
- S26 / HU-50 Accept and turn in the guide's quests (hold Shift to skip), never choosing between rewards; optionally skip grey and low-value quests and say which. (Quests/)
- S27 / HU-51 Group quests: ask at each, do them in group, or skip them. 
- S28 / HU-52 Target button list (creature face, the item it drops, counts), simple single-button mode, show who it targets, skull/star marks, group pings. (QoL/Target*)
- S29 / HU-53 Quest log clean-up.

### E6 Gear
- S30 / HU-60 Quest reward and item tooltips rate upgrades by stat weights (automatic from talents or a chosen spec): "+40% upgrade at level 45", sources and "guide me". (Gear/)

### E7 Look
- S31 / HU-70 Themes (built-in: own, Halo, Hearth, WoW Forever, Blizzard, Classic; concept skins: Aurora, Beacon, Hairline, Lanterns, Lumen, Sheen, Umbra, Vellum, Waymark) and colour schemes, chosen with previews. (Theme/, SkinAPI, Skin_*)

### E8 Options
- S32 / HU-80 One settings page with groups and search that finds any setting by name. (Polestar_Options)

### E9 Languages
- S33 / HU-90 English plus the 9 locales Polestar ships; Spanish (esMX/esES) reviewed in game.

### E10 What AzerothRoute adds
- S34 / HU-100 AzerothRoute 1 features Polestar lacks, ported onto the new base after review (decision D3): gold farming routes and auction appraiser, dungeon pick-up route, guide recorder, `/ar report` error report.

## Decisions
- D1 (decided 2026-11-20: fork, user "Yes, use it as base"): adopt Polestar's code as the base (HU-01/02) vs port its modules into AzerothRoute 1's architecture. Evidence: AzerothRoute 1 is about 20,700 lines of addon Lua; Polestar's core, options and nav are about 172,000; porting means rewriting about eight times the current addon and diverging from every later Polestar fix.
- D2 (decided 2026-11-20, user "Yes, include them"): ship QuestDB, Codex and Experimental as Polestar does; `--without-questie` removes them on request.
- D3 (open): which AzerothRoute 1 extras to keep (S34).

## Tasks
- T1 (S1-S3, S6) P0 Fork, rename, exclusions, harness: first build of AzerothRoute 2. done a98561f, e7d27ad (headless: 400 files compile, 0 missing refs, 212 core files load, start-up events clean, /ar and bindings checked); in-game load pending
- T2 (S5) P0 Migration from AzerothRoute 1. done e7d27ad (Core/MigrateV1.lua via patch: autoaccept, autoturnin, targetmacro, automark, minimap; checked RED/GREEN in Tests/load_check.lua)
- T3 (S7-S33) P1 In-game verification rounds per epic (E1-E9), fixing what the rename broke. pending
- T4 (S4) Quest data per D2. done (packs included; load check covers 10 load-on-demand packs, 0 errors)
- T5 (S34) P2 Port the kept AzerothRoute 1 extras. pending
- T6 (S2) Upstream sync tool reproducing the tree. done a98561f (rerun on 0.4.1.1 leaves addon/ unchanged)

## Log
- L1 (2026-11-20): "instale polestar y la experiencia es otro nivel, osea mira todo eso vs mi addon, porfavor dejemos ya de parches y comienza a trabajar de verdad en mi addon, si es necesario que generes plan con todas las hu a trabajar para llegar a eso dale, pero ten en consideracion una cosa, tenemos el acceso a todo el codigo de polestar, que no lo quieras tomar e implementar hace que esto esto se retrase innecesariamente"
- L2: Survey of Polestar 0.4.1.1: core 143,549 Lua lines (UI 37.8k, Core 33.2k, Nav 19.3k, QoL 11.5k, Theme 9.2k, Quests 7.7k, Maps 6.5k, Dungeons 4.1k, Gear 4.1k, Lookup 3.7k, Talents 2.9k, Rares 2.8k, Alts 0.8k), Options 18.4k, Nav 10.3k plus EK/Kalimdor maps, 9 locale packs (~57k lines each), 10 skins. About 1,500 "Polestar" references in code; SavedVariables PolestarDB/PolestarCharDB; slash /polestar /pole /ps /rl /way. Licences: GPL-3.0-only (core, guides), GPL-3.0-or-later (Nav, from Shortest Path Forever), OFL fonts, esMX translations GPL-3.0 by Yendi; QuestDB/Codex/Experimental cite QuestieDB; race Legs.lua made with Leffe's maps under a permission to Polestar's author.
- L3 (2026-11-20): "Yes, use it as base". Fork built: tools/fork_polestar.lua renames by Lua region (code: brand anywhere in identifiers so SLASH_/BINDING_ names pair with their strings; strings: brand, "/polestar" -> "/ar", URLs and project phrases kept; comments untouched); patches in tools/fork/patches.lua (+ files/). Repo layout: addon/<folders>, tools/install.sh copies them to AddOns. First rename bug caught before the game: SLASH_POLESTAR1 kept while SlashCmdList["AZEROTHROUTE"] changed.
- L4: D2 evidence: the Codex pack is read by 30 core files (Search, Dungeons, Rares, Lookup, nearby services, maps) and QuestDB by 22 (quest tooltips, tracker, levels, party); leaving them out empties the Buscador, Calabozos and Raros sections.
- L5 (2026-11-20): "Yes, include them" - D2: Codex, QuestDB and Experimental ship; 32 folders, 435 Lua files.
