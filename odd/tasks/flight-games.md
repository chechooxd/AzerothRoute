# Flight games

Objective: on a long flight, offer (optionally) one of two light games of AzerothRoute's own instead of watching the landscape.
Branch: claude/azerothroute-2. Delivery: work-unit commits merged into master, in the open (unreleased) version. Checks: `luajit Tests/load_check.lua`.

## Specs

- S1: "cuando el vuelo sea largo, mas de 1 minuto quizas, se pueda jugar algo ligero ... pero de manera opcional" — with 60 s or more of flight left (the flight timer's ETA), out of combat and instances, a card under the flight timer offers the games once per flight (Play one, Not now, Don't ask again); after it, a row to play. Off in Options (Integrations). 10 s before landing, on landing and in a fight the game is paused and closed, the keys go back to the character; it resumes where it was.
- S2: "elijan jugar algo entre esas 2 opciones" — two games to choose from: a falling-blocks puzzle and a shooter, in the genres the user named ("como un tetris o space invader"), each AzerothRoute's own (its own name, rules and look: no copy of an existing game's name, art or look).
- S3: "menos Doom que lo odio !!" — no Doom: Polestar's Freedoom Arcade stays out.
- S4: the games open any time with /ar arcade and from the guide window's menu.

## Tasks

- T1 (S1, S3, S4, inline): the game window and host (Games/Host.lua, the contract the games implement) and the flight launcher (Maps/Arcade.lua replaced). Done: adad9b7.
- T2 (S2, delegated: parallel unit): Rune Fall, the falling runestones puzzle (Games/RuneFall.lua). Done (writer, checks pass).
- T3 (S2, delegated: parallel unit): Sky Patrol, the gryphon rider shooter (Games/SkyPatrol.lua, its sprites). Done (writer, checks pass).
- T4 (S1-S4, inline): Spanish texts, changelog, seam check (full suite), install. Done; not yet played in game.

## Log

- L1 (2026-11-22): "quisiera que cuando el vuelo sea largo, mas de 1 minuto quizas, se pueda jugar algo ligero, como un tetris o space invader, pero de manera opcional, cosa de que en vez de esperar mirando el paisaje hasta llegar al destino, elijan jugar algo entre esas 2 opciones, o tu busca un juego que podamos programar para eso, menos Doom que lo odio !!"
- L2: Polestar's Maps/Arcade.lua already offers a game on flights with 60 s or more left (Maps.GetFlight), guards landing and fights; only its game (Freedoom, excluded) is replaced. Writers for T2 and T3: two independent units, disjoint files, several hundred lines each.
