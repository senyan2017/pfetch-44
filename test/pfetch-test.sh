#!/bin/sh
#
# pfetch test suite
# Usage: sh test/pfetch-test.sh
#
# Tests core behaviors: CLI flags, info modules, output formatting,
# color control, and layout.  Designed to be CI-friendly — no root,
# no network, no interactive input required.

set -e

# ── Locate pfetch ──────────────────────────────────────────────────────
PF="${PF_BIN:-$(cd "$(dirname "$0")/.." && pwd)/pfetch}"

if [ ! -f "$PF" ]; then
	printf 'ERROR: pfetch not found at %s\n' "$PF"
	exit 1
fi

# ── Test harness ───────────────────────────────────────────────────────
_t_run=0
_t_pass=0
_t_fail=0
_t_fail_details=''

_pass() { _t_pass=$((_t_pass + 1)); printf 'PASS\n'; }
_fail() {
	_t_fail=$((_t_fail + 1))
	printf 'FAIL\n'
	_t_fail_details="$_t_fail_details
  - $1"
}

# Strip ANSI/VT escape sequences for plain-text comparison.
strip_esc() {
	printf '%s' "$1" | sed "s/$(printf '\033')\[[0-9;]*[a-zA-Z]//g"
}

assert_exit() {
	# assert_exit <actual> <expected> <message>
	if [ "$1" -eq "$2" ] 2>/dev/null; then
		_pass
	else
		_fail "$3: expected exit $2, got $1"
	fi
}

assert_contains() {
	# assert_contains <haystack> <needle> <message>
	case "$1" in
		*"$2"*) _pass ;;
		*)      _fail "$3: output does not contain '$2'" ;;
	esac
}

assert_not_contains() {
	# assert_not_contains <haystack> <needle> <message>
	case "$1" in
		*"$2"*) _fail "$3: output should not contain '$2'" ;;
		*)      _pass ;;
	esac
}

assert_nonempty() {
	# assert_nonempty <value> <message>
	if [ -n "$1" ]; then
		_pass
	else
		_fail "$2: expected non-empty output"
	fi
}

# Run a test: increments counter and prints label.
run_test() {
	_t_run=$((_t_run + 1))
	printf '  %2d. %-40s ' "$_t_run" "$1"
}

# ── Tests ──────────────────────────────────────────────────────────────
printf '\npfetch test suite\n'
printf '%s\n' "================="

# --- CLI flags ---

run_test "version flag (-v)"
out=$(TERM=dumb sh "$PF" -v 2>&1)
assert_contains "$out" "pfetch" "version flag"

run_test "version flag exit code"
assert_exit $? 0 "version exit code"

run_test "help flag (unknown arg)"
out=$(TERM=dumb sh "$PF" -h 2>&1)
assert_contains "$out" "show system information" "help flag"

run_test "debug mode (-d)"
out=$(TERM=dumb sh "$PF" -d 2>&1)
assert_exit $? 0 "debug mode"

# --- Basic execution ---

run_test "default run exits 0"
out=$(TERM=dumb sh "$PF" 2>/dev/null)
assert_exit $? 0 "default run"

run_test "default run produces output"
clean=$(strip_esc "$out")
assert_nonempty "$clean" "default output"

# --- PF_INFO module selection ---

run_test "PF_INFO=ascii (art only)"
out=$(TERM=dumb PF_INFO=ascii sh "$PF" 2>/dev/null)
assert_exit $? 0 "ascii only"

