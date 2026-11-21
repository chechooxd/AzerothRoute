# Changelog

AzerothRoute follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH.
The current version lives in the `VERSION` file; every addon folder and the in-game
"What's new" card take it from there when `tools/fork_polestar.lua` generates `addon/`.

To release: bump `VERSION`, add its entry here, regenerate, commit, and tag `vX.Y.Z`.

- PATCH (0.1.x): fixes only.
- MINOR (0.x.0): new features or guides.
- MAJOR: reserved for 1.0.0, the first stable release.

## [0.6.0] - in progress

### Changed
- A Battle.net style look for the hub and the settings: rounded windows, panels, buttons, tiles, fields and
  menus; flat headers without the night band, haze or gold rim; rounded selection blocks in the side list
  and the icon rail; primary buttons, switches and tab lines in the theme's accent, so the scheme and accent
  the player picks colour all of it; the theme's band and gold rim on the top bar.
- The hub has a big blue "Continue guide" button at the foot of its side column that opens the guide window.
- New layout: the hub's sections are tabs in a bar across the top with the logo, the name, Import, Options
  and the search (icons alone when they do not fit); its side column lists the section's categories from the
  top. The settings have the same top bar with their groups (Guided, Look, Settings, About) as tabs, and the
  side list shows the open group's pages only. Headers are shorter (80px); the hub's search sits above its
  side list and its tabs use short names (Pace, Routes) so they keep their labels. The settings' tools (Install,
  the search, Peek and Fold, the menu scale, close) sit in the top bar, over everything; the header keeps the title.
  Folded, the settings keep their top bar only. The hub's top bar has its search, the menu scale and a close
  button at the right; where not every tab fits, the open one keeps its name and the others show their icon.
  The hub's search is global and always there: typed in a section without its own search it opens Lookup
  (guides, items, mounts, NPCs, quests, places); the Lookup tab left the bar.
- The target button and its list draw common mobs in the accent gold instead of red; elites, rares and
  bosses stay Forever blue, NPCs green, and an item out of range still turns red.
- Only AzerothRoute's own design is offered and drawn: Polestar's other looks (Halo, Hearth, the game looks
  and skin addons) are hidden; a saved choice is kept.

### Added
- Gathering routes page in the menu: for Herbalism and Mining, the three zones with most spots of the
  herbs or ores that still teach your skill (up to 100 points below it, zones up to 5 levels above
  yours), each as one closed loop through every spot (nearest neighbour, then 2-opt). Start holds the
  arrow on the nearest spot and moves on within 25 yards; Skip spot and Stop. Built from Polestar's
  node spawn data, so a spot is where a node can spawn, not a promise one is up.
- Race your best character: every character's level times are kept for the account, and the Leveling
  pace page compares each fully measured level with your fastest other character's (a mark on the bar,
  "4m faster than Jaina") and sums it up ("12m faster over 8 levels"). Partly measured levels never count.
- Milestone card: at levels 20, 30, 40, 50 and 60 a card sums up the last ten levels (time, kills,
  quests, deaths) against your best other character's same ten, and at 60 the whole measured run.
  View pace opens the Leveling pace page. Setting under Options > Quality of Life > Trackers & map.
- Deaths are counted at each level and shown on the Leveling pace page.

### Fixed
- Self-found characters no longer get auction house buys (the guide's card, the town reminder and the
  list): they cannot use the auction house.

### Not possible in Forever
- An in-combat rotation helper: Forever keeps cooldowns, auras, health and power secret from addons
  in combat, and Blizzard's combat assistant is off (checked in game, 2026-11-21).
- Hardcore death alerts with a place and level: Forever's HARDCORE_DEATHS gives only a name.

## [0.5.2] - 2026-11-21

### Fixed
- Resizing the Options window raised "Options.lua:4260: attempt to call a nil value": it still
  called the special-thanks line's placer, which no longer exists.

## [0.5.1] - 2026-11-21

### Changed
- The Azeroth colours are WoW Forever's blue and gold: night blue #0A1A33 grounds, gold #F2C14E
  accent, Forever blue #4DB4FF for quests and the route, warm white #F5EFE0 text; the logo too.

## [0.5.0] - 2026-11-21

### Added
- Leveling pace page in the menu: XP per hour, time to the next level and to level 60 at your pace,
  and every level played with the XP tracker on as a bar of its play time with its kills and quests.
  The time to 60 adds this level's XP left to every later level's at the tracker's rate, or at the
  rate of the levels already played before there is one. Uses Polestar's XP tracker (`/ar xp`); with
  the tracker off the page offers to turn it on.

## [0.4.0] - 2026-11-21

### Added
- Talent point card: after a level-up with a point waiting, a card at the top of the screen names the
  followed plan's next talent, with Apply talents and View plan. It closes on its own after 25 seconds
  (not while the cursor is on it) or once no point waits. Setting under Options > Questing > Talents,
  "Show a card with Apply when a point is waiting" (on by default, with the chat reminder).

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
