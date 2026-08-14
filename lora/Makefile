
.PHONY: all build test clean format lint doc examples help

S_COMPILER := s
S_FLAGS := -std=latest -Wall -Wextra -O2
DEBUG_FLAGS := -g -O0
PROFILE_FLAGS := -pg

SRC_DIR := .
BUILD_DIR := build
TEST_DIR := tests
EXAMPLES_DIR := examples
DOC_DIR := docs

CORE_MODULES := \
	lora_config.s \
	lora_adapter.s \
	weight_fusion.s \
	lora_state.s \
	lora_utils.s \
	lora_manager.s

EXAMPLE_MODULES := \
	$(EXAMPLES_DIR)/basic_usage.s \
	$(EXAMPLES_DIR)/advanced_usage.s

CORE_OBJECTS := $(CORE_MODULES:.s=.o)
EXAMPLE_OBJECTS := $(EXAMPLE_MODULES:.s=.o)

all: build

build: $(BUILD_DIR)
	@echo "=== 编译 LoRA 核心模块 ==="
	@for file in $(CORE_MODULES); do \
		echo "编译: $$file"; \
		$(S_COMPILER) $(S_FLAGS) -c $$file -o $(BUILD_DIR)/$$(basename $$file .s).o; \
	done
	@echo "✓ 核心模块编译完成"

examples: build
	@echo "=== 编译 LoRA 示例 ==="
	@mkdir -p $(BUILD_DIR)
	@for file in $(EXAMPLE_MODULES); do \
		echo "编译: $$file"; \
		$(S_COMPILER) $(S_FLAGS) -c $$file -o $(BUILD_DIR)/$$(basename $$file .s).o; \
	done
	@echo "✓ 示例编译完成"

debug: EXTRA_FLAGS = $(DEBUG_FLAGS)
debug: clean build
	@echo "✓ 调试版本编译完成"

profile: EXTRA_FLAGS = $(PROFILE_FLAGS)
profile: clean build
	@echo "✓ 性能分析版本编译完成"

