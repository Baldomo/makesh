#!/usr/bin/env bash

set -eo pipefail

_makesh_dir="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
_enable_shellcheck=1
_output_dir="$(pwd)"
_output_name="make.sh"

source "$_makesh_dir"/message.sh
source "$_makesh_dir"/parseopts.sh
source "$_makesh_dir"/util.sh

_usage() {
    cat <<EOF
./$(basename "$0") - generate your very own make.sh

Usage: $0 [options]
  Options:
    -s
    --no-shellcheck
        disable generation of a .shellcheckrc file with useful
        defaults to make your make.sh script shellcheck-compliant. 

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
    # Activate terminal colors
    msg::colorize

    # Parse command line flags
    OPT_SHORT="d:hn:s"
    OPT_LONG=("dir:" "help" "name:" "no-shellcheck")
    if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
        msg::die "Error parsing command line. Use --help to see CLI usage."
    fi
    set -- "${OPTRET[@]}"
    unset OPT_SHORT OPT_LONG OPTRET

    while true; do
        case "$1" in
            -d|--dir)
                shift; _output_dir="$(util::realpath "$1")" ;;
            -n|--name)
                shift; _output_name="$1" ;;
            -h|--help)
                _usage; exit ;;
            -s|--no-shellcheck)
                _enable_shellcheck=0 ;;
            --)
                shift; break 2 ;;
        esac
        shift
    done

    # Try looking for the library in output directory
    if [[ ! "$_makesh_dir" = "$_output_dir"/* ]]; then
        msg::warning "makesh is not a submodule in this directory: %s" "$_output_dir"
    fi

    # Calculate makesh library path relative to the output directory
    _relative_makesh_dir="${_makesh_dir#"$_output_dir/"}"
    msg::msg "makesh library found at: $_relative_makesh_dir"

    # Generate .shellcheckrc
    if (( _enable_shellcheck )); then
        cat <<EOF > "$_output_dir/.shellcheckrc"
# Don't highlight unreachable code (SC2317)
disable=SC2317

# Enable following external files when sourcing
external-sources=true
EOF
        msg::msg "generated Shellcheck config: $_output_dir/.shellcheckrc"
    fi

    # Write the actual make.sh script
    cat <<EOF > "$_output_dir/$_output_name"
#!/usr/bin/env bash
makesh_lib_dir=$_makesh_dir
source "\$makesh_lib_dir"/lib.sh
source "\$makesh_lib_dir"/message.sh

#:(all) Help for the default target
make::all() {
    msg::msg "Hello! Check out the README!"
}

source "\$makesh_lib_dir"/runtime.sh
EOF

    # Make the make.sh runnable
    chmod +x "$_output_dir/$_output_name"
    msg::msg "generated script: $_output_dir/$_output_name"
}