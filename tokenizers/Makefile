# NeurX Tokenizers - Build Configuration
# Makefile for tokenizer module compilation and testing

# Compiler and flags
SC := scc
CFLAGS := -O2
DEBUG_FLAGS := -g -D DEBUG

# Directories
SRC_DIR := .
BUILD_DIR := build
BIN_DIR := $(BUILD_DIR)/bin
OBJ_DIR := $(BUILD_DIR)/obj
EXAMPLES_DIR := examples
TESTS_DIR := tests

# Source files
CORE_SOURCES := \
	types.s \
	tokenizer.s \
	huggingface_tokenizer.s \
	special_tokens.s \
	cache.s \
	utils.s

CORE_OBJECTS := $(CORE_SOURCES:%.s=$(OBJ_DIR)/%.o)

EXAMPLE_SOURCES := $(EXAMPLES_DIR)/basic_example.s $(EXAMPLES_DIR)/advanced_example.s
TEST_SOURCES := $(TESTS_DIR)/tokenizers_tests.s

# Targets
EXAMPLE_BINS := $(BIN_DIR)/basic_example $(BIN_DIR)/advanced_example
TEST_BIN := $(BIN_DIR)/tokenizers_tests

# Default target
.PHONY: help
help:
	@echo "NeurX Tokenizers - Build System"
	@echo "================================"
	@echo ""
	@echo "Available targets:"
	@echo "  make build       - Compile all core modules"
	@echo "  make examples    - Build example programs"
	@echo "  make test        - Run test suite"
	@echo "  make quick       - Fast build and test"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make docs        - Generate documentation"
	@echo "  make all         - Build everything"
	@echo ""

# Main build target
.PHONY: build
build: $(BIN_DIR) $(OBJ_DIR) $(CORE_OBJECTS)
	@echo "✓ Core modules compiled successfully"
	@echo "  Compiled objects: $(CORE_OBJECTS)"

# Create build directories
$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

$(OBJ_DIR):
	@mkdir -p $(OBJ_DIR)

# Compile core objects
$(OBJ_DIR)/%.o: %.s
	$(SC) $(CFLAGS) -c $< -o $@
	@echo "  Compiled: $<"

# Build examples
.PHONY: examples
examples: build $(EXAMPLE_BINS)
	@echo "✓ All examples built successfully"

$(BIN_DIR)/basic_example: $(EXAMPLES_DIR)/basic_example.s $(CORE_OBJECTS)
	$(SC) $(CFLAGS) $< $(CORE_OBJECTS) -o $@
	@echo "  Built: $@"

$(BIN_DIR)/advanced_example: $(EXAMPLES_DIR)/advanced_example.s $(CORE_OBJECTS)
	$(SC) $(CFLAGS) $< $(CORE_OBJECTS) -o $@
	@echo "  Built: $@"

# Build tests
$(TEST_BIN): $(TESTS_DIR)/tokenizers_tests.s $(CORE_OBJECTS)
	$(SC) $(CFLAGS) $< $(CORE_OBJECTS) -o $@
	@echo "  Built: $@"

# Run tests
.PHONY: test
test: $(TEST_BIN)
	@echo ""
	@echo "Running test suite..."
	@echo "===================="
	$(TEST_BIN)

# Quick build and test
.PHONY: quick
quick: clean build test
	@echo "✓ Quick build completed"

# Build everything
.PHONY: all
all: build examples test
	@echo ""
	@echo "✓ All targets built successfully"
	@echo ""
	@echo "Artifacts:"
	@echo "  Core: $(CORE_OBJECTS)"
	@echo "  Examples: $(EXAMPLE_BINS)"
	@echo "  Tests: $(TEST_BIN)"

# Run basic example
.PHONY: run-basic
run-basic: $(BIN_DIR)/basic_example
	@echo ""
	@echo "Running basic example..."
	@echo "========================"
	$(BIN_DIR)/basic_example

