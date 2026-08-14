
.PHONY: all build test clean docs help

SC := scc
SFLAGS := -O2

SOURCES := types.s \
           memory_manager.s \
           cuda_primitives.s \
           matrix_kernels.s \
           attention_kernels.s \
           norm_kernels.s \
           activation_kernels.s \
           dtype_conversion.s \
           kernel_launcher.s \
           utils.s

EXAMPLES := examples/basic_example.s \
            examples/matrix_operations.s \
            examples/attention_operations.s

TESTS := tests/kernels_tests.s

BUILD_DIR := build
OUTPUT_DIR := $(BUILD_DIR)/bin

all: build

build: $(SOURCES)
	@mkdir -p $(OUTPUT_DIR)
	@echo "Building CUDA Kernels module..."
	@for file in $(SOURCES); do \
		echo "  Compiling $$file"; \
		$(SC) $(SFLAGS) -c $$file -o $(OUTPUT_DIR)/$${file%.s}.o; \
	done
	@echo "✅ Build completed"

examples: $(EXAMPLES)
	@mkdir -p $(OUTPUT_DIR)
	@echo "Building examples..."
	@for file in $(EXAMPLES); do \
		echo "  Compiling $$file"; \
		$(SC) $(SFLAGS) -c $$file -o $(OUTPUT_DIR)/$${file##*/%.s}.o; \
	done
	@echo "✅ Examples built"

test: build $(TESTS)
	@mkdir -p $(OUTPUT_DIR)
	@echo "Running tests..."
	@$(SC) $(SFLAGS) -c $(TESTS) -o $(OUTPUT_DIR)/kernels_tests.o
	@echo "✅ Tests completed"

quick:
	@echo "Quick building..."
	@$(SC) $(SFLAGS) types.s kernel_launcher.s -o $(OUTPUT_DIR)/kernels

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean completed"

docs:
	@echo "Generating documentation..."
	@mkdir -p docs
	@echo "# CUDA Kernels Module API" > docs/API.md
	@echo "" >> docs/API.md
	@echo "## Core Components" >> docs/API.md
	@echo "1. **types.s** - Core data types and structures" >> docs/API.md
	@echo "2. **memory_manager.s** - CUDA memory allocation and management" >> docs/API.md
	@echo "3. **cuda_primitives.s** - Low-level CUDA operations" >> docs/API.md
	@echo "4. **matrix_kernels.s** - GEMM and matrix operations" >> docs/API.md
	@echo "5. **attention_kernels.s** - Attention mechanisms" >> docs/API.md
	@echo "6. **norm_kernels.s** - Normalization operations" >> docs/API.md
	@echo "7. **activation_kernels.s** - Activation functions" >> docs/API.md
	@echo "8. **dtype_conversion.s** - Data type conversions" >> docs/API.md
	@echo "9. **kernel_launcher.s** - Kernel scheduling and execution" >> docs/API.md
	@echo "10. **utils.s** - Utility functions" >> docs/API.md
	@echo "✅ Documentation generated"

help:
	@echo "CUDA Kernels Module - Makefile Targets"
	@echo "======================================="
	@echo "all          - Build all components"
	@echo "build        - Build source files"
	@echo "examples     - Build example programs"
	@echo "test         - Run unit tests"
	@echo "quick        - Quick build for development"
	@echo "clean        - Remove build artifacts"
	@echo "docs         - Generate documentation"
	@echo "help         - Show this help message"

.PHONY: $(SOURCES) $(EXAMPLES) $(TESTS)
