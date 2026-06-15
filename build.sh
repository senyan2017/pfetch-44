#!/bin/sh
#
# build.sh - Assemble the single-file `pfetch` artifact from the modules
# in src/.
#
# pfetch is *delivered* as one self-contained POSIX sh script (drop it on a
# machine and run it). It is *developed* as a handful of focused modules so
# that editing one concern (config, terminal output, info detection, ascii
# art/layout) does not require reading the whole program. This script glues
# the modules back together, in a fixed order, into the runnable `pfetch`.
#
# Usage:
#   ./build.sh            # writes ./pfetch
#   ./build.sh path/out   # writes a custom output path

# Fail early and loudly; a half-written interpreter script is worse than none.
set -e

# Operate relative to the repository root regardless of the caller's CWD.
cd "$(dirname "$0")"

out=${1:-pfetch}

# The order is significant and therefore explicit (not a glob):
#   - 00_header  must be first  (it carries the '#!' shebang line).
#   - 90_main    must be last   (it ends with the 'main "$@"' entry point).
# Everything in between only defines functions, so its relative order is
# free; it is kept in reading order (terminal -> layout -> info -> ascii).
modules="
src/00_header.sh
src/10_terminal.sh
src/20_layout.sh
src/30_info.sh
src/40_ascii.sh
src/90_main.sh
"

# Refuse to build if a module is missing rather than emit a broken script.
for m in $modules; do
    [ -f "$m" ] || { printf 'build.sh: missing module: %s\n' "$m" >&2; exit 1; }
done

# Assemble into a temporary file first, then move it into place so that a
# failed build never leaves a partially written (and possibly executable)
# `pfetch` behind.
tmp=${TMPDIR:-/tmp}/pfetch.build.$$
trap 'rm -f "$tmp"' EXIT INT TERM

# shellcheck disable=2086
cat $modules > "$tmp"

chmod +x "$tmp"
mv "$tmp" "$out"

printf 'build.sh: wrote %s\n' "$out"
