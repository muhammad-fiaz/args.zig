# Contributing to args.zig

Thank you for your interest in contributing to args.zig! This document provides guidelines and information for contributors.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## Getting Started

### Prerequisites

- Zig 0.15.0 or later
- Git
- Node.js 18+ (for documentation)

### Setup

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/args.zig.git
   cd args.zig
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/muhammad-fiaz/args.zig.git
   ```

## Development Workflow

### Building

```bash
# Build the library
zig build

# Build with optimizations
zig build -Doptimize=ReleaseFast
```

### Running Tests

```bash
# Run all tests
zig build test

# Run with summary
zig build test --summary all
```

### Running Examples

```bash
# Run basic example
zig build run-basic

# Run advanced example
zig build run-advanced
```

### Running Benchmarks

```bash
zig build bench
```

### Code Formatting

```bash
# Check formatting
zig build fmt-check

# Auto-format
zig build fmt
```

## Submitting Changes

### Creating a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add support for custom validators
fix: resolve integer overflow in tokenizer
docs: update getting started guide
test: add tests for counter action
refactor: simplify help generation logic
```

### Pull Request Process

1. Ensure all tests pass
2. Update documentation if needed
3. Add tests for new features
4. Push your branch and create a PR
5. Fill out the PR template
6. Wait for review

## Project Structure

```
args.zig/
├── src/
│   ├── args.zig         # Main entry point
│   ├── types.zig        # Core type definitions
│   ├── schema.zig       # Argument schema definitions
│   ├── tokenizer.zig    # Command-line tokenizer
│   ├── parser.zig       # Main argument parser
│   ├── validation.zig   # Value validation
│   ├── help.zig         # Help text generation
│   ├── completion.zig   # Shell completion generation
│   ├── config.zig       # Configuration management
│   ├── errors.zig       # Error types and handling
│   ├── version.zig      # Version information
│   ├── update_checker.zig # Update checking
│   └── network.zig      # Network utilities
├── examples/
│   ├── basic.zig        # Basic usage example
│   ├── advanced.zig     # Advanced features example
│   └── update_check.zig # Update checker example
├── bench/
│   └── benchmark.zig    # Performance benchmarks
├── docs/                # VitePress documentation
├── build.zig            # Build configuration
└── build.zig.zon        # Package manifest
```

## Coding Guidelines

### Style

- Use Zig's standard formatting (`zig fmt`)
- Keep functions small and focused
- Add documentation comments for public APIs
- Use meaningful variable and function names

### Testing

- Write tests for all new functionality
- Place tests in the same file as the code being tested
- Use descriptive test names
- Test edge cases and error conditions

### Documentation

- Update documentation for API changes
- Include code examples where helpful
- Keep documentation concise and clear

## Reporting Issues

### Bug Reports

Include:
- Zig version
- Operating system
- Minimal reproduction code
- Expected vs actual behavior
- Error messages (if any)

### Feature Requests

Include:
- Clear description of the feature
- Use cases and motivation
- Proposed API (if applicable)
- Potential alternatives

## Questions?

Feel free to:
- Open a GitHub issue
- Start a discussion on GitHub Discussions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to args.zig! 🎉
