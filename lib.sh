#!/usr/bin/env bash

# shellcheck disable=SC2034
# The absolute path of the directory of the makesh library
makesh_lib_dir="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &>/dev/null && pwd)"

source "$makesh_lib_dir"/message.sh
source "$makesh_lib_dir"/util.sh

# shellcheck disable=SC2034
# The absolute path to the root make script in the project directory
makesh_script="$(util::realpath "$0")"
# shellcheck disable=SC2034
# The absolute path of the directory of makesh_script (the project directory)
makesh_script_dir="$(util::realpath "$(dirname "$0")")"
# Disables the file change cache if set to 0 (zero)
makesh_enable_cache=1
# Internal variable to keep track of how many --force were used
makesh_force=0

# Checks changes for a set of files by comparing the last modified time of the
# file to an empty file inside a temporary cache in /tmp or $TMPDIR (if set).
# If the file in the project directory is older than the cache, the target is
# not executed. All non-existing files, or files/links which resolve to outside
# the project folder are ignored. Follows links.
# $1 : list of file paths, can be relative
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
    local _file_real _file_cache _file_cache_dir
    local _existing=()
    for _file in "$@"; do
        _file_real=$(util::realpath "$_file")

        # Do not check non-existing files
        if [ ! -f "$_file_real" ]; then
            _existing+=("$_file_real")
            continue
        fi

        # We deliberately skip files/links which redirect outside the project 
        # directory for a little more security when caching them below
        if [[ ! $(util::realpath "$_file") = $(util::realpath "$makesh_script_dir")/* ]]; then
            msg::msg2 "File %s redirects outside the project folder, skipping" "$_file"
            continue
        fi

        # Create a path with symlinks and redirects resolved, starting with the
        # cache folder and ending with the file path relative to the 
        # project root
        _file_cache="$_cache_dir/${_file_real#"$makesh_script_dir/"}"
        # Extract the directory structure from the above file
        _file_cache_dir="$(dirname "$_file_cache")"

        # Create directory structure if it does not exist
        if [ ! -d "$_file_cache_dir" ]; then
            mkdir -p "$_file_cache_dir"
        fi

        # Create the fake file in the cache folder
        if [[ "$_file" -nt "$_file_cache" ]]; then
            touch "$_file_cache"
            return
        fi
    done

    # Give warning for non-existing files (which have been ignored)
    if (( ${#_existing[@]} )); then
        msg::warning "These files do not exist, skipping:"
        msg::plain "%s" "${_existing[@]}"
    fi

    lib::return "No changes detected for given files, exiting from target."
}

# Checks existence of directories. Will exit from the current target if at least
# one of the given directories exists. Follows links.
# $1 : list of directory paths, can be relative
lib::check_dir() {
    for _dir in "$@"; do
        if [ -d "$(util::realpath "$_dir")" ] && (( ! makesh_force )); then
            lib::return "directory $_dir already exists"
        fi
    done
}

# Checks existence of files. Will exit from the current target if at least one
# of the given files exists. Follows links.
# $1 : list of file paths, can be relative
lib::check_file() {
    for _file in "$@"; do
        if [ -f "$(util::realpath "$_file")" ] && (( ! makesh_force )); then
            lib::return "file $_file already exists"
        fi
    done
}

# Run another target before the caller, decreasing $makesh_force by 1.
# This lets the user have granular control over the depth to which propagate
# --force to the called targets. Will also forward all extra arguments to the
# required target. Will interrup execution if the given target does not exist
# $1 : a valid target name, can omit 'make::'
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
    [ $# -gt 0 ] && msg::warning "$@"
    trap 'trap "shopt -u extdebug; trap - DEBUG; return 0" DEBUG; return 2' DEBUG
    shopt -s extdebug
    return
}