# Run advanced example
.PHONY: run-advanced
run-advanced: $(BIN_DIR)/advanced_example
	@echo ""
	@echo "Running advanced example..."
	@echo "============================"
	$(BIN_DIR)/advanced_example

# Run all examples
.PHONY: run-examples
run-examples: run-basic run-advanced
	@echo ""
	@echo "✓ All examples completed"

# Generate documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	@echo ""
	@echo "# NeurX Tokenizers Module Documentation" > GENERATED_DOCS.md
	@echo "" >> GENERATED_DOCS.md
	@echo "## Module Overview" >> GENERATED_DOCS.md
	@echo "" >> GENERATED_DOCS.md
	@echo "The tokenizers module provides comprehensive tokenization functionality:" >> GENERATED_DOCS.md
	@echo "" >> GENERATED_DOCS.md
	@echo "### Core Components:" >> GENERATED_DOCS.md
	@echo "- **types.s**: Type definitions and structures" >> GENERATED_DOCS.md
	@echo "- **tokenizer.s**: Base tokenizer interface" >> GENERATED_DOCS.md
	@echo "- **huggingface_tokenizer.s**: HuggingFace tokenizer implementation" >> GENERATED_DOCS.md
	@echo "- **special_tokens.s**: Special token management" >> GENERATED_DOCS.md
	@echo "- **cache.s**: Token caching system" >> GENERATED_DOCS.md
	@echo "- **utils.s**: Utility functions" >> GENERATED_DOCS.md
	@echo "" >> GENERATED_DOCS.md
	@echo "### Features:" >> GENERATED_DOCS.md
	@echo "- Multi-format tokenization (BERT, LLaMA, GPT)" >> GENERATED_DOCS.md
	@echo "- Efficient caching with LRU/LFU/FIFO policies" >> GENERATED_DOCS.md
	@echo "- Special token management" >> GENERATED_DOCS.md
	@echo "- Batch processing support" >> GENERATED_DOCS.md
	@echo "- Token sequence analysis" >> GENERATED_DOCS.md
	@echo "" >> GENERATED_DOCS.md
	@echo "✓ Documentation generated: GENERATED_DOCS.md"

# Static analysis
.PHONY: check
check:
	@echo "Running static checks..."
	@echo "Source lines of code:"
	@wc -l $(CORE_SOURCES) $(EXAMPLE_SOURCES) $(TEST_SOURCES)
	@echo ""
	@echo "Total modules: 6"
	@echo "Total examples: 2"
	@echo "Total tests: 14"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

# Cleanup everything
.PHONY: distclean
distclean: clean
	@rm -f GENERATED_DOCS.md
	@rm -f *.log
	@echo "✓ Distribution clean complete"

# Stats
.PHONY: stats
stats:
	@echo "Tokenizers Module Statistics"
	@echo "============================="
	@echo ""
	@echo "Core Modules:"
	@wc -l $(CORE_SOURCES)
	@echo ""
	@echo "Examples:"
	@wc -l $(EXAMPLE_SOURCES)
	@echo ""
	@echo "Tests:"
	@wc -l $(TEST_SOURCES)
	@echo ""
	@echo "Total:"
	@wc -l $(CORE_SOURCES) $(EXAMPLE_SOURCES) $(TEST_SOURCES) | tail -1

# Display build info
.PHONY: info
info:
	@echo "NeurX Tokenizers Module"
	@echo "======================="
	@echo ""
	@echo "Build Configuration:"
	@echo "  Compiler: $(SC)"
	@echo "  Flags: $(CFLAGS)"
	@echo "  Build Dir: $(BUILD_DIR)"
	@echo ""
	@echo "Components:"
	@echo "  Core Sources: 6"
	@echo "  Examples: 2"
	@echo "  Tests: 1"
	@echo ""
	@echo "Use 'make help' for available commands"

.PHONY: .PHONY
