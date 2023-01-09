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
# shellcheck disable=SC2034
# The absolute path of the file cache directory
makesh_cache_dir="$makesh_lib_dir/cache"
# Disables the file change cache if set to 0 (zero)
makesh_enable_cache=1
# Disables clearing the cache automatically when calling the make::clean
# target if set to 0 (zero)
makesh_enable_cache_autoclean=1
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

    # Iterate over the given files
    local _file_real _file_cache _file_cache_dir
    local _non_existant=()
    for _file in "$@"; do
        _file_real=$(util::realpath "$_file")

        # Do not check non-existing files
        if [ ! -f "$_file_real" ]; then
            _non_existant+=("$_file_real")
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
        _file_cache="$makesh_cache_dir/${_file_real#"$makesh_script_dir/"}"
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
    if (( ${#_non_existant[@]} )); then
        msg::warning "These files do not exist, skipping:"
        msg::plain "%s" "${_non_existant[@]}"
    fi

    lib::return "No changes detected for given files, exiting from target."
}

# Deletes the file cache directory, but only if it is somewhere inside the
# project directory
lib::clean_cache() {
    if [[ ! $(util::realpath "$makesh_cache_dir") = $(util::realpath "$makesh_script_dir")/* ]]; then
        msg::die "Can only clean cache (%s) safely if it is inside the project directory (%s)" \
            "$makesh_cache_dir" \
            "$makesh_script_dir"
    fi

    # Warn the user if the cache was already deleted
    if [ ! -d "$makesh_cache_dir" ]; then
        msg::warning "Cache was already cleaned (%s)" "$makesh_cache_dir"
        return
    fi

    msg::msg "Cleaning makesh cache"
    rm -rf "$makesh_cache_dir"
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