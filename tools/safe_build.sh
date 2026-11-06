#!/usr/bin/env bash
# Safe wrapper around the scene generator (tools/build_scenes.gd).
#
# The generator rewrites main.tscn, crash_site.tscn, the ship scenes, the
# HUD, the character and many materials/meshes, and it must start from the
# first commit's main.tscn (eb09d90). Run directly in your working tree, a
# failure halfway leaves a half-generated project, and editor edits to the
# generated scenes are silently overwritten. So this wrapper never builds in
# your working tree:
#
#   1. checks the project files, Godot, a display (never --headless) and a
#      clean working tree;
#   2. builds in a temporary git worktree of HEAD (with a copy of the import
#      cache), starting from eb09d90:main.tscn there, not in your tree;
#   3. checks the build log (BUILD DONE, no script errors) and the output
#      (forest MultiMesh data present, crash_site.tscn a sane size);
#   4. sorts every changed file into: expected generator output, ID-only
#      churn (unique_id renumbering, reverted in the temporary worktree
#      only), or unexpected (stops; nothing is applied);
#   5. reports it all. Only with --apply does it copy the expected outputs
#      into your working tree, after backing up the current versions
#      outside the repository. It never deletes files, never runs
#      git reset/clean/restore on your tree, and never commits.
#
# Usage:
#   tools/safe_build.sh            # build and report (dry run, default)
#   tools/safe_build.sh --apply    # build, report, then apply the outputs
#   tools/safe_build.sh --keep     # keep the temporary worktree afterwards
# Environment:
#   GODOT=/path/to/godot                 Godot 4.7 binary (else found on PATH
#                                        or in /Applications/Godot.app)
#   KH_BACKUP_DIR=~/.kestrels-hope/build-backups   where --apply backs up
#   KH_BUILD_TIMEOUT=1800                seconds allowed for the build
# Exit codes: 0 ok; 1 build or validation failed; 2 environment unusable;
#             3 unexpected changes (nothing applied); 4 working tree not clean.

set -euo pipefail

APPLY=0
KEEP=0
for arg in "$@"; do
	case "$arg" in
		--apply) APPLY=1 ;;
		--keep) KEEP=1 ;;
		-h|--help) sed -n '2,36p' "$0"; exit 0 ;;
		*) echo "Unknown option: $arg (see --help)"; exit 2 ;;
	esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repository."; exit 2; }
cd "$ROOT"
# shellcheck source=tools/_godot_env.sh
. "$ROOT/tools/_godot_env.sh"

BASE_MAIN_COMMIT="eb09d90"
BUILD_TIMEOUT="${KH_BUILD_TIMEOUT:-1800}"
BACKUP_ROOT="${KH_BACKUP_DIR:-$HOME/.kestrels-hope/build-backups}"

say() { printf '%s\n' "$*"; }
fail() { say "FAILED: $1"; exit "${2:-1}"; }

# ---------- 1. preconditions ----------

say "== Safe build: preconditions"
for f in project.godot tools/build_scenes.gd main.tscn crash_site.tscn ship/ship_interior.tscn ship/ship_crashed.tscn; do
	[ -f "$f" ] || fail "required file missing: $f" 2
done
git cat-file -e "${BASE_MAIN_COMMIT}:main.tscn" 2>/dev/null \
	|| fail "base main.tscn (${BASE_MAIN_COMMIT}:main.tscn) not in git history" 2
kh_find_godot || fail "Godot not found: set GODOT=/path/to/Godot (4.7)" 2
kh_find_display || fail "no display and no xvfb-run: the generator needs a real renderer (--headless saves the forest empty)" 2
say "Godot:   $GODOT_BIN"
say "Display: ${RENDER_WRAP:-native}"

DIRTY="$(git status --porcelain)"
if [ -n "$DIRTY" ]; then
	say "Your working tree has uncommitted changes; nothing was built:"
	say "$DIRTY"
	say "Commit or stash them first (this script never discards them)."
	exit 4
fi
HEAD_SHA="$(git rev-parse HEAD)"
say "HEAD:    $HEAD_SHA ($(git rev-parse --abbrev-ref HEAD))"

# ---------- 2. build in a temporary worktree ----------