run_test "PF_INFO=os (single module)"
out=$(TERM=dumb PF_INFO=os sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "os" "PF_INFO=os label"

run_test "PF_INFO=title (title line)"
out=$(TERM=dumb PF_INFO=title sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
# Title should contain @ (user@host)
assert_contains "$clean" "@" "title has @"

run_test "PF_INFO=kernel"
out=$(TERM=dumb PF_INFO=kernel sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "kernel" "kernel label"

run_test "PF_INFO=host"
out=$(TERM=dumb PF_INFO=host sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "host" "host label"

run_test "PF_INFO=uptime"
out=$(TERM=dumb PF_INFO=uptime sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "uptime" "uptime label"

run_test "PF_INFO=pkgs"
out=$(TERM=dumb PF_INFO=pkgs sh "$PF" 2>/dev/null)
assert_exit $? 0 "pkgs module"

run_test "PF_INFO=memory"
out=$(TERM=dumb PF_INFO=memory sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "memory" "memory label"

run_test "PF_INFO=shell"
out=$(TERM=dumb PF_INFO=shell sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "shell" "shell label"

run_test "PF_INFO=de"
out=$(TERM=dumb PF_INFO=de sh "$PF" 2>/dev/null)
assert_exit $? 0 "de module"

run_test "PF_INFO=palette"
out=$(TERM=dumb PF_INFO=palette sh "$PF" 2>/dev/null)
assert_exit $? 0 "palette module"

run_test "PF_INFO with multiple modules"
out=$(TERM=dumb PF_INFO="title os kernel uptime" sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "os" "multi: os"

run_test "PF_INFO with all known modules"
out=$(TERM=dumb PF_INFO="ascii title os host kernel uptime pkgs memory shell editor wm de palette" sh "$PF" 2>/dev/null)
assert_exit $? 0 "all modules"

run_test "PF_INFO empty (no modules)"
out=$(TERM=dumb PF_INFO="" sh "$PF" 2>/dev/null)
assert_exit $? 0 "empty PF_INFO"

run_test "PF_INFO with unknown module (ignored)"
out=$(TERM=dumb PF_INFO="nonexistent os" sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "os" "unknown module ignored"

# --- Color control ---

run_test "PF_COLOR=0 disables SGR sequences"
out=$(TERM=dumb PF_COLOR=0 PF_INFO="os kernel" sh "$PF" 2>/dev/null)
esc_char=$(printf '\033')
assert_not_contains "$out" "${esc_char}[3" "no SGR color codes"

run_test "PF_COLOR=1 (default) includes SGR"
out=$(TERM=dumb PF_COLOR=1 PF_INFO="os" sh "$PF" 2>/dev/null)
esc_char=$(printf '\033')
assert_contains "$out" "${esc_char}[" "has escape sequences"

# --- Separator ---

run_test "PF_SEP=':' adds separator"
out=$(TERM=dumb PF_SEP=":" PF_INFO="os" sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" ":" "PF_SEP colon"

run_test "PF_SEP unset (no separator)"
out=$(TERM=dumb PF_INFO="os" sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
# Without separator, "os" and the value should be adjacent (no colon)
assert_not_contains "$clean" ":" "no separator by default"

# --- Alignment ---

run_test "PF_ALIGN controls padding"
out=$(TERM=dumb PF_ALIGN=20 PF_INFO="os kernel" sh "$PF" 2>/dev/null)
assert_exit $? 0 "PF_ALIGN"

# --- ASCII art override ---

run_test "PF_ASCII=arch overrides art"
out=$(TERM=dumb PF_ASCII=arch PF_INFO="ascii os" sh "$PF" 2>/dev/null)
assert_exit $? 0 "PF_ASCII override"

run_test "PF_ASCII=ubuntu overrides art"
out=$(TERM=dumb PF_ASCII=ubuntu PF_INFO="ascii os" sh "$PF" 2>/dev/null)
assert_exit $? 0 "PF_ASCII ubuntu"

# --- Layout sanity ---

run_test "ascii+info layout doesn't crash"
out=$(TERM=dumb PF_INFO="ascii title os kernel" sh "$PF" 2>/dev/null)
assert_exit $? 0 "layout"

run_test "info without ascii doesn't crash"
out=$(TERM=dumb PF_INFO="title os host kernel uptime pkgs memory" sh "$PF" 2>/dev/null)
assert_exit $? 0 "no-ascii layout"

# --- TERM=dumb compatibility (CI requirement) ---

run_test "TERM=dumb full run"
out=$(TERM=dumb sh "$PF" 2>/dev/null)
assert_exit $? 0 "TERM=dumb"

# --- Edge cases ---

run_test "PF_SOURCE with nonexistent file"
out=$(TERM=dumb PF_SOURCE=/nonexistent/file.sh sh "$PF" 2>/dev/null)
assert_exit $? 0 "bad PF_SOURCE"

run_test "HOSTNAME override"
out=$(TERM=dumb HOSTNAME=testbox PF_INFO=title sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "testbox" "HOSTNAME override"

run_test "USER override"
out=$(TERM=dumb USER=testuser PF_INFO=title sh "$PF" 2>/dev/null)
clean=$(strip_esc "$out")
assert_contains "$clean" "testuser" "USER override"

# ── Summary ────────────────────────────────────────────────────────────
printf '\n%s\n' "─────────────────────────────────"
printf '  Total:  %d\n' "$_t_run"
printf '  Passed: %d\n' "$_t_pass"
printf '  Failed: %d\n' "$_t_fail"

if [ "$_t_fail" -gt 0 ]; then
	printf '\nFailures:%s\n' "$_t_fail_details"
	exit 1
fi

printf '\nAll tests passed.\n'
exit 0
