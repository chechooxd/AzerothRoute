# Two skins for the new UI

Objective: two skins of AzerothRoute's own over the Battle.net layout (top bar, short header): Classic (the game's own buttons and frames) and Marble (white marble and gold).
Branch: claude/azerothroute-2. Delivery: work-unit commits merged into master, in the open (unreleased) version. Checks: `luajit Tests/load_check.lua`.

## Specs

- S1: "elimina las carpetas de skin que ya no usamos" — no skin folders ship or stay installed (Polestar_Looks, Polestar_SkinAPI, Polestar_Skin_* are already out of the fork and removed by tools/install.sh since 6daa1bf). The Skin API's checks the new skins need move into the core addon (AzerothRoute/Theme/SkinCheck.lua), not a folder of their own.
- S2: "crea 2 nuevas skin para esta nueva ui que trabajamos" — both skins keep the new UI's layout (top bar, tabs, short header) and are offered in the Theme page and the welcome looks next to AzerothRoute's own look; the player's choice is drawn.
- S3: "1 que sea la classic botones y diseños de wow" — Classic: the game's red panel buttons, its dialog and tooltip borders, gold titles, dark grounds, square corners, the game font.
- S4: "la otra marmoleado, tipo civilization VII" — Marble: white-and-grey veined marble grounds, gold trim lines, dark ink text, square corners. Its own art (generated texture), no art or logo taken from that game.

## Tasks

- T1 (S1, S2, inline): SkinCheck into the core, own skins drawn and listed, square corners for skins that ask. Done.
- T2 (S3, inline): Classic skin (Theme/SkinClassic.lua). Done.
- T3 (S4, inline): Marble skin (Theme/SkinMarble.lua, Media/UI/marble.tga from tools/fork/make_skin_art.lua). Done.
- T4 (S1-S4, inline): Spanish names, changelog, checks, install. Done; checks pass (section 30), not yet seen in game.

## Log

- L1 (2026-11-22): "elimina las carpetas de skin que ya no usamos, y crea 2 nuevas skin para esta nueva ui que trabajamos, 1 que sea la classic botones y diseños de wow, y la otra marmoleado, tipo civilization VII" (with a picture of the game's marble-and-gold title art).
- L2: the skin folders are already gone from the fork and the game's AddOns (checked 2026-11-22). Theme.RegisterSkin needs the checks Polestar kept in Polestar_SkinAPI; Theme.SkinId and Theme.SkinChoices are patched to AzerothRoute's look only. Plan: move SkinCheck.lua into the core, let skins with addon "AzerothRoute" through, register both skins from the core.
- L3: the presets name ui.* settings that UI/UI.lua defines after Theme/ loads, so both skins register at login (ns.OnLogin). Classic id "classicwow" (Polestar's built-in "classic" id is taken). Checks: luajit Tests/load_check.lua OK, "skins: checked".
