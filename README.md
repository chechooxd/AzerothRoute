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
the guide menu, middle-click opens the Guide Center on Talents. Drag it around the minimap
edge; `/ar minimap` hides or shows it. Its position is saved per account.

Step waypoints appear on the world map (zone and continent) and on the minimap
through `HereBeDragons-Pins-2.0`; minimap pins stay on the edge when out of range.
Without that library the addon falls back to its own pin placement.

## Guide flow

- On login the addon resumes the guide and step you were on (chat: "Resumed guide").
- When the last step is done it loads the guide named by the `next` header and says so in
  chat; without one it shows "Guide complete!" and points you to `/ar menu`.
- Finishing a step plays a map ping (Options > Guide > Step complete sound) and flashes
  the guide window; steps you had already done are skipped silently.
- `>`: next step. Right-click: next unfinished step. Shift-click: 10 steps.
  `<`: previous step. Ctrl-click: first step.

## Guide window

Each line starts with an icon for its action (accept, turn in, kill, collect, talk, fly,
hearth...) that turns into a check when done, and the text switches to past tense
("Accepted X", "Aceptada X"). Options > Guide > "Upcoming steps shown" (0-4 slider) previews
the next steps dimmed under the current one; the window grows to fit its lines.

## Waypoint arrow

The arrow shows the target name and, below it, the distance with an ETA (m:ss) based on your
average speed; the distance turns from red to green as you close in. Within 8 yd (15 yd while
flying) it switches to a bouncing check, "You are here". When a step waypoint is reached the
arrow moves to the next one. If the distance cannot be measured (another continent) it shows
the target map name. "Go to" goals never complete while you are on a flight path.

## Options & profiles

There is one settings page: the Guide Center's Options tab. `/ar config` (also `/ar opciones`),
the minimap button menu, the guide window menu and the button in the Blizzard AddOns options
all open it. Groups: Appearance, Guide, Navigation, Quests, Merchants, Targeting and Profiles.
Each setting has its own control: check boxes for switches (clicking the row toggles too),
colour swatches for the accent, drop-down lists for schemes, styles and profiles, and sliders
(with the mouse wheel) for opacity, size and upcoming steps. Changes apply at once; right-click
a setting to reset it, or "Reset group" for the whole group.

