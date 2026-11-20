# Polestar guides import
Objective: relicense AzerothRoute under GPL-3.0-only and ship Polestar 0.4.1.1's guides through an adapter.
Branch: claude/polestar-guides-import · Delivery: work-unit commits, merged into master · Runner: `luajit Tests/run_tests.lua`

## Specs
- S1: "sí, pasa a GPL-3 e importa las guías" — AzerothRoute is published under GPL-3.0-only (LICENSE, toc X-License, README), crediting Polestar.
- S2: Import Polestar's guides (Polestar_Guides, _Horde, _Alliance) so they appear in the Guide Center and run in the guide window, keeping Polestar's notices.
- S3: Leave out what the user agreed to exclude: `Legs.lua` (Leffe's maps) and QuestieDB data packs; strip spawn spots, crumbs and smart-target candidates (unused, unclear provenance).
- S4: Generated, reproducible: `tools/import_polestar.lua <Polestar dir>` rewrites the data files.

## Tasks
- T1 (S1) inline: LICENSE, THIRD_PARTY.md, toc, README. done 9da6c03
- T2 (S2-S4) inline: import tool writing Guides/Polestar/*.lua + notices. done fb9e9dc
- T3 (S2) inline: adapter Guides/PolestarAdapter.lua (guide/step/goal mapping, when/only conditions, faction gating, categories). done 66fc454
- T4 (S2) inline: Guide Center categories (Class, Reputation, Collectibles, Other), tests. done 66fc454 (Tests/test_polestar_guides.lua, 4 tests; 189 pass)

## Log
- L1 (2026-11-20): "sí, pasa a GPL-3 e importa las guías" (after: "las guias de polestar las podemos usar para no? la licencia que el tiene es 100% free ? si es asi yo igual voy por ese camino").
- L2: Polestar guides are compiled Lua tables (265 guides, 6780 steps, 28 goal kinds, 15 `when` kinds); an adapter maps them to Guide/Step/Goal objects instead of a lossy text conversion.
- L3: Built headless for both factions: Horde 176 guides / 4058 steps, Alliance 186 / 4297, ~0.1 s each, no build errors. Race/class lookups first returned nil (`a and f()` keeps one value); fixed and covered by the class-letter test.
- L4: Open: the old built-in guides stay next to Polestar's (duplicate zones); in-game check pending.
- L5 (2026-11-20): "Yes, hide them" - built-in Leveling\ and Professions\ guides are hidden from lists, search and suggestions once Polestar guides load; open ones keep working; dungeons and gold stay.
