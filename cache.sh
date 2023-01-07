#!/usr/bin/env bash

# Detects and uses the platform's md5 utility.
# Returns 1 in case of errors and 0 otherwise.
# Outputs the md5 sum of the given data.
# $1 : a string to convert to md5 sum
_md5() {
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
    if ! _project_dir_sum=$(echo "$1" | _md5 -); then
        return 1
    fi

    local _project_dir="$_cache_dir/$_project_dir_sum"
    mkdir -p "$_project_dir"
    echo "$_project_dir"
    return 0
}