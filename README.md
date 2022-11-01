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
  - [`runtime.sh`](#runtimesh)
  - [`message.sh`](#messagesh)
  - [`parseopts.sh`](#parseoptssh)

## Installation
`makesh` is built to be used as a git submodule for easy update and usage inside a bigger project/repository.

```shell
$ git submodule add https://github.com/Baldomo/makesh.git
$ git submodule update --init
```

You can update your submodule to the latest version with

```shell
$ git submodule update --remote
```

or using the utility function

```shell
$ ./make.sh --update
```

## Usage
To start using `makesh` after placing the submodule in the `makesh` directory, just run

```shell
$ makesh/generate.sh
```
> **Note:** see `makesh/generate.sh --help` for more information

This will create a simple `make.sh` file in your current directory (using `pwd`) with the basic imports and a sample target.
You will only need to write your build targets as explained in the rest of the documentation, `makesh` will take care of the CLI and utilities.

You can run a target by calling

```shell
$ ./make.sh <target>
```

or, without specifying a target, `make::all` will be called

```shell
$ ./make.sh
```

### Writing your targets
Targets are to be defined before importing `runtime.sh`. Each "target" is a Bash function which:
1. has a name starting with `make::`
2. can produces files and skip running if files are already present
3. can ignore present files and run anyway ("force")
4. can call other targets before (or after) doing whatever it needs to do
5. can return and be skipped arbitrarily (see API)
6. uses utility functions provided by `makesh`
7. provides its own documentation with special comment syntax

For example:

```bash
#:(your_target) First line of documentation for your_target
#:(your_target) Second line of documentation  (7)
make::your_target() {                       # (1)
    lib::check_file "build-artifact.o"      # (2) and (3)
    lib::requires "other_target"            # (4)
    [[ -f "yourfile" ]] && lib::return      # (5)
    # Using "lib::" functions implies (6)
}
```

> Keep in mind that the `make::all` target can be executed by not passing any target name to the `make.sh` script, as mentioned above.

### CLI
`runtime.sh` will provide a simple CLI that can:
- run targets
- set the "force" with which to call a target (to make it run even if it's not needed)
- show documentation for a target
- show documentation and usage information for itself
- check if a called target exists or not

## API documentation

> **WARNING**: the API is very prone to breaking changes and incomplete documentation. It's a work in progress, after all.

### `generate.sh`
Simple shell script which generates a `make.sh` example file in your root project directory (or an arbitrary directory).
Get more information with

```shell
$ makesh/generate.sh --help
```

---

### `lib.sh`
Contains the fundamental functions and variables provided by `makesh` to write your targets. 
The code is fairly well-documented, reading it directly is recommended.

#### `lib::check_dir`
Break from current target if directory `$1` exists. Does not support wildcards. Can accept relative paths.

Usage examples:
```bash
lib::check_dir "some_dir"
```

#### `lib::check_file`
Break from current target if file `$1` exists. Does not support wildcards. Can accept relative paths.

Usage examples:
```bash
lib::check_file "some_dir/some_file"
```

#### `lib::requires`
Run another target before the caller, passing `$makesh_force` decreased by 1.
This lets you have granular control over the depth to which propagate --force to the called targets. Will also forward all extra arguments to the required target.

Usage examples:
```bash
lib::requires "other_target"
```

#### `lib::return`
Exits from the current target (and *only* the current target) unconditionally. Can be used to exit on arbitrary rules, for example:

```bash
if [[ "test" = "test" ]]; then
    lib::return "optional message"
fi
```

Will basically resume execution after skipping a single target, in short.

---

### `runtime.sh`
Contains code for the main entrypoint of the generated `make.sh` script. Does not export functions. Generates output for `--help` automatically and parses command line flags.

---

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

---

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