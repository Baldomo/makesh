#!/usr/bin/env bash

set -eo pipefail

_script="$(realpath "$0")"
_makesh_dir="$(dirname "$_script")"
_output_dir="$(pwd)"

source "$_makesh_dir"/message.sh
source "$_makesh_dir"/parseopts.sh

_usage() {
    cat <<EOF
./$(basename "$0") - generate your very own make.sh

Usage: $0 [options]
  Options:
    -d <directory>
    --dir <directory>    
        specify a directory in which to deploy the generated script.

    -h, --help    
        display this help message.
EOF
}

{
    msg::colorize

    OPT_SHORT="dh"
    OPT_LONG=("dir" "help")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::die "Error parsing command line"
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    while true; do
        case "$1" in
            -d|--dir)   shift; _output_dir="$(realpath "$1")" ;;
            -h|--help)  _usage; exit ;;
            --)         shift; break 2 ;;
        esac
        shift
    done

    if [[ ! "$_makesh_dir" = "$_output_dir"/* ]]; then
        msg::die "makesh is not a submodule in this directory: %s" "$_output_dir"
    fi

    _relative_makesh_dir="$(realpath --relative-to "$_output_dir" "$_makesh_dir")"
    msg::msg "Relative makesh dir: $_relative_makesh_dir"
    msg::msg "make.sh output dir: $_output_dir"

    cat <<EOF > "$_output_dir"/make.sh
#!/usr/bin/env bash
source $_relative_makesh_dir/lib.sh
source $_relative_makesh_dir/message.sh

#:(all) Help for the default target
make::all() {
    msg::msg "Hello! Check out the README!"
}

source $_relative_makesh_dir/runtime.sh
EOF

    chmod +x "$_output_dir"/make.sh
}