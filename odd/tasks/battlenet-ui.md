# Battle.net style UI

Objective: the hub and the settings window look and work like the Battle.net app, not like Polestar. Branch
claude/azerothroute-2; part of the open 0.6.0; tests: `luajit Tests/load_check.lua` (structure only: looks are
checked in game by the user).

## Specs

- S1 "quiero cambiar un poco la ui del panel y config, quiero darle un toke mas battlenet posiciones, botones,
  toda la experiencia para diferenciarnos igual en eso a polestar"
- S2 The approved mockup: a left rail of icons with the logo on top and settings at the foot; horizontal tabs on
  top instead of Polestar's sidebar list; content as cards with rounded corners; one big blue primary button at
  the bottom left ("Continuar guía"); settings with categories on the left, options in cards, blue switches and
  "Restablecer" / "Listo" at the bottom.
- S3 This design is AzerothRoute's only layout (recommended and accepted with "Yes, build it"); colour schemes stay.

## Stages

- T1 S1,S2 look: rounded corners (nine-slice art) on windows, panels, buttons, tabs, tiles, edit boxes and
  dropdowns; flat header (no night band, haze, gold rim or edge light); Battle.net blue primary buttons - inline
- T2 S2 hub layout: bigger icon rail with the logo, sidebar navigation as top tabs, guide list as cards, primary
  "Continue guide" button bottom left - inline
- T3 S2 settings layout: categories on the left, options in cards, blue switches, Reset and Done in the footer - inline - done (rows on rounded panels read as cards; blue switches)
- T4 S3 only the AzerothRoute design offered (other looks hidden), docs, CHANGELOG 0.6.0, install, commit - inline - done

## Log

- L1 (2026-11-21): "mira, quiero cambiar un poco la ui del panel y config, quiero darle un toke mas battlenet
  posiciones, botones, toda la experiencia para diferenciarnos igual en eso a polestar, es que si yo veo el panel
  es como ver polestar a pesar de que diga azerothroute y que tenga un color diferente" / "Yes, build it"
- L2 (2026-11-21): Polestar's skins only recolour and repaint (Theme.Skin kinds, SkinAPI); the shell layout
  (rail, 240px sidebar, header, tab row) is fixed in W.Shell (Theme/Widgets.lua:4219). No rounded art exists;
  Forever's client has SetTextureSliceMargins/SetTextureSliceMode for nine-slice.
- L3 (2026-11-21): built in Theme/Battlenet.lua (wraps house painters, W.Shell, W.ShellNav, W.ShellRail,
  W.Button, Theme.SwitchColors) plus patches (primary colour in W.Button; SkinId and SkinChoices limited to
  "polestar"). Checks: load_check 20-21. Not seen in game: corner art, slice margins and spacing need the
  user's eye.
- L4 (2026-11-21): "respecto a las ui de menu y configuraciones, siguen casi igual que antes solo que los botones y
  algunas cosillas las cambiaste pero en si siguen muy similar a polestar, porfa cambia la distribucion" / "Yes, build
  it" (second mockup). Built: hub rail -> top bar (sections as tabs, search, Import/Options), side list from the top,
  header 80px; settings top bar with groups as tabs, side list = open group's pages, folding off. Checks 22-23.
- L5 (2026-11-21): "me gusta pero siento que perdio tokes del tema general ... no trabajaste bien la UX/UI ... que el
  tema seleccionado impacte todo". Fixed: logo, name and version were hidden by the line clean-up (only white divider
  textures are hidden now); fixed blue removed (primary, switches, tab lines use the theme accent); theme band in both
  top bars and the gold rim back; hub tabs keep labels (short names, search moved above the side list).
