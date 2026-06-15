#!/bin/sh
#
# pfetch - Simple POSIX sh fetch script.
#
# -------------------------------------------------------------------------
# THIS FILE IS GENERATED. Do not edit `pfetch` directly.
#
# pfetch is developed as small, single-responsibility modules under src/ and
# assembled into this one self-contained script by build.sh. To change
# behavior, edit the relevant module and re-run ./build.sh (or `make build`):
#
#   src/00_header.sh    this banner + the shared-state contract (below)
#   src/10_terminal.sh  terminal escapes, color model, command detection
#   src/20_layout.sh    log(): the art-aware info layout / printing engine
#   src/30_info.sh      detection + info modules (detect_os, get_os, ...)
#   src/40_ascii.sh     get_ascii(): the ascii-art table + size measurement
#   src/90_main.sh      config parsing, orchestration, the entry point
#
# -------------------------------------------------------------------------
# Shared-state contract
#
# pfetch renders almost like a tiny TUI, so a few variables are intentionally
# shared between modules rather than passed as arguments. They are listed
# here so the data flow is explicit instead of being an "you must call X
# before Y" folk rule. The producing step is named in parentheses.
#
#   $os $kernel $arch  uname fields, cached once          (main, Phase 1)
#   $distro            detected distribution name         (detect_os)
#   $c1..$c8           the 8 ansi color escape strings     (main, Phase 1)
#   $ascii            the selected ascii art               (get_ascii)
#   $ascii_width       art width + gap, info indent column (get_ascii)
#   $ascii_height      art line count, for final cursor    (get_ascii)
#   $info_length       widest info name, for alignment     (main, Phase 2)
#   $info_height       number of info lines printed so far (log, accumulates)
#
# Rendering happens in three phases, all driven from main():
#   Phase 1  detect_os + set up colors/uname           (no output yet)
#   Phase 2  measure info-name widths into $info_length
#   Phase 3  print ascii (must be first) then each info line via log()
# -------------------------------------------------------------------------

