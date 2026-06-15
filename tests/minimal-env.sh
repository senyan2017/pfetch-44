#!/bin/sh
#
# Regression tests for pfetch's system detection in minimal / degraded
# environments (containers, stripped images, rescue shells).
#
# pfetch supports a wide range of systems and most of its probes assume a
# fairly complete environment. When it is dropped into a container or a
# rescue shell, commands such as 'lsb_release' or 'hostname' may be missing
# or broken and standard files such as '/etc/os-release' or '/etc/hostname'
# may be absent or non-standard. These tests pin down the behaviour of the
# two most fragile (and most basic) pieces of information -- the
# distribution name and the hostname -- so that every degradation path
# yields a sane, non-empty value rather than a blank field or half-broken
# string.
#
# Two layers are exercised:
#   1. Unit tests that source pfetch's detection helpers and feed them
#      crafted fixtures (non-standard os-release files, missing hostname
#      sources, simulated WSL, a broken 'lsb_release', ...).
#   2. An end-to-end smoke test that runs the real script with broken
#      'lsb_release'/'hostname' stubs on PATH and asserts it still exits
#      cleanly with a usable title.
#
# Run with:  sh tests/minimal-env.sh   (or: make test)
#
# These tests source pfetch's helpers and drive them through indirection
# (e.g. get_os calls the overridden 'has'/'parse_os_release' stubs). The
# checker cannot follow that across the source boundary, so the directive
# below silences the resulting false positives:
#   SC2034 - variables consumed by the sourced functions look "unused" here
#   SC2154 - '$hostname' is assigned inside the sourced get_hostname()
#   SC2329 - stub functions are invoked indirectly by the sourced code
# shellcheck disable=SC2034,SC2154,SC2329

set -u

# Resolve the repository root relative to this script so the tests work
# regardless of the directory they are invoked from.
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH='' cd -- "$script_dir/.." && pwd)
pfetch=$repo_dir/pfetch

tmp=$(mktemp -d) || { echo "could not create temp dir" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT INT TERM

fails=0

pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }

# check <description> <expected> <actual>
check() {
    if [ "$2" = "$3" ]; then
        pass "$1"
    else
        fail "$1"
        printf '       expected: [%s]\n       actual:   [%s]\n' "$2" "$3"
    fi
}

# contains <description> <needle> <haystack>
contains() {
    case $3 in
        (*"$2"*) pass "$1" ;;
        (*) fail "$1"; printf '       missing [%s] in [%s]\n' "$2" "$3" ;;
    esac
}

# not_empty <description> <value>
not_empty() {
    if [ -n "$2" ]; then
        pass "$1"
    else
        fail "$1"
        printf '       value was empty\n'
    fi
}

# write_osr <line>...  -- write an os-release fixture, one key=value per line.
osr=$tmp/os-release
write_osr() {
    : > "$osr"
    for _line do
        printf '%s\n' "$_line" >> "$osr"
    done
}

# ---------------------------------------------------------------------------
# Load pfetch's functions without executing main().
#
# pfetch's only top-level statement is the final 'main "$@"' call, so a copy
# with that line neutralised defines all the helpers and nothing else. This
# keeps the production script free of any test-only hooks.
# ---------------------------------------------------------------------------
lib=$tmp/pfetch_lib.sh
sed 's/^main "\$@"$/: # main disabled for tests/' "$pfetch" > "$lib"
# shellcheck source=/dev/null
. "$lib"

echo "# parse_os_release"

# Standard, fully-populated, quoted os-release: PRETTY_NAME wins.
write_osr 'NAME="Ubuntu"' 'PRETTY_NAME="Ubuntu 20.04.1 LTS"' 'VERSION_ID="20.04"'
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "PRETTY_NAME is preferred" "Ubuntu 20.04.1 LTS" "$result"

# No PRETTY_NAME -> fall back to NAME + VERSION.
write_osr 'NAME="Alpine Linux"' 'VERSION="3.18.2"'
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "NAME + VERSION when PRETTY_NAME missing" "Alpine Linux 3.18.2" "$result"

# No PRETTY_NAME and no VERSION -> NAME + VERSION_ID.
write_osr 'NAME="Alpine Linux"' 'VERSION_ID=3.18'
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "NAME + VERSION_ID when VERSION missing" "Alpine Linux 3.18" "$result"

# Only NAME present.
write_osr 'NAME=BareDistro'
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "bare NAME only" "BareDistro" "$result"

# Only ID present (last resort before the caller's fallback).
write_osr 'ID=tinycore' 'BUILD_ID=rolling'
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "ID only" "tinycore" "$result"

# Single-quoted values are stripped just like double-quoted ones.
write_osr "PRETTY_NAME='Void Linux'"
result=$( distro=''; parse_os_release "$osr"; printf '%s' "$distro" )
check "single-quoted PRETTY_NAME stripped" "Void Linux" "$result"

# A file with no usable keys reports failure and leaves $distro empty.
write_osr '# a comment' 'ANSI_COLOR="0;38"' 'HOME_URL="https://example.org"'
result=$( distro=''; parse_os_release "$osr" && printf 'SET:%s' "$distro" || printf 'EMPTY' )
check "no usable keys -> failure, distro untouched" "EMPTY" "$result"

# A missing file reports failure.
result=$( distro=''; parse_os_release "$tmp/does-not-exist" && printf 'SET' || printf 'EMPTY' )
check "missing os-release file -> failure" "EMPTY" "$result"