TMP_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/kh-safe-build.XXXXXX")"
WT="$TMP_PARENT/worktree"
LOG_DIR="$TMP_PARENT/logs"
mkdir -p "$LOG_DIR"
SUCCESS=0
cleanup() {
	if [ "$SUCCESS" = "1" ] && [ "$KEEP" = "0" ]; then
		git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
		rm -rf "$TMP_PARENT"
	else
		say "Temporary build kept for inspection: $WT (logs: $LOG_DIR)"
		say "Remove it later with: git worktree remove --force \"$WT\""
	fi
}
trap cleanup EXIT

say "== Building in a temporary worktree: $WT"
git worktree add --detach --quiet "$WT" "$HEAD_SHA"
if [ -d "$ROOT/.godot" ]; then
	# The import cache, so Godot doesn't re-import every asset.
	cp -R "$ROOT/.godot" "$WT/.godot"
fi
# The generator starts from the first commit's main.tscn. Only the
# temporary worktree's copy is replaced; your main.tscn is untouched.
git show "${BASE_MAIN_COMMIT}:main.tscn" >"$WT/main.tscn"
say "Base main.tscn restored from ${BASE_MAIN_COMMIT} (in the temporary worktree only)."

say "Importing assets..."
rc=0
kh_godot_render 900 "$LOG_DIR/import.log" --path "$WT" --import || rc=$?
[ "$rc" = "124" ] && fail "asset import timed out (log: $LOG_DIR/import.log)"
# Re-assert the base main.tscn (an import pass must not have touched it).
git show "${BASE_MAIN_COMMIT}:main.tscn" >"$WT/main.tscn"

say "Running tools/build_scenes.gd (this takes a few minutes)..."
rc=0
kh_godot_render "$BUILD_TIMEOUT" "$LOG_DIR/build.log" --path "$WT" --script tools/build_scenes.gd || rc=$?

# ---------- 3. validate the build ----------

say "== Validating the build"
[ "$rc" = "124" ] && fail "build timed out after ${BUILD_TIMEOUT}s (log: $LOG_DIR/build.log)"
[ "$rc" = "0" ] || fail "Godot exited with code $rc (log: $LOG_DIR/build.log)"
grep -q "BUILD DONE" "$LOG_DIR/build.log" || fail "build did not finish: no BUILD DONE (log: $LOG_DIR/build.log)"
ERRS="$(kh_script_errors "$LOG_DIR/build.log")"
if [ -n "$ERRS" ]; then
	say "$ERRS" | head -20
	fail "script errors during the build (log: $LOG_DIR/build.log)"
fi
CS="$WT/crash_site.tscn"
CS_SIZE="$(kh_size "$CS")"
[ "$CS_SIZE" -gt 5000000 ] || fail "crash_site.tscn is only $CS_SIZE bytes: the world did not build"
BUFFERS="$(grep -c '^buffer = PackedFloat32Array(' "$CS" || true)"
EMPTY="$(grep -c '^buffer = PackedFloat32Array()$' "$CS" || true)"
[ "$BUFFERS" -ge 20 ] || fail "only $BUFFERS MultiMesh buffers in crash_site.tscn (expected ~23)"
[ "$EMPTY" = "0" ] || fail "$EMPTY empty MultiMesh buffers in crash_site.tscn: the forest saved empty (was it run headless?)"
say "Build log clean; crash_site.tscn $CS_SIZE bytes; $BUFFERS MultiMesh buffers, none empty."

# ---------- 4. classify the changes ----------