Settings belong to an AceDB-3.0 profile; every character starts on the shared "Default" profile
and can switch or reset it under Options > Profiles (copy and delete stay in the Blizzard AddOns
entry's Profiles tab). Settings saved by older versions are moved into the profile the first
time this version loads.

## Target button

The Target button (`AzerothRouteTargetButton`) is a secure action button of the addon's own: a
click, or its key binding (Key Bindings > AzerothRoute), targets the current step's enemies first
and then its NPCs (`/targetexact`, the first living match wins; out of combat it starts from no
target, a corpse is dropped), then marks it (`/tm` skull or star). It shows only while the step
has something to target; shift-drag it to move it. The addon only sets the button's own
attributes and waits out combat to change them: it no longer edits account macros. The old
`ARTargeting` macro is rewritten once to a note pointing at the button. `/ar macro` refreshes the
button; turn it off with the `targetmacro` profile setting.

## Map coordinates & upstream libraries

`Spatial/Coords.lua` integrates unmodified upstream `LibStub` (minor 2),
`CallbackHandler-1.0` (minor 8), and `HereBeDragons-2.0` (`2.18-release`, minor 35)
loaded before `Spatial/Coords.lua` in `AzerothRoute.toc` and `Tests/run_tests.lua`
(provenance and notices in `Libs/NOTICES.md`). `Coords:GetWorldPair` resolves
both endpoints through the same tier (`HereBeDragons-2.0` -> native
`C_Map.GetWorldPosFromMapPos` -> `ZONE_BOUNDS` -> estimated yards) so distance,
bearing, and minimap radar offsets never mix coordinate spaces.

## Verification

Run `luajit Tests/run_tests.lua` from the repository root (`Summary: 183 passed, 0 failed` across 36 test suites). Client verification is pending:

- Check the minimap button, its clicks and tooltip; move it, `/reload`, and check that it keeps its position.
- `/ar config` and the minimap "Options" open the Guide Center Options tab (no separate window): tick a check box, `/reload`, check it stuck; pick an accent swatch, drag the opacity slider, choose a scheme from its list; right-click a row to reset it; switch profile under Profiles and check the settings follow it.
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
- Talents: the rail entry, `/ar talents`, the minimap middle-click and the guide window toolbar all open the Guide Center on its Talents tab (no separate window): your class specs in the sidebar (">" marks the followed plan), picks level 10-60 with icons, learned ones ticked, opening on the next pick; "Follow this plan" switches plans, "Apply talents" spends up to the next point.
- Rares tab: target or see a rare's nameplate: chat says "Rare nearby" once; the Rares tab lists it under Seen with when and how often; "Set waypoint" points the arrow.
- Characters tab: log in two characters; each shows level, class, gold, zone, guide and step, rested XP; the total gold is in the header; "Forget this character" removes an alt.
- Options tab: change the accent colour, guide-window opacity and size and see the guide window repaint; Reload UI applies the accent everywhere.
- Import: in the Guide Center click "+ Import", paste a guide (first line `guide My Loop`, then `step` blocks), Import: it opens selected in the list; `/reload` keeps it; "Delete imported guide" removes it. Try text without steps to see the error.
- Home: the Guide Center opens on Home with the guide in progress first; its button reads Continue and brings the guide window back at the same step.
- Dungeons: hover a quest to read its objective; "Pick up the quests" opens a route tab that walks to each quest giver nearest-first.
- Gear tooltips: hover a better item: "AzerothRoute: upgrade +N%"; hover a worse one: no line. Check rings and trinkets compare against the weaker one you wear.
- Colour schemes: Options > Appearance > Colour scheme; the guide window repaints, other windows after Reload UI.
- Bags: fill your bags to 2 free slots; the guide window says so in its notice band within 5 s.
- What's new: on the first login after updating, a card lists the new features once.
- Quest XP: finish a quest: a green stretch appears on the XP bar after your XP; hovering the bar lists pending quest XP; the turn-in line shows "+N XP".
- Zone art: in Dungeons, Rares and the guide list the details title sits on the zone's map painting (from your client); unknown maps show no art.
- Report: "..." menu > Report a problem (or `/ar report`): type what happened, Make the report, Ctrl+C copies the selected text.
- Recorder: "..." menu > Record a route (or `/ar record`): Record, accept and hand in a few quests in two places, Save: a guide appears in the Guide Center.
- Gamepad: with a controller enabled, open the Guide Center: the D-pad moves a gold frame, A presses, B closes, LB/RB change tabs; the pad works normally again once it closes.

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

## Auditing the guides

`luajit tools/audit_guides.lua` checks every accept, turn-in and talk line of the built-in guides
against the NPC positions in the database (for every race and class) and lists the ones more than 1%
of the map away; `--fix` rewrites them to the NPC's position.

## Polestar guides

AzerothRoute ships the guides of Polestar 0.4.1.1 (GPL-3.0-only, https://github.com/fitzforge/polestar):
leveling 1-60 for every race, class quests, professions, reputations, mounts and pets. They show in
the Guide Center under Leveling, Professions, Class, Reputation, Collectibles and Other, keyed
`Polestar\<id>`, and only for your faction. `Guides/PolestarAdapter.lua` runs them on AzerothRoute's
engine: each Polestar goal becomes an AzerothRoute goal with its quest objective, coordinates and
note (in the tooltip), and Polestar's race/class/faction filters and quest conditions decide which
steps and goals you see.

Once they load, AzerothRoute's own leveling and profession guides (which Polestar's cover) drop
out of the Guide Center lists, search and suggestions; one you already have open keeps working.
The dungeon and gold guides stay.

To refresh them from a newer Polestar install:

```bash
luajit tools/import_polestar.lua "<path to the Polestar addons folder>"
```

The tool rewrites `Guides/Polestar/*.lua` and Polestar's data notice `Guides/Polestar/LICENSE-DATA.txt`.
It leaves out spawn-spot lists, walking crumbs, smart-target candidates, Polestar's walking legs and
its quest/item databases (see THIRD_PARTY.md).

## License

AzerothRoute is free software under the GNU General Public License, version 3 only (LICENSE).
It includes guides converted from Polestar (https://github.com/fitzforge/polestar, GPL-3.0-only,
Copyright (c) 2026 The Polestar authors); THIRD_PARTY.md lists every third-party component and
data source with its licence.
