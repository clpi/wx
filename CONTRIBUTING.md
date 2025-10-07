# Contributing to wx

Thank you for your interest in contributing to wx! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Project Structure](#project-structure)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/wx.git
   cd wx
   ```
3. **Add the upstream repository**:
   ```bash
   git remote add upstream https://github.com/clpi/wx.git
   ```

## Development Setup

### Prerequisites

- **Zig compiler** (version 0.11.0 or later recommended)
  - Install from [ziglang.org](https://ziglang.org/download/)
  - Or use your package manager (e.g., `brew install zig`)

- **Optional tools** for benchmarking:
  - Wasmtime: `curl https://wasmtime.dev/install.sh -sSfL | bash`
  - Wasmer: `curl https://get.wasmer.io -sSfL | sh`
  - Python 3 for extended benchmarks

### Building the Project

```bash
# Build the wx runtime
zig build

# Build the WASI opcodes CLI
zig build opcodes-wasm

# Run tests
zig build test
```

### Running the Runtime

```bash
# Run with help
./zig-out/bin/wx --help

# Run a WASM file
./zig-out/bin/wx examples/simple.wasm

# Run with debug output
./zig-out/bin/wx --debug examples/math.wasm
```

## Making Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the [coding standards](#coding-standards)

3. **Test your changes** thoroughly:
   ```bash
   zig build test
   ./zig-out/bin/wx examples/simple.wasm
   ```

4. **Commit your changes** with clear, descriptive messages:
   ```bash
   git commit -m "Add feature: brief description"
   ```

### Commit Message Guidelines

- Use the imperative mood ("Add feature" not "Added feature")
- Keep the first line under 72 characters
- Reference issues and pull requests where appropriate
- Examples:
  - `Add support for WASM bulk memory operations`
  - `Fix memory leak in module loading`
  - `Improve performance of opcode execution`
  - `Update documentation for CLI usage`

## Testing

### Running Tests

```bash
# Run all tests
zig build test

# Test with specific WASM files
./zig-out/bin/wx examples/simple.wasm
./zig-out/bin/wx zig-out/bin/opcodes_cli.wasm --list
```

### Benchmarking

```bash
# Run basic benchmarks
bash bench/run.sh

# Run extended benchmark suite
python3 bench_extended.py
```

### Adding New Tests

- Add unit tests in the relevant `.zig` files using `test` blocks
- Add integration tests as WASM files in the `examples/` directory
- Update benchmark scripts if adding performance-critical features

## Submitting Changes

1. **Push your branch** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a Pull Request** on GitHub:
   - Provide a clear title and description
   - Reference any related issues
   - Include test results or benchmark comparisons if relevant

3. **Respond to review feedback**:
   - Make requested changes in new commits
   - Keep the conversation constructive and professional

4. **Wait for approval** from maintainers before merging

## Coding Standards

### Zig Code Style

- Follow the official [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide)
- Use 4 spaces for indentation (not tabs)
- Keep line length under 100 characters when possible
- Use meaningful variable and function names
- Add comments for complex logic or non-obvious behavior

### Code Organization

- Keep functions focused and single-purpose
- Use appropriate error handling with Zig's error sets
- Prefer compile-time evaluation where possible
- Document public APIs with doc comments (`///`)

### Example Code Style

```zig
/// Executes a WebAssembly function with the given arguments.
/// Returns an error if execution fails.
pub fn executeFunction(
    self: *Runtime,
    func_index: u32,
    args: []const Value,
) ![]Value {
    // Validate function index
    if (func_index >= self.module.functions.items.len) {
        return error.InvalidFunctionIndex;
    }
    
    // Execute function...
    // ...
}
```

## Project Structure

```
wx/
├── src/              # Source code
│   ├── main.zig     # Entry point
│   ├── root.zig     # Library root
│   └── ...          # Runtime implementation
├── examples/        # Example WASM files
├── bench/           # Benchmark scripts
├── build.zig        # Build configuration
├── README.md        # Project documentation
├── CHANGELOG.md     # Version history
├── CONTRIBUTING.md  # This file
└── LICENSE          # MIT License
```

### Key Components

- **Parser**: WASM module parsing and validation
- **Runtime**: Opcode execution and state management
- **WASI**: WebAssembly System Interface implementation
- **Memory**: Linear memory management
- **Stack**: Value and call stack handling

## Areas for Contribution

- **Performance improvements**: Optimize hot paths and reduce allocations
- **WASI support**: Expand syscall implementation
- **WebAssembly features**: Add support for newer WASM proposals
- **Testing**: Add more test cases and benchmarks
- **Documentation**: Improve code comments and user guides
- **Tooling**: Enhance build scripts and development tools
- **Bug fixes**: Fix reported issues

## Questions?

If you have questions or need help:

1. Check existing issues and pull requests
2. Open a new issue with the `question` label
3. Be specific about what you're trying to accomplish

## License

By contributing to wx, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to wx! 🚀
