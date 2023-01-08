#!/usr/bin/bash

# Detects and uses the platform's md5 utility.
# Returns 1 in case of errors and 0 otherwise.
# Outputs the md5 sum of the given data.
# $1 : a string to convert to md5 sum
util::md5() {
    if builtin command -v md5 > /dev/null 2>&1; then
        _sum=$(md5 "$@")
        echo "${_sum##* }"
        return 0
    elif builtin command -v md5sum > /dev/null 2>&1; then
        _sum=$(md5sum "$@")
        echo "${_sum%% *}"
        return 0
    elif builtin command -v gmd5sum > /dev/null 2>&1; then
        _sum=$(gmd5sum "$@")
        echo "${_sum%% *}"
        return 0
    else
        for _path in /usr/gnu/bin /opt/csw/bin /sbin /bin /usr/bin /usr/sbin; do
            if [ -x "${_path}/md5" ]; then
                _sum=$(${_path}/md5 "$@")
                echo "${_sum##* }"
                return 0
            elif [ -x "${_path}/md5sum" ]; then
                _sum=$(${_path}/md5sum "$@")
                echo "${_sum%% *}"
                return 0
            elif [ -x "${_path}/gmd5sum" ]; then
                _sum=$(${_path}/gmd5sum "$@")
                echo "${_sum%% *}"
                return 0
            fi
        done
    fi

    echo "Neither of md5sum, md5, gmd5sum found in the PATH"
    return 1
}

# Creates a cache directory under /tmp or $TMPDIR, given a project directory.
# Returns 1 in case of errors and 0 otherwise.
# Outputs the path of the cache directory.
# $1 : a directory
_setup_cache_dir() {
    local _cache_dir="/tmp/makesh"
    if [ -n "${TMPDIR+x}" ]; then
        _cache_dir="$TMPDIR"/makesh
    fi

    local _project_dir_sum
    if ! _project_dir_sum=$(echo "$1" | util::md5 -); then
        return 1
    fi

    local _project_dir="$_cache_dir/$_project_dir_sum"
    mkdir -p "$_project_dir"
    echo "$_project_dir"
    return 0
}

# Resolve all symlinks to the given path, then output the canonicalized result.
# $1 : a file path
util::realpath() {
    util::canonicalize_path "$(util::resolve_symlinks "$1")"
}

# If the given path is a symlink, follow it as many times as possible; output 
# the path of the first non-symlink found.
# $1 : a file path
util::resolve_symlinks() {
    _resolve_symlinks "$1"
}

_resolve_symlinks() {
    _assert_no_path_cycles "$@" || return

    local dir_context path
    if path=$(readlink -- "$1"); then
        dir_context=$(dirname -- "$1")
        _resolve_symlinks "$(_prepend_dir_context_if_necessary "$dir_context" "$path")" "$@"
    else
        printf '%s\n' "$1"
    fi
}

_prepend_dir_context_if_necessary() {
    if [ "$1" = . ]; then
        printf '%s\n' "$2"
    else
        _prepend_path_if_relative "$1" "$2"
    fi
}

_prepend_path_if_relative() {
    case "$2" in
        /* ) printf '%s\n' "$2" ;;
         * ) printf '%s\n' "$1/$2" ;;
    esac
}

_assert_no_path_cycles() {
    local target path

    target=$1
    shift

    for path in "$@"; do
        if [ "$path" = "$target" ]; then
            return 1
        fi
    done
}

# Output absolute path that the given path refers to, resolving any relative
# directories (., ..) and any symlinks in the path's ancestor directories.
# $1 : a file path
util::canonicalize_path() {
    if [ -d "$1" ]; then
        _canonicalize_dir_path "$1"
    else
        _canonicalize_file_path "$1"
    fi
}

_canonicalize_dir_path() {
    (cd "$1" 2>/dev/null && pwd -P)
}

_canonicalize_file_path() {
    local dir file
    dir=$(dirname -- "$1")
    file=$(basename -- "$1")
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$file")
}