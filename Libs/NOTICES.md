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

## Integration Scope

Only `LibStub`, `CallbackHandler-1.0`, and `HereBeDragons-2.0` coordinate data APIs are loaded and integrated into `Spatial/Coords.lua`. Full Ace3, `HereBeDragons-Pins-2.0`, targeting, SavedVariables, and party communications remain native to AzerothRoute.
