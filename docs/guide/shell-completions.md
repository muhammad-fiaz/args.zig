---
title: Shell Completions
description: Generate shell completion scripts for Bash, Zsh, Fish, and PowerShell with args.zig.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, shell completions, bash, zsh, fish, powershell, autocomplete
---

# Shell Completions

args.zig can generate shell completion scripts for Bash, Zsh, Fish, Nushell, and PowerShell.

## Generating Completions

```zig
const script = try parser.generateCompletion(.bash);
defer allocator.free(script);
std.debug.print("{s}", .{script});
```

## Supported Shells

| Shell | Enum Value | Notes |
|-------|------------|-------|
| Bash | `.bash` | Most common Linux shell |
| Zsh | `.zsh` | Default on macOS |
| Fish | `.fish` | User-friendly shell |
| PowerShell | `.powershell` | Windows and cross-platform |
| Nushell | `.nushell` | Modern, structured shell |

## Adding Completion Subcommand

A common pattern is to add a `completion` subcommand:

```zig
try parser.addSubcommand(.{
    .name = "completion",
    .help = "Generate shell completion script",
    .args = &[_]args.ArgSpec{
        .{ 
            .name = "shell", 
            .positional = true, 
            .required = true, 
            .help = "Shell type (bash, zsh, fish, powershell)" 
        },
    },
});

// Handle the completion subcommand
if (result.subcommand) |cmd| {
    if (std.mem.eql(u8, cmd, "completion")) {
        const shell_name = result.subcommand_args.?.getString("shell").?;
        if (args.Shell.fromString(shell_name)) |shell| {
            const script = try parser.generateCompletion(shell);
            defer allocator.free(script);
            const stdout = std.io.stdout.writer();
            try stdout.writeAll(script);
        } else {
            std.debug.print("Unknown shell: {s}\n", .{shell_name});
            std.debug.print("Supported: bash, zsh, fish, powershell, nushell\n", .{});
        }
    }
}
```

## Installing Completions

### Bash

```bash
# Generate and install
myapp completion bash > ~/.local/share/bash-completion/completions/myapp

# Or add to .bashrc
myapp completion bash >> ~/.bashrc
```

### Zsh

```bash
# Generate completion file
myapp completion zsh > ~/.zfunc/_myapp

# Add to .zshrc
fpath+=~/.zfunc
autoload -Uz compinit && compinit
```

### Fish

```bash
# Generate and install
myapp completion fish > ~/.config/fish/completions/myapp.fish
```

### PowerShell

```powershell
# Generate and add to profile
myapp completion powershell >> $PROFILE
```

### Nushell

```nu
# Generate and save to a file
myapp completion nushell | save completions.nu

# Use in your config.nu or interactively
source completions.nu
```

## Generated Script Examples

### Bash Output

```bash
# Bash completion for myapp
_myapp_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts="-v --verbose -o --output --help --version"

    if [[ ${cur} == -* ]]; then
        COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
    else
        COMPREPLY=($(compgen -f -- ${cur}))
    fi
}
complete -F _myapp_completions myapp
```

### Fish Output

```fish
# Fish completion for myapp
complete -c myapp -s v -l verbose -d 'Enable verbose output'
complete -c myapp -s o -l output -d 'Output file'
complete -c myapp -s h -l help -d 'Print help'
complete -c myapp -s V -l version -d 'Print version'
```

## Shell Detection

To auto-detect the current shell:

```zig
const std = @import("std");

fn detectShell() ?args.Shell {
    const shell_path = std.process.getEnvVarOwned(
        allocator, 
        "SHELL"
    ) catch return null;
    defer allocator.free(shell_path);
    
    if (std.mem.endsWith(u8, shell_path, "bash")) return .bash;
    if (std.mem.endsWith(u8, shell_path, "zsh")) return .zsh;
    if (std.mem.endsWith(u8, shell_path, "fish")) return .fish;
    
    return null;
}
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });

    try parser.addSubcommand(.{
        .name = "completion",
        .help = "Generate shell completions",
        .args = &[_]args.ArgSpec{
            .{ .name = "shell", .positional = true, .required = true },
        },
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    if (result.subcommand) |cmd| {
        if (std.mem.eql(u8, cmd, "completion")) {
            const shell_str = result.subcommand_args.?.getString("shell").?;
            const shell = args.Shell.fromString(shell_str) orelse {
                std.debug.print("Unknown shell: {s}\n", .{shell_str});
                return;
            };
            const script = try parser.generateCompletion(shell);
            defer allocator.free(script);
            std.debug.print("{s}", .{script});
        }
    }
}
```
