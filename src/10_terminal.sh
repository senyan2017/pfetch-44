# Terminal output primitives: every escape sequence and every coloring
# decision pfetch makes goes through this module, so there is a single
# rendering path rather than ad-hoc sequences scattered across modules.
#
# Color & alignment model (the one place these rules are defined):
#
#   PF_COLOR  master switch. 1 = emit SGR color sequences (default),
#             0 = suppress them. Enforced once, in esc()'s SGR branch, so
#             disabling color never changes layout (cursor moves still run).
#   PF_COL1   info-name color   (default 4; auto-set from the ascii art's
#             accent color by get_ascii's read_ascii when left unset).
#   PF_COL2   info-data color   (default 9).
#   PF_COL3   title color       (default 1; also auto-derived from the art).
#   PF_ALIGN  fixed column for info data; when unset, $info_length (the
#             widest info name) is used so columns auto-align.
#
# Defaults are applied at the point of use via '${PF_COLn-default}' so that
# a value injected by read_ascii (for art-matched coloring) always wins.
#
# Wrapper around all escape sequences used by pfetch to allow for
# greater control over which sequences are used (if any at all).
esc() {
    case $1 in
        CUU) e="${esc_c}[${2}A" ;; # cursor up
        CUD) e="${esc_c}[${2}B" ;; # cursor down
        CUF) e="${esc_c}[${2}C" ;; # cursor right
        CUB) e="${esc_c}[${2}D" ;; # cursor left

        # text formatting
        SGR)
            case ${PF_COLOR:=1} in
                (1)
                    e="${esc_c}[${2}m"
                ;;

                (0)
                    # colors disabled
                    e=
                ;;
            esac
        ;;

        # line wrap
        DECAWM)
            case $TERM in
                (dumb | minix | cons25)
                    # not supported
                    e=
                ;;

                (*)
                    e="${esc_c}[?7${2}"
                ;;
            esac
        ;;
    esac
}

# Print a sequence to the terminal.
esc_p() {
    esc "$@"
    printf '%s' "$e"
}

# This is just a simple wrapper around 'command -v' to avoid
# spamming '>/dev/null' throughout this function. This also guards
# against aliases and functions.
has() {
    _cmd=$(command -v "$1") 2>/dev/null || return 1
    [ -x "$_cmd" ] || return 1
}

