# Discoveries: Missions and Tasks

Discoveries is a section of Gana's wrist terminal. It lists **Missions** (larger main objectives) and **Tasks** (smaller jobs, side quests and survival actions).

## Adding an objective

Each objective is a `.tres` resource in `discoveries/objectives/`, using the script `objective_def.gd` (`ObjectiveDef`). Copy `make_something_to_eat.tres` and change its fields:

| Field | Meaning |
|-------|---------|
| `id` | Stable id. Saves use it, so never rename one. |
| `category` | `"mission"` or `"task"`. Missions are green; tasks are amber. |
| `title`, `summary`, `description` | Text for the list row, its one-line summary, and the detail pane. |
| `required` | Stays tracked until done; the player can't untrack it. |
| `takes_precedence` | A required progression objective. It takes the HUD badge over the player's own choice. |
| `track_on_discovery` | Optional objectives start tracked when they're discovered. |
| `image` | An optional picture for the detail pane. |
| `highlight_vital` | A vitals row to light up while the objective is active, for example `"hunger"`. |
| `waypoint_node`, `waypoint_offset`, `waypoint_scene` | A known destination for the compass, as a node path from the scene root. Leave `waypoint_node` empty when the destination isn't known; no marker is shown then. |

## From gameplay

| Call | Effect |
|------|--------|
| `Game.state().add_objective(id)` | Unlocks the objective, adds it to Discoveries and shows the new-objective notification. Calling it again is harmless. |
| `Game.state().complete_objective(id)` | Finishes the objective and shows the complete notification. Its badge and compass marker go. |
| `Game.state().objective_completed` | A signal (`id`) for whatever comes next to start from. |

Only call `add_objective` where a clue, transmission, conversation or discovery is meant to create an objective. A clue on its own isn't one.

Everything is saved: discovered objectives, tracked or untracked, done, and the HUD focus.

## Cooking hook (not built yet)

When Gana has prepared and eaten his meal, call:

```gdscript
Game.state().complete_objective(Game.state().EAT_TASK)
```

That finishes "Make something to eat" and clears its badge and the hunger highlight. It also unlocks the cockpit door and Meki's repairs: `GameState.opening_locked()` becomes false.

## Locking terminal sections

The wrist terminal is available from the start. To keep a section locked until an objective is done, add it to `TerminalUI.SECTION_UNLOCKS` in `ui/wrist_ui/terminal_ui.gd`, for example `{"map": "some_mission_id"}`. Nothing is locked yet.

## Files

| Path | What it is |
|------|------------|
| `discoveries/objective_def.gd`, `discoveries/objectives.gd` | The definition resource, and the registry that loads every `.tres`. |
| `game_state.gd` | Objective state, tracking rules, HUD focus, save and load. |
| `ui/discoveries/discoveries_panel.gd` | The Discoveries panel: left navigation, centre list, right detail. |
| `ui/discoveries/objective_hud.gd` | The notification, the persistent badge (click it or press J) and the vitals highlight. |
| `ui/discoveries/discoveries_style.gd` | The shared palette, fonts and plate helpers. |
| `ui/discoveries/art/` | Art cut from the approved Discoveries design by `tools/make_discoveries_art.py`, with the placeholder text painted out. The compass markers are SVGs from the first asset pack. |
| `ui/wrist_ui/art/` | The wrist terminal home screen's art, cut from its approved design by `tools/make_terminal_art.py`. |
| `ui/fonts/barlow-condensed-*.woff2` | Barlow Condensed (OFL; the licence is next to it), the designs' lettering. |
| `ui/nav_compass/nav_compass.gd` | Draws markers for tracked objectives that have a destination. |
| `tools/discoveries_playtest.gd` | The automated test. |
