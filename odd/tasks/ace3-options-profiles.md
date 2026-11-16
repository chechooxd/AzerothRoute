# Feature: ace3-options-profiles
Objective: Phase 2 — move settings to AceDB-3.0 profiles (with migration) and add an AceConfig options panel with AceDBOptions profiles.
Branch: feat/ar-13-ace3-libraries-fixes · Delivery: ask-on-risk · Test runner: `luajit Tests/run_tests.lua`

## Specs
- S1: "pero me gustaria avcanzar con la fase 2 ahora para ver reales avances en el addon" — Phase 2 as proposed on 2026-11-16: "AceConfig + AceConfigDialog + AceDBOptions | Panel de opciones real en Interface de Blizzard, con perfiles" and "AceDB | Perfiles por personaje/reino. Requiere migrar tus SavedVariables (riesgo alto: pérdida de datos si se hace mal)".
- S2: Vendor Ace3 unmodified from the official repository (WoWUIDev/Ace3), pinned to a commit that supports WoW Forever (16001); record provenance in `Libs/NOTICES.md`.
- S3: Settings read by the addon (autoaccept, autoacceptall, autoturnin, autoselectreward, corpsearrow, autotaxi, automark, targetmacro, autogrey, autorepair, autobuy, loadguidesfully, style, actionbar_pos, itembar_pos) live in the AceDB profile, default profile "Default" shared by all characters. Existing values in `AzerothRouteSavedDB.global` are moved into the profile once, without losing user choices. Data (taxitimes, minimap, flags), faction-realm data and per-character data keep their current storage.
- S4: Options panel registered in the Blizzard Interface Options and opened with `/ar config` (and from the minimap button), localized esMX/esES/enUS, with groups for quests, navigation, merchant automation, targeting, interface, plus an AceDBOptions "Profiles" tab. Changing profile updates the live settings.
- S5 (read-only, pending): "revisa como funciona zygor en esas cosas y ahi sabras a que me refiero con el tema de la experiencia" — analyse Zygor's arrow and flight-path UX for a later fix proposal.

## Tasks
- [x] T1 [S2] Vendor Ace3 (AceDB, AceDBOptions, AceConfig, AceGUI, AceConsole) @ ac3d122 + TOC + NOTICES — inline · commit d3e0ded
- [x] T2 [S3] AceDB-backed profile storage + one-time migration + readers + tests — inline · Risk: item 1 (stored data) · commit 50c39f0 · RED 5/5 → GREEN 88/88 · independent verifier PASS · native review approved+acknowledged (risk, reliability)
- [x] T3 [S4] AceConfig options panel, `/ar config`, minimap shortcut, locale, tests — inline · GREEN 94/94
- [ ] T4 [S5] Zygor arrow/flight UX analysis — read-only, pending

## Log
- L1 (2026-11-16): "revisa como funciona zygor en esas cosas y ahi sabras a que me refiero con el tema de la experiencia, pero me gustaria avcanzar con la fase 2 ahora para ver reales avances en el addon"
- L2: Prior uncommitted work committed on this branch as `25e5ad3` (vendored libs) and `31f36de` (features). Assess (untracked user files excluded): medium, `under_budget`, no review due. Boundary pending at master.
- L3: Ace3 release r1403 lacks 16001; upstream master `ac3d1225037e0dc74e025a72342c0f7824aae147` (2026-10-28) includes "AceDB-3.0: Compatibility with WoW Forever" and Forever realm keys. Pinned to it.
- L4: T2 review: full slice exceeded the lens budget (vendored libs); reduced to base d3e0ded (278 lines), user granted, risk+reliability approved, acknowledged (authority burned). Reviewed boundary → 50c39f0. Independent verifier: 5/5 PASS, notes: degraded no-AceDB mode does not persist changes; stray legacy globals are ignored but never cleaned.
- L5: T3 tests were written first but the first run failed on a test-helper bug (AceConfigRegistry uiName), so a clean RED was not observed; GREEN 94/94 after implementation. AceConfigDialog/AceGUI rendering is stubbed in tests; in-client check pending.
