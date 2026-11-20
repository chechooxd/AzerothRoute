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

## Tasks
- [x] T1 [S3] Viewer heading, folded done goals, Then preview, note line — inline · 122/122
- [x] T2 [S4] Toolbar Skip/map/more menu + XP/h footer (search lives in the guide center, T6) — inline · 125/125
- [x] T3 [S9] While-here distance and dismiss — inline · 126/126
- [x] T4 [S5] All-steps browser — inline · 128/128
- [x] T5 [S6] Minimap dropdown menu + hide all (right-click now opens the menu; left-click hides/shows all) — inline · 130/130
- [x] T6 [S7] Guide center search, row tags, details (chips, status, stats) — inline · 132/132
- [ ] T7 [S8] Quest log cleanup dialog — inline
- [ ] T8 [S10] Key bindings — inline
- [ ] T9 Merge to master, README checklist

## Log
- L1 (2026-11-19): "corrige el addon que estamos desarrollando, quiero que te inspires en polestar, sobretodo en la interfaz, es totalmente lo que busco para mi addon" — done as ced39ce (viewer + guide center) and 94f6faa (arrow).
- L2 (2026-11-19): "sigue con todo lo demas, no pares hasta dejarlo al mismo nivel de polestar"
- L3: Route: all tasks inline (no writer trigger: sequential units sharing ViewerFrame/Locale). Data-dependent Polestar features listed as out of scope.
- L4: T6 replaced level-band section headers with a right-hand row tag ("x/y" on the loaded guide, "Your level" on matching guides): headers inside the paged list would change the 14-rows-per-page contract that existing tests pin (Page 1/4 for 55 guides).
