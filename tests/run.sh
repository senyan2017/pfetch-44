#!/bin/sh
#
# tests/run.sh - Behavioral regression checks for pfetch.
#
# These guard the *contract* of the program (what it prints and how it lays
# things out) so the refactor into src/ modules cannot silently drift. They
# are deliberately pattern-based rather than golden-file diffs so they pass
# on any machine regardless of the actual distro/uptime/memory values.
#
# Coverage: build, version/help, the color master switch, the main info
# modules (os, kernel, uptime, memory, title) and the layout primitives
# (auto/forced alignment, separator, ascii geometry).
#
# Usage:   sh tests/run.sh   (or `make test`).  Exit status is non-zero if
#          any check fails.

# Run from the repository root regardless of how we were invoked.
cd "$(dirname "$0")/.." || exit 2

ESC=$(printf '\033')
pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   - %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL - %s\n' "$1"; }

# Literal substring assertions (no glob.regex surprises).
have()  { case $2 in *"$3"*) ok "$1" ;; *) no "$1"; printf '         expected to contain: %s\n' "$3" ;; esac; }

# Does "$1" contain a match for BRE pattern "$2"?
matches() { printf '%s' "$1" | grep -q "$2"; }

# Build into a temp dir, named 'pfetch' so '$0' basename stays "pfetch"
# (version/help echo the program name). This also leaves the committed
# ./pfetch untouched and exercises build.sh's custom-output argument.
tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT INT TERM
BIN="$tmp/pfetch"

printf '== build ==\n'
if ./build.sh "$BIN" >/dev/null && [ -x "$BIN" ]; then
    ok "build.sh produces an executable pfetch"
else
    no "build.sh produces an executable pfetch"
    printf '\n%d passed, %d failed\n' "$pass" "$fail"
    exit 1
fi

# Convenience: run the built script with color off and a given PF_INFO.
# Color is disabled so assertions match the plain text, not SGR codes.
plain() { PF_COLOR=0 PF_INFO="$1" TERM=dumb sh "$BIN" 2>/dev/null; }

printf '== cli ==\n'
if matches "$("$BIN" -v)" '^pfetch [0-9]'; then ok "-v prints a version"; else no "-v prints a version"; fi
have "-h prints usage" "$("$BIN" -h 2>&1)" "show system information"

printf '== color master switch ==\n'
if matches "$(plain os)" "${ESC}\[[0-9][0-9]*m"; then
    no "PF_COLOR=0 suppresses all SGR color sequences"
else
    ok "PF_COLOR=0 suppresses all SGR color sequences"
fi
if matches "$(PF_COLOR=1 PF_INFO=os TERM=dumb sh "$BIN" 2>/dev/null)" "${ESC}\[[0-9][0-9]*m"; then
    ok "PF_COLOR=1 emits SGR color sequences"
else
    no "PF_COLOR=1 emits SGR color sequences"
fi

printf '== info modules ==\n'
# Each labelled module should print its own name. (Values vary per machine.)
for m in os kernel uptime memory; do
    out=$(plain "$m")
    if [ -n "$out" ]; then have "module '$m' prints its line" "$out" "$m"
    else no "module '$m' prints its line (was empty)"; fi
done
# Memory should render as "<used>M / <total>M" (or '?M' fallback).
have "memory renders used / total" "$(plain memory)" "M / "
# Title is the only module with no label; it is user@host.
have "title renders user@host" "$(plain title)" "@"

printf '== layout ==\n'
# Forced alignment column: data is indented to exactly PF_ALIGN.
if matches "$(PF_COLOR=0 PF_ALIGN=9 PF_INFO=os TERM=dumb sh "$BIN" 2>/dev/null)" "${ESC}\[9C"; then
    ok "PF_ALIGN forces the data column (9)"
else
    no "PF_ALIGN forces the data column (9)"
fi
if matches "$(PF_COLOR=0 PF_ALIGN=2 PF_INFO=os TERM=dumb sh "$BIN" 2>/dev/null)" "${ESC}\[2C"; then
    ok "PF_ALIGN forces the data column (2)"
else
    no "PF_ALIGN forces the data column (2)"
fi
# Separator is appended between name and data when PF_SEP is set.
have "PF_SEP is appended after the name" "$(PF_COLOR=0 PF_SEP=: PF_INFO=os TERM=dumb sh "$BIN" 2>/dev/null)" "os:"
# Ascii art prints first and repositions the cursor upward (CUU) so info can
# be drawn beside it; this verifies the ascii<->layout coupling.
if matches "$(plain 'ascii os')" "${ESC}\[[0-9][0-9]*A"; then
    ok "ascii art renders and repositions the cursor (CUU)"
else
    no "ascii art renders and repositions the cursor (CUU)"
fi

printf '== smoke ==\n'
if PF_INFO="ascii title os kernel uptime memory" TERM=dumb sh "$BIN" >/dev/null 2>&1; then
    ok "a full default-style run exits 0"
else
    no "a full default-style run exits 0"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
