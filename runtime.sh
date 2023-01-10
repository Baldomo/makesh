#!/usr/bin/env bash

source "$makesh_lib_dir"/message.sh
source "$makesh_lib_dir"/parseopts.sh
source "$makesh_lib_dir"/lib.sh

# Print usage
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

{
    # Colors
    msg::colorize

    # Root is bad
    if [ "$EUID" = 0 ]; then
        msg::die "Don't run this script as root!"
    fi

    # Parse command line options
    OPT_SHORT="fh?lu"
    OPT_LONG=("force:" "help?" "list" "update")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::die "Error parsing command line. Use --help to see CLI usage."
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    declare makesh_help makesh_list makesh_update
    while true; do
        case "$1" in
            -f)          (( makesh_force++ )) ;;
            --force)     shift; makesh_force="$1" ;;
            -h|--help)   makesh_help=1 ;;
            -l|--list)   makesh_list=1 ;;
            -u|--update) makesh_update=1 ;;
            --)          shift; break 2 ;;
        esac
        shift
    done

    # Exit if --force was given anything other than a number
    case $makesh_force in
        ''|*[!0-9]*) msg::die "Invalid value passed to --force: %s" "$makesh_force" ;;
    esac

    # No targets were passed from command line
    if [ "$#" = 0 ]; then
        # Allow calling just --help
        if (( makesh_help )); then
            _usage
            exit 0
        fi

        if (( makesh_list )); then
            _target_list
            exit 0
        fi

        # Update git submodules if --update was used
        if (( makesh_update )); then
            git submodule update --remote
            exit 0
        fi

        # Maybe a make::all target exists? If so, run it
        if declare -F -- make::all >/dev/null; then
            if (( makesh_force )); then
                msg::msg "Running target make::all with %d force" "$makesh_force"
                # If at least one -f was passed to the CLI, increase it by one
                # to directly propagate it to the other targets called by 
                # make::all, so user won't need to use -ff (since one -f is 
                # consumed by running make::all)
                (( makesh_force++ ))
            else
                msg::msg "Running target make::all"
            fi
            make::all
            exit 0
        fi

        # Otherwise, error
        msg::error "Target not specified (and default target make::all not defined)!"
        _usage
        exit 1
    fi

    # Special targets
    case "$1" in
        # "help" is not a target but we know what the user meant
        # (unless make::help actually exists)
        help)
            if ! declare -F -- make::help >/dev/null; then
                msg::error "Target 'help' does not exist (use --help)! Showing help anyways."
                _usage
                exit 1
            fi
            ;;
        # Special case for make::clean, clean cache unless explicitly disabled.
        # Will also always run without errors, even if make::clean does not exist
        clean)
            (( makesh_enable_cache_autoclean )) && lib::clean_cache
            ;;
        # Catch-all for normal targets
        *)
            # Exit if target does not exist (checks if function is defined)
            if ! declare -F -- make::"$1" >/dev/null; then
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

    # If after all the checks the given target still does not exist (may be a
    # special target), just exit the script
    if ! declare -F -- make::"$1" >/dev/null; then
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