# Talent plan import

Objective: paste a talent calculator link in the game and follow it as a plan. Branch claude/azerothroute-2;
delivery: one feature commit, release 0.3.0; tests: `luajit Tests/load_check.lua`.

## Specs

- S1 In-game import: "Dentro del juego" - the player pastes an Icy Veins WoW Forever talent calculator link
  (`https://www.icy-veins.com/wow-forever/<class>-talent-calculator#tc-<letters>~...`) into the Talents
  section and gets a plan with the link's exact pick order (one letter per point, in order).
- S2 The imported plan has a name, is saved per character, survives addon updates, and can be removed.
- S3 An imported plan works like the built-in ones: its own tab, Follow this plan, Apply talents, the tree view.
- S4 A link for another class, a letter that is no talent, a rank past a talent's maximum or more than 51
  points is refused with a message saying why; nothing is saved.
- Assumption: only Icy Veins links (the source of the built-in plans); other calculators are out of scope.

## Tasks

- T1 S1,S4 letter tables (tools/fork/icyveins/calculator.txt) into IcyVeins.lua; decoder Talents/Import.lua - inline - done
- T2 S2,S3 saved imports attached as plans; tabs keyed by plan; Import page and Remove in View.lua - inline - done
- T3 S1-S4 load_check 6c, docs, CHANGELOG 0.3.0, install, commit - inline - done

## Log

- L1 (2026-11-21): "me encanto !! seria ideal poder importar despues guias de talentos igualente" / "Dentro del juego" / "Yes, start now"
- L2 (2026-11-21): the calculator hash `#tc-<letters>` holds one letter per point in pick order (fire mage:
  51 letters matching the guide's slider order); letters are per-talent ids (`data-talenturlid`), not positional.
- L3 (2026-11-21): View.lua now owned outright (patch `overwrite`); tabs keyed by plan key; checks in
  Tests/load_check.lua section 12 (decode order, 5 refusals, save/reload/follow/tab/remove, view page);
  mock gained CreateFont. All checks OK. Release 0.3.0.