is_expected_output() {
	case "$1" in
		main.tscn|crash_site.tscn|ship/ship_interior.tscn|ship/ship_crashed.tscn|ship/seat.tscn) return 0 ;;
		character/character.tscn|ui/hud.tscn|ui/terminal_theme.tres) return 0 ;;
		ship/materials/*.tres|character/materials/*.tres|world/materials/*.tres) return 0 ;;
		ship/meshes/*.res|world/models/*.res|world/models/*.tres|world/redwoods/*.res) return 0 ;;
		world/redwood_spray.res|world/grass_density.res|world/grass_density_east.res) return 0 ;;
		*.uid|*.import) return 1 ;;
	esac
	return 1
}

# Same file once the unique_id=... attributes are ignored?
id_only_change() {
	local f="$1"
	[ "${f##*.}" = "tscn" ] || return 1
	cmp -s <(git -C "$WT" show "HEAD:$f" | sed -E 's/ unique_id=[0-9]+//g') \
		<(sed -E 's/ unique_id=[0-9]+//g' "$WT/$f")
}

EXPECTED=""
CHURN=""
UNEXPECTED=""
while IFS= read -r line; do
	[ -z "$line" ] && continue
	status="${line:0:2}"
	path="${line:3}"
	case "$status" in
		" D"|"D "|"DD") UNEXPECTED="$UNEXPECTED
  deleted: $path"; continue ;;
	esac
	if [ "$status" = "??" ]; then
		if [ -d "$WT/$path" ]; then
			UNEXPECTED="$UNEXPECTED
  new directory: $path"
		elif is_expected_output "$path"; then
			EXPECTED="$EXPECTED
$path"
		else
			UNEXPECTED="$UNEXPECTED
  new file: $path"
		fi
		continue
	fi
	if id_only_change "$path"; then
		git -C "$WT" checkout --quiet -- "$path"
		CHURN="$CHURN
  $path"
	elif is_expected_output "$path"; then
		EXPECTED="$EXPECTED
$path"
	else
		UNEXPECTED="$UNEXPECTED
  modified: $path"
	fi
done <<EOF
$(git -C "$WT" status --porcelain --untracked-files=all)
EOF

say "== Changes produced by the generator"
if [ -n "$EXPECTED" ]; then
	say "Generator outputs that changed:"
	printf '%s\n' "$EXPECTED" | sed '/^$/d' | while IFS= read -r p; do
		say "  $p ($(git -C "$WT" diff --shortstat -- "$p" 2>/dev/null | sed 's/^ *//' || true))"
	done
else
	say "No generator outputs changed (the committed scenes match a fresh build)."
fi
[ -n "$CHURN" ] && say "ID-only churn, ignored (unique_id renumbering only):$CHURN"
if [ -n "$UNEXPECTED" ]; then
	say "UNEXPECTED changes (not generator outputs) - nothing will be applied:$UNEXPECTED"
	exit 3
fi

# ---------- 5. apply (optional) ----------

if [ "$APPLY" = "0" ]; then
	SUCCESS=1
	say "== Dry run: your working tree was not touched."
	[ -n "$EXPECTED" ] && say "Re-run with --apply to copy these outputs into your working tree."
	exit 0
fi
if [ -z "$EXPECTED" ]; then
	SUCCESS=1
	say "== Nothing to apply."
	exit 0
fi
# Your tree must still be exactly as it was when the build started.
[ -z "$(git status --porcelain)" ] || fail "your working tree changed during the build; nothing applied" 4
[ "$(git rev-parse HEAD)" = "$HEAD_SHA" ] || fail "HEAD moved during the build; nothing applied" 4

STAMP="$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
BACKUP="$BACKUP_ROOT/$STAMP"
mkdir -p "$BACKUP"
{
	echo "Backup made by tools/safe_build.sh --apply"
	echo "Repository: $ROOT"
	echo "HEAD at the time: $HEAD_SHA"
	echo "These are the versions of each file before the build was applied."
	echo "To put one back:  cp -p \"$BACKUP/<path>\" \"$ROOT/<path>\""
	echo "Or from git:      git checkout $HEAD_SHA -- <path>"
} >"$BACKUP/README.txt"
say "== Applying (backups of the current versions: $BACKUP)"
printf '%s\n' "$EXPECTED" | sed '/^$/d' | while IFS= read -r p; do
	if [ -f "$ROOT/$p" ]; then
		mkdir -p "$BACKUP/$(dirname "$p")"
		cp -p "$ROOT/$p" "$BACKUP/$p"
	fi
	mkdir -p "$ROOT/$(dirname "$p")"
	cp -p "$WT/$p" "$ROOT/$p"
	say "  applied: $p"
done
SUCCESS=1
say "== Applied. Review with 'git status' / 'git diff --stat', then run tools/check.sh."
say "Nothing was committed."
