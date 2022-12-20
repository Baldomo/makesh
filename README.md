# make.sh <!-- omit in toc -->
`makesh` is a simple requirement-based task runner similar to GNU Make, minus the C-oriented build system. `makesh` is also written in Bash.

This project was born of necessity and many late hours wasted on writing files for Make and other such task runners, but it's not meant as a complete replacement. Compatibility with Bash versions older than 5.0 is not guaranteed.

### Table of contents
- [Installation](#installation)
- [Usage](#usage)
  - [Writing targets](#writing-targets)
  - [CLI](#cli)
- [Library](#library)
  - [`generate.sh`](#generatesh)
  - [`lib.sh`](#libsh)
  - [`runtime.sh`](#runtimesh)
  - [`message.sh`](#messagesh)
  - [`parseopts.sh`](#parseoptssh)

## Installation
`makesh` is built to be used as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for easy update and usage inside a bigger project/repository.

```terminal
$ git submodule add https://github.com/Baldomo/makesh.git
$ git submodule update --init
```

You can update `makesh` to the latest version with

```terminal
$ ./make.sh --update
```

which basically runs 

```terminal
$ git submodule update --remote --init
```

## Usage
To start using `makesh` after placing the submodule in your project directory, just run

```terminal
$ makesh/generate.sh
```
> **Note:** see `makesh/generate.sh --help` for more information and CLI options.

This will create a simple `make.sh` file in your current directory (using `pwd`) with the basic imports and a default target.
You will only need to write your build targets as explained in the rest of the documentation, `makesh` will take care of the CLI and utilities.

A `.shellcheckrc` will also be generated alongside the script with useful defaults for Shellcheck users (mainly to disable [SC2317](https://github.com/koalaman/shellcheck/wiki/SC2317)). This is the default behaviour but it can be disabled using the corresponding CLI flag.

You can run a target by calling

```terminal
$ ./make.sh <target>
```

or, without specifying a target, `make::all` will be called

```terminal
$ ./make.sh
```

### Writing targets
Targets are to be defined before importing `runtime.sh`. Each "target" is a Bash function which:
1. has a name starting with `make::`
2. can produces files and skip running if files are already present
3. can ignore present files and run anyway ("force", see [`$makesh_force`](#makesh_force))
4. can call other targets before (or after) doing whatever it needs to do
5. can return and be skipped arbitrarily (see API)
6. can use utility functions provided by `makesh`
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

You can also just source other files containing valid targets (and **just** the targets, no sourcing of `makesh` files) in your `make.sh` script and use them just the same as if they were in the main script. Note that `source` will not change the current working directory.

```bash
# scripts/utility.sh

make::utility() {
    msg::msg "Included target"
}
```

```bash
# make.sh

make::all() {
    source ./include.sh
    lib::requires make::utility
    msg::msg "Hello world!"
}
```

Running `./make.sh` will yield:
```
==> Running target make::all
==> Included target
==> Hello world!
```

### CLI
The CLI is provided automatically by sourcing `runtime.sh`. It can:
- run targets
- set the "force" with which to call a target (see [`$makesh_force`](#makesh_force))
- show documentation for a target
- show documentation and usage information for itself
- check if a called target exists or not

For more information and full usage, see
```terminal
$ ./make.sh --help
```

## Library

> ⚠️ The API is very prone to breaking changes, but the documentation will always be fairly extensive.

`makesh` provides a simple utility library in the form of `source`-able shell scripts. Generally, sourcing one of such files will add:
- functions prefixed by a sort of namespace like `lib::` or `msg::`
- variables prefixed by `makesh_`.

The "standard library" structure can be summed up as follows:

<table>
  <tbody>
    <tr>
      <th>File</th>
      <th>Functions</th>
      <th>Variables</th>
    </tr>
    <tr>
      <td><a href="#libsh"><code>lib.sh</code></a></td>
      <td><code>lib::*</code></td>
      <td>
        <ul>
            <li><code>makesh_force</code></li>
            <li><code>makesh_script</code></li>
            <li><code>makesh_script_dir</code></li>
            <li><code>makesh_lib_dir</code></li>
        </ul>
      </td>
    </tr>
    <tr>
      <td><a href="#messagesh"><code>message.sh</code></a></td>
      <td><code>msg::*</code></td>
      <td></td>
    </tr>
    <tr>
      <td><a href="#parseoptssh"><code>parseopts.sh</code></a></td>
      <td><code>lib::parseopts</code></td>
      <td></td>
    </tr>
  </tbody>
</table>

---

### `generate.sh`
Simple shell script which generates a `make.sh` example file in your root project directory (or an arbitrary directory).
Get more information with

```terminal
$ makesh/generate.sh --help
```

---

### `lib.sh`
Contains useful functions and variables to be used when writing targets. 
The code is fairly well-documented, reading it directly is recommended.

#### `$makesh_force`
Counts how many --force were used (as an integer number). Gets decreased by 1 each time `lib::requires` is called. You can use it explicitly in your targets when you want to be able to skip running a command if not forced, for example:

```bash
make::your_target() {
    if (( ! makesh_force )); then
        # This will run if makesh_force is zero
        lib::return "I don't need to do stuff"
    fi

    # This will only run if makesh_force is higher than zero
    do_stuff
}
```

Note that functions under `lib::` already check `makesh_force` and act accordingly, see the implementation of `lib::check_file`:

```bash
lib::check_file() {
    # Returns from the caller target if file exists 
    # AND makesh_force is zero
    if [ -f "$(realpath "$1")" ] && (( ! makesh_force )); then
        lib::return "file $1 already exists"
    fi
}
```

#### `$makesh_script`
The absolute path to the root `make.sh` script in the project directory. For example `/home/user/project/make.sh`.

#### `$makesh_script_dir`
The absolute path of the directory of `$makesh_script` (the project directory). For example `/home/user/project`.

#### `$makesh_lib_dir`
The absolute path of the directory containing the `makesh` library. For example `/home/user/project/makesh`.

#### `lib::check_dir()`
Break from current target if directory `$1` exists. Does not support wildcards. Can accept relative paths.

Usage examples:
```bash
lib::check_dir "some_dir"
```

#### `lib::check_file()`
Break from current target if file `$1` exists. Does not support wildcards. Can accept relative paths.

Usage examples:
```bash
lib::check_file "some_dir/some_file"
```

#### `lib::requires()`
Run another target before the caller, passing `$makesh_force` decreased by 1.
This lets you have granular control over the depth to which propagate `--force` to the called targets. Will also forward all extra arguments to the required target.

Usage examples:
```bash
lib::requires "other_target"

lib::requires other_target "string argument"

lib::requires make::other_target
```

#### `lib::return()`
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

msg::error "Docker container failed to start: %s" "$container_name"

msg::die "Critical error during execution"
```

#### `msg::ask()`
Useful for asking user input, will not print a newline (`\n`) after the text. 
Output format:
```
:: Your text?
```

#### `msg::die()`
Calls `msg::error` then `exit 1`, so works the same as that function (see below)

#### `msg::error()`
Used to print errors, prints to `stderr`
Output format:
```
==> ERROR: (<target name>) Your text
```

#### `msg::msg()`
Used to print generic messages.
Output format:
```
==> Your text
```

#### `msg::msg2()`
Used to print less important generic messages or second-level messages.
Output format:
```
  -> Your text
```

#### `msg::plain()`
Primarily used to continue a previous message on a new line.
Output format:
```
    Your text
```

#### `msg::plainerror()`
Primarily used to continue a previous error message on a new line, prints to `stderr`.
Output format:
```
    Your text
```

#### `msg::warning()`
Used to print warnings, prints to `stderr`
Output format:
```
==> WARNING: Your text
```

#### `msg::colorize()`
Activates output colorization if supported by the output terminal. Used internally.

---

### `parseopts.sh`
A modified version of `/usr/share/makepkg/util/parseopts.sh` from Arch's `makepkg` packaging software.
Contains a single function: `lib::parseopts`, see [the source code](/parseopts.sh) for actual documentation.

> For both short and long flags
> - options requiring an argument should be suffixed with a colon (`:`)
> - options with optional arguments should be suffixed with a question mark (`?`).

Example usage from `runtime.sh`:
```bash
OPT_SHORT="fh?u"
OPT_LONG=("force" "help?" "update")
if ! lib::parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
    msg::error "Error parsing command line."
    _usage
    exit 1
fi
set -- "${OPTRET[@]}"
unset OPT_SHORT OPT_LONG OPTRET

declare makesh_help makesh_update
while true; do
    case "$1" in
        -f|--force)  (( makesh_force++ )) ;;
        -h|--help)   makesh_help=1 ;;
        -u|--update) makesh_update=1 ;;
        --)          shift; break 2 ;;
    esac
    shift
done

# All remaining arguments are left in "$@"
```