#!/usr/bin/env bash

source "$makesh_lib_dir"/message.sh
source "$makesh_lib_dir"/parseopts.sh
source "$makesh_lib_dir"/lib.sh

# Prints script usage and defined targets
_usage() {
    local _targets
    _targets=$(compgen -A "function" | sed -nE "s/^make::(.*)$/\1/p" | sort | tr '\n' ' ')
    cat <<EOF
./$(basename "$0") - makesh-enabled build script

Usage: $0 [options] <target>
  Targets: $_targets

  Options:
    -f
    --force <N>
        force the target to run even if files have already been built.
        Can be called multiple (N) times and will set \$makesh_force to N, e.g.:
            ./$(basename "$0") -fffff
        Or, using the long flag:
            ./$(basename "$0") --force 5
    
    -l, --list
        shows a list of all defined targets and their help message, if present.

    -u, --update
        update makesh to the latest commit (updates git submodules).

    -v, --version
        prints the current version and other informations on makesh.

    -h, --help
        display this help message or target-specific help (--help <target>).
EOF
}

# Shows help/documentation for a specific target
# Documentation syntax (ignore first #):
# #:(<target name>) <documentation>
# #:(<target name>) <other line of documentation>
_target_help() {
    local _help
    # Get line with a specific comment and use it as documentation
    # Look for lines starting with `#:(<target>)`
    _help=$(sed -nE "s/^#:\(($1)\)\s+(.*)$/\2/p" "$makesh_script")
    msg::msg "make::%s" "$1"
    # Print all lines with plain()
    IFS=$'\n'; for _line in $_help; do
        msg::plain "%s" "$_line"
    done
}

# Lists targets and their help comments
_target_list() {
    msg::msg "Listing targets"
    _targets=$(compgen -A "function" | sed -nE "s/^make::(.*)$/\1/p")
    for _target in $_targets; do
        _target_help "$_target"
    done
}

# Returns true if the given function exists in the current scope
_is_func() {
    declare -F -- "$1" >/dev/null
}

# Prints formatted version information
_version() {
    msg::msg "Version"
    local _tag
    pushd "$makesh_lib_dir" >/dev/null || exit 1
    if _tag=$(git describe --exact-match 2>/dev/null); then
        msg::msg2 "Version: $_tag"
    fi
    msg::plain "%-10sr%s.%s" "Revision:" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
    msg::plain "%-10s%s" "Commit:" "$(git rev-parse HEAD)"
    msg::plain "%-10s%s" "Date:" "$(git show -s --format="%ci")"
    msg::plain "%-10s%s" "Branch:" "$(git rev-parse --abbrev-ref HEAD)"
    popd >/dev/null || exit 1
}

{
    # Colors
    msg::colorize

    # Root is bad
    if [ "$EUID" = 0 ]; then
        msg::die "Don't run this script as root!"
    fi

    # Parse command line options
    OPT_SHORT="fh?luv"
    OPT_LONG=("force:" "help?" "list" "update" "version")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::die "Error parsing command line. Use --help to see CLI usage."
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    declare makesh_help makesh_list makesh_update makesh_version
    while true; do
        case "$1" in
            -f)           (( makesh_force++ )) ;;
            --force)      shift; makesh_force="$1" ;;
            -h|--help)    makesh_help=1 ;;
            -l|--list)    makesh_list=1 ;;
            -u|--update)  makesh_update=1 ;;
            -v|--version) makesh_version=1 ;;
            --)           shift; break 2 ;;
        esac
        shift
    done

    # Exit if --force was given anything other than a number
    case $makesh_force in
        ''|*[!0-9]*) msg::die "Invalid value passed to --force: %s" "$makesh_force" ;;
    esac

    # No targets were passed from command line
    if [ "$#" = 0 ]; then
        if (( makesh_version )); then
            _version
            exit 0
        fi

        # Allow calling just --help
        if (( makesh_help )); then
            _usage
            exit 0
        fi

        # Show the target list
        if (( makesh_list )); then
            _target_list
            exit 0
        fi

        # Update git submodules if --update was used
        if (( makesh_update )); then
            git submodule update --remote
            exit 0
        fi

        # Suppose a make::all target exists. Set $1 to "all" to run it later
        set -- "all" "$@"

        # If make::all does not exist after all, print help and exit
        if ! _is_func make::all; then
            msg::error "Target not specified (and default target make::all not defined)!"
            _usage
            exit 1
        fi
    fi

    # Special targets
    case "$1" in
        # "help" is not a target but we know what the user meant
        # (unless make::help actually exists)
        help)
            if ! _is_func make::help; then
                msg::error "Target 'help' does not exist (use --help)! Showing help anyways."
                _usage
                exit 1
            fi
            ;;
        # Special case for make::clean, clean cache unless explicitly disabled.
        # Will also always run without errors, even if make::clean does not exist
        clean)
            # If a make::clean target does not exist, create one
            if ! _is_func make::clean; then
                # shellcheck disable=SC2317
                make::clean() {
                    (( makesh_enable_cache_autoclean )) && lib::clean_cache
                }
            else
                # Otherwise, just clean the cache before running it
                (( makesh_enable_cache_autoclean )) && lib::clean_cache
            fi
            ;;
        # Catch-all for normal targets
        *)
            # Exit if target does not exist (checks if function is defined)
            if ! _is_func make::"$1"; then
                msg::error "Unknown target: $1"
                # Give a tip if the given command line argument starts with "make::"
                [[ $1 = make::* ]] && msg::plain "Did you mean '%s'?" "${1#"make::"}"
                exit 1
            fi
            ;;
    esac

    # Show help for target if --help <target> was used
    if (( makesh_help )); then
        _target_help "$1"
        exit 0
    fi

    # Run the actual target
    if (( makesh_force )); then
        msg::msg "Running target make::$1 with %d force" "$makesh_force"
    else
        msg::msg "Running target make::$1"
    fi

    make::"$1"
    exit 0
}