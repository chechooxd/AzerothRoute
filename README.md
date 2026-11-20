# AzerothRoute

World of Warcraft guide addon under development. The catalog is not yet a verified
end-to-end leveling route; registered guides and step counts do not prove coverage.

## Guide actions

Load a guide through `/ar menu`. Available actions appear in a five-button strip on
the right side of the screen. Click a target button to select a nearby NPC or enemy
by its localized name: friendly NPCs use a star, enemies use a skull. The client
controls target range and raid-marker permissions. A click selects/marks a target;
it does not automatically interact with the NPC or attack an enemy.

Buttons refresh as objectives complete. During combat their protected actions stay
unchanged; the latest guide state is applied after combat. No F key is bound or
overwritten. Item, spell, and equipment actions share the same five-button pool.

Vendor goals require the specified merchant, while junk selling still works at
other merchants. Flight discovery uses nodes actually reported by the taxi map;
opening an unrelated flightmaster no longer fabricates the requested discovery.

## Minimap button & map pins

A minimap button opens the addon: left-click shows/hides the guide, right-click opens
the guide menu, middle-click opens the talent advisor. Drag it around the minimap
edge; `/ar minimap` hides or shows it. Its position is saved per account.

Step waypoints appear on the world map (zone and continent) and on the minimap
through `HereBeDragons-Pins-2.0`; minimap pins stay on the edge when out of range.
Without that library the addon falls back to its own pin placement.

## Guide flow

- On login the addon resumes the guide and step you were on (chat: "Resumed guide").
- When the last step is done it loads the guide named by the `next` header and says so in
  chat; without one it shows "Guide complete!" and points you to `/ar menu`.
- Finishing a step plays a map ping (Options > Interface > Step complete sound) and flashes
  the guide window; steps you had already done are skipped silently.
- `>`: next step. Right-click: next unfinished step. Shift-click: 10 steps.
  `<`: previous step. Ctrl-click: first step.

## Guide window

Each line starts with an icon for its action (accept, turn in, kill, collect, talk, fly,
hearth...) that turns into a check when done, and the text switches to past tense
("Accepted X", "Aceptada X"). Options > Interface > "Upcoming steps shown" (0-4) previews
the next steps dimmed under the current one; the window grows to fit its lines.

## Waypoint arrow

The arrow shows the target name and, below it, the distance with an ETA (m:ss) based on your
average speed; the distance turns from red to green as you close in. Within 8 yd (15 yd while
flying) it switches to a bouncing check, "You are here". When a step waypoint is reached the
arrow moves to the next one. If the distance cannot be measured (another continent) it shows
the target map name. "Go to" goals never complete while you are on a flight path.

## Options & profiles

`/ar config` (also `/ar opciones`, or Shift-click on the minimap button) opens the options
panel, which is also listed in the Blizzard Interface Options. Tabs: Quests, Navigation,
Merchants, Targeting, Interface and Profiles. Settings belong to an AceDB-3.0 profile; every
character starts on the shared "Default" profile and can switch, copy, reset or delete
profiles in the Profiles tab. Settings saved by older versions are moved into the profile
the first time this version loads.

## Target macro

Like RXPGuides, the addon keeps an account macro named `ARTargeting` up to date with the
current step: `/targetexact` for each NPC and enemy (enemies last, so they win), then
`/tm [harm,nodead] !8` (skull) or `/tm [help,nodead] 1` (star). Drag it to an action bar and
bind a key; `/ar macro` refreshes it and opens the macro window. It is rewritten only out of
combat and never created when the 120 account macro slots are full. Set
`AzerothRouteSavedDB.global.targetmacro = false` to stop managing it.

## Map coordinates & upstream libraries

`Spatial/Coords.lua` integrates unmodified upstream `LibStub` (minor 2),
`CallbackHandler-1.0` (minor 8), and `HereBeDragons-2.0` (`2.18-release`, minor 35)
loaded before `Spatial/Coords.lua` in `AzerothRoute.toc` and `Tests/run_tests.lua`
(provenance and notices in `Libs/NOTICES.md`). `Coords:GetWorldPair` resolves
both endpoints through the same tier (`HereBeDragons-2.0` -> native
`C_Map.GetWorldPosFromMapPos` -> `ZONE_BOUNDS` -> estimated yards) so distance,
bearing, and minimap radar offsets never mix coordinate spaces.

## Verification

Run `luajit Tests/run_tests.lua` from the repository root (`` across 36 test suites). Client verification is pending:

