# Reported live-client UX gaps
Objective: address the reported interaction gaps; do not claim Zygor parity or protected-action compatibility from mocks.
Branch: feat/live-ux-gaps; baseline c57963d. Delivery ask-on-risk, forecast ~250 authored lines. Runner: luajit Tests/run_tests.lua.

## Specs
- S1: "el tema de target sigue siendo un bug que bloquea, se genera la macro y se hace focus al npc pero este no queda con una marca y salta el mismo error de siempre y en el chat un mensaje de bloqueo." Acceptance requires live forbidden-function evidence; do not suppress warnings or guess a secure workaround.
- S2: "no se puede marcar temas como terminados por mi, por ejemplo que ya llegue a la zona que pedian llegar y demas cosas". Implement explicit manual arrival completion without fabricating quest records; preserve ordinary navigation clicks.
- S3: "ademas de ello el mapa no se marca como zygor lo hace". Address confirmed stale marks and goal-map selection; full rendered-route parity remains unverified.
- S4: "no se guarda la ultima posicion que debe la ventana". Save scalar viewer anchors in profile, restore at initialization and profile changes.
- S5: "por que esperar que te reclame para hacerlo, yo estoy aca para aprobar desiciones pero no para decirte que te falto o no considerar si tu mismo puedes verlo". Audit adjacent reported flows proactively; distinguish implemented behavior from client acceptance. Worktree isolation remains required.

## Tasks
- T1 [S2,S3,S4,S5] inline, implemented and verified: explicit arrival action, stale destination cleanup and viewer anchor persistence; tests/docs. Risk item 3: shared goal/viewer/pointer contracts.
- T2 [S1] pending live proof: identify actual forbidden function and compare identical manual macro/button click; do not mask popup.
- T3 [S1-S5] independent verification and native reliability review completed; client visual/marking acceptance pending.

## Log
- L1 User: "el tema de target sigue siendo un bug que bloquea, se genera la macro y se hace focus al npc pero este no queda con una marca y salta el mismo error de siempre y en el chat un mensaje de bloqueo. pero en cuando a la experiencia del paso a paso, no se puede marcar temas como terminados por mi, por ejemplo que ya llegue a la zona que pedian llegar y demas cosas, ademas de ello el mapa no se marca como zygor lo hace, no se guarda la ultima posicion que debe la ventana y asi varias cosillas que aun no llegan al nivel de zygor, y siento que no es mucho trabajo el considerarlas si tu revisas el codigo y lo entiendes, saber hacer inge inversa y todo ello, por que no aplicas cada funcionalidad al addon ? por que esperar que te reclame para hacerlo, yo estoy aca para aprobar desiciones pero no para decirte que te falto o no considerar si tu mismo puedes verlo"
- L2 Current main c57963d already includes library/UX integrations from other work; obsolete fcfc worktree removed. New isolated checkout 0de6 created. Baseline suite observed111/111. Read-only explorer confirmed missing goto row action, absent drag persistence, stale pin/activeTarget on empty step, no map-zone switch. Target string tests cannot verify protected-action execution; old addon conditionally hides forbidden warnings, which must not be imported.

- L3 Tests: baseline111/111; initial regression RED111 passed3 failed -> GREEN114/0. Independent verifier found preview mutation; corrected, RED114/1 -> GREEN115/0. Native reliability review found preview left-click regression from that correction; preserved goal references, blocked preview right-click only. Regression RED114/1 -> GREEN115/0. Targeted validator approved correction; exact acknowledgement completed, authority burned. No live targeting or rendered-route parity claim.
- L4 Delivery: implementation remains on feat/live-ux-gaps in the isolated worktree. No deployment, merge or push. S1 blocked by missing live forbidden-function/manual-macro evidence; S3 full route overlays remain pending. Risk item3. Commit identity follows in git history for this document.
