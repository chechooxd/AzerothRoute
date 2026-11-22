# Changelog

AzerothRoute follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH.
The current version lives in the `VERSION` file; every addon folder and the in-game
"What's new" card take it from there when `tools/fork_polestar.lua` generates `addon/`.

To release: bump `VERSION`, add its entry here, regenerate, commit, and tag `vX.Y.Z`.

- PATCH (0.1.x): fixes only.
- MINOR (0.x.0): new features or guides.
- MAJOR: reserved for 1.0.0, the first stable release.

## [Unreleased]

### Added
- Games on long flights: with a minute or more of flight left, a card under the flight timer offers two light
  games of AzerothRoute's own, Rune Fall (a falling runestones puzzle) and Sky Patrol (a gryphon rider shooting
  bats and harpies), once per flight, then a row to play. 10 seconds before landing, on landing and in a fight the
  game is paused and closed; it goes on where it was. Best scores are kept. Esc closes, P pauses; /ar arcade and the
  guide window's menu open them any time; off in Options > Integrations > Flight games. Polestar's Doom stays out.
  The games have sound (the game's own effects: turns, landings, cleared rows, level ups, throws, hits, waves,
  game over and a new best), on the effects volume; the speaker in the window's bar mutes them. The window keeps a wide column (the tabs, sound and close in its
  bar, the score on a line of its own under it, the keys under the game) and Rune Fall has larger stones (22 px).
  A third game, Gem Bazaar: swap neighbouring gems on an 8 x 8 board to line up three or more of a kind; they
  shatter, the gems above fall and every cascade counts more. Four in a line leave a flare gem (it clears its row
  and column), five or more a prism (swapped with a gem, every gem of that kind shatters). Each level has a target
  score and 20 moves; a hint pulses after 7 seconds without a move, and a board with no move is dealt again.
  Mouse (click two gems) or keyboard (arrows or WASD, Space picks, an arrow swaps).
- Three skins for the new look, in Options > Theme and on the welcome looks next to AzerothRoute's own: Classic (the
  game's red buttons, its gold-trimmed dialog border on windows and tooltip border on menus, gold titles, dark
  grounds, square corners), Marble (white marble with beige veins and gold threads, gold edges, an antique gold
  accent and dark ink) and Terminal (a neon code terminal: phosphor green text on black under scanlines, cyan edges
  and HUD brackets on the corners). All keep the top bar and tabs. They ship inside the main folder: no skin folder to install.
- World objects that glow: the object in front of you that the game's interact targeting picks glows gold with a
  quest icon, its name, the quest and your progress when an open quest still needs it (wood, crates, scattered
  parts...), green for a herb and copper for an ore vein. The glow sits on the object's nameplate, or on a small card
  under the middle of the screen. The game only tells addons about that one object, so only the nearest object in
  front of you glows. Options > Questing > Quests > World objects: on or off, quest objects, herbs and ore, and the
  detection range. While on, AzerothRoute sets the game's interact targeting for objects and puts your own settings
  back when you turn it off.

### Changed
- The guide step icons and the map icons are AzerothRoute's own drawings in place of Polestar's; flight is a
  winged boot, the inn a tankard, mail a sealed envelope, a corpse a ghost, a rare a gem, selling a price tag
  and using an item a potion. The map medallion is a rounded square badge, sapphire with a gold rim; the guide's places on the map
  are a compass needle (in a ring for the arrow's target), stops and spots a diamond, and the marker of a point
  on the map and minimap is a ring with a compass needle instead of Polestar's star.

### Removed
- Polestar's looks, skin checks and skin folders (AzerothRoute_Looks, AzerothRoute_SkinAPI, AzerothRoute_Skin_*)
  are no longer shipped: only AzerothRoute's own look is offered. install.sh deletes old copies.

### Fixed
- The guide's level mark ("Guide: 14 (2 levels)") and completed quest XP now show on a classic-style XP bar
  (MainMenuExpBar) and on a UI addon's own XP bar, not only on the game's tracking bars.
- The instance tracker no longer draws the wait over the count ("1/5 esta hora" under "la más antigua expira en
  44:05"): where both do not fit on one line, the wait takes a line of its own under the count.
- "ObjectGlow.lua:103: attempt to index local 'guid' (a secret string value)": in combat the game hides the object's
  id; the world object glow now reads it as no object instead of an error. The gathering routes read a hidden level
  the same way.
- Kill targets wait for the quest: before you take a quest, its mobs are no longer on the target button, its list
  or the step key, and its kill areas and goal pins are no longer drawn on the map and minimap (the arrow already
  led to the quest giver first). Mobs killed then count for nothing.
- The guide menu's favourite star sits in the picture's corner on a dark ground of its own; the ground no longer
  stretches over the empty spot of the old close button, which is in the top bar now.

## [0.6.0] - 2026-11-21

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
- Quest icons on enemy nameplates, on by default: a sword when a quest needs the mob killed, a bag when it
  needs an item the mob drops (the sword when both), in the theme's accent. Off in Options > Quests.
- Lookup previews: a mount as the mount collection shows it, gear tried on your character as the
  appearances collection does, and NPCs and rares as themselves, under the result's title; drag to turn them.
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
