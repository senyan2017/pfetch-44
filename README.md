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
systems.

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

## Minimal and degraded environments

`pfetch` is frequently run inside containers, stripped-down images and
remote rescue environments where commands and standard files cannot be
relied upon. Detection of the most basic information degrades gracefully
in these environments instead of producing blank fields or broken text:

- **Distribution** is resolved in order from `lsb_release` (used only when
  it actually returns a value), Android, then `/etc/os-release` with a
  fallback to `/usr/lib/os-release`. Within the os-release file
  `PRETTY_NAME` is preferred, falling back to `NAME` (plus `VERSION` or
  `VERSION_ID`) and finally the bare `ID`. If none of these are available
  it falls back to `Linux <kernel>`, so the OS field is never empty.
- **Hostname** is resolved from `$HOSTNAME`, then the `hostname` command
  (only if it exists), then `/etc/hostname`, then
  `/proc/sys/kernel/hostname`, and finally the placeholder `unknown`.
- **User** is resolved from `$USER`, then `$LOGNAME`, then `id -un`, and
  finally `unknown`.

Missing commands and files are probed defensively, so even debug mode
(`pfetch -d`, which shows `stderr`) stays free of `command not found` and
`No such file` noise.

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

## Testing

A small POSIX `sh` regression suite exercises the minimal-environment
detection paths described above (non-standard `os-release` files, a missing
or broken `hostname` command, an absent `/etc/hostname`, simulated WSL, and
a broken `lsb_release`). Run it with:

```sh
make test
# or directly
sh tests/minimal-env.sh
```

## Credit

- [ufetch](https://gitlab.com/jschx/ufetch): Lots of ASCII logos.
    - Contrary to the belief of a certain youtuber, `pfetch` shares **zero** code with `ufetch`. Only some of the ASCII logos were used.
