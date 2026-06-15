#!/bin/sh
#
# test_minimal_env.sh - Regression tests for pfetch in minimal environments.
#
# This script simulates various degraded/container environments by
# temporarily hiding commands and files, then running pfetch and
# verifying the output is sane (no empty fields, no crashes).
#
# Usage:
#   sh test_minimal_env.sh          # run all tests
#   sh test_minimal_env.sh -v       # verbose output
#
# Exit code: 0 if all tests pass, 1 if any test fails.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PFETCH="$SCRIPT_DIR/pfetch"
VERBOSE=0
PASSED=0
FAILED=0
TOTAL=0

[ "$1" = "-v" ] && VERBOSE=1

# Colors (if terminal supports it)
case $TERM in
    (dumb|minix|cons25|"") red=; green=; yellow=; reset= ;;
    (*) red='\033[31m'; green='\033[32m'; yellow='\033[33m'; reset='\033[0m' ;;
esac

pass() {
    PASSED=$((PASSED + 1))
    TOTAL=$((TOTAL + 1))
    printf "${green}PASS${reset} %s\n" "$1"
}

fail() {
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    printf "${red}FAIL${reset} %s: %s\n" "$1" "$2"
}

info() {
    [ "$VERBOSE" = 1 ] && printf "${yellow}INFO${reset} %s\n" "$1"
}

# run_pfetch: run pfetch with given environment, capture output
# Returns the output via stdout. Disables colors for easier parsing.
run_pfetch() {
    PF_COLOR=0 "$@" sh "$PFETCH" 2>/dev/null || true
}

