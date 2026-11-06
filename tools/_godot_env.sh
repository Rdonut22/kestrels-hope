# Shared helpers for tools/safe_build.sh and tools/check.sh (sourced, not run).
# Works with the bash 3.2 that ships with macOS: no associative arrays,
# no mapfile, no ${var,,}.

# Finds the Godot binary: $GODOT, then godot / godot4 on PATH, then the
# usual macOS app location. Sets GODOT_BIN, or returns 1.
kh_find_godot() {
	GODOT_BIN=""
	if [ -n "${GODOT:-}" ] && [ -x "${GODOT}" ]; then
		GODOT_BIN="$GODOT"
	elif command -v godot >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot)"
	elif command -v godot4 >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot4)"
	elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
	fi
	[ -n "$GODOT_BIN" ]
}

# How to run Godot with a real renderer (never --headless): directly when a
# display exists (macOS, or $DISPLAY / $WAYLAND_DISPLAY set), else under
# xvfb-run. Sets RENDER_WRAP (possibly empty), or returns 1 when there is
# no way to get a renderer.
kh_find_display() {
	RENDER_WRAP=""
	if [ "$(uname -s)" = "Darwin" ] || [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
		return 0
	fi
	if command -v xvfb-run >/dev/null 2>&1; then
		RENDER_WRAP="xvfb-run"
		return 0
	fi
	return 1
}

# Runs Godot with a renderer: kh_godot_render <timeout_s> <log> <args...>
# Returns Godot's exit code, or 124 on timeout.
kh_godot_render() {
	local limit="$1" log="$2"
	shift 2
	if [ -n "$RENDER_WRAP" ]; then
		kh_with_timeout "$limit" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" "$@" >"$log" 2>&1
	else
		kh_with_timeout "$limit" "$GODOT_BIN" "$@" >"$log" 2>&1
	fi
}

# Runs Godot headless (only for --check-only and small queries, never to
# save scenes or resources): kh_godot_headless <timeout_s> <log> <args...>
kh_godot_headless() {
	local limit="$1" log="$2"
	shift 2
	kh_with_timeout "$limit" "$GODOT_BIN" --headless "$@" >"$log" 2>&1
}

# kh_with_timeout <seconds> <command...>: uses timeout / gtimeout when
# available (macOS has neither by default), else a background watchdog.
kh_with_timeout() {
	local limit="$1"
	shift
	if command -v timeout >/dev/null 2>&1; then
		timeout "$limit" "$@"
		return $?
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout "$limit" "$@"
		return $?
	fi
	"$@" &
	local pid=$!
	( sleep "$limit"; kill -TERM "$pid" 2>/dev/null ) &
	local watchdog=$!
	local rc=0
	wait "$pid" || rc=$?
	if kill -0 "$watchdog" 2>/dev/null; then
		kill "$watchdog" 2>/dev/null
		wait "$watchdog" 2>/dev/null
	else
		rc=124
	fi
	return $rc
}

# Lines in a Godot log that mean a script failed (parse or runtime).
kh_script_errors() {
	grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$1" || true
}

# File size in bytes (portable).
kh_size() {
	wc -c <"$1" | tr -d ' '
}
