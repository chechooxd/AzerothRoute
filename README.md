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

## Map coordinates & upstream libraries

`Spatial/Coords.lua` integrates unmodified upstream `LibStub` (minor 2),
`CallbackHandler-1.0` (minor 8), and `HereBeDragons-2.0` (`2.18-release`, minor 35)
loaded before `Spatial/Coords.lua` in `AzerothRoute.toc` and `Tests/run_tests.lua`
(provenance and notices in `Libs/NOTICES.md`). `Coords:GetWorldPair` resolves
both endpoints through the same tier (`HereBeDragons-2.0` -> native
`C_Map.GetWorldPosFromMapPos` -> `ZONE_BOUNDS` -> estimated yards) so distance,
bearing, and minimap radar offsets never mix coordinate spaces.

## Verification

Run `luajit Tests/run_tests.lua` from the repository root (`Summary: 66 passed, 0 failed` across 23 test suites, including `Tests/test_map_libraries.lua`). Client verification is pending:

- Load a guide with NPC/enemy goals and check localized labels, selection and marks.
- Complete an objective within a step and check that its action disappears.
- Change steps during combat; check that buttons update only after combat ends.
- Visit the wrong merchant/flightmaster; check that unrelated goals stay incomplete.

The mock suite cannot establish live-client protected-action compatibility,
minimap positioning, talent texture availability, or leveling-route completeness.
