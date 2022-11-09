#!/usr/bin/env bash

set -eo pipefail

_script="$(realpath "$0")"
_makesh_dir="$(dirname "$_script")"
_output_dir="$(pwd)"
_output_name="make.sh"

source "$_makesh_dir"/message.sh
source "$_makesh_dir"/parseopts.sh

_usage() {
    cat <<EOF
./$(basename "$0") - generate your very own make.sh

Usage: $0 [options]
  Options:
    -n <filename>
    --name <filename>
        change the name of the generated file.
        Defaults to "make.sh".

    -d <directory>
    --dir <directory>
        specify a directory in which to deploy the generated script.

    -h, --help
        display this help message.
EOF
}

{
    msg::colorize

    OPT_SHORT="d:hn:"
    OPT_LONG=("dir:" "help" "name:")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::error "Error parsing command line."
        _usage
        exit 1
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    while true; do
        case "$1" in
            -n|--name)  shift; _output_name="$1" ;;
            -d|--dir)   shift; _output_dir="$(realpath "$1")" ;;
            -h|--help)  _usage; exit ;;
            --)         shift; break 2 ;;
        esac
        shift
    done

    # Try looking for the library in current directory
    if [[ ! "$_makesh_dir" = "$_output_dir"/* ]]; then
        msg::die "makesh is not a submodule in this directory: %s" "$_output_dir"
    fi

    _relative_makesh_dir="$(realpath --relative-to "$_output_dir" "$_makesh_dir")"
    msg::msg "makesh library found at: $_relative_makesh_dir"
    msg::msg "generated script: $_output_dir/$_output_name"

    cat <<EOF > "$_output_dir"/"$_output_name"
#!/usr/bin/env bash
source $_relative_makesh_dir/lib.sh
source $_relative_makesh_dir/message.sh

#:(all) Help for the default target
make::all() {
    msg::msg "Hello! Check out the README!"
}

source $_relative_makesh_dir/runtime.sh
EOF

    chmod +x "$_output_dir"/"$_output_name"
}