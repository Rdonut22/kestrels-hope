#!/usr/bin/env bash
# Validation suite for Kestrel's Hope. Run before calling any task done.
#
#   1. Compiles every GDScript file (--check-only) and fails on any parse or
#      script error.
#   2. Runs every automated playtest with a real renderer and reads its
#      PASS/FAIL lines and "FAILS: n" summary. A test that crashes, times out
#      or never prints its summary counts as failed, never as passed. Any
#      SCRIPT ERROR in a test's log also fails it.
#   3. Prints renderer statistics (draw calls, triangles, video memory) for
#      the ship and the crash site: information, not pass/fail.
#   4. Checks the tests left the repository's files as they found them.
#
# Your real save game (user://savegame.json) is backed up before the tests
# (which autosave) and put back afterwards, even if the run is interrupted.
#
# Usage:
#   tools/check.sh              # everything
#   tools/check.sh --quick      # compile check only
#   tools/check.sh --no-stats   # skip the renderer statistics
#   tools/check.sh --only playtest,save_playtest   # just these tests
# Environment: GODOT=/path/to/godot, KH_TEST_TIMEOUT=1500 (seconds per test)
# Exit codes: 0 all required checks passed; 1 a required check failed;
#             2 the environment can't run the checks (no Godot / no display).

set -uo pipefail

QUICK=0
STATS=1
ONLY=""
while [ $# -gt 0 ]; do
	case "$1" in
		--quick) QUICK=1 ;;
		--no-stats) STATS=0 ;;
		--only) shift; ONLY="${1:-}" ;;
		-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1 (see --help)"; exit 2 ;;
	esac
	shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repository."; exit 2; }
cd "$ROOT"
# shellcheck source=tools/_godot_env.sh
. "$ROOT/tools/_godot_env.sh"

TEST_TIMEOUT="${KH_TEST_TIMEOUT:-1500}"
# Required playtests, in order. Each prints PASS/FAIL lines and "FAILS: n".
TESTS="playtest crash_playtest intro_playtest pause_playtest daynight_playtest footstep_playtest save_playtest"

LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kh-check.XXXXXX")"
SUMMARY=""
FAILED=0
UNAVAILABLE=0
note() { SUMMARY="$SUMMARY
$1"; }
say() { printf '%s\n' "$*"; }

kh_find_godot || { say "UNAVAILABLE: Godot not found (set GODOT=/path/to/Godot 4.7)"; exit 2; }
say "Godot: $GODOT_BIN"
say "Logs:  $LOG_DIR"
STATUS_BEFORE="$(git status --porcelain --untracked-files=all)"

# ---------- 1. compile every script ----------

say "== 1. Compiling GDScript"
COMPILED=0
BAD=0
while IFS= read -r f; do
	COMPILED=$((COMPILED + 1))
	log="$LOG_DIR/compile_$(echo "$f" | tr '/' '_').log"
	kh_godot_headless 120 "$log" --path . --check-only --script "$f" || true
	errs="$(kh_script_errors "$log")"
	if [ -n "$errs" ]; then
		BAD=$((BAD + 1))
		say "  FAIL $f"
		printf '%s\n' "$errs" | head -4 | sed 's/^/       /'
	fi
done <<EOF
$(git ls-files '*.gd'; git ls-files --others --exclude-standard '*.gd')
EOF
if [ "$BAD" = "0" ]; then
	note "PASS    compile: $COMPILED scripts, no errors"
else
	note "FAIL    compile: $BAD of $COMPILED scripts have errors"
	FAILED=1
fi

if [ "$QUICK" = "1" ]; then
	say "== Summary$SUMMARY"
	exit $FAILED
fi

if ! kh_find_display; then
	note "UNAVAIL playtests and stats: no display and no xvfb-run (they need a renderer)"
	say "== Summary$SUMMARY"
	[ "$FAILED" = "1" ] && exit 1
	exit 2
fi
say "Display: ${RENDER_WRAP:-native}"

# ---------- back up the real save ----------

kh_godot_headless 60 "$LOG_DIR/userdir.log" --path . --script tools/user_data_dir.gd || true
USER_DIR="$(sed -n 's/^USER_DATA_DIR=//p' "$LOG_DIR/userdir.log" | head -1)"
SAVE_BACKUP=""
restore_save() {
	[ -z "$USER_DIR" ] && return 0
	if [ -n "$SAVE_BACKUP" ] && [ -f "$SAVE_BACKUP" ]; then
		cp -p "$SAVE_BACKUP" "$USER_DIR/savegame.json"
	elif [ -z "$SAVE_BACKUP" ]; then
		# There was no save before the tests: remove any the tests made.
		rm -f "$USER_DIR/savegame.json"
	fi
}
if [ -n "$USER_DIR" ] && [ -f "$USER_DIR/savegame.json" ]; then
	SAVE_BACKUP="$LOG_DIR/savegame.json.backup"
	cp -p "$USER_DIR/savegame.json" "$SAVE_BACKUP"
	say "Real save backed up: $SAVE_BACKUP"
fi
trap restore_save EXIT INT TERM

# ---------- 2. playtests ----------

say "== 2. Playtests (renderer: ${RENDER_WRAP:-native}; can take a while)"
for t in $TESTS; do
	if [ -n "$ONLY" ] && ! printf ',%s,' "$ONLY" | grep -q ",$t,"; then
		continue
	fi
	script="tools/$t.gd"
	if [ ! -f "$script" ]; then
		note "FAIL    $t: test script missing ($script)"
		FAILED=1
		continue
	fi
	log="$LOG_DIR/$t.log"
	say "  running $t..."
	start=$(date +%s)
	rc=0
	kh_godot_render "$TEST_TIMEOUT" "$log" --path . --script "$script" || rc=$?
	secs=$(( $(date +%s) - start ))
	passes="$(grep -c '^PASS ' "$log" || true)"
	fails_listed="$(grep '^FAIL ' "$log" || true)"
	summary_line="$(grep -E '^FAILS: [0-9]+' "$log" | tail -1 || true)"
	errs="$(kh_script_errors "$log")"
	if [ "$rc" = "124" ]; then
		note "FAIL    $t: timed out after ${TEST_TIMEOUT}s ($passes checks passed before that)"
		FAILED=1
	elif [ -z "$summary_line" ]; then
		note "FAIL    $t: did not finish (no FAILS summary; exit code $rc) - see $log"
		FAILED=1
	elif [ -n "$errs" ]; then
		note "FAIL    $t: script errors during the run - see $log"
		FAILED=1
	elif [ "${summary_line#FAILS: }" != "0" ]; then
		note "FAIL    $t: ${summary_line#FAILS: } failed, $passes passed (${secs}s)"
		printf '%s\n' "$fails_listed" | sed 's/^/          /' >>"$LOG_DIR/failures.txt"
		SUMMARY="$SUMMARY
$(printf '%s\n' "$fails_listed" | sed 's/^/          /')"
		FAILED=1
	else
		note "PASS    $t: $passes checks (${secs}s)"
	fi
	if [ -n "$errs" ]; then
		printf '%s\n' "$errs" | sort | uniq -c | head -5 | sed 's/^/          /'
	fi
done

# ---------- 3. renderer statistics ----------

if [ "$STATS" = "1" ] && [ -z "$ONLY" ]; then
	say "== 3. Renderer statistics (information only)"
	for sc in res://main.tscn res://crash_site.tscn; do
		log="$LOG_DIR/stats_$(basename "$sc" .tscn).log"
		rc=0
		kh_godot_render 1200 "$log" --path . --script tools/render_stats.gd -- "$sc" || rc=$?
		if grep -q '^STAT ' "$log"; then
			grep '^STAT ' "$log" | sed 's/^STAT /  /'
		else
			say "  stats unavailable for $sc (exit code $rc) - see $log"
			note "SKIP    render stats for $sc: unavailable"
		fi
	done
	[ -n "$RENDER_WRAP" ] && say "  (software renderer: frame_ms is not representative of a real GPU)"
fi

# ---------- 4. the repository is untouched ----------

restore_save
trap - EXIT INT TERM
STATUS_AFTER="$(git status --porcelain --untracked-files=all)"
if [ "$STATUS_BEFORE" != "$STATUS_AFTER" ]; then
	note "FAIL    the checks changed files in the repository:"
	SUMMARY="$SUMMARY
$(diff <(printf '%s\n' "$STATUS_BEFORE") <(printf '%s\n' "$STATUS_AFTER") | sed -n 's/^> /          /p')"
	FAILED=1
else
	note "PASS    repository files unchanged by the checks"
fi

say "== Summary$SUMMARY"
say "Logs: $LOG_DIR"
if [ "$FAILED" = "1" ]; then
	say "RESULT: FAILED"
	exit 1
fi
say "RESULT: PASSED"
exit 0
