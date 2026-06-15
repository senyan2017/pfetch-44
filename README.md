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

# Output mode.
# Default: unset (rich/interactive: ascii art, colors, alignment)
# Valid: plain
#
# 'plain' is an automation-friendly mode for CI logs, login banners
# and shell pipelines. It disables ascii art, colors and cursor-based
# alignment and prints one field per line as 'name<sep>value' (see
# 'PF_SEP'). All other 'PF_*' options still apply, so 'PF_INFO' keeps
# controlling which fields are shown and in what order.
# See the "Automation / scripting" section below for examples.
PF_MODE="plain"

# A file to source before running pfetch.
# Default: unset
# Valid: A shell script
PF_SOURCE=""

# Separator between info name and info data.
# Default: unset
# Valid: string
#
# In 'PF_MODE=plain' this is the field separator and defaults to a
# single space (so output parses with 'read -r key value'). Set it to
# something like ': ' for human-readable banners.
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

## Automation / scripting

For CI logs, init/provisioning scripts and login banners the rich
ascii-art output gets in the way. Set `PF_MODE=plain` to switch to a
lightweight mode that prints one `name value` pair per line with **no**
ascii art, **no** colors and **no** cursor-based alignment. Everything
else about the configuration is unchanged, so `PF_INFO` still selects the
fields and their order and `PF_SEP` still sets the separator.

```sh
$ PF_MODE=plain pfetch
user@host
os Ubuntu 22.04.3 LTS
host ...
kernel 6.5.0-14-generic
uptime 3h 12m
pkgs 1893
memory 2451M / 15888M
```

**Login / SSH banner.** Drop a snippet in `/etc/profile.d` (or append to
a user's shell rc) for a clean banner that won't smear color codes into
logs or non-interactive sessions:

```sh
# /etc/profile.d/zz-pfetch-banner.sh
PF_MODE=plain PF_SEP=": " PF_INFO="title os kernel uptime" pfetch
```

**No-color CI / build logs.** Plain mode already disables color, so the
output stays readable when captured to a file or a CI web UI:

```sh
PF_MODE=plain pfetch | tee system-info.log
```

**Only the key fields.** Use `PF_INFO` to pin exactly which fields are
emitted and in what order — handy when a later step greps for specific
values:

```sh
PF_MODE=plain PF_INFO="title os kernel memory" pfetch
```

**Consuming the output from shell.** With the default space separator the
first word is the key and the rest is the value, so a plain `read` loop
works:

```sh
PF_MODE=plain PF_INFO="os kernel memory" pfetch |
    while read -r key value; do
        printf 'detected %s = %s\n' "$key" "$value"
    done
```

> The `title` field prints just `user@host` with no value, so omit it
> (as above) when you want strict `key value` pairs for parsing.

## Credit

- [ufetch](https://gitlab.com/jschx/ufetch): Lots of ASCII logos.
    - Contrary to the belief of a certain youtuber, `pfetch` shares **zero** code with `ufetch`. Only some of the ASCII logos were used.
