#!/usr/bin/env bash

source "$makesh_lib_dir"/message.sh
source "$makesh_lib_dir"/parseopts.sh
source "$makesh_lib_dir"/lib.sh

# Print usage
_usage() {
    local _targets
    _targets=$(declare -F | awk '{print $NF}' | sed -nE "s/(make::)(.*)$/\2/p" | sort | tr '\n' ' ')
    cat <<EOF
./$(basename "$0") - makesh-enabled build script

Usage: $0 [options] <target>
  Targets: $_targets

  Options:
    -f, --force    
        force the target to run even if files have already been built.
        Can be called multiple (N) times and will set \$makesh_force to N, e.g.:
            ./$(basename "$0") -fffff

    --update
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
    msg::msg "./make.sh $1"
    # Print all lines with plain()
    IFS=$'\n'; for _line in $_help; do
        msg::plain "$_line"
    done
}

{
    # Colors
    msg::colorize

    # Root is bad
    if [[ "$EUID" = 0 ]]; then
        msg::die "Don't run this script as root!"
    fi

    # Parse command line options
    OPT_SHORT="fh"
    OPT_LONG=("force" "help" "update")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::die "Error parsing command line"
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    declare makesh_help makesh_update
    while true; do
        case "$1" in
            -f|--force) (( makesh_force++ )) ;;
            -h|--help)  makesh_help=1 ;;
            --update)   makesh_update=1 ;;
            --)         shift; break 2 ;;
        esac
        shift
    done

    # No targets were passed from command line
    if [[ "$#" = 0 ]]; then
        # Allow calling just --help
        if (( makesh_help )); then
            _usage
            exit 0
        fi

        # Update git submodules if --update was used
        if (( makesh_update )); then
            git submodules update --remote
            exit 0
        fi

        # Otherwise, error
        msg::error "Target not specified! Use --help for more information."
        _usage
        exit 1
    fi

    # "help" is not a target but we know what the user meant
    if [[ "$1" = "help" ]]; then
        msg::error "Target 'help' does not exist (use --help)! Showing help anyways"
        _usage
        exit 1
    fi

    # Exit if target does not exist (checks if function is defined in this script)
    if ! declare -F -- make::"$1" >/dev/null; then
        msg::error "Uknown target: $1"
        _usage
        exit 1
    fi

    # Show help for target if --help <target> was used
    if (( makesh_help )); then
        _target_help "$1"
        exit 0
    fi

    # Run the actual target
    if [[ $makesh_force -gt 1 ]]; then
        msg::msg "Running target $1 at full force"
    else
        msg::msg "Running target $1"
    fi
    make::"$1"
    exit 0
}