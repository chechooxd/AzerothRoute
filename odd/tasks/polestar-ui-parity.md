# Feature: polestar-ui-parity
Objective: bring the in-game UI to the level of Polestar (reference screenshots in F:\addons\polestar-img) without copying its GPL code or assets.
Branch: claude/addon-polestar-interface-71be44 → master · Delivery: commit per task, merge at end · Test runner: `luajit Tests/run_tests.lua`

## Specs
- S1: "corrige el addon que estamos desarrollando, quiero que te inspires en polestar, sobretodo en la interfaz, es totalmente lo que busco para mi addon"
- S2: "sigue con todo lo demas, no pares hasta dejarlo al mismo nivel de polestar"
- S3 (viewer body, from screenshots 01/03/04/11): step heading (who/where in large coloured text with the zone under it), finished goals fold into one "N done" line, a "Then: …" one-line preview of the next step, the step note shown as a muted line.
- S4 (viewer toolbar/footer, screenshots 01/05): "Skip" button, map-pin button (open the world map on the waypoint), search button (open the guide center search), "…" menu; footer line "XP/h · time to level".
- S5 (all steps, screenshot 15): clicking the step counter opens a browser of every step as cards ("26 · Ratchet", goal lines, done ticks, "+N more"); clicking a card jumps there.
- S6 (minimap menu, screenshot 13): the minimap button opens a menu: Guide window (✓), Hide arrow, Hide everything / show everything in one click, Keep the arrow when hidden, Guides, Talents, Options.
- S7 (guide center, screenshots 07/screenshot_232144): search box, level-band section headers, details with level chips, status ("Not started" / "Step x of y" + bar) and stats (Steps, Quests, Next guide).
- S8 (quest log, screenshot 10): "Make room in your quest log" dialog listing quests the loaded route never hands in, each with Abandon (the game's own confirmation asks first).
- S9 ("While you're here", screenshots 03/04/11): each sticky goal shows its distance in yards and a × to dismiss it for the session.
- S10 (keybinds, screenshot 14): key bindings for toggle guide window, next step, previous step, guide center.
- Out of scope (need item/NPC/route databases this addon does not ship): Lookup, Dungeons browser, Nearby services, multi-leg Journey, new-spell costs, quest-starting loot glow.
- S11: "sigue con lookup y mazmorras, crea las bases de datos" — data source chosen by the user: pfQuest (MIT), generated into DB/ by tools/build_db.lua.
- S12 (Lookup, screenshot 08): search guides, quests, NPCs, items, mounts, recipes and world objects; details with where to get it; "Show on map" points the arrow there.
- S13 (Dungeons, screenshot_232430): every Classic dungeon/raid with level range, zone, "Your level", and the quests that lead into it for your faction.
- S14: "sigue con servicios cercanos y el viaje por tramos" (screenshots 05 journey, 06 nearby).
- S15: "sigue con la piedra de hogar en el viaje".
- S16: "sigue con los entrenadores en servicios cercanos" — source chosen by the user: learn in game (tooltip title on mouse-over + TRAINER_SHOW).
- S17: "sigue con lo que falta de polestar". Feasible with available data: new spells on level up (11), quest-starting loot glow (12), rares, guide tabs strip (01 "+" tab). Not feasible without new data: group-quest banner (no group flag), quest reward preview (no reward data), alts/characters, import.

## Tasks
- [x] T1 [S3] Viewer heading, folded done goals, Then preview, note line — inline · 122/122
- [x] T2 [S4] Toolbar Skip/map/more menu + XP/h footer (search lives in the guide center, T6) — inline · 125/125
- [x] T3 [S9] While-here distance and dismiss — inline · 126/126
- [x] T4 [S5] All-steps browser — inline · 128/128
- [x] T5 [S6] Minimap dropdown menu + hide all (right-click now opens the menu; left-click hides/shows all) — inline · 130/130
- [x] T6 [S7] Guide center search, row tags, details (chips, status, stats) — inline · 132/132
- [x] T7 [S8] Quest log cleanup dialog — inline · 134/134
- [x] T8 [S10] Key bindings (Bindings.xml + UI/Bindings.lua) — inline · 135/135
- [x] T9 Merge to master, README checklist
- [x] T10 [S11] Generated database (DB/, tools/build_db.lua, DB/LICENSE-pfQuest.txt) — inline
- [x] T11 [S12-S13] Lookup and Dungeons modes in the Guide Center (MenuPanel, Lookup, Dungeons) + manual arrow target — inline � 142/142
- [x] T12 [S14] Nearby services from DB flags in the map-pin menu (Spatial/Nearby.lua) — inline
- [x] T13 [S14] Journey planner (Spatial/TravelData.lua, Spatial/Journey.lua), arrow steering and Journey section in the guide window — inline � 146/146
- [x] T14 [S15] Hearthstone leg in the journey (TaxiTracker:RecordHearth on HEARTHSTONE_BOUND, GetHearthLocation, Journey hearth node with cooldown) — inline � 149/149
- [x] T15 [S16] Trainers learned in game (Spatial/Trainers.lua) in the map pin menu: own class trainer, weapon master, each profession — inline � 151/151
- [x] T16 [S17] Rares: DB flag, nearest rare in the map menu, Lookup category — inline · 152/152
- [x] T17 [S17] Quest-starting loot on the item bar with glow (Quest/QuestLoot.lua) — inline · 153/153
- [x] T18 [S17] New spells on level up (Modules/Professions/ClassSpells.lua, UI/SpellToast.lua) — inline · 155/155
- [ ] T19 [S17] Guide tabs strip in the guide window — inline

## Log
- L1 (2026-11-19): "corrige el addon que estamos desarrollando, quiero que te inspires en polestar, sobretodo en la interfaz, es totalmente lo que busco para mi addon" — done as ced39ce (viewer + guide center) and 94f6faa (arrow).
- L2 (2026-11-19): "sigue con todo lo demas, no pares hasta dejarlo al mismo nivel de polestar"
- L3: Route: all tasks inline (no writer trigger: sequential units sharing ViewerFrame/Locale). Data-dependent Polestar features listed as out of scope.
- L4: T6 replaced level-band section headers with a right-hand row tag ("x/y" on the loaded guide, "Your level" on matching guides): headers inside the paged list would change the 14-rows-per-page contract that existing tests pin (Page 1/4 for 55 guides).
- L5: All tasks done inline (no writer trigger). Suite 135/135 (34 suites). README checklist added. Risk: item 6 (layout, fonts, glyphs and the abandon popup are only verifiable in the live client) and a requested behaviour change: minimap left-click now hides/shows everything and right-click opens the menu.
- L6 (2026-11-19): "sigue con lookup y mazmorras, crea las bases de datos". User chose pfQuest MIT as the data source (rev 104f356). pfQuest keeps no coordinates for instance creatures, so dungeon quests are attached heuristically (objective text names the dungeon; or description names it with an instance-only objective; or an instance-only objective given in the dungeon zone at its level) — lists are useful but not exact. Forever-only dungeons (Hall of Thanes, Ruins of Lordaeron) are not in pfQuest and are missing. Dungeon entrances have no coordinates; "Show on map" opens the zone map.
- L7 (2026-11-20): "sigue con servicios cercanos y el viaje por tramos". Flight nodes and docks are hand-written with approximate positions; nodes snap to the nearest database flight master. Only known flight paths are used (KnowsTaxi, English canonical names — Spanish clients may miss untranslated nodes). Hearthstone not planned. Map pin button now opens a menu (waypoint + services); its old test now clicks the menu item. Direct-arrow tests stub Journey:GetSteering.
- L8 (2026-11-20): "sigue con la piedra de hogar en el viaje". Bind position recorded on HEARTHSTONE_BOUND (player stands at the innkeeper); falls back to a flight-path node of the same name; an older bind is ignored when GetBindLocation changes. Characters that set their stone before this version get a position only after binding again or when the inn shares a flight-path name.
- L9 (2026-11-20): "sigue con los entrenadores en servicios cercanos". pfQuest has no trainer flags; user chose in-game learning over a hand seed or GPL server data. Records in AR.db.global.trainers. Test found a real bug: `local _, c = _G.UnitClass and _G.UnitClass("player")` keeps only one return value; fixed with select(2, ...).
- L10 (2026-11-20): "sigue con lo que falta de polestar". Scope set to T16-T19; infeasible items listed in S17.
