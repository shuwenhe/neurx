# NeurX CLI Build Instructions

## Building the Unified CLI

The NeurX CLI consolidates all 159+ shell scripts into a single S language binary.

### Prerequisites

1. **S Compiler**: Version 1.0+
   ```bash
   # Check if S compiler is available
   s --version
   
   # Or build it
   cd ../s && make build
   ```

2. **Go/System Libraries**: For file I/O, process execution
   ```bash
   # macOS
   xcode-select --install
   
   # Ubuntu
   sudo apt-get install build-essential
   
   # Fedora
   sudo dnf install gcc
   ```

### Quick Build

```bash
# Compile the CLI binary
s cmd/neurx_cli.s -o neurx_cli

# Or with optimization
s -O3 cmd/neurx_cli.s -o neurx_cli

# Test it
./neurx_cli help
```

### Build via Makefile

Add to `neurx/Makefile`:

```makefile
CLI_COMPILER ?= s
CLI_SOURCE = cmd/neurx_cli.s
CLI_BIN = bin/neurx

build-cli: $(CLI_BIN)

$(CLI_BIN): $(CLI_SOURCE) scripts/*.s
	@echo "Building NeurX CLI..."
	@mkdir -p bin
	$(CLI_COMPILER) $(CLI_SOURCE) -o $(CLI_BIN)
	@chmod +x $(CLI_BIN)
	@echo "✓ CLI built: $(CLI_BIN)"

run-cli: $(CLI_BIN)
	./$(CLI_BIN) $(ARGS)

install-cli: $(CLI_BIN)
	cp $(CLI_BIN) /usr/local/bin/neurx
	chmod +x /usr/local/bin/neurx
	@echo "✓ Installed to /usr/local/bin/neurx"

clean-cli:
	rm -f $(CLI_BIN)

.PHONY: build-cli run-cli install-cli clean-cli
```

### Using the Makefile

```bash
# Build the CLI
make build-cli

# Run with arguments
make run-cli ARGS="train large 64"

# Install system-wide
make install-cli

# Clean build artifacts
make clean-cli
```

### Full Build System

For complete build with all components:

```bash
# Build everything
make build

# Build with documentation
make build docs

# Build with tests
make build test

# Build and install
make install
```

### Production Build

```bash
# Optimized production build
s -O3 -static cmd/neurx_cli.s -o bin/neurx-prod

# Stripped binary (smaller size)
s -O3 cmd/neurx_cli.s -o bin/neurx && strip bin/neurx

# Cross-compile for Linux
CC=gcc GOOS=linux GOARCH=amd64 s cmd/neurx_cli.s -o bin/neurx-linux

# Cross-compile for ARM64
CC=gcc GOOS=linux GOARCH=arm64 s cmd/neurx_cli.s -o bin/neurx-arm64
```

### Verification

```bash
# Test basic functionality
./neurx_cli help

# Test training command
./neurx_cli help train

# Test build command
./neurx_cli help build

# Check version
./neurx_cli version

# Show status
./neurx_cli status
```

### Continuous Integration

Example GitHub Actions workflow:

```yaml
name: Build NeurX CLI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install S Compiler
        run: |
          cd ../s
          make build
          export PATH=$PATH:$(pwd)/.local/bin
      
      - name: Build CLI
        run: |
          cd train/neurx
          s cmd/neurx_cli.s -o neurx_cli
      
      - name: Test CLI
        run: |
          cd train/neurx
          ./neurx_cli version
          ./neurx_cli help
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v2
        with:
          name: neurx-cli
          path: train/neurx/neurx_cli
```

### Troubleshooting

#### S Compiler Not Found
```bash
# Set explicit path
export S_COMPILER=/path/to/s/compiler
s $S_COMPILER cmd/neurx_cli.s -o neurx_cli
```

#### Build Errors
```bash
# Check S compiler version
s --version

# Verbose compilation
s -v cmd/neurx_cli.s -o neurx_cli

# Check IR generation
s cmd/neurx_cli.s -emit-ir -o neurx_cli.ir
```

#### Runtime Issues
```bash
# Set debug logging
export NEURX_DEBUG=1
./neurx_cli train mini 1

# Check environment
./neurx_cli status
```

### Benchmarking Build Performance

```bash
# Time the build
time s cmd/neurx_cli.s -o neurx_cli

# Measure binary size
ls -lh neurx_cli

# Strip and measure again
strip neurx_cli
ls -lh neurx_cli
```

### Binary Distribution

The compiled binary can be distributed as:

1. **Standalone Binary**: Just the `neurx_cli` executable
2. **Docker Image**: With all dependencies included
3. **Package Manager**: `apt`, `brew`, `pacman`, etc.
4. **Source Distribution**: With build scripts

Example Dockerfile:

```dockerfile
FROM ubuntu:22.04

# Install S compiler
COPY s-compiler /usr/local/bin/s

# Build NeurX CLI
COPY neurx /opt/neurx
WORKDIR /opt/neurx
RUN s cmd/neurx_cli.s -o /usr/local/bin/neurx && chmod +x /usr/local/bin/neurx

ENTRYPOINT ["neurx"]
```

---

## Build Configuration Details

### Compilation Flags

- **`-O3`**: Full optimization (size and speed)
- **`-static`**: Static linking (no dependencies)
- **`-v`**: Verbose output
- **`-emit-ir`**: Generate IR file
- **`--version`**: Show compiler version

### Environment Variables

- **`S_COMPILER`**: Path to S compiler binary
- **`NEURX_VERSION`**: Version string to embed
- **`NEURX_BUILD_TIME`**: Build timestamp
- **`NEURX_COMMIT`**: Git commit hash

### Module Dependencies

```
neurx_cli.s
├── shell_compat.s
├── train_orchestrator.s
├── build_orchestrator.s
├── inference_orchestrator.s
└── data_orchestrator.s
```

All modules are in `scripts/` directory.

---

## Next Steps

1. **Build the CLI**: `make build-cli`
2. **Test functionality**: `./neurx_cli help`
3. **Install globally**: `make install-cli` or `cp neurx_cli /usr/local/bin/neurx`
4. **Run training**: `neurx train large 64`

---

**Last Updated**: 2026-07-12
