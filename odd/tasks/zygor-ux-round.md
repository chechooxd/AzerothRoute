# Feature: zygor-ux-round
Objective: finish the Zygor-inspired UX round (arrow, viewer, race flight paths) and merge to master for in-game testing.
Branch: feat/ar-13-ace3-libraries-fixes → master · Delivery: commit per package, merge at end · Test runner: `luajit Tests/run_tests.lua`

## Specs
- S1: "Dale commitea siempre y pasa a main siempre porfa al finalizar, y continua con lo demás, cuando finalizes todo lo propuesto lo cargare al juego he iré probando y anotando cada detalle para otra ronda de mejoras"
- S2 (package 2, arrow, as proposed 2026-11-16): arrival state, ETA, automatic move to the next waypoint, "Go to" never completes while on a flight, distance color.
- S3 (package 3, viewer, as proposed): per-action icons, check icon when complete, past-tense text, preview of the next steps.
- S4 (small, as proposed): seed the race's starting flight path ("sembrar las rutas de vuelo de la raza").
- Out of scope (proposed as a separate project): multi-hop travel routes (LibRover-style).

## Tasks
- [x] T1 [S2] Arrow: arrival, ETA, next waypoint, no goto on taxi, distance color — inline · RED 6/6 → GREEN 105/105
- [ ] T2 [S3] Viewer: icons, check, past tense, step preview — inline
- [ ] T3 [S4] Seed racial starting flight paths once per character — inline
- [ ] T4 [S1] Merge branch into master

## Log
- L1 (2026-11-16): "Dale commitea siempre y pasa a main siempre porfa al finalizar, y continua con lo demás, cuando finalizes todo lo propuesto lo cargare al juego he iré probando y anotando cada detalle para otra ronda de mejoras"
- L2: Package 1 committed as 6f7f294 before this document.
