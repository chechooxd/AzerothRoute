# Gathering routes

Objective: data-driven gold guides: loops of herb and ore spawn points for the character's skill, followed with
the arrow. Branch claude/azerothroute-2; delivery: feature commits, part of 0.6.0; tests: `luajit Tests/load_check.lua`.

## Specs

- S1 "Gathering routes": for Herbalism or Mining, the addon builds a loop of node spawn points (Polestar's
  gather data) in a zone suited to the character's current skill, e.g. "Minería 175-245: circuito en Tierras
  Inhóspitas".
- S2 The arrow guides the player node to node around the loop, moving on when the player is near the point.
- S3 A page lists the routes for the character's gathering skills (zone, skill range, node kinds, length) to
  pick and start or stop one.
- S4 Routes are generated from data, not copied from third-party guides.
- Assumption: Herbalism and Mining only (fishing pools move and have no loop); the character's faction and level
  are not filtered in the first version beyond what the data allows.

## Tasks

- T1 S1,S4 route builder (pure): kinds for a skill, best zone by spawn count, loop ordering - inline - done
- T2 S2 follow a route with the arrow, advance on arrival - inline - done
- T3 S3 Routes page in the hub - inline - done
- T4 S1-S3 checks, docs, CHANGELOG 0.6.0, install, commit - inline - done

## Log

- L1 (2026-11-21): "Si dale con esas mejoras para la 0.6 y cuando termines busquemos mas cosas como guías para
  ganar oro y mas cosas por el estilo" / "Gathering routes"
- L2 (2026-11-21): no Icy Veins gold guide for Forever; third-party guides agree gathering is the best early gold.
  Polestar has node spawn data (Core/GatherData.lua) used only for "While you're here" spots, no routes.
- L3 (2026-11-21): built and checked (load_check 18, 19). Sample: Mining 180 at level 38 -> Arathi, Stranglethorn,
  Badlands; Mining 260 at 55 -> Burning Steppes. Fixed: zones whose spots the client cannot place (the new Forever
  maps in the mock) are not offered. Not yet seen in game. Part of 0.6.0 (the user keeps 0.6.0 open until they close it).