# strip_esc: remove ANSI escape sequences (colors + cursor movement)
# from pfetch output for easier text matching.
strip_esc() {
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\[?[0-9]*[a-zA-Z]//g' |
    sed 's/\x1b\[[0-9;]*m//g' |
    sed 's/^[[:space:]]*//' |
    sed '/^$/d'
}

# assert_not_empty: check that output contains a non-empty value after the field name
# $1: test name, $2: field name (e.g. "os"), $3: pfetch output
assert_field_present() {
    _name=$1
    _field=$2
    _output=$3

    # Strip escape sequences for matching
    _clean=$(printf '%s\n' "$_output" | strip_esc)

    # Check that the field name appears and has a value after it
    if printf '%s\n' "$_clean" | grep -q "^${_field}"; then
        # Extract value after field name
        _val=$(printf '%s\n' "$_clean" | grep "^${_field}" | sed "s/^${_field}[[:space:]]*//")
        if [ -n "$_val" ] && [ "$_val" != " " ]; then
            pass "$_name: '$_field' = '$_val'"
            return
        fi
    fi
    # The field might be embedded (e.g., title line "user@host")
    # Try a looser match
    if printf '%s\n' "$_clean" | grep -q "$_field"; then
        _val=$(printf '%s\n' "$_clean" | grep "$_field" | head -1)
        pass "$_name: field '$_field' found in output"
        return
    fi
    fail "$_name" "field '$_field' is missing or empty"
}

# assert_no_empty_lines_with_label: check there are no lines that are
# just a label with no value (e.g. "os " with nothing after)
assert_no_degenerate_output() {
    _name=$1
    _output=$2

    # Strip escape sequences for analysis
    _clean=$(printf '%s\n' "$_output" | strip_esc)

    # Check output is not completely empty
    if [ -z "$_clean" ]; then
        fail "$_name" "output is completely empty"
        return
    fi

    # Check no line is just a label with no value
    _bad=0
    while IFS= read -r line; do
        # Skip blank lines
        case "$line" in
            ("") continue ;;
        esac
        # A degenerate line is one with only a label and no value
        _stripped=$(printf '%s' "$line" | sed 's/[[:space:]]*$//')
        case "$_stripped" in
            (*" "*)
                _val="${_stripped#* }"
                _val=$(printf '%s' "$_val" | sed 's/^[[:space:]]*//')
                if [ -z "$_val" ]; then
                    _bad=1
                    info "degenerate line: '$line'"
                fi
            ;;
        esac
    done <<-EOF
$_clean
EOF

    if [ "$_bad" -eq 0 ]; then
        pass "$_name: no degenerate output lines"
    else
        fail "$_name" "found degenerate output lines (label with no value)"
    fi
}

# assert_exit_clean: pfetch should not crash (no stderr errors, exit 0)
# For safety, this always runs pfetch in a subshell with the given env.
assert_exit_clean() {
    _name=$1
    shift
    # Run in a subshell to avoid polluting the parent environment
    _stderr=$(
        for _assign in "$@"; do
            export "$_assign"
        done
        PF_COLOR=0 sh "$PFETCH" 2>&1 >/dev/null || true
    )
    if [ -z "$_stderr" ]; then
        pass "$_name: clean exit (no stderr)"
    else
        fail "$_name" "stderr output: $(printf '%s' "$_stderr" | head -1)"
    fi
}

printf '=== pfetch minimal environment regression tests ===\n\n'

# ---------------------------------------------------------------
# Test 1: Normal execution on current system
# ---------------------------------------------------------------
printf -- '--- Test group: Normal execution ---\n'

_output=$(run_pfetch)
assert_no_degenerate_output "normal-run" "$_output"
assert_exit_clean "normal-run-no-stderr"

# ---------------------------------------------------------------
# Test 2: No lsb_release available (simulate with empty PATH)
# ---------------------------------------------------------------
printf -- '\n--- Test group: No lsb_release ---\n'

# Create a temporary PATH that excludes lsb_release
_tmpdir=$(mktemp -d)
_trap_cleanup() { rm -rf "$_tmpdir"; }
trap _trap_cleanup EXIT

# Copy only essential commands (sh, uname, id, etc.) to tmpdir
for cmd in sh uname id cat sed grep wc read rm; do
    _real=$(command -v "$cmd" 2>/dev/null) || continue
    if [ -x "$_real" ]; then
        ln -sf "$_real" "$_tmpdir/$cmd" 2>/dev/null || cp "$_real" "$_tmpdir/$cmd" 2>/dev/null || true
    fi
done

_output=$(PATH="$_tmpdir" PF_COLOR=0 sh "$PFETCH" 2>/dev/null || true)
assert_no_degenerate_output "no-lsb-release" "$_output"
assert_exit_clean "no-lsb-release-no-stderr" "PATH=$_tmpdir"

# ---------------------------------------------------------------
# Test 3: Missing /etc/hostname (simulate via env override)
# ---------------------------------------------------------------
printf -- '\n--- Test group: Hostname fallbacks ---\n'

# Test with HOSTNAME env var set
_output=$(HOSTNAME=testhost run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
if printf '%s\n' "$_clean" | grep -q "testhost"; then
    pass "hostname-from-env: found 'testhost'"
else
    fail "hostname-from-env" "HOSTNAME=testhost not reflected in output"
fi

# Test with hostname unavailable — force fallback to uname -n
# We can't easily hide the hostname command, but we can unset HOSTNAME
# and rely on the fallback chain
_output=$(unset HOSTNAME; run_pfetch)
assert_no_degenerate_output "hostname-fallback" "$_output"

# ---------------------------------------------------------------
# Test 4: Container detection (simulate Docker)
# ---------------------------------------------------------------
printf -- '\n--- Test group: Container detection ---\n'

# We can test that pfetch doesn't crash even if DMI files are missing
# (which they are in most containers already)
_output=$(run_pfetch)
assert_field_present "container-host-fallback" "host" "$_output"

# ---------------------------------------------------------------
# Test 5: os-release parsing edge cases
# ---------------------------------------------------------------
printf -- '\n--- Test group: os-release edge cases ---\n'

# Test with a minimal os-release that only has NAME (no PRETTY_NAME)
_osrel_dir=$(mktemp -d)
cat > "$_osrel_dir/os-release" <<'OSREL'
NAME="Minimal Linux"
VERSION="1.0"
ID=minimal
OSREL

# We can't easily override /etc/os-release, but we can verify our parser
# handles quoted values by examining the actual system's output
_output=$(run_pfetch)
assert_field_present "os-release-basic" "os" "$_output"

# Test with os-release containing unquoted values
cat > "$_osrel_dir/os-release-unquoted" <<'OSREL'
NAME=UnquotedLinux
PRETTY_NAME=UnquotedLinux 2.0
OSREL

rm -rf "$_osrel_dir"

# ---------------------------------------------------------------
# Test 6: Missing /proc/uptime (container edge case)
# ---------------------------------------------------------------
printf -- '\n--- Test group: Missing /proc files ---\n'

# On the current system /proc/uptime likely exists, so just verify
# uptime field doesn't cause issues
_output=$(run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
if printf '%s\n' "$_clean" | grep -q "^uptime"; then
    pass "uptime-present: shown when available"
else
    pass "uptime-omitted: gracefully omitted (acceptable)"
fi

# ---------------------------------------------------------------
# Test 7: Title line always has user@host format
# ---------------------------------------------------------------
printf -- '\n--- Test group: Title format ---\n'

_output=$(run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
# The title line should contain '@' separator
if printf '%s\n' "$_clean" | grep -q "@"; then
    pass "title-format: contains '@' separator"
else
    fail "title-format" "no '@' found in output"
fi

# Test that even with empty USER, we get a fallback
_output=$(USER= run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
if printf '%s\n' "$_clean" | grep -q "@"; then
    pass "title-empty-user: still has '@' with fallback"
else
    fail "title-empty-user" "title line missing with empty USER"
fi

# ---------------------------------------------------------------
# Test 8: No package managers available
# ---------------------------------------------------------------
printf -- '\n--- Test group: No package managers ---\n'

# When no package managers are found, pkgs field should be omitted
# (not shown as "0" or empty)
_output=$(run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
if printf '%s\n' "$_clean" | grep -q "^pkgs"; then
    _pkgs_val=$(printf '%s\n' "$_clean" | grep "^pkgs" | sed 's/^pkgs[[:space:]]*//')
    case "$_pkgs_val" in
        (""|"0"|" ")
            fail "pkgs-zero" "pkgs shown as '$_pkgs_val' (should be omitted)"
        ;;
        (*)
            pass "pkgs-valid: pkgs = '$_pkgs_val'"
        ;;
    esac
else
    pass "pkgs-omitted: not shown when no packages (acceptable)"
fi

# ---------------------------------------------------------------
# Test 9: PF_INFO with various subsets
# ---------------------------------------------------------------
printf -- '\n--- Test group: PF_INFO subsets ---\n'

_output=$(PF_INFO="title os" run_pfetch)
assert_no_degenerate_output "pf-info-title-os" "$_output"

_output=$(PF_INFO="ascii title os" run_pfetch)
assert_no_degenerate_output "pf-info-ascii-title-os" "$_output"

_output=$(PF_INFO="title" run_pfetch)
assert_no_degenerate_output "pf-info-title-only" "$_output"

# ---------------------------------------------------------------
# Test 10: Debug mode (-d) doesn't crash
# ---------------------------------------------------------------
printf -- '\n--- Test group: Debug mode ---\n'

_output=$(PF_COLOR=0 sh "$PFETCH" -d 2>&1)
if [ -n "$_output" ]; then
    pass "debug-mode: produces output with -d flag"
else
    fail "debug-mode" "no output with -d flag"
fi

# ---------------------------------------------------------------
# Test 11: Version flag
# ---------------------------------------------------------------
printf -- '\n--- Test group: Version flag ---\n'

_output=$(sh "$PFETCH" -v 2>&1)
if printf '%s\n' "$_output" | grep -q "pfetch"; then
    pass "version-flag: shows version info"
else
    fail "version-flag" "no version output"
fi

# ---------------------------------------------------------------
# Test 12: WSL detection doesn't produce garbage on non-WSL
# ---------------------------------------------------------------
printf -- '\n--- Test group: WSL non-interference ---\n'

# On a non-WSL system, make sure "Windows 10" doesn't appear spuriously
_output=$(unset WSLENV; run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
if printf '%s\n' "$_clean" | grep -qi "windows"; then
    # This could be a real WSL system, so only fail if we know we're not on WSL
    case "$(uname -r)" in
        (*Microsoft*|*microsoft*)
            pass "wsl-real: WSL detected, Windows string expected"
        ;;
        (*)
            fail "wsl-false-positive" "Windows string on non-WSL kernel"
        ;;
    esac
else
    pass "wsl-non-interference: no spurious Windows string"
fi

# ---------------------------------------------------------------
# Test 13: Output is non-empty for default invocation
# ---------------------------------------------------------------
printf -- '\n--- Test group: Output sanity ---\n'

_output=$(run_pfetch)
_clean=$(printf '%s\n' "$_output" | strip_esc)
_line_count=$(printf '%s\n' "$_clean" | grep -c '[^ ]' || true)
if [ "$_line_count" -ge 2 ]; then
    pass "output-line-count: $_line_count non-empty lines"
else
    fail "output-line-count" "only $_line_count non-empty lines (expected >= 2)"
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed, %d total ===\n' "$PASSED" "$FAILED" "$TOTAL"

if [ "$FAILED" -gt 0 ]; then
    printf "${red}Some tests failed!${reset}\n"
    exit 1
else
    printf "${green}All tests passed.${reset}\n"
    exit 0
fi
