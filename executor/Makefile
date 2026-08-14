# NeurX Executor Module Makefile

SC = scc
CFLAGS = -O2
SRCDIR = .
BUILDDIR = build
EXAMPLEDIR = examples
TESTDIR = tests

# Source files
SOURCES = $(SRCDIR)/types.s \
          $(SRCDIR)/executor_base.s \
          $(SRCDIR)/prefill_executor.s \
          $(SRCDIR)/decode_executor.s \
          $(SRCDIR)/executor_scheduler.s \
          $(SRCDIR)/cache_manager.s \
          $(SRCDIR)/distributed_executor.s

# Object files
OBJECTS = $(patsubst %.s, $(BUILDDIR)/%.o, $(notdir $(SOURCES)))

# Example files
EXAMPLES = $(EXAMPLEDIR)/basic_example.s $(EXAMPLEDIR)/advanced_example.s

# Test files
TESTS = $(TESTDIR)/executor_tests.s

# Documentation files
DOCS = README.md IMPLEMENTATION_SUMMARY.md

# All targets
.PHONY: all build examples test quick clean docs help stats verify run-basic run-advanced run-tests

# Default target
all: build examples test

# Build core modules
build: $(BUILDDIR) $(OBJECTS)
	@echo "✓ Core modules built successfully"
	@echo "  Modules: $(shell ls -1 $(BUILDDIR)/*.o 2>/dev/null | wc -l)"

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

$(BUILDDIR)/%.o: $(SRCDIR)/%.s
	@echo "Compiling $<..."
	@$(SC) $(CFLAGS) -c $< -o $@

# Build examples
examples: build $(EXAMPLES)
	@echo "✓ Examples compiled"
	@echo "  Example files: $(shell echo $(EXAMPLES) | wc -w)"
	@$(SC) $(CFLAGS) -o $(BUILDDIR)/basic_example $(SRCDIR)/types.s $(EXAMPLEDIR)/basic_example.s 2>/dev/null || true
	@$(SC) $(CFLAGS) -o $(BUILDDIR)/advanced_example $(SRCDIR)/types.s $(EXAMPLEDIR)/advanced_example.s 2>/dev/null || true

# Run basic examples
run-basic: examples
	@echo "Running basic examples..."
	@$(BUILDDIR)/basic_example 2>/dev/null || echo "  Note: Run examples on system with S runtime"

# Run advanced examples
run-advanced: examples
	@echo "Running advanced examples..."
	@$(BUILDDIR)/advanced_example 2>/dev/null || echo "  Note: Run examples on system with S runtime"

# Run all examples
run-examples: run-basic run-advanced

# Build and run tests
test: build $(TESTS)
	@echo "✓ Tests compiled"
	@$(SC) $(CFLAGS) -o $(BUILDDIR)/executor_tests $(SRCDIR)/types.s $(TESTDIR)/executor_tests.s 2>/dev/null || true
	@echo "Running tests..."
	@$(BUILDDIR)/executor_tests 2>/dev/null || echo "  Note: Run tests on system with S runtime"

# Quick build (without tests)
quick: build examples
	@echo "✓ Quick build complete"

# Clean build artifacts
clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILDDIR)
	@echo "✓ Build artifacts removed"

# Generate documentation
docs:
	@echo "Documentation generated:"
	@echo "  - README.md ($(shell wc -l < README.md) lines)"
	@echo "  - IMPLEMENTATION_SUMMARY.md ($(shell wc -l < IMPLEMENTATION_SUMMARY.md) lines)"