- Check the minimap button, its clicks and tooltip; move it, `/reload`, and check that it keeps its position.
- `/ar config`: change a toggle, `/reload`, check it stuck; create a second profile, switch, check the toggle follows the profile.
- After updating from an older version, check that your previous settings (auto-accept, bar positions) were kept.
- `/reload` mid-guide: the same guide and step come back. Finish a guide with a `next` header: the next one loads; hear the ping on each finished step.
- Change a setting, `/reload`, and check that it persists (SavedVariables now rebind on `ADDON_LOADED`).
- Check step pins on the zone map, continent map, and minimap edge.
- Walk toward and away from a waypoint; the arrow must point up and green toward it, down and red away.
- Walk to a waypoint: check icon within 8 yd, ETA while moving, then the arrow jumps to the next waypoint.
- Guide window: icons per line, check + past tense when done; set "Upcoming steps shown" to 2 and check the dimmed preview and window height.
- Talk to a flight master whose path the guide asks for; the flight map opens and the step advances.
- With the hearthstone already set where the guide asks, the "set hearthstone" goal is complete.
- Click an enemy target button twice; the skull stays. If a "blocked action" popup appears, the chat names the function.
- Put the `ARTargeting` macro on a bar, press it near a step NPC/enemy: it targets and marks it; in combat it keeps the previous content.
- Load a guide with NPC/enemy goals and check localized labels, selection and marks.
- Complete an objective within a step and check that its action disappears.
- Change steps during combat; check that buttons update only after combat ends.
- Visit the wrong merchant/flightmaster; check that unrelated goals stay incomplete.
- Polestar-style guide window: step heading (NPC in blue, zone under it), two or more finished goals fold into "N done" (click to unfold), "Then:" line, step tip as a muted "›" line; nothing overlaps at the default width.
- Toolbar: Skip advances, the map pin opens the world map on the waypoint, "..." opens the menu (All steps, Clean up quest log, Guides, Talents, Options, Hide). Labels follow the client language.
- After a few minutes of questing the footer shows "XP/h · time to level".
- "While you're here": distance in yards updates while moving; × removes the goal until `/reload`.
- Click the step counter: step cards with ticks and "+N more"; the wheel scrolls; clicking a card jumps there.
- Minimap button: left-click hides/shows everything; right-click opens the menu (Guide window ✓, Hide arrow, Hide/Show AzerothRoute, Keep the arrow when hidden).
- Guide center: type in the search box, check the row tags ("x/y" on the loaded guide, "Your level"), chips, status bar and Steps/Quests/Next.
- "Clean up quest log": only quests the route never hands in; Abandon must open the game's own confirmation and cancel must keep the quest.
- Key Bindings > AddOns > AzerothRoute: six bindings with readable names; Next/Previous step work from the keyboard.
- Arrow: no backdrop, a shadow that turns with it, gold when sideways; distance, destination and ETA on three lines.
- Guide Center tabs Guides / Lookup / Dungeons: the search box follows the tab; reopening keeps the last tab.
- Lookup: type "swift", "defias" or "linen": categories show counts; a quest shows level, giver and turn-in NPC; "Show on map" points the arrow there and the guide's next refresh does not take it back until you arrive.
- Lookup on an esES/esMX client: quest, NPC and item names come out in Spanish.
- Dungeons: "For your level" matches your level; a dungeon lists only your faction's quests; clicking one points the arrow at the giver. Check a few lists against your own knowledge (the quest attachment is heuristic).
- `/reload` with Lookup open and check memory with the addon list (the database adds about 2.5 MB of text).
- Map pin button: first item shows the waypoint on the map; below it the nearest vendor, repair, innkeeper, flight master, bank, auction house, stable master and mailbox with yards; clicking one points the arrow there.
- Journey: set a far destination (e.g. Lookup a quest giver in another zone). With known flight paths the arrow says "Walk to <flight path>", shows "m:ss total", and the guide window lists numbered legs with times; check a boat/zeppelin crossing too. Options: `journey` can be turned off in the profile.
- On a Spanish client, check whether flight paths you know are used (names outside the built-in translation list may not be recognised).
- Hearthstone: set it at an inn (the position is recorded then), travel far away and pick a destination near that inn: the first leg must be "Hearthstone to <inn>"; with the stone on a long cooldown it must prefer flights or boats.
- Trainers: hover over a class trainer, a weapon master and a profession trainer, and open one trainer window; the map pin menu must then list "Class trainer" (only your class), "Weapon master" and the profession title with yards. Check the tooltip title is read on Forever (line 2 of the NPC tooltip) on an English and a Spanish client.
- Rares: Lookup has a Rares category; the map pin menu names the nearest rare with yards.
- Quest-starting loot: loot an item that starts a quest; it appears first on the item bar with a gold glow and a tooltip line, and disappears once the quest is in your log.
- New spells: open your class trainer once, then level up: a card above the guide window lists the new spells, their cost and whether you can pay; "Go to trainer" points the arrow; "Turn these off" stops the cards.
- Tabs: load a second guide from the Guide Center; switch tabs and check each resumes at its step; close one with ×; + opens the guide list.
- Group quests: reach a step with a group quest (e.g. Wanted: "Hogger"): a banner offers "Skip it" (its accept, kill and turn-in leave the route) or "Do it with a group" (banner goes away); `/reload` keeps the choice.
- Rewards: open a quest offer with item rewards, accept it: under the accept/turn-in line the guide shows "Reward: <item>" ("new" for an upgrade, "at turn-in" on accepts). With the quest log open, check it does not jump to another quest.
- Talents: open the talent window: classes in the sidebar with the gold bar, spec tabs underlined, the next point in the gold card, spent points ticked, the mouse wheel scrolls.
- Rares tab: target or see a rare's nameplate: chat says "Rare nearby" once; the Rares tab lists it under Seen with when and how often; "Set waypoint" points the arrow.
- Characters tab: log in two characters; each shows level, class, gold, zone, guide and step, rested XP; the total gold is in the header; "Forget this character" removes an alt.
- Options tab: change the accent colour, guide-window opacity and size and see the guide window repaint; Reload UI applies the accent everywhere.
- Import: in the Guide Center click "+ Import", paste a guide (first line `guide My Loop`, then `step` blocks), Import: it opens selected in the list; `/reload` keeps it; "Delete imported guide" removes it. Try text without steps to see the error.