echo "# get_hostname"

printf 'box-from-etc\n'  > "$tmp/etc_hostname"
printf 'box-from-proc\n' > "$tmp/proc_hostname"

# 'hostname' command unavailable + $HOSTNAME unset -> use /etc/hostname.
result=$(
    has() { return 1; }
    unset HOSTNAME hostname
    get_hostname "$tmp/etc_hostname" "$tmp/proc_hostname"
    printf '%s' "$hostname"
)
check "falls back to /etc/hostname" "box-from-etc" "$result"

# /etc/hostname missing -> use /proc/sys/kernel/hostname.
result=$(
    has() { return 1; }
    unset HOSTNAME hostname
    get_hostname "$tmp/missing_etc" "$tmp/proc_hostname"
    printf '%s' "$hostname"
)
check "falls back to kernel-exported hostname" "box-from-proc" "$result"

# Every source missing -> placeholder, never a dangling value.
result=$(
    has() { return 1; }
    unset HOSTNAME hostname
    get_hostname "$tmp/missing_etc" "$tmp/missing_proc"
    printf '%s' "$hostname"
)
check "degrades to 'unknown' placeholder" "unknown" "$result"

# $HOSTNAME always wins, even when files exist.
result=$(
    has() { return 1; }
    HOSTNAME=env-host
    unset hostname
    get_hostname "$tmp/etc_hostname" "$tmp/proc_hostname"
    printf '%s' "$hostname"
)
check "respects \$HOSTNAME override" "env-host" "$result"

echo "# get_os (Linux degradation, WSL, Android boundary)"

# A broken 'lsb_release' (present but prints nothing) must fall through to
# the os-release parser instead of leaving an empty distro. This is the core
# minimal-environment bug.
result=$(
    has() { case $1 in (lsb_release) return 0 ;; (*) return 1 ;; esac; }
    lsb_release() { return 1; }                 # present but yields nothing
    parse_os_release() { distro="FromOsRelease"; return 0; }
    os=Linux kernel=1.2.3 distro='' WSLENV=''
    get_os
    printf '%s' "$distro"
)
check "broken lsb_release falls through to os-release" "FromOsRelease" "$result"

# When *every* distro source fails, fall back to 'Linux <kernel>' rather
# than printing a blank os field.
result=$(
    has() { return 1; }                         # no lsb_release/crux/guix
    parse_os_release() { return 1; }             # no usable os-release
    os=Linux kernel=9.9.9-test distro='' WSLENV=''
    get_os
    printf '%s' "$distro"
)
check "final fallback to 'Linux <kernel>'" "Linux 9.9.9-test" "$result"

# WSL2 is detected via an exported $WSLENV and appends a suffix while
# preserving the detected distro name.
result=$(
    has() { return 1; }
    parse_os_release() { distro="TestDistro"; return 0; }
    os=Linux kernel=5.0.0-generic distro='' WSLENV=1
    get_os
    printf '%s' "$distro"
)
check "WSL2 suffix appended to distro" "TestDistro on Windows 10 [WSL2]" "$result"

# WSL1 is detected via a '-Microsoft' kernel suffix when $WSLENV is unset.
result=$(
    has() { return 1; }
    parse_os_release() { distro="TestDistro"; return 0; }
    os=Linux kernel=4.4.0-19041-Microsoft distro='' WSLENV=''
    get_os
    printf '%s' "$distro"
)
check "WSL1 suffix appended to distro" "TestDistro on Windows 10 [WSL1]" "$result"

echo "# end-to-end (degraded PATH)"

# Stub a broken 'lsb_release' and 'hostname' (present on PATH but failing),
# which is exactly how minimal images tend to misbehave.
stub_dir=$tmp/stubs
mkdir -p "$stub_dir"
printf '#!/bin/sh\nexit 1\n' > "$stub_dir/lsb_release"
printf '#!/bin/sh\nexit 1\n' > "$stub_dir/hostname"
chmod +x "$stub_dir/lsb_release" "$stub_dir/hostname"

esc=$(printf '\033')

# Title only: assert the script survives and produces 'user@host' with both
# halves non-empty (no dangling '@').
PATH="$stub_dir:$PATH" PF_INFO="title" PF_COLOR=0 HOSTNAME='' "$pfetch" \
    > "$tmp/title_out" 2>/dev/null
status=$?
check "pfetch exits cleanly with broken probes (title)" "0" "$status"

title=$(sed "s/${esc}\[[?0-9;]*[A-Za-z]//g" "$tmp/title_out" | tr -d '\n')
contains "title contains an '@' separator" "@" "$title"
not_empty "title user part is non-empty" "${title%@*}"
not_empty "title host part is non-empty" "${title##*@}"

# OS only: assert the script survives and prints a non-empty distribution.
PATH="$stub_dir:$PATH" PF_INFO="os" PF_COLOR=0 "$pfetch" \
    > "$tmp/os_out" 2>/dev/null
status=$?
check "pfetch exits cleanly with broken probes (os)" "0" "$status"
os_line=$(sed "s/${esc}\[[?0-9;]*[A-Za-z]//g" "$tmp/os_out" | tr -d '\n')
not_empty "os line is non-empty" "$os_line"

echo
if [ "$fails" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$fails test(s) failed."
    exit 1
fi
