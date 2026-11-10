# Navigation compass

`nav_compass.gd` (`NavCompass`) is the strip at the top of the gameplay HUD. `ui/hud.gd` adds it in `_ready()`.

- **Player marker:** fixed at the centre.
- **Line, ticks and letters:** scroll with the camera's heading. North is -Z and east is +X, the same convention as the sky.
- **Waypoint:** slides along the line by its bearing from the camera, with an amber glow leading back to the centre. It fades out past about ±90°.
- **Visibility:** hidden while a menu, book or the sleep fade is up. There's no background panel.

## Glyphs

The glyphs in `glyphs/` are cut from the approved reference. Each one is an exported texture on the node, so any of them can be swapped without touching the code:

| File | What it is |
|------|------------|
| `player_marker.png` | Triangle in a broken ring |
| `waypoint.png` | Amber diamond and glow |
| `cap_left.png`, `cap_right.png` | Runic end caps |
| `letter_n.png`, `letter_e.png`, `letter_w.png` | Cardinal letters |
| `letter_s.png` | Drawn to match the others, because the reference has no S |

The line and ticks are drawn in code, which lets them scroll. The line's wear is tied to world headings.

## Waypoints

- Call `compass.set_waypoint(node_or_position)` and `compass.clear_waypoint()`.
- Or drop a `NavWaypoint` (`nav_waypoint.gd`, a Marker3D) into a scene. The first active one is tracked when no waypoint was set from code.

## Settings

The size, top margin, degree scale, opacity and colours are exported on `NavCompass`. Layout numbers are in the reference image's pixels; see the top of `nav_compass.gd`.