The mock suite cannot establish live-client protected-action compatibility,
minimap positioning, talent texture availability, or leveling-route completeness.

## Viewer interactions

Right-click a Go to objective to mark arrival manually; right-click again to undo
while the step is displayed. Quest records are never changed. Left-click selects
the waypoint and switches the open world map to its zone. Empty steps clear stale
waypoint pins and arrows. Drag the viewer to save its position in the profile.

Target marking on Forever remains unverified in the live client. No forbidden-action
warnings are hidden. Rendered route overlays and complete Zygor parity are not claimed.

## Lookup and Dungeons database

`DB/` holds quest, NPC, item and world-object records generated from
[pfQuest](https://github.com/shagu/pfQuest) (MIT, notice in `DB/LICENSE-pfQuest.txt`) by
`tools/build_db.lua`. `DB/DungeonDefs.lua` is hand-written (names, level ranges, entrance zone).
To regenerate after updating pfQuest:

```bash
luajit tools/build_db.lua <path-to-pfQuest>/db
```

Limits: pfQuest stores no positions for creatures inside instances, so each dungeon's quest list is
attached from the quest texts and may miss or misplace a few quests. Forever-only dungeons are not in
pfQuest and are not listed. Dungeon entrances have no coordinates; "Show on map" opens the zone.

## Nearby services and journeys

Services come from the database flags (pfQuest meta: vendor, repair, innkeeper, flight master,
banker, auctioneer, stable master, mailbox). Trainers are not in that data: `Spatial/Trainers.lua` learns them in game
(the NPC tooltip title on mouse-over, and the trainer window) into the shared SavedVariables, so the
list starts empty and fills as you meet them. Journeys are planned by `Spatial/Journey.lua` over
`Spatial/TravelData.lua`: Classic flight-path nodes (snapped to the nearest flight master in the
database) and hand-written boat, zeppelin and tram docks with approximate positions and crossing
times. Only flight paths the character knows are used. Times are estimates (run speed or your
measured speed on foot, a fixed effective flight speed). The hearthstone is planned when it is in your bags: it lands where you last set it (recorded when the
stone is bound, or a flight path of the same name), and its remaining cooldown counts as waiting.

## Importing guides

The Guide Center's "+ Import" takes text in the same guide language as `Guides/Autoload.lua`
(header lines such as `type`, `startlevel`, `endlevel`, `description`, then `step` blocks). An optional
first line `guide <Name>` names it; otherwise the name field is used. Imported guides are saved in the
shared SavedVariables and appear in the list like any other guide.
