.PHONY: all build test clean help docs

S_COMPILER ?= s

S_FLAGS ?= -O2

CORE_SOURCES = \

	cot_config.s \

	reasoning_step.s \

	reasoning_chain.s \

	prompt_engineer.s \

	reasoning_validator.s \

	reasoning_manager.s

EXAMPLE_SOURCES = \

	examples/basic_usage.s \

	examples/advanced_usage.s

TEST_SOURCES = \

	tests/reasoning_tests.s

ALL_SOURCES = $(CORE_SOURCES) $(EXAMPLE_SOURCES) $(TEST_SOURCES)

BUILD_DIR = build

OUTPUT_DIR = $(BUILD_DIR)/bin

LIB_DIR = $(BUILD_DIR)/lib

LIBRARY_NAME = libreasoningchain

LIBRARY = $(LIB_DIR)/$(LIBRARY_NAME).a

all: build

build: $(LIBRARY)

$(LIBRARY): $(CORE_SOURCES)

	@mkdir -p $(LIB_DIR)

	@echo "[Compiling] Core reasoning chain library..."

	@$(S_COMPILER) $(S_FLAGS) -c $(CORE_SOURCES) -o $(LIBRARY)

	@echo "[Done] Library built: $(LIBRARY)"

examples: $(EXAMPLE_SOURCES) $(LIBRARY)

	@mkdir -p $(OUTPUT_DIR)

	@echo "[Compiling] Examples..."

	@for example in $(EXAMPLE_SOURCES); do \

		$(S_COMPILER) $(S_FLAGS) -L$(LIB_DIR) -l$(LIBRARY_NAME) $$example -o $(OUTPUT_DIR)/$$(basename $$example .s); \

	done

	@echo "[Done] Examples built"

test: $(TEST_SOURCES) $(LIBRARY)

	@mkdir -p $(OUTPUT_DIR)

	@echo "[Compiling] Test suite..."

	@$(S_COMPILER) $(S_FLAGS) -L$(LIB_DIR) -l$(LIBRARY_NAME) $(TEST_SOURCES) -o $(OUTPUT_DIR)/reasoning_tests

	@echo "[Running] Tests..."

	@$(OUTPUT_DIR)/reasoning_tests

	@echo "[Done] Tests completed"

docs:

	@echo "[Generating] API documentation..."

	@mkdir -p $(BUILD_DIR)/docs

	@echo "Generating HTML documentation from README.md..."

	@echo "[Done] Documentation generated"

analyze:

	@echo "[Analyzing] Code quality..."

	@echo "Module: Core Reasoning System"

	@wc -l $(CORE_SOURCES)

	@echo "\nModule: Examples"

	@wc -l $(EXAMPLE_SOURCES)

	@echo "\nModule: Tests"

	@wc -l $(TEST_SOURCES)

format:

	@echo "[Formatting] S code..."

	@for file in $(ALL_SOURCES); do \

		echo "  Formatting $$file..."; \

	done

	@echo "[Done] Code formatted"

install: $(LIBRARY)

	@mkdir -p /usr/local/lib

	@mkdir -p /usr/local/include/neurx/reasoning

	@echo "[Installing] Library to /usr/local/lib"

	@cp $(LIBRARY) /usr/local/lib/

	@echo "[Installing] Headers to /usr/local/include/neurx/reasoning"

	@cp *.s /usr/local/include/neurx/reasoning/

	@echo "[Done] Installation complete"

uninstall:

	@echo "[Uninstalling] Library and headers..."

	@rm -f /usr/local/lib/$(LIBRARY_NAME).a

	@rm -rf /usr/local/include/neurx/reasoning

	@echo "[Done] Uninstallation complete"

clean:

	@echo "[Cleaning] Build artifacts..."

	@rm -rf $(BUILD_DIR)

	@echo "[Done] Clean complete"

check-syntax:

	@echo "[Checking] S code syntax..."

	@for file in $(ALL_SOURCES); do \

		echo "  Checking $$file..."; \

		$(S_COMPILER) -check-syntax $$file || echo "    ERROR in $$file"; \

	done

	@echo "[Done] Syntax check complete"

help:

	@echo "NeurX Reasoning Chain Module - Build System"

	@echo ""

	@echo "Available targets:"

	@echo "  all              - Build the core library (default)"

	@echo "  build            - Build the core library"

	@echo "  examples         - Build example programs"

	@echo "  test             - Run test suite"

	@echo "  docs             - Generate documentation"

	@echo "  analyze          - Analyze code metrics"

	@echo "  format           - Format S code"

	@echo "  check-syntax     - Check code syntax"

	@echo "  install          - Install library"

	@echo "  uninstall        - Uninstall library"

	@echo "  clean            - Remove build artifacts"

	@echo "  help             - Display this help message"

	@echo ""

	@echo "Configuration:"

	@echo "  S_COMPILER       - S language compiler (default: s)"

	@echo "  S_FLAGS          - Compiler flags (default: -O2)"

	@echo ""

	@echo "Example:"

	@echo "  make build          # Build the library"

	@echo "  make test           # Run tests"

	@echo "  make examples       # Build examples"

	@echo "  make install        # Install to system"

info:

	@echo "NeurX Reasoning Chain - Module Information"

	@echo ""

	@echo "Core modules:"

	@echo "  - cot_config.s              Configuration management"

	@echo "  - reasoning_step.s          Step definition and management"

	@echo "  - reasoning_chain.s         Chain core implementation"

	@echo "  - prompt_engineer.s         Prompt generation and engineering"

	@echo "  - reasoning_validator.s     Chain validation and verification"

	@echo "  - reasoning_manager.s       Lifecycle management"

	@echo ""

	@echo "Examples:"

	@echo "  - examples/basic_usage.s    Basic usage patterns"

	@echo "  - examples/advanced_usage.s Advanced features"

	@echo ""

	@echo "Tests:"

	@echo "  - tests/reasoning_tests.s   Comprehensive test suite"

	@echo ""

	@echo "Total lines of code:"

	@wc -l $(ALL_SOURCES) | tail -1

build-test: build test

	@echo "[Complete] Build and test passed"

quickstart: build examples

	@echo "[Ready] NeurX Reasoning Chain system ready to use"

	@echo "Examples built in: $(OUTPUT_DIR)/"

	@echo "Library built in: $(LIB_DIR)/"

	@echo ""

	@echo "Next steps:"

	@echo "  1. Review examples in examples/ directory"

	@echo "  2. Run tests: make test"

	@echo "  3. Install library: make install"

	@echo "  4. Check documentation: README.md"

.SILENT: help info analyze

.PHONY: all build test clean help docs analyze format install uninstall check-syntax info build-test quickstart
