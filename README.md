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

Run `luajit Tests/run_tests.lua` from the repository root (`Summary: 83 passed, 0 failed` across 26 test suites). Client verification is pending:

- Check the minimap button, its clicks and tooltip; move it, `/reload`, and check that it keeps its position.
- Change a setting, `/reload`, and check that it persists (SavedVariables now rebind on `ADDON_LOADED`).
- Check step pins on the zone map, continent map, and minimap edge.
- Walk toward and away from a waypoint; the arrow must point up and green toward it, down and red away.
- Talk to a flight master whose path the guide asks for; the flight map opens and the step advances.
- With the hearthstone already set where the guide asks, the "set hearthstone" goal is complete.
- Click an enemy target button twice; the skull stays. If a "blocked action" popup appears, the chat names the function.
- Put the `ARTargeting` macro on a bar, press it near a step NPC/enemy: it targets and marks it; in combat it keeps the previous content.
- Load a guide with NPC/enemy goals and check localized labels, selection and marks.
- Complete an objective within a step and check that its action disappears.
- Change steps during combat; check that buttons update only after combat ends.
- Visit the wrong merchant/flightmaster; check that unrelated goals stay incomplete.

The mock suite cannot establish live-client protected-action compatibility,
minimap positioning, talent texture availability, or leveling-route completeness.
