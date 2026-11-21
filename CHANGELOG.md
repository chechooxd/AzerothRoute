# Changelog

AzerothRoute follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH.
The current version lives in the `VERSION` file; every addon folder and the in-game
"What's new" card take it from there when `tools/fork_polestar.lua` generates `addon/`.

To release: bump `VERSION`, add its entry here, regenerate, commit, and tag `vX.Y.Z`.

- PATCH (0.1.x): fixes only.
- MINOR (0.x.0): new features or guides.
- MAJOR: reserved for 1.0.0, the first stable release.

## [0.3.0] - 2026-11-21

### Added
- Import a talent plan in the game: paste an Icy Veins WoW Forever talent calculator link under
  Talents > Import a plan. The plan keeps the link's pick order, gets its own tab and name, works with
  Follow this plan, Apply talents and the talent trees, is saved per character and can be removed.
- Links for another class, with an unknown talent, more points than a talent has ranks or more than
  51 points are refused with the reason; nothing is saved.

### Changed
- Talent tabs are one per plan instead of one per spec.

## [0.2.0] - 2026-11-21

### Changed
- Talent plans now follow Icy Veins' WoW Forever leveling guides: all 27 specs, one point a level
  from 10 to 60, with each spec's guide linked and dated in the plan's Source line.
- The talent tree data matches today's Forever trees: 30 talents with new rank counts or names are
  corrected and 16 new talents (Shieldsworn, Boot Knife, Bloom, Reckless Swings and more) are added,
  so plans, Apply talents and the tree view find them in the game.

### Removed
- Polestar's talent plans and their notes.

## [0.1.0] - 2026-11-20

First release built on Polestar 0.4.1.1 (GPL-3.0-only).

### Added
- Leveling 1 to 60 for every race, class quests, professions, reputations, dungeons and rares.
- Waypoint arrow along real roads, journey list with flights and boats, and the route on the map.
- Talent plans for every spec, an "Apply talents" button, talent icons with tooltips, and the
  class's talent trees drawn from the live game tree.
- AzerothRoute 1 settings migration (auto accept, auto turn-in, target button, marking, minimap button).
- AzerothRoute identity: compass-and-route mark, wordmark, and the "Azeroth" scheme in
  sapphire #13285A, pearl white #ECE6DC and ember orange #FF5A12.

### Removed
- Polestar branding, community links, thanks page, release history and the Arcade mini-game.
