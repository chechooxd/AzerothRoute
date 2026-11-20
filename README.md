# AzerothRoute

Leveling guides for World of Warcraft: Forever (Interface 16001).

AzerothRoute 2 is a modified version of [Polestar](https://github.com/fitzforge/polestar)
(Copyright (c) 2026 The Polestar authors, GPL-3.0-only): Polestar's guides, guide engine, walking
routes and interface under AzerothRoute's name, with AzerothRoute's own changes on top.
AzerothRoute 1 (its own engine) is kept at the git tag `v1.0-final`.

## Install

```bash
bash tools/install.sh
```

It copies every folder of `addon/` into `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`
(pass another AddOns path as the first argument), replacing the older copy of each folder. Then quit the
game and start it again: a `/reload` does not load new addon folders. Run AzerothRoute or Polestar, not
both: turn one off in the AddOns list on the character screen.

In game: `/ar` (or `/azerothroute`). AzerothRoute 1's auto-accept, auto-turn-in, target button and
minimap button settings carry over on the first login.

## How the repository is built

`addon/` is generated; do not edit it by hand.

- `tools/fork_polestar.lua <Polestar addons folder>` copies the Polestar folders AzerothRoute ships,
  renames the brand (folders, globals, saved variables, slash commands, bindings, visible text; never
  comments, licence files, URLs or the phrases about Polestar as a project) and applies
  `tools/fork/patches.lua`. Rerunning it on the same Polestar release reproduces `addon/` exactly.
- `tools/fork/patches.lua` lists AzerothRoute's changes: text replacements in Polestar's files and whole
  files of its own (`tools/fork/files/`). A patch that no longer applies fails the run, which is how a
  new Polestar release shows what needs a look.

Left out of `addon/` (see THIRD_PARTY.md): Polestar's Doom arcade, the race guide parts (only
`Legs.lua`, made with Leffe's navigation maps under a permission given to Polestar's author), and the
QuestDB, Codex and Experimental packs, which carry QuestieDB-derived facts (decision D2 in
`odd/tasks/azerothroute-2-polestar-base.md`).

To update to a new Polestar release:

```bash
luajit tools/fork_polestar.lua "<path to the Polestar addons folder>"
luajit Tests/load_check.lua
```

## Checks

```bash
luajit Tests/load_check.lua
```

Compiles every Lua file, checks every file a `.toc` or `.xml` names, loads the main addon in `.toc`
order with a permissive WoW API (`Tests/mock_wow.lua`), runs its start-up events, checks the slash
commands and bindings carry AzerothRoute's names, and checks AzerothRoute 1's settings carry over once.
Drawing, game data and protected actions are only checked in game.

## Plan

`odd/tasks/azerothroute-2-polestar-base.md` lists every user story (setup wizard, guide window,
navigation, Guide Center sections, quests, targeting, gear, themes, options, languages, AzerothRoute's
own additions) and the open decisions.

## License

AzerothRoute is free software under the GNU General Public License, version 3 only (LICENSE).
THIRD_PARTY.md lists Polestar and every other component and data source with its licence.
