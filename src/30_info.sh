get_title() {
    # Username is retrieved by first checking '$USER' with a fallback
    # to the 'id -un' command.
    user=${USER:-$(id -un)}

    # Hostname is retrieved by first checking '$HOSTNAME' with a fallback
    # to the 'hostname' command.
    #
    # Disable the warning about '$HOSTNAME' being undefined in POSIX sh as
    # the intention for using it is allowing the user to overwrite the
    # value on invocation.
    # shellcheck disable=3028,2039
    hostname=${HOSTNAME:-${hostname:-$(hostname)}}

    # If the hostname is still not found, fallback to the contents of the
    # /etc/hostname file.
    [ "$hostname" ] || read -r hostname < /etc/hostname

    # Add escape sequences for coloring to user and host name. As we embed
    # them directly in the arguments passed to log(), we cannot use esc_p().
    esc SGR 1
    user=$e$user
    esc SGR "3${PF_COL3:-1}"
    user=$e$user
    esc SGR 1
    user=$user$e
    esc SGR 1
    hostname=$e$hostname
    esc SGR "3${PF_COL3:-1}"
    hostname=$e$hostname

    log "${user}@${hostname}" " " " " >&6
}

# Display the detected OS/distribution name.
#
# This is a pure info module: it only prints. The actual detection lives in
# 'detect_os' below, which main() runs exactly once before any output. This
# replaces the old arrangement where a single 'get_os' was called twice and
# behaved differently on each call ("first call detects, second call prints"),
# an implicit ordering rule that was easy to trip over.
#
# Reads: $distro (populated by detect_os). 'log' no-ops if it is empty.
get_os() {
    log os "$distro" >&6
}

