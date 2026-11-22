# Own icons and unused folders

Objective: drop the addon folders AzerothRoute no longer uses and replace Polestar's guide and map icons with AzerothRoute's own drawings.
Branch: claude/azerothroute-2. Delivery: commits merged into master, inside the open version. Checks: `luajit Tests/load_check.lua`.

## Specs

- S1: "puedes eliminar las carpetas o archivos que no se usan por ahora" — the skin folders (AzerothRoute_Skin_*, AzerothRoute_SkinAPI, AzerothRoute_Looks) are no longer generated or shipped, since only AzerothRoute's own look is offered; nothing asks for them as missing companions; the installer removes old copies from the game.
- S2: "cambiar iconos para que sean mas representativos de mi addon y no de polestar, si bien hacer unos similares mas no usar los mismos" — the guide step icons (Media/UI/icon-*.tga) and map icons (Media/Map/icon-*.tga) are redrawn by AzerothRoute's own generator: same meaning, new drawings.
- S3: "el de vuelo sobretodo, que polestar lo toma como un ave yo lo quiero mas como la bota con alas de wow" — flight icons (fly, getfp, flightmaster) are a winged boot.

## Tasks

- T1 (S1, inline): exclude the skin folders, drop them from companion checks, installer cleanup.
- T2 (S2, S3, inline): tools/fork/make_icons.lua draws the step and map icons into tools/fork/assets.

## Log

- L1 (2026-11-22): "puedes eliminar las carpetas o archivos que no se usan por ahora, tambien cambiar iconos para que sean mas representativos de mi addon y no de polestar, si bien hacer unos similares mas no usar los mismos"
- L2 (2026-11-22): "el de vuelo sibretodo, que polestar lo toma como un ave yo lo quiero mas como la bota con alas de wow"
