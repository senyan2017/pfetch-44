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

## Internal architecture

Although pfetch is delivered as a single file, the source is organized
into clearly delimited sections so you can modify one area without
re-reading the entire script:

| Section      | Responsibility                                      |
|--------------|-----------------------------------------------------|
| `[TERMINAL]` | Escape-sequence primitives (`esc`, `esc_p`)         |
| `[UTILITY]`  | General helpers (`has`)                             |
| `[CONFIG]`   | Configuration loading, color map initialization     |
| `[DETECT]`   | System information probes (each sets `_pf_val`)     |
| `[ASCII]`    | ASCII art data, selection, and measurement          |
| `[RENDER]`   | Info-line rendering and layout engine               |
| `[MAIN]`     | Entry point and orchestration                       |

**Data flow:**

```
config_init → detect_platform / detect_distro → main loop:
  for each PF_INFO item:
    "ascii"  → ascii_init (print art, set dimensions)
    other    → detect_<item> (set _pf_val) → render_info (print line)
  → render_finish (position cursor below output)
```

**Key design rules:**

- Detection functions (`detect_*`) never print directly.  They store
  their result in `_pf_val` and the rendering engine decides how to
  display it.
- All visible output goes through `render_info()`, so color, alignment,
  and separator behavior are consistent across every module.
- Cross-section shared state is limited to a documented set of `_pf_*`
  variables listed in the file header.

## Available info modules

| Module    | What it shows                        | Enabled by default |
|-----------|--------------------------------------|:------------------:|
| `ascii`   | Distribution ASCII art               |         yes        |
| `title`   | `user@hostname`                      |         yes        |
| `os`      | OS / distribution name               |         yes        |
| `host`    | Machine model / product name         |         yes        |
| `kernel`  | Kernel release (`uname -r`)          |         yes        |
| `uptime`  | System uptime                        |         yes        |
| `pkgs`    | Installed package count              |         yes        |
| `memory`  | Used / total RAM                     |         yes        |
| `shell`   | Current shell (`$SHELL`)             |         no         |
| `editor`  | Editor (`$VISUAL` or `$EDITOR`)      |         no         |
| `wm`      | Window manager (X11 only)            |         no         |
| `de`      | Desktop environment                  |         no         |
| `palette` | Terminal color swatches              |         no         |

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
# Default: unset (auto from ASCII art)
# Valid: 0-9
PF_COL1=4

# Color of info data:
# Default: unset (auto)
# Valid: 0-9
PF_COL2=9

# Color of title data:
# Default: unset (auto from ASCII art)
# Valid: 0-9
PF_COL3=1

# Alignment padding.
# Default: unset (auto, based on longest info label)
# Valid: int
PF_ALIGN=""

# Which ascii art to use.
# Default: unset (auto-detect from distribution)
# Valid: string (e.g. "arch", "ubuntu", "openbsd")
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

A test suite covering core behaviors lives in `test/`:

```sh
sh test/pfetch-test.sh
```

It validates CLI flags, individual info modules, color control,
separator/alignment behavior, layout combinations, and edge cases.
No root or network access required.

## Credit

- [ufetch](https://gitlab.com/jschx/ufetch): Lots of ASCII logos.
    - Contrary to the belief of a certain youtuber, `pfetch` shares **zero** code with `ufetch`. Only some of the ASCII logos were used.