# Detect the OS/distribution name into the shared '$distro' variable.
#
# Run once from main() *before* the info loop, because the result is needed
# both to pick the ascii art and (optionally) to print the 'os' line.
#
# Reads: $os, $kernel (cached 'uname' output set in main()).
# Writes: $distro. May also clear the EXIT trap on platforms whose terminals
#         do not support the escape sequences pfetch relies on.
detect_os() {
    case $os in
        (Linux*)
            # Some Linux distributions (which are based on others)
            # fail to identify as they **do not** change the upstream
            # distribution's identification packages or files.
            #
            # It is senseless to add a special case in the code for
            # each and every distribution (which _is_ technically no
            # different from what it is based on) as they're either too
            # lazy to modify upstream's identification files or they
            # don't have the know-how (or means) to ship their own
            # lsb-release package.
            #
            # This causes users to think there's a bug in system detection
            # tools like neofetch or pfetch when they technically *do*
            # function correctly.
            #
            # Exceptions are made for distributions which are independent,
            # not based on another distribution or follow different
            # standards.
            #
            # This applies only to distributions which follow the standard
            # by shipping unmodified identification files and packages
            # from their respective upstreams.
            if has lsb_release; then
                distro=$(lsb_release -sd)

            # Android detection works by checking for the existence of
            # the follow two directories. I don't think there's a simpler
            # method than this.
            elif [ -d /system/app ] && [ -d /system/priv-app ]; then
                distro="Android $(getprop ro.build.version.release)"

            elif [ -f /etc/os-release ]; then
                # This used to be a simple '. /etc/os-release' but I believe
                # this is insecure as we blindly executed whatever was in the
                # file. This parser instead simply handles 'key=val', treating
                # the file contents as plain-text.
                while IFS='=' read -r key val; do
                    case $key in
                        (PRETTY_NAME)
                            distro=$val
                        ;;
                    esac
                done < /etc/os-release

            else
                # Special cases for (independent) distributions which
                # don't follow any os-release/lsb standards whatsoever.
                has crux && distro=$(crux)
                has guix && distro='Guix System'
            fi

            # 'os-release' and 'lsb_release' sometimes add quotes
            # around the distribution name, strip them.
            distro=${distro##[\"\']}
            distro=${distro%%[\"\']}

            # Check to see if we're running Bedrock Linux which is
            # very unique. This simply checks to see if the user's
            # PATH contains a Bedrock specific value.
            case $PATH in
                (*/bedrock/cross/*)
                    distro='Bedrock Linux'
                ;;
            esac

            # Check to see if Linux is running in Windows 10 under
            # WSL1 (Windows subsystem for Linux [version 1]) and
            # append a string accordingly.
            #
            # If the kernel version string ends in "-Microsoft",
            # we're very likely running under Windows 10 in WSL1.
            if [ "$WSLENV" ]; then
                distro="${distro}${WSLENV+ on Windows 10 [WSL2]}"

            # Check to see if Linux is running in Windows 10 under
            # WSL2 (Windows subsystem for Linux [version 2]) and
            # append a string accordingly.
            #
            # This checks to see if '$WSLENV' is defined. This
            # appends the Windows 10 string even if '$WSLENV' is
            # empty. We only need to check that is has been _exported_.
            elif [ -z "${kernel%%*-Microsoft}" ]; then
                distro="$distro on Windows 10 [WSL1]"
            fi
        ;;

        (Darwin*)
            # Parse the SystemVersion.plist file to grab the macOS
            # version. The file is in the following format:
            #
            # <key>ProductVersion</key>
            # <string>10.14.6</string>
            #
            # 'IFS' is set to '<>' to enable splitting between the
            # keys and a second 'read' is used to operate on the
            # next line directly after a match.
            #
            # '_' is used to nullify a field. '_ _ line _' basically
            # says "populate $line with the third field's contents".
            while IFS='<>' read -r _ _ line _; do
                case $line in
                    # Match 'ProductVersion' and read the next line
                    # directly as it contains the key's value.
                    ProductVersion)
                        IFS='<>' read -r _ _ mac_version _
                        continue
                    ;;

                    ProductName)
                        IFS='<>' read -r _ _ mac_product _
                        continue
                    ;;
                esac
            done < /System/Library/CoreServices/SystemVersion.plist

            # Use the ProductVersion to determine which macOS/OS X codename
            # the system has. As far as I'm aware there's no "dynamic" way
            # of grabbing this information.
            case $mac_version in
                (10.4*)  distro='Mac OS X Tiger' ;;
                (10.5*)  distro='Mac OS X Leopard' ;;
                (10.6*)  distro='Mac OS X Snow Leopard' ;;
                (10.7*)  distro='Mac OS X Lion' ;;
                (10.8*)  distro='OS X Mountain Lion' ;;
                (10.9*)  distro='OS X Mavericks' ;;
                (10.10*) distro='OS X Yosemite' ;;
                (10.11*) distro='OS X El Capitan' ;;
                (10.12*) distro='macOS Sierra' ;;
                (10.13*) distro='macOS High Sierra' ;;
                (10.14*) distro='macOS Mojave' ;;
                (10.15*) distro='macOS Catalina' ;;
                (11*)    distro='macOS Big Sur' ;;
                (12*)    distro='macOS Monterey' ;;
                (*)      distro='macOS' ;;
            esac

            # Use the ProductName to determine if we're running in iOS.
            case $mac_product in
                (iP*) distro='iOS' ;;
            esac

            distro="$distro $mac_version"
        ;;

        (Haiku)
            # Haiku uses 'uname -v' for version information
            # instead of 'uname -r' which only prints '1'.
            distro=$(uname -sv)
        ;;

        (Minix|DragonFly)
            distro="$os $kernel"

            # Minix and DragonFly don't support the escape
            # sequences used, clear the exit trap.
            trap '' EXIT
        ;;

        (SunOS)
            # Grab the first line of the '/etc/release' file
            # discarding everything after '('.
            IFS='(' read -r distro _ < /etc/release
        ;;

        (OpenBSD*)
            # Show the OpenBSD version type (current if present).
            # kern.version=OpenBSD 6.6-current (GENERIC.MP) ...
            IFS=' =' read -r _ distro openbsd_ver _ <<-EOF
				$(sysctl kern.version)
			EOF

            distro="$distro $openbsd_ver"
        ;;

        (FreeBSD)
            distro="$os $(freebsd-version)"
        ;;

        (*)
            # Catch all to ensure '$distro' is never blank.
            # This also handles the BSDs.
            distro="$os $kernel"
        ;;
    esac
}

get_kernel() {
    case $os in
        # Don't print kernel output on some systems as the
        # OS name includes it.
        (*BSD*|Haiku|Minix)
            return
        ;;
    esac

    # '$kernel' is the cached output of 'uname -r'.
    log kernel "$kernel" >&6
}

get_host() {
    case $os in
        (Linux*)
            # Despite what these files are called, version doesn't
            # always contain the version nor does name always contain
            # the name.
            read -r name    < /sys/devices/virtual/dmi/id/product_name
            read -r version < /sys/devices/virtual/dmi/id/product_version
            read -r model   < /sys/firmware/devicetree/base/model

            host="$name $version $model"
        ;;

        (Darwin* | FreeBSD* | DragonFly*)
            host=$(sysctl -n hw.model)
        ;;

        (NetBSD*)
            host=$(sysctl -n machdep.dmi.system-vendor \
                             machdep.dmi.system-product)
        ;;

        (OpenBSD*)
            host=$(sysctl -n hw.version)
        ;;

        (*BSD* | Minix)
            host=$(sysctl -n hw.vendor hw.product)
        ;;
    esac

    # Turn the host string into an argument list so we can iterate
    # over it and remove OEM strings and other information which
    # shouldn't be displayed.
    #
    # Disable the shellcheck warning for word-splitting
    # as it's safe and intended ('set -f' disables globbing).
    # shellcheck disable=2046,2086
    {
        set -f
        set +f -- $host
        host=
    }

    # Iterate over the host string word by word as a means of stripping
    # unwanted and OEM information from the string as a whole.
    #
    # This could have been implemented using a long 'sed' command with
    # a list of word replacements, however I want to show that something
    # like this is possible in pure sh.
    #
    # This string reconstruction is needed as some OEMs either leave the
    # identification information as "To be filled by OEM", "Default",
    # "undefined" etc and we shouldn't print this to the screen.
    for word do
        # This works by reconstructing the string by excluding words
        # found in the "blacklist" below. Only non-matches are appended
        # to the final host string.
        case $word in
           (To      | [Bb]e      | [Ff]illed | [Bb]y  | O.E.M.  | OEM  |\
            Not     | Applicable | Specified | System | Product | Name |\
            Version | Undefined  | Default   | string | INVALID | �    | os |\
            Type1ProductConfigId )
                continue
            ;;
        esac

        host="$host$word "
    done

    # '$arch' is the cached output from 'uname -m'.
    log host "${host:-$arch}" >&6
}

get_uptime() {
    # Uptime works by retrieving the data in total seconds and then
    # converting that data into days, hours and minutes using simple
    # math.
    case $os in
        (Linux* | Minix* | SerenityOS*)
            IFS=. read -r s _ < /proc/uptime
        ;;

        (Darwin* | *BSD* | DragonFly*)
            s=$(sysctl -n kern.boottime)

            # Extract the uptime in seconds from the following output:
            # [...] { sec = 1271934886, usec = 667779 } Thu Apr 22 12:14:46 2010
            s=${s#*=}
            s=${s%,*}

            # The uptime format from 'sysctl' needs to be subtracted from
            # the current time in seconds.
            s=$(($(date +%s) - s))
        ;;

        (Haiku)
            # The boot time is returned in microseconds, convert it to
            # regular seconds.
            s=$(($(system_time) / 1000000))
        ;;

        (SunOS)
            # Split the output of 'kstat' on '.' and any white-space
            # which exists in the command output.
            #
            # The output is as follows:
            # unix:0:system_misc:snaptime	14809.906993005
            #
            # The parser extracts:          ^^^^^
            IFS='	.' read -r _ s _ <<-EOF
				$(kstat -p unix:0:system_misc:snaptime)
			EOF
        ;;

        (IRIX)
            # Grab the uptime in a pretty format. Usually,
            # 00:00:00 from the 'ps' command.
            t=$(LC_ALL=POSIX ps -o etime= -p 1)

            # Split the pretty output into days or hours
            # based on the uptime.
            case $t in
                (*-*)   d=${t%%-*} t=${t#*-} ;;
                (*:*:*) h=${t%%:*} t=${t#*:} ;;
            esac

            h=${h#0} t=${t#0}

            # Convert the split pretty fields back into
            # seconds so we may re-convert them to our format.
            s=$((${d:-0}*86400 + ${h:-0}*3600 + ${t%%:*}*60 + ${t#*:}))
        ;;
    esac

    # Convert the uptime from seconds into days, hours and minutes.
    d=$((s / 60 / 60 / 24))
    h=$((s / 60 / 60 % 24))
    m=$((s / 60 % 60))

    # Only append days, hours and minutes if they're non-zero.
    case "$d" in ([!0]*) uptime="${uptime}${d}d "; esac
    case "$h" in ([!0]*) uptime="${uptime}${h}h "; esac
    case "$m" in ([!0]*) uptime="${uptime}${m}m "; esac

    log uptime "${uptime:-0m}" >&6
}

get_pkgs() {
    # This works by first checking for which package managers are
    # installed and finally by printing each package manager's
    # package list with each package one per line.
    #
    # The output from this is then piped to 'wc -l' to count each
    # line, giving us the total package count of whatever package
    # managers are installed.
    packages=$(
        case $os in
            (Linux*)
                # Commands which print packages one per line.
                has bonsai     && bonsai list
                has crux       && pkginfo -i
                has pacman-key && pacman -Qq
                has dpkg       && dpkg-query -f '.\n' -W
                has rpm        && rpm -qa
                has xbps-query && xbps-query -l
                has apk        && apk info
                has guix       && guix package --list-installed
                has opkg       && opkg list-installed

                # Directories containing packages.
                has kiss       && printf '%s\n' /var/db/kiss/installed/*/
                has cpt-list   && printf '%s\n' /var/db/cpt/installed/*/
                has brew       && printf '%s\n' "$(brew --cellar)/"*
                has emerge     && printf '%s\n' /var/db/pkg/*/*/
                has pkgtool    && printf '%s\n' /var/log/packages/*
                has eopkg      && printf '%s\n' /var/lib/eopkg/package/*

                # 'nix' requires two commands.
                has nix-store  && {
                    nix-store -q --requisites /run/current-system/sw
                    nix-store -q --requisites ~/.nix-profile
                }
            ;;

            (Darwin*)
                # Commands which print packages one per line.
                has pkgin      && pkgin list
                has dpkg       && dpkg-query -f '.\n' -W

                # Directories containing packages.
                has brew       && printf '%s\n' /usr/local/Cellar/*

                # 'port' prints a single line of output to 'stdout'
                # when no packages are installed and exits with
                # success causing a false-positive of 1 package
                # installed.
                #
                # 'port' should really exit with a non-zero code
                # in this case to allow scripts to cleanly handle
                # this behavior.
                has port       && {
                    pkg_list=$(port installed)

                    case "$pkg_list" in
                        ("No ports are installed.")
                            # do nothing
                        ;;

                        (*)
                            printf '%s\n' "$pkg_list"
                        ;;
                    esac
                }
            ;;

            (FreeBSD*|DragonFly*)
                pkg info
            ;;

            (OpenBSD*)
                printf '%s\n' /var/db/pkg/*/
            ;;

            (NetBSD*)
                pkg_info
            ;;

            (Haiku)
                printf '%s\n' /boot/system/package-links/*
            ;;

            (Minix)
                printf '%s\n' /usr/pkg/var/db/pkg/*/
            ;;

            (SunOS)
                has pkginfo && pkginfo -i
                has pkg     && pkg list
            ;;

            (IRIX)
                versions -b
            ;;

            (SerenityOS)
                while IFS=" " read -r type _; do
                    [ "$type" != dependency ] &&
                        printf "\n"
                done < /usr/Ports/packages.db
            ;;
        esac | wc -l
    )

    # 'wc -l' can have leading and/or trailing whitespace
    # depending on the implementation, so strip them.
    # Procedure explained at https://github.com/dylanaraps/pure-sh-bible
    # (trim-leading-and-trailing-white-space-from-string)
    packages=${packages#"${packages%%[![:space:]]*}"}
    packages=${packages%"${packages##*[![:space:]]}"}

    case $os in
        # IRIX's package manager adds 3 lines of extra
        # output which we must account for here.
        (IRIX)
            packages=$((packages - 3))
        ;;

        # OpenBSD's wc prints whitespace before the output
        # which needs to be stripped.
        (OpenBSD)
            packages=$((packages))
        ;;
    esac

    case $packages in
        (1?*|[2-9]*)
            log pkgs "$packages" >&6
        ;;
    esac
}

get_memory() {
    case $os in
        # Used memory is calculated using the following "formula":
        # MemUsed = MemTotal + Shmem - MemFree - Buffers - Cached - SReclaimable
        # Source: https://github.com/KittyKatt/screenFetch/issues/386
        (Linux*)
            # Parse the '/proc/meminfo' file splitting on ':' and 'k'.
            # The format of the file is 'key:   000kB' and an additional
            # split is used on 'k' to filter out 'kB'.
            while IFS=':k '  read -r key val _; do
                case $key in
                    (MemTotal)
                        mem_used=$((mem_used + val))
                        mem_full=$val
                    ;;

                    (Shmem)
                        mem_used=$((mem_used + val))
                    ;;

                    (MemFree | Buffers | Cached | SReclaimable)
                        mem_used=$((mem_used - val))
                    ;;

                    # If detected this will be used over the above calculation
                    # for mem_used. Available since Linux 3.14rc.
                    # See kernel commit 34e431b0ae398fc54ea69ff85ec700722c9da773
                    (MemAvailable)
                        mem_avail=$val
                    ;;
                esac
            done < /proc/meminfo

            case $mem_avail in
                (*[0-9]*)
                    mem_used=$(((mem_full - mem_avail) / 1024))
                ;;

                *)
                    mem_used=$((mem_used / 1024))
                ;;
            esac

            mem_full=$((mem_full / 1024))
        ;;

        # Used memory is calculated using the following "formula":
        # (wired + active + occupied) * 4 / 1024
        (Darwin*)
            mem_full=$(($(sysctl -n hw.memsize) / 1024 / 1024))

            # Parse the 'vmstat' file splitting on ':' and '.'.
            # The format of the file is 'key:   000.' and an additional
            # split is used on '.' to filter it out.
            while IFS=:. read -r key val; do
                case $key in
                    (*' wired'*|*' active'*|*' occupied'*)
                        mem_used=$((mem_used + ${val:-0}))
                    ;;
                esac

            # Using '<<-EOF' is the only way to loop over a command's
            # output without the use of a pipe ('|').
            # This ensures that any variables defined in the while loop
            # are still accessible in the script.
            done <<-EOF
                $(vm_stat)
			EOF

            mem_used=$((mem_used * 4 / 1024))
        ;;

        (OpenBSD*)
            mem_full=$(($(sysctl -n hw.physmem) / 1024 / 1024))

            # This is a really simpler parser for 'vmstat' which grabs
            # the used memory amount in a lazy way. 'vmstat' prints 3
            # lines of output with the needed value being stored in the
            # final line.
            #
            # This loop simply grabs the 3rd element of each line until
            # the EOF is reached. Each line overwrites the value of the
            # previous one so we're left with what we wanted. This isn't
            # slow as only 3 lines are parsed.
            while read -r _ _ line _; do
                mem_used=${line%%M}

            # Using '<<-EOF' is the only way to loop over a command's
            # output without the use of a pipe ('|').
            # This ensures that any variables defined in the while loop
            # are still accessible in the script.
            done <<-EOF
                $(vmstat)
			EOF
        ;;

        # Used memory is calculated using the following "formula":
        # mem_full - ((inactive + free + cache) * page_size / 1024)
        (FreeBSD*|DragonFly*)
            mem_full=$(($(sysctl -n hw.physmem) / 1024 / 1024))

            # Use 'set --' to store the output of the command in the
            # argument list. POSIX sh has no arrays but this is close enough.
            #
            # Disable the shellcheck warning for word-splitting
            # as it's safe and intended ('set -f' disables globbing).
            # shellcheck disable=2046
            {
                set -f
                set +f -- $(sysctl -n hw.pagesize \
                                      vm.stats.vm.v_inactive_count \
                                      vm.stats.vm.v_free_count \
                                      vm.stats.vm.v_cache_count)
            }

            # Calculate the amount of used memory.
            # $1: hw.pagesize
            # $2: vm.stats.vm.v_inactive_count
            # $3: vm.stats.vm.v_free_count
            # $4: vm.stats.vm.v_cache_count
            mem_used=$((mem_full - (($2 + $3 + $4) * $1 / 1024 / 1024)))
        ;;

        (NetBSD*)
            mem_full=$(($(sysctl -n hw.physmem64) / 1024 / 1024))

            # NetBSD implements a lot of the Linux '/proc' filesystem,
            # this uses the same parser as the Linux memory detection.
            while IFS=':k ' read -r key val _; do
                case $key in
                    (MemFree)
                        mem_free=$((val / 1024))
                        break
                    ;;
                esac
            done < /proc/meminfo

            mem_used=$((mem_full - mem_free))
        ;;

        (Haiku)
            # Read the first line of 'sysinfo -mem' splitting on
            # '(', ' ', and ')'. The needed information is then
            # stored in the 5th and 7th elements. Using '_' "consumes"
            # an element allowing us to proceed to the next one.
            #
            # The parsed format is as follows:
            # 3501142016 bytes free      (used/max  792645632 / 4293787648)
            IFS='( )' read -r _ _ _ _ mem_used _ mem_full <<-EOF
                $(sysinfo -mem)
			EOF

            mem_used=$((mem_used / 1024 / 1024))
            mem_full=$((mem_full / 1024 / 1024))
        ;;

        (Minix)
            # Minix includes the '/proc' filesystem though the format
            # differs from Linux. The '/proc/meminfo' file is only a
            # single line with space separated elements and elements
            # 2 and 3 contain the total and free memory numbers.
            read -r _ mem_full mem_free _ < /proc/meminfo

            mem_used=$(((mem_full - mem_free) / 1024))
            mem_full=$(( mem_full / 1024))
        ;;

        (SunOS)
            hw_pagesize=$(pagesize)

            # 'kstat' outputs memory in the following format:
            # unix:0:system_pages:pagestotal	1046397
            # unix:0:system_pages:pagesfree		885018
            #
            # This simply uses the first "element" (white-space
            # separated) as the key and the second element as the
            # value.
            #
            # A variable is then assigned based on the key.
            while read -r key val; do
                case $key in
                    (*total)
                        pages_full=$val
                    ;;

                    (*free)
                        pages_free=$val
                    ;;
                esac
            done <<-EOF
				$(kstat -p unix:0:system_pages:pagestotal \
                           unix:0:system_pages:pagesfree)
			EOF

            mem_full=$((pages_full * hw_pagesize / 1024 / 1024))
            mem_free=$((pages_free * hw_pagesize / 1024 / 1024))
            mem_used=$((mem_full - mem_free))
        ;;

        (IRIX)
            # Read the memory information from the 'top' command. Parse
            # and split each line until we reach the line starting with
            # "Memory".
            #
            # Example output: Memory: 160M max, 147M avail, .....
            while IFS=' :' read -r label mem_full _ mem_free _; do
                case $label in
                    (Memory)
                        mem_full=${mem_full%M}
                        mem_free=${mem_free%M}
                        break
                    ;;
                esac
            done <<-EOF
                $(top -n)
			EOF

            mem_used=$((mem_full - mem_free))
        ;;

        (SerenityOS)
            IFS='{}' read -r _ memstat _ < /proc/memstat

            set -f -- "$IFS"
            IFS=,

            for pair in $memstat; do
                case $pair in
                    (*user_physical_allocated*)
                        mem_used=${pair##*:}
                    ;;

                    (*user_physical_available*)
                        mem_free=${pair##*:}
                    ;;
                esac
            done

            IFS=$1
            set +f --

            mem_used=$((mem_used * 4096 / 1024 / 1024))
            mem_free=$((mem_free * 4096 / 1024 / 1024))

            mem_full=$((mem_used + mem_free))
        ;;
    esac

    log memory "${mem_used:-?}M / ${mem_full:-?}M" >&6
}

get_wm() {
    case $os in
        (Darwin*)
            # Don't display window manager on macOS.
        ;;

        (*)
            # xprop can be used to grab the window manager's properties
            # which contains the window manager's name under '_NET_WM_NAME'.
            #
            # The upside to using 'xprop' is that you don't need to hardcode
            # a list of known window manager names. The downside is that
            # not all window managers conform to setting the '_NET_WM_NAME'
            # atom..
            #
            # List of window managers which fail to set the name atom:
            # catwm, fvwm, dwm, 2bwm, monster, wmaker and sowm [mine! ;)].
            #
            # The final downside to this approach is that it does _not_
            # support Wayland environments. The only solution which supports
            # Wayland is the 'ps' parsing mentioned below.
            #
            # A more naive implementation is to parse the last line of
            # '~/.xinitrc' to extract the second white-space separated
            # element.
            #
            # The issue with an approach like this is that this line data
            # does not always equate to the name of the window manager and
            # could in theory be _anything_.
            #
            # This also fails when the user launches xorg through a display
            # manager or other means.
            #
            #
            # Another naive solution is to parse 'ps' with a hardcoded list
            # of window managers to detect the current window manager (based
            # on what is running).
            #
            # The issue with this approach is the need to hardcode and
            # maintain a list of known window managers.
            #
            # Another issue is that process names do not always equate to
            # the name of the window manager. False-positives can happen too.
            #
            # This is the only solution which supports Wayland based
            # environments sadly. It'd be nice if some kind of standard were
            # established to identify Wayland environments.
            #
            # pfetch's goal is to remain _simple_, if you'd like a "full"
            # implementation of window manager detection use 'neofetch'.
            #
            # Neofetch use a combination of 'xprop' and 'ps' parsing to
            # support all window managers (including non-conforming and
            # Wayland) though it's a lot more complicated!

            # Don't display window manager if X isn't running.
            [ "$DISPLAY" ] || return

            # This is a two pass call to xprop. One call to get the window
            # manager's ID and another to print its properties.
            has xprop && {
                # The output of the ID command is as follows:
                # _NET_SUPPORTING_WM_CHECK: window id # 0x400000
                #
                # To extract the ID, everything before the last space
                # is removed.
                id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK)
                id=${id##* }

                # The output of the property command is as follows:
                # _NAME 8t
                # _NET_WM_PID = 252
                # _NET_WM_NAME = "bspwm"
                # _NET_SUPPORTING_WM_CHECK: window id # 0x400000
                # WM_CLASS = "wm", "Bspwm"
                #
                # To extract the name, everything before '_NET_WM_NAME = \"'
                # is removed and everything after the next '"' is removed.
                wm=$(xprop -id "$id" -notype -len 25 -f _NET_WM_NAME 8t)
            }

            # Handle cases of a window manager _not_ populating the
            # '_NET_WM_NAME' atom. Display nothing in this case.
            case $wm in
                (*'_NET_WM_NAME = '*)
                    wm=${wm##*_NET_WM_NAME = \"}
                    wm=${wm%%\"*}
                ;;

                (*)
                    # Fallback to checking the process list
                    # for the select few window managers which
                    # don't set '_NET_WM_NAME'.
                    while read -r ps_line; do
                        case $ps_line in
                            (*catwm*)     wm=catwm ;;
                            (*fvwm*)      wm=fvwm ;;
                            (*dwm*)       wm=dwm ;;
                            (*2bwm*)      wm=2bwm ;;
                            (*monsterwm*) wm=monsterwm ;;
                            (*wmaker*)    wm='Window Maker' ;;
                            (*sowm*)      wm=sowm ;;
							(*penrose*)   wm=penrose ;;
                        esac
                    done <<-EOF
                        $(ps x)
					EOF
                ;;
            esac
        ;;
    esac

    log wm "$wm" >&6
}


get_de() {
    # This only supports Xorg related desktop environments though
    # this is fine as knowing the desktop environment on Windows,
    # macOS etc is useless (they'll always report the same value).
    #
    # Display the value of '$XDG_CURRENT_DESKTOP', if it's empty,
    # display the value of '$DESKTOP_SESSION'.
    log de "${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}" >&6
}

get_shell() {
    # Display the basename of the '$SHELL' environment variable.
    log shell "${SHELL##*/}" >&6
}

get_editor() {
    # Display the value of '$VISUAL', if it's empty, display the
    # value of '$EDITOR'.
    editor=${VISUAL:-"$EDITOR"}

    log editor "${editor##*/}" >&6
}

get_palette() {
    # Print the first 8 terminal colors. This uses the existing
    # sequences to change text color with a sequence prepended
    # to reverse the foreground and background colors.
    #
    # This allows us to save hardcoding a second set of sequences
    # for background colors.
    #
    # False positive.
    # shellcheck disable=2154
    {
        esc SGR 7
        palette="$e$c1 $c1 $c2 $c2 $c3 $c3 $c4 $c4 $c5 $c5 $c6 $c6 "
        esc SGR 0
        palette="$palette$e"
    }

    # Print the palette with a new-line before and afterwards but no seperator.
    printf '\n' >&6
    log "$palette
        " " " " " >&6
}

