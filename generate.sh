#!/usr/bin/env bash

set -eo pipefail

_makesh_dir="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
_enable_shellcheck=1
_output_dir="$(pwd)"
_output_name="make"

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
        Defaults to "make".

    -d <directory>
    --dir <directory>
        specify a directory in which to deploy the generated script.

    -h, --help
        display this help message.
EOF
}

# Generates a makesh script in the given file path (directory AND file)
# $1 : the output file path
_generate_script() {
    cat <<EOF > "$1"
#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
[[ \$(git submodule status makesh 2>/dev/null) =~ ^- ]] && \\
    git submodule update --remote --init makesh
source makesh/lib.sh
source makesh/message.sh

#:(all) Help for the default target
make::all() {
    msg::msg "Hello! Check out the README!"
}

source makesh/runtime.sh
EOF

    # Make the script runnable
    chmod +x "$_output_dir/$_output_name"
    msg::msg "generated script: $_output_dir/$_output_name"
}

# Generates a .shellcheckrc in the given file path (directory AND file)
# $1 : the output file path
_generate_shellcheckrc() {
    cat <<EOF > "$1"
# Don't highlight unreachable code (SC2317)
disable=SC2317

# Enable following external files when sourcing
external-sources=true

# Look for files in ./$_makesh_dir
source-path=$_makesh_dir
EOF
    msg::msg "generated Shellcheck config: $_output_dir/.shellcheckrc"
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
        # If the file already exists, ask the user to overwrite
        if [ -f "$_output_dir/.shellcheckrc" ]; then
            msg::ask ".shellcheckrc already exists, overwrite? [y/N] "
            read -r _reply
            _reply="${_reply:-N}"
            case $_reply in
                [Yy]) _generate_shellcheckrc "$_output_dir/.shellcheckrc" ;;
                [Nn]) msg::msg2 "Skipped generation of .shellcheckrc" ;;
                *) msg::die "Invalid response \"$_reply\"" ;;
            esac
        else
            _generate_shellcheckrc "$_output_dir/.shellcheckrc"
        fi
    fi

    # Write the actual makesh script. If the file already exists, ask the user 
    # to overwrite
    if [ -f "$_output_dir/$_output_name" ]; then
        msg::ask "makesh script already exists, overwrite? [y/N] "
        read -r _reply
        _reply="${_reply:-N}"
        case $_reply in
            [Yy]) _generate_script "$_output_dir/$_output_name" ;;
            [Nn]) msg::msg2 "Skipped generation of makesh script" ;;
            *) msg::die "Invalid response \"$_reply\"" ;;
        esac
    else
        _generate_script "$_output_dir/$_output_name"
    fi
}