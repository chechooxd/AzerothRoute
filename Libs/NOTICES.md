# Upstream Library Provenance & Notices

The libraries in this directory are vendored verbatim from the official `HereBeDragons` `2.18-release` GitHub distribution (`Nevcairiel/HereBeDragons`), without Zygor forks or edits to upstream source files.

## Included Packages

1. **LibStub** (`Libs/LibStub/LibStub.lua`, `Libs/LibStub/LibStub.toc`)
   - **Minor**: `2`
   - **Authors**: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
   - **License**: Public Domain (per `LibStub.lua` header and `LibStub.toc`).

2. **CallbackHandler-1.0** (`Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`, `Libs/CallbackHandler-1.0/CallbackHandler-1.0.xml`)
   - **Minor**: `8` (`$Id: CallbackHandler-1.0.lua 26 2022-12-12 15:09:39Z nevcairiel $`)
   - **Maintainer**: Nevcairiel / Ace3 team
   - **License**: BSD (as published upstream).

3. **HereBeDragons-2.0** (`Libs/HereBeDragons/HereBeDragons-2.0.lua`, `Libs/HereBeDragons/HereBeDragons.toc`, `Libs/HereBeDragons/CHANGELOG.md`)
   - **Release**: `2.18-release` (2026-10-02), minor `35`
   - **Author**: Nevcairiel (`h.leppkes@gmail.com`)
   - **Upstream**: https://github.com/Nevcairiel/HereBeDragons / https://www.wowace.com/addons/herebedragons/
   - **License**: BSD (per `HereBeDragons.toc` `X-License: BSD`; CurseForge's published BSD text retains placeholder copyright fields, preserved verbatim in provenance notes rather than inventing a notice).

4. **HereBeDragons-Pins-2.0** (`Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua`)
   - **Release**: `2.18-release`, minor `17`; byte-identical (ignoring line endings) to `raw.githubusercontent.com/Nevcairiel/HereBeDragons/2.18-release/HereBeDragons-Pins-2.0.lua`. Zygor's bundled copy is a modified fork and was not used.
   - **License**: BSD (same package as HereBeDragons-2.0).

5. **LibDataBroker-1.1** (`Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua`)
   - **Minor**: `4`; byte-identical (ignoring line endings) to `github.com/tekkub/libdatabroker-1-1` `master`.
   - **Author**: tekkub. **License**: Public Domain (as published upstream).

6. **LibDBIcon-1.0** (`Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua`)
   - **Minor**: `52`; copied from the CurseForge-packaged copy bundled with RXPGuides (`@curseforge-project-slug: libdbicon-1-0@` header). Not re-verified against the upstream repository, which could not be fetched.
   - **Author**: funkydude. **License**: not verified here (the file carries no license header); confirm on the upstream project page before redistribution.

7. **Ace3 subset** (`Libs/AceConsole-3.0`, `Libs/AceGUI-3.0`, `Libs/AceConfig-3.0`, `Libs/AceDB-3.0`, `Libs/AceDBOptions-3.0`)
   - **Source**: https://github.com/WoWUIDev/Ace3 at commit `ac3d1225037e0dc74e025a72342c0f7824aae147` (2026-10-28), byte-identical directory copies. Pinned past `Release-r1403` because only master lists Interface 16001 and contains "AceDB-3.0: Compatibility with WoW Forever".
   - **Minors**: AceDB 40, AceDBOptions per file header, AceConfigDialog/Registry/Cmd and AceGUI per file headers.
   - **License**: BSD, Ace3 Development Team (`Libs/Ace3-LICENSE.txt`).

## Integration Scope

`HereBeDragons-2.0` coordinate data APIs are integrated into `Spatial/Coords.lua`. `HereBeDragons-Pins-2.0` places world map and minimap pins in `Spatial/Pointer.lua` (native placement remains as a fallback). `LibDataBroker-1.1` + `LibDBIcon-1.0` provide the minimap launcher in `UI/MinimapButton.lua`. Ace3, targeting, SavedVariables, and party communications remain native to AzerothRoute.
