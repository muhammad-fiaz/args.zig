# args.zig Starter Project

Demo CLI using [args.zig](https://github.com/muhammad-fiaz/args.zig) v0.0.7.

## Prerequisites

- Zig 0.16.0+

## Setup

```bash
zig build
```

## Run

```bash
# Run with required positional argument
zig build run -- input.txt

# Run with flags
zig build run -- --verbose -n Alice input.txt

# No args shows help automatically
zig build run
```

When a required argument is missing, args.zig automatically prints the help text and exits with error code. No raw stack traces.

## Usage

```
demo [OPTIONS] <file>

ARGUMENTS:
    <file>      Input file to process [required]

OPTIONS:
    -v, --verbose           Verbose output
    -n, --name <STRING>     Your name [default: World]
    -h, --help              Print help
    -V, --version           Print version
```
