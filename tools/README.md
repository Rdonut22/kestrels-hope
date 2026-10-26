# Tools

These scripts generate and test the game's scenes. You don't need them to
play the game; they're here so the ship can be rebuilt and changed later.

- `build_scenes.gd` builds `ship/ship_interior.tscn`, `ship/ship_crashed.tscn`,
  `crash_site.tscn`, `ship/seat.tscn`,
  `character/character.tscn`, `ui/hud.tscn` and the materials, and wires
  them into `main.tscn`. It starts from the original `main.tscn`
  (first commit), so restore that first:

      git show eb09d90:main.tscn > main.tscn
      godot --headless --path . --script tools/build_scenes.gd

- `playtest.gd` walks the player through every doorway, uses the coffee
  machine, computer, log and bed, and prints PASS/FAIL for each check:

      godot --path . --script tools/playtest.gd

- `crash_playtest.gd` does the same for the crash site: wakes up in the
  quarters, walks out through the hull breach into the forest and back:

      godot --path . --script tools/crash_playtest.gd
