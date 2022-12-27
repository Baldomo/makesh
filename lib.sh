#!/usr/bin/env bash

# shellcheck disable=SC2034
# The absolute path to the root make script in the project directory
makesh_script="$(realpath "$0")"
# shellcheck disable=SC2034
# The absolute path of the directory of makesh_script (the project directory)
makesh_script_dir="$(realpath "$(dirname "$0")")"
# shellcheck disable=SC2034
# The absolute path of the directory of the makesh library
makesh_lib_dir="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"
# Disables the file change cache if set to 0 (zero)
makesh_enable_cache=1
# Internal variable to keep track of how many --force were used
makesh_force=0

source "$makesh_lib_dir"/cache.sh
source "$makesh_lib_dir"/message.sh

# Quick and dirty platform-indipendent realpath
# $1 : a relative path
_realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

# Checks changes for a set of files by comparing the last modified time of the
# file to an empty file inside a temporary cache in /tmp or $TMPDIR (if set).
# If the file in the project directory is older than the cache, the target is
# not executed.
lib::needs_changes() {
    # Run the target unconditionally if cache is disabled
    if (( ! makesh_enable_cache )); then
        return
    fi

    # Try to initialize the project cache
    local _cache_dir
    if ! _cache_dir=$(_setup_cache_dir "$makesh_script_dir"); then
        # If that fails, give a warning and run the target anyways
        msg::warning "Cannot access project cache!"
        return
    fi

    # Iterate over the given files
    for _file in "$@"; do
        if [[ $_file =~ \.\. ]] && [[ $_file =~ \./ ]]; then
            msg::msg2 "File path %s contains invalid redirections (./ or ../), skipping" "$_file"
            continue
        fi

        if [[ "$_file" -nt "$_cache_dir/$_file" ]]; then
            touch "$_cache_dir/$_file"
            return
        fi
    done

    lib::return "No changes detected for given files, exiting from target."
}

# Checks existence of a directory.
# $1 : directory path, can be relative
lib::check_dir() {
    if [ -d "$(_realpath "$1")" ] && (( ! makesh_force )); then
        lib::return "directory $1 already exists"
    fi
}

# Checks existence of a file.
# $1 : file path, can be relative
lib::check_file() {
    if [ -f "$(_realpath "$1")" ] && (( ! makesh_force )); then
        lib::return "file $1 already exists"
    fi
}

# Run another target before the caller, decreasing $makesh_force by 1.
# This lets the user have granular control over the depth to which propagate
# --force to the called targets. Will also forward all extra arguments to the
# required target.
lib::requires() {
    makesh_force=$(( makesh_force > 0 ? makesh_force-1 : 0 ))

    # If the given target name does not start with `make::` but a valid target
    # exists when `make::` is prefixed to the name, run it
    if declare -F -- make::"$1" >/dev/null; then
        make::"$1" "${@:2}"
        return
    fi

    # If the given target exists, run it as is
    if declare -F -- "$1" >/dev/null; then
        if [[ ! "$1" =~ ^(make::) ]]; then
            msg::warning "(lib::requires) Non-target function detected! Be careful."
        fi
        "$1" "${@:2}"
        return
    fi

    # Exit with error if target still wasn't found
    msg::die "Unknown target: $1"
}

# Unconditionally returns from current target.
# $1 : string, message to be displayed before returning (uses msg::warn)
lib::return() {
    [[ $# -gt 0 ]] && msg::warning "$@"
    trap 'trap "shopt -u extdebug; trap - DEBUG; return 0" DEBUG; return 2' DEBUG
    shopt -s extdebug
    return
}