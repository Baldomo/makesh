#!/usr/bin/env bash

# shellcheck disable=SC2034
# The absolute path to the root make script in the project directory
makesh_script="$(realpath "$0")"
# shellcheck disable=SC2034
# The absolute path of the directory of makesh_script (the project directory)
makesh_script_dir="$(realpath "$(dirname "$0")")"
# shellcheck disable=SC2034
# The absolute path of the directory of the makesh library
makesh_lib_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd )"
# Internal variable to keep track of how many --force were used
makesh_force=0

source "$makesh_lib_dir"/message.sh

# Checks existence of a directory
# $1 : directory path, can be relative
# $2 : (optional) command to execute if condition is true but makesh_force is zero
lib::check_dir() {
    if [ -d "$(realpath "$1")" ] && (( ! makesh_force )); then
        lib::return "directory $1 already exists"
    fi
}

# Checks existence of file
# $1 : file path, can be relative
# $2 : (optional) command to execute if condition is true but makesh_force is zero
lib::check_file() {
    if [ -f "$(realpath "$1")" ] && (( ! makesh_force )); then
        lib::return "file $1 already exists"
    fi
}

# Run another target before the caller, passing $makesh_force decreased by 1.
# This lets the user have granular control over the depth to which propagate
# --force to the called targets. Will also forward all extra arguments to the
# required target
lib::requires() {
    makesh_force=$(( makesh_force > 0 ? makesh_force-1 : 0 ))
    if ! declare -F -- make::"$1" >/dev/null; then
        if declare -F -- "$1" >/dev/null; then
            if [[ ! "$1" =~ ^(make::) ]]; then
                msg::warning "(lib::requires) Non-target function detected! Be careful."
            fi
            # shift
            "$1" "${@:2}"
            return
        fi
        msg::error "Uknown target required: $1"
        exit 1
    fi
    # shift
    make::"$1" "${@:2}"
}

# Unconditionally returns from current target
# $1 : string, message top be displayed before returning (uses msg::warn)
lib::return() {
    [[ $# -gt 0 ]] && msg::warning "$@"
    trap 'trap "shopt -u extdebug; trap - DEBUG; return 0" DEBUG; return 2' DEBUG
    shopt -s extdebug
    return
}