test: build
	@echo "=== 运行 LoRA 单元测试 ==="
	@if [ -d "$(TEST_DIR)" ]; then \
		for test_file in $(TEST_DIR)/*.s; do \
			echo "运行: $$test_file"; \
			$(S_COMPILER) $(S_FLAGS) $$test_file $(BUILD_DIR)/*.o -o $(BUILD_DIR)/test; \
			./$(BUILD_DIR)/test || exit 1; \
		done; \
		echo "✓ 所有测试通过"; \
	else \
		echo "⚠ 没有找到测试文件"; \
	fi

run-examples: examples
	@echo "=== 运行 LoRA 示例 ==="
	@echo ""
	@echo ">>> 基础使用示例"
	@$(S_COMPILER) $(S_FLAGS) $(EXAMPLES_DIR)/basic_usage.s -o $(BUILD_DIR)/basic_example
	@./$(BUILD_DIR)/basic_example
	@echo ""
	@echo ">>> 高级使用示例"
	@$(S_COMPILER) $(S_FLAGS) $(EXAMPLES_DIR)/advanced_usage.s -o $(BUILD_DIR)/advanced_example
	@./$(BUILD_DIR)/advanced_example

format:
	@echo "=== 格式化代码 ==="
	@for file in $(CORE_MODULES) $(EXAMPLE_MODULES); do \
		echo "格式化: $$file"; \
		s-fmt -w $$file 2>/dev/null || echo "  (跳过: 未安装 s-fmt)"; \
	done
	@echo "✓ 格式化完成"

lint:
	@echo "=== 静态代码检查 ==="
	@for file in $(CORE_MODULES); do \
		echo "检查: $$file"; \
		$(S_COMPILER) $(S_FLAGS) -lint $$file; \
	done
	@echo "✓ 代码检查完成"

doc: doc-check
	@echo "=== 生成 API 文档 ==="
	@mkdir -p $(DOC_DIR)
	@echo "生成文档..." \
	@echo "" > $(DOC_DIR)/api.md
	@echo "# LoRA API 参考" >> $(DOC_DIR)/api.md
	@echo "" >> $(DOC_DIR)/api.md
	@for file in $(CORE_MODULES); do \
		echo "## $$(basename $$file .s)" >> $(DOC_DIR)/api.md; \
		echo "" >> $(DOC_DIR)/api.md; \
		grep -E "^(func|struct|interface)" $$file >> $(DOC_DIR)/api.md || true; \
		echo "" >> $(DOC_DIR)/api.md; \
	done
	@echo "✓ 文档生成完成: $(DOC_DIR)/api.md"

doc-check:
	@echo "=== 检查文档 ==="
	@if [ -f "README.md" ]; then \
		echo "✓ README.md 存在"; \
	else \
		echo "✗ README.md 不存在"; \
		exit 1; \
	fi

clean:
	@echo "=== 清理编译产物 ==="
	@rm -rf $(BUILD_DIR) $(DOC_DIR)/api.md
	@find . -name "*.o" -delete
	@find . -name "*.a" -delete
	@find . -name "*.so" -delete
	@echo "✓ 清理完成"

distclean: clean
	@echo "=== 完整清理 ==="
	@rm -rf $(DOC_DIR) $(BUILD_DIR)
	@echo "✓ 完全清理完成"

package: clean format
	@echo "=== 打包源代码 ==="
	@tar -czf neurx-lora-$(shell date +%Y%m%d).tar.gz \
		--exclude=.git \
		--exclude=__pycache__ \
		--exclude=.DS_Store \
		.
	@echo "✓ 源代码包创建完成"

install: build
	@echo "=== 安装 LoRA 模块 ==="
	@if [ -z "$(NEURX_HOME)" ]; then \
		echo "错误: 请设置 NEURX_HOME 环境变量"; \
		exit 1; \
	fi
	@cp -v *.s $(NEURX_HOME)/lora/
	@cp -v README.md $(NEURX_HOME)/lora/
	@cp -rv examples $(NEURX_HOME)/lora/
	@echo "✓ 安装完成"

info:
	@echo "=== LoRA 模块信息 ==="
	@echo "核心模块数量: $$(echo $(CORE_MODULES) | wc -w)"
	@echo "示例数量: $$(echo $(EXAMPLE_MODULES) | wc -w)"
	@echo ""
	@echo "代码行数统计:"
	@wc -l $(CORE_MODULES) $(EXAMPLE_MODULES) | tail -1
	@echo ""
	@echo "文件大小:"
	@du -sh . | cut -f1

benchmark: build
	@echo "=== LoRA 性能基准测试 ==="
	@echo "运行基准测试..."
	@$(S_COMPILER) $(S_FLAGS) examples/advanced_usage.s $(BUILD_DIR)/*.o -o $(BUILD_DIR)/benchmark
	@./$(BUILD_DIR)/benchmark
	@echo "✓ 基准测试完成"

help:
	@echo "=========================================="
	@echo "   NeurX LoRA 编译系统"
	@echo "=========================================="
	@echo ""
	@echo "可用目标："
	@echo "  make all          - 编译所有模块（默认）"
	@echo "  make build        - 仅编译核心模块"
	@echo "  make examples     - 编译示例代码"
	@echo "  make test         - 运行单元测试"
	@echo "  make run-examples - 编译并运行示例"
	@echo "  make format       - 代码格式化"
	@echo "  make lint         - 静态代码检查"
	@echo "  make doc          - 生成 API 文档"
	@echo "  make clean        - 删除编译产物"
	@echo "  make distclean    - 完整清理"
	@echo "  make package      - 打包源代码"
	@echo "  make install      - 安装到 NeurX"
	@echo "  make info         - 显示模块信息"
	@echo "  make benchmark    - 运行性能测试"
	@echo "  make debug        - 调试编译"
	@echo "  make profile      - 性能分析编译"
	@echo "  make help         - 显示此帮助信息"
	@echo ""
	@echo "环境变量:"
	@echo "  NEURX_HOME        - NeurX 安装目录（用于 make install）"
	@echo ""
	@echo "示例:"
	@echo "  make build test              # 编译并测试"
	@echo "  NEURX_HOME=.. make install   # 安装到 NeurX"
	@echo "  make debug                   # 调试编译"
	@echo ""

.DEFAULT_GOAL := help

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

%.o: %.s
	@$(S_COMPILER) $(S_FLAGS) $(EXTRA_FLAGS) -c $< -o $(BUILD_DIR)/$@

ci: lint format test examples
	@echo "✓ CI 检查通过"

pre-commit: format lint doc-check
	@echo "✓ 预提交检查通过"

.PHONY: ci pre-commit
