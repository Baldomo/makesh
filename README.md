# make.sh <!-- omit in toc -->
> This project isn't really meant to be serious or functional in any way, but it does do its thing.

`makesh` is a simple requirement-based task runner similar to GNU Make, minus the C-oriented build system and using `include` to import other target files (not yet). `makesh` is also written in Bash.

### Table of contents
- [Installation](#installation)
- [Usage](#usage)
  - [Writing your targets](#writing-your-targets)
  - [CLI](#cli)
- [API documentation](#api-documentation)
  - [`generate.sh`](#generatesh)
  - [`lib.sh`](#libsh)
    - [`lib::check_bool`](#libcheck_bool)
    - [`lib::check_dir`](#libcheck_dir)
    - [`lib::check_file`](#libcheck_file)
    - [`lib::requires`](#librequires)
  - [`runtime.sh`](#runtimesh)
  - [`message.sh`](#messagesh)
    - [`msg::ask`](#msgask)
    - [`msg::die`](#msgdie)
    - [`msg::error`](#msgerror)
    - [`msg::msg`](#msgmsg)
    - [`msg::msg2`](#msgmsg2)
    - [`msg::plain`](#msgplain)
    - [`msg::plainerror`](#msgplainerror)
    - [`msg::warning`](#msgwarning)
    - [`msg::colorize`](#msgcolorize)
  - [`parseopts.sh`](#parseoptssh)

## Installation
`makesh` is built to be used as a git submodule for easy update and usage inside a bigger project/repository.

```
$ git submodule add https://github.com/Baldomo/makesh
$ git submodule update --init
```

## Usage
To start using `makesh` after placing the submodule in the `makesh` directory, just run

```
$ makesh/generate.sh
```
> **Note:** see `makesh/generate.sh --help` for more information

This will create a simple `make.sh` file in your current directory (using `pwd`) with the basic imports and a sample target.
You will only need to write your build targets as explained in the rest of the documentation, `makesh` will take care of the CLI and utilities.

### Writing your targets
Targets are to be defined before importing `runtime.sh`. Each "target" is a Bash function which:
1. has a name starting with `make::`
2. can produces files and skip running if files are already present
3. can ignore present files and run anyway ("force")
4. can call other targets before (or after) doing whatever it needs to do
5. can depend on boolean conditions (see API)
6. uses utility functions provided by `makesh`
7. provides its own documentation with special comment syntax

For example:

```bash
#:(your_target) First line of documentation for your_target
#:(your_target) Second line of documentation  (7)
make::your_target() {                       # (1)
    lib::check_file "build-artifact.o"      # (2) and (3)
    lib::requires "other_target"            # (4)
    lib::check_boolean [[ -f "yourfile" ]]  # (5)
    # Using "lib::" functions implies (6)
}
```

### CLI
`runtime.sh` will provide a simple CLI that can:
- run targets
- set the "force" with which to call a target (to make it run even if it's not needed)
- show documentation for a target
- show documentation and usage information for itself
- check if a called target exists or not

## API documentation

### `generate.sh`
Simple shell script which generates a `make.sh` example file in your root project directory (or an arbitrary directory).
Get more information with

```
$ makesh/generate.sh --help
```

### `lib.sh`
Contains the fundamental functions and variables provided by `makesh` to write your targets. 
The code is fairly well-documented, reading it directly is recommended.

#### `lib::check_bool`
<!-- TODO: documentation -->

#### `lib::check_dir`
<!-- TODO: documentation -->

#### `lib::check_file`
<!-- TODO: documentation -->

#### `lib::requires`
Run another target before the caller, passing `$makesh_force` decreased by 1.
This lets you have granular control over the depth to which propagate --force to the called targets. Will also forward all extra arguments to the required target.

Usage examples:
```bash
lib::requires "other_target"
```

### `runtime.sh`
<!-- TODO: documentation -->

### `message.sh`
A modified version of `/usr/share/makepkg/util/message.sh` from Arch's `makepkg` packaging software.

Contains function for pretty formatted output. All functions are `printf`-like (first parameter is a string with formatting instructions, all other parameters are printed as per the instructions), for example:

```bash
msg::msg "Simple single message"

msg::error "Docker container not started: %s" "$container_name"

msg::die "Critical error during execution"
```

#### `msg::ask`
Useful for asking user input, will not print a newline (`\n`) after the text. 
Output format:
```
:: Your text?
```

#### `msg::die`
Calls `msg::error` then `exit 1`, so works the same as that function (see below)

#### `msg::error`
Used to print errors, prints to `stderr`
Output format:
```
==> ERROR: (<target name>) Your text
```

#### `msg::msg`
Used to print generic messages.
Output format:
```
==> Your text
```

#### `msg::msg2`
Used to print less important generic messages or second-level messages.
Output format:
```
  -> Your text
```

#### `msg::plain`
Primarily used to continue a previous message on a new line.
Output format:
```
    Your text
```

#### `msg::plainerror`
Primarily used to continue a previous error message on a new line, prints to `stderr`.
Output format:
```
    Your text
```

#### `msg::warning`
Used to print warnings, prints to `stderr`
Output format:
```
==> WARNING: Your text
```

#### `msg::colorize`
Activates output colorization if supported by the output terminal. Used internally.

### `parseopts.sh`
A modified version of `/usr/share/makepkg/util/parseopts.sh` from Arch's `makepkg` packaging software.
Contains a single function: `lib::parseopts`, see the file for actual documentation.

Example usage from `runtime.sh`:
```bash
OPT_SHORT="fh"
OPT_LONG=("force" "help")
if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
    msg::die "Error parsing command line"
fi
set -- "${OPTRET[@]}"
unset OPT_SHORT OPT_LONG OPTRET

declare makesh_help
while true; do
    case "$1" in
        -f|--force) (( makesh_force++ )) ;;
        -h|--help)  makesh_help=1 ;;
        --)         shift; break 2 ;;
    esac
    shift
done

# All remaining arguments are left in "$@"
```