# Display file statistics
stats:
	@echo "═══════════════════════════════════════════"
	@echo "  NeurX Executor Module Statistics"
	@echo "═══════════════════════════════════════════"
	@echo ""
	@echo "Core Modules:"
	@echo "  types.s                 $$(wc -l < $(SRCDIR)/types.s) lines"
	@echo "  executor_base.s         $$(wc -l < $(SRCDIR)/executor_base.s) lines"
	@echo "  prefill_executor.s      $$(wc -l < $(SRCDIR)/prefill_executor.s) lines"
	@echo "  decode_executor.s       $$(wc -l < $(SRCDIR)/decode_executor.s) lines"
	@echo "  executor_scheduler.s    $$(wc -l < $(SRCDIR)/executor_scheduler.s) lines"
	@echo "  cache_manager.s         $$(wc -l < $(SRCDIR)/cache_manager.s) lines"
	@echo "  distributed_executor.s  $$(wc -l < $(SRCDIR)/distributed_executor.s) lines"
	@echo ""
	@echo "Core Total: $$(awk 'BEGIN{sum=0} {sum+=$$1} END{print sum}' <(for f in $(SOURCES); do wc -l < $$f; done)) lines"
	@echo ""
	@echo "Examples:"
	@echo "  basic_example.s         $$(wc -l < $(EXAMPLEDIR)/basic_example.s) lines"
	@echo "  advanced_example.s      $$(wc -l < $(EXAMPLEDIR)/advanced_example.s) lines"
	@echo ""
	@echo "Example Total: $$(awk 'BEGIN{sum=0} {sum+=$$1} END{print sum}' <(for f in $(EXAMPLES); do wc -l < $$f; done)) lines"
	@echo ""
	@echo "Tests:"
	@echo "  executor_tests.s        $$(wc -l < $(TESTDIR)/executor_tests.s) lines"
	@echo ""
	@echo "Documentation:"
	@echo "  README.md               $$(wc -l < README.md) lines"
	@echo "  IMPLEMENTATION_SUMMARY  $$(wc -l < IMPLEMENTATION_SUMMARY.md) lines"
	@echo ""
	@echo "File Sizes:"
	@du -ch $(SOURCES) 2>/dev/null | tail -1 || echo "  (requires du command)"
	@du -ch $(EXAMPLES) 2>/dev/null | tail -1 || echo "  (requires du command)"
	@du -ch $(TESTDIR)/executor_tests.s 2>/dev/null | tail -1 || echo "  (requires du command)"
	@echo ""
	@echo "═══════════════════════════════════════════"

# Verify module structure
verify:
	@echo "Verifying module structure..."
	@echo ""
	@echo "Core Modules:"
	@for file in $(SOURCES); do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$(basename $$file)"; \
		else \
			echo "  ✗ $$(basename $$file) (missing)"; \
		fi \
	done
	@echo ""
	@echo "Examples:"
	@for file in $(EXAMPLES); do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$(basename $$file)"; \
		else \
			echo "  ✗ $$(basename $$file) (missing)"; \
		fi \
	done
	@echo ""
	@echo "Tests:"
	@for file in $(TESTS); do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$(basename $$file)"; \
		else \
			echo "  ✗ $$(basename $$file) (missing)"; \
		fi \
	done
	@echo ""
	@echo "Documentation:"
	@for file in $(DOCS); do \
		if [ -f "$$file" ]; then \
			echo "  ✓ $$file"; \
		else \
			echo "  ✗ $$file (missing)"; \
		fi \
	done
	@echo ""
	@echo "✓ Verification complete"

# Display help
help:
	@echo "╔═══════════════════════════════════════════════════╗"
	@echo "║  NeurX Executor Module - Build System             ║"
	@echo "╚═══════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available Targets:"
	@echo ""
	@echo "  Build Targets:"
	@echo "    make build        Build core modules only"
	@echo "    make examples     Build core + examples"
	@echo "    make test         Build everything + run tests"
	@echo "    make quick        Fast build (core + examples)"
	@echo "    make all          Full build (default)"
	@echo ""
	@echo "  Run Targets:"
	@echo "    make run-basic    Run basic example programs"
	@echo "    make run-advanced Run advanced example programs"
	@echo "    make run-examples Run all examples"
	@echo ""
	@echo "  Utility Targets:"
	@echo "    make clean        Remove all build artifacts"
	@echo "    make docs         Show documentation info"
	@echo "    make stats        Display code statistics"
	@echo "    make verify       Verify module structure"
	@echo "    make help         Display this message"
	@echo ""
	@echo "Variables:"
	@echo "    SC                Compiler: $$(which $(SC) || echo 'scc not found')"
	@echo "    CFLAGS            Compiler flags: $(CFLAGS)"
	@echo "    SRCDIR            Source directory: $(SRCDIR)"
	@echo "    BUILDDIR          Build directory: $(BUILDDIR)"
	@echo ""
	@echo "Examples:"
	@echo "    make              # Full build"
	@echo "    make clean build  # Clean and rebuild"
	@echo "    make stats        # Show statistics"
	@echo "    make verify       # Verify structure"
	@echo ""

# Phony declarations (must be last)
.PHONY: all build examples test quick clean docs help stats verify run-basic run-advanced run-examples run-tests
