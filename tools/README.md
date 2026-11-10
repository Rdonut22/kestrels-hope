# Tools

These scripts generate, check and test the game's scenes. You don't need
them to play the game; they're here so the ship can be rebuilt and changed
safely.

Both shell scripts find Godot 4.7 by themselves: `$GODOT`, else `godot` or
`godot4` on your PATH, else `/Applications/Godot.app` on a Mac. To point at
a specific build: `GODOT=/path/to/Godot tools/check.sh`.

## Before calling any task done: `check.sh`

    tools/check.sh              # everything (takes a while)
    tools/check.sh --quick      # compile every script only (fast)
    tools/check.sh --no-stats   # skip the renderer statistics
    tools/check.sh --only playtest,save_playtest

It:

1. compiles every GDScript file and fails on any parse or script error;
2. runs every playtest below with a real renderer and reads its PASS/FAIL
   lines. A test that crashes, times out or never prints its `FAILS: n`
   summary counts as **failed**, not passed. Any `SCRIPT ERROR` in its log
   also fails it;
3. prints renderer statistics for the ship and the crash site (draw calls,
   triangles, video memory). Information only, never a failure. Under a
   software renderer (`xvfb-run` in the cloud) the frame times mean
   nothing, but the counts are valid;
4. fails if the tests changed any file in the repository.

Your real save game is backed up before the tests (they autosave) and put
back afterwards. The backup (`savegame.json.check-backup`) sits next to the
save, so if a run is killed outright (a crash, a power cut) the next run of
`check.sh` puts your save back before doing anything else.

Exit codes: `0` all required checks passed, `1` a required check failed,
`2` the checks can't run here (no Godot, or no display for the renderer).
Logs go to a temporary folder printed at the start and the end.

## Rebuilding the scenes: `safe_build.sh`

`build_scenes.gd` regenerates `main.tscn`, `crash_site.tscn`,
`ship/ship_interior.tscn`, `ship/ship_crashed.tscn`, `ship/seat.tscn`,
`character/character.tscn`, `ui/hud.tscn` and many materials and meshes.
It must start from the first commit's `main.tscn` (`eb09d90`), it must run
with a renderer (`--headless` saves the forest empty), and any editor
change to those scenes is lost when it runs. So don't run it directly;
use the wrapper:

    tools/safe_build.sh            # build and report (dry run)
    tools/safe_build.sh --apply    # build, report, then apply the outputs
    tools/safe_build.sh --keep     # also keep the temporary build

It:

- refuses to run unless your working tree is clean (commit or stash
  first). It never discards anything;
- builds in a **temporary git worktree** of your current commit, starting
  from `eb09d90:main.tscn` there. Your `main.tscn` and the rest of your
  tree aren't touched while it builds;
- stops if the build log lacks `BUILD DONE`, shows a script error, or the
  forest's MultiMesh data came out empty;
- sorts every changed file into expected generator outputs, ID-only churn
  (Godot renumbering `unique_id`s, ignored) and **unexpected** changes. If
  there are any unexpected ones it stops and applies nothing;
- with `--apply`, backs up the current version of every file it replaces
  to `~/.kestrels-hope/build-backups/<time>-<commit>/` (with a README
  saying how to put each back), then copies the new outputs into your
  tree. It never deletes files and never commits.

After `--apply`: review `git status` and `git diff --stat`, run
`tools/check.sh`, then commit.

Exit codes: `0` ok, `1` build or validation failed, `2` environment
unusable, `3` unexpected changes (nothing applied), `4` working tree not
clean.

## Playtests

Each prints `PASS ...` / `FAIL ...` lines and ends with `FAILS: n`.
`check.sh` runs them all; to run one by hand (with a renderer):

    godot --path . --script tools/playtest.gd

- `playtest.gd`: the ship in space. Walks through every doorway (quarters,
  deck, lounge, kitchen, the cockpit in the nose, bathroom, engineering,
  gunner), uses the ship computer, checks the personal log needs power
  (shows "(no power)" on emergency power, readable once the power is back),
  the bed and the boarding ramp.
- `crash_playtest.gd`: the crash site. Wakes up in the quarters, walks out
  through the hull breach into the forest and back, checks the outdoor
  sound and a few prompts.
- `intro_playtest.gd`: New Game, the intro, ending in the cockpit.
- `pause_playtest.gd`: the pause menu, and Quit to Menu.
- `daynight_playtest.gd`: the day-night cycle, fireflies and butterflies,
  sleeping to morning, the ship computer clock.
- `footstep_playtest.gd`: footstep sounds on the ship floor and on grass.
- `save_playtest.gd`: a save/load round trip in the ship and at the crash
  site (flag, item, day, player position, time of day), through
  GameState's own API. It deletes the save it made.
- `nav_compass_playtest.gd`: the navigation compass at the top of the HUD
  (`ui/nav_compass`): headings, cardinal letters, waypoint bearing and range,
  hiding behind menus. Saves screenshots to its output folder.
- `wrist_ui_playtest.gd`: Gana's wrist computer (Tab, `ui/wrist_ui`): opening on
  the G-07 model, home-screen navigation by keys and mouse, Back/Home,
  reopening the last section, unread markers. Saves screenshots.

## Other tools

- `render_stats.gd`: renderer statistics for a scene (used by `check.sh`):
  `godot --path . --script tools/render_stats.gd -- res://crash_site.tscn`
- `user_data_dir.gd`: prints the folder the save game lives in (used by
  `check.sh`).
- `corridor_shots.gd`, `ship_shots.gd`, `sky_shots.gd`, `cloud_shots.gd`:
  render screenshots from fixed camera positions, for before/after
  comparisons of visual changes.
- `cloud_bench.gd`: cloud rendering benchmark.
- `make_intro.gd`, `make_menu.gd`: build the intro and title scenes.
- `flightdeck_check.gd`: **obsolete**, written for the raised flight deck,
  which no longer exists (the cockpit is now at deck level in the nose).
  Not part of `check.sh`.
- `_godot_env.sh`: shared helpers for the two shell scripts (finding Godot
  and a display, timeouts). Works with the bash 3.2 that ships with macOS.
