# USHIDA Field Terminal, Wrist Unit G-07 (Gana's wrist computer)

A standalone prop, built entirely in code (`wrist_terminal.gd`, class
`WristTerminal`). There's no UI or gameplay yet, and it isn't used by any game
scene.

- `wrist_terminal.tscn`: the prop. Instance it anywhere.
- `wrist_terminal_preview.tscn`: the inspection scene. Open it and press F6.
  - Left drag orbits, right or middle drag pans, the wheel zooms.
  - Keys 1-8 switch between the preset views.
  - A toggles the stand-in arm, P the port cover, K turns the knob,
    L toggles the lamp, B presses the buttons, T starts a turntable.
- `wrist_wear.gdshader`: temporary procedural weathering (chips, edge wear,
  grime). It uses no textures. Replace it per material with real PBR
  textures later.
- `tools/wrist_terminal_shots.gd`: renders every preset to PNG.

Axes (metres): the forearm runs along X (+X towards the hand), the screen
faces +Y, the handle rail is on the -Z edge and the piston, cable and label
are on the +Z edge. It's about 21 cm long on a 4 cm-radius forearm.

Node groups (each is built by its own `_build_*` function):

- **ForearmMount**: Cuff, WristBand, ElbowStrap, CenterStrap, Buckle.
- **Unit/Housing**: Saddle, MainBody, EndBlock, LowerDeck, SideSkirt,
  ControlBody, SideRail.
- **Unit/Screen**: Bezel, plus Display (UVs 0-1, ready for a SubViewport;
  see `get_display()`).
- **Unit/LatchPanel**, **Controls** (Knob, ButtonA, ButtonB, StatusLamp),
  **Vent**, **Brackets** (HandleRail, DRing, StrapBrackets), **Piston**,
  **Ports** (DataPort, PortCover), **Cables**, **Labels**, and **Screws**
  (one MultiMesh).

Exported parameters:

- `arm_radius`
- `wear`
- `knob_angle`
- `button_a_pressed`
- `button_b_pressed`
- `indicator_on`
- `port_cover_open`
- `round_segments`
- `cuff_segments`
