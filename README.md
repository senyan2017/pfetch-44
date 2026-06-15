<p align="center"><img src="https://user-images.githubusercontent.com/6799467/65944518-68834d80-e421-11e9-9b14-6ca26a16108a.png" width="350px"></p>
<h1 align="center">pfetch</h1>
<p align="center">A pretty system information tool written in POSIX sh</p><br>

<img src="https://user-images.githubusercontent.com/6799467/65945384-5bfff480-e423-11e9-863e-4e7cf16eb648.png" width="40%" align="right">

The goal of this project is to implement a simple system
information tool in POSIX `sh` using features built into
the language itself (*where possible*).

The source code is highly documented and I hope it will
act as a learning resource for POSIX `sh` and simple
information detection across various different operating
systems. It is organized into small, single-responsibility
modules under `src/` (see [Building and hacking](#building-and-hacking))
and assembled into the single `pfetch` script you run.

If anything in the source code is unclear or is lacking
in its explanation, open an issue. Sometimes you get too
close to something and you fail to see the "bigger
picture"!

<br>
<br>
<br>
<br>

## OS support

- **Linux**
    - Alpine Linux, Arch Linux, Arco Linux, Artix Linux, CentOS, Dahlia, Debian, Devuan, Elementary, EndeavourOS, Fedora, Garuda Linux, Gentoo, Guix, Hyperbola, instantOS, KISS Linux, Linux Lite, Linux Mint, Mageia, Manjaro, MX Linux, NixOS, OpenSUSE, Parabola, Pop!\_OS, PureOS, Slackware, Solus, Ubuntu and Void Linux.
    - All other distributions are supported with a generic penguin logo.
- **Android**
- **BSD**
    - DragonflyBSD, FreeBSD, NetBSD and OpenBSD.
- **Windows**
    - Windows subsystem for Linux.
- **Haiku**
- **MacOS**
- **Minix**
- **Solaris**
- **IRIX**
- **SerenityOS**

## Configuration

`pfetch` is configured through environment variables.

```sh
# Which information to display.
# NOTE: If 'ascii' will be used, it must come first.
# Default: first example below
# Valid: space separated string
#
# OFF by default: shell editor wm de palette
PF_INFO="ascii title os host kernel uptime pkgs memory"

# Example: Only ASCII.
PF_INFO="ascii"

# Example: Only Information.
PF_INFO="title os host kernel uptime pkgs memory"

# A file to source before running pfetch.
# Default: unset
# Valid: A shell script
PF_SOURCE=""

# Separator between info name and info data.
# Default: unset
# Valid: string
PF_SEP=":"

# Enable/Disable colors in output:
# Default: 1
# Valid: 1 (enabled), 0 (disabled)
PF_COLOR=1

# Color of info names:
# Default: unset (auto)
# Valid: 0-9
PF_COL1=4

# Color of info data:
# Default: unset (auto)
# Valid: 0-9
PF_COL2=9

# Color of title data:
# Default: unset (auto)
# Valid: 0-9
PF_COL3=1

# Alignment padding.
# Default: unset (auto)
# Valid: int
PF_ALIGN=""

# Which ascii art to use.
# Default: unset (auto)
# Valid: string
PF_ASCII="openbsd"

# The below environment variables control more
# than just 'pfetch' and can be passed using
# 'HOSTNAME=cool_pc pfetch' to restrict their
# usage solely to 'pfetch'.

# Which user to display.
USER=""

# Which hostname to display.
HOSTNAME=""

# Which editor to display.
EDITOR=""

# Which shell to display.
SHELL=""

# Which desktop environment to display.
XDG_CURRENT_DESKTOP=""
```

## Building and hacking

`pfetch` is *delivered* as one self-contained POSIX `sh` script — drop the
`pfetch` file onto any machine and run it, no build step required. It is
*developed* as a handful of focused modules under `src/`, assembled into that
single script by `build.sh`, so that editing one concern does not mean reading
the whole program:

| Module | Responsibility |
| --- | --- |
| `src/00_header.sh` | Banner + the shared-state contract (read this first) |
| `src/10_terminal.sh` | Terminal escapes, the color/alignment model, command detection |
| `src/20_layout.sh` | `log()`: the art-aware info layout / printing engine |
| `src/30_info.sh` | Detection + info modules (`detect_os`, `get_os`, `get_kernel`, …) |
| `src/40_ascii.sh` | `get_ascii()`: the ascii-art table and size measurement |
| `src/90_main.sh` | Config parsing, the three render phases, the entry point |

```sh
./build.sh        # assemble src/*.sh into ./pfetch  (or: make)
make test         # run the behavioral checks in tests/
make check        # shellcheck the assembled script + helper scripts
```

`pfetch` is a generated file: **edit the modules in `src/`, then rebuild.**
CI fails if the committed `pfetch` does not match a fresh build of `src/`.

Detection and rendering are kept apart. Distribution detection runs once
(`detect_os`) before any output, and the info modules (`get_*`) only print, so
behavior no longer depends on which function happened to run first. The handful
of variables shared between modules (`$os`, `$distro`, `$ascii_width`, …) are
documented as an explicit contract at the top of `src/00_header.sh`. The only
ordering rule that remains is that **`ascii` must be listed first in
`PF_INFO`**, because it establishes the geometry every info line is drawn
against.

## Credit

- [ufetch](https://gitlab.com/jschx/ufetch): Lots of ASCII logos.
    - Contrary to the belief of a certain youtuber, `pfetch` shares **zero** code with `ufetch`. Only some of the ASCII logos were used.
