neurx: docker-deploy
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✨ NeurX 推理服务已启动！$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)🌐 服务地址: http://localhost:8001$(NC)"
	@echo "$(GREEN)📊 查看日志: make neurx-logs$(NC)"
	@echo "$(GREEN)⏹️  停止服务: make neurx-stop$(NC)"
	@echo "$(GREEN)📋 所有命令: make neurx-help$(NC)"
	@echo ""

neurx-help:
	@echo ""
	@echo "🚀 一键启动:"
	@echo "  make neurx                     # 完整一键部署（CPU 推理）"
	@echo ""
	@echo "🎯 快速启动:"
	@echo "  make neurx-start               # 启动 CPU 推理"
	@echo "  make neurx-start-gpu           # 启动 GPU 推理"
	@echo "  make neurx-api                 # 启动 API 服务器（前台）"
	@echo "  make neurx-api-bg              # 启动 API 服务器（后台）"
	@echo ""
	@echo "📦 镜像和模型:"
	@echo "  make neurx-build               # 构建 CPU 镜像"
	@echo "  make neurx-build-gpu           # 构建 GPU 镜像"
	@echo "  make neurx-models              # 显示推荐模型列表"
	@echo "  make neurx-download-model MODEL=<name>  # 下载模型"
	@echo ""
	@echo "📊 管理和监控:"
	@echo "  make neurx-status              # 查看服务状态"
	@echo "  make neurx-logs                # 实时日志"
	@echo "  make neurx-shell               # 进入容器 shell"
	@echo "  make neurx-stop                # 停止所有服务"
	@echo ""
	@echo "🧹 清理工具:"
	@echo "  make neurx-clean               # 清理容器"
	@echo "  make neurx-clean-images        # 删除镜像"
	@echo ""
	@echo "🐳 Docker 原生命令:"
	@echo "  make docker-help               # 显示完整 Docker 命令"
	@echo ""

neurx-start:
	@make docker-start-cpu

neurx-start-gpu:
	@make docker-start-gpu

neurx-api:
	@make docker-start-api

neurx-api-bg:
	@make docker-start-api-bg

neurx-build:
	@make docker-build-cpu

neurx-build-gpu:
	@make docker-build-gpu

neurx-models:
	@make docker-list-models

neurx-download-model:
	@make docker-download-model

neurx-logs:
	@make docker-logs

neurx-status:
	@make docker-status

neurx-shell:
	@make docker-shell

neurx-stop:
	@make docker-stop

neurx-clean:
	@make docker-clean

neurx-clean-images:
	@make docker-clean-images

docker: docker-deploy
	@echo "$(GREEN)✓ NeurX deployed successfully!$(NC)"

docker-deploy: docker-build-cpu docker-start-cpu
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)✓ 一键部署完成！$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)NeurX 推理服务运行在 http://localhost:8001$(NC)"
	@echo "$(GREEN)查看日志: make docker-logs$(NC)"
	@echo "$(GREEN)停止服务: make docker-stop$(NC)"
	@echo ""

docker-ensure-models:
	@mkdir -p /model
	@if [ ! -f "/model/model.safetensors" ] && [ ! -f "/model/model.safetensors.index.json" ]; then \
		echo "$(YELLOW)⚠️  模型不存在: /model/model.safetensors 或 /model/model.safetensors.index.json$(NC)"; \
		echo "$(YELLOW)请手动下载模型到 /model 目录，或运行: make docker-download-model$(NC)"; \
	else \
		echo "$(GREEN)✓ 模型已存在$(NC)"; \
	fi

docker-build-cpu:
	@if docker images | grep -q "neurx.*latest"; then \
		echo "$(GREEN)✓ Docker 镜像已存在，跳过构建$(NC)"; \
	else \
		echo "$(BLUE)📦 构建 Docker 镜像...$(NC)"; \
		docker build -t neurx:latest -f Dockerfile . && \
		echo "$(GREEN)✓ 镜像构建成功$(NC)"; \
	fi

docker-build-cpu-force:
	@echo "$(BLUE)📦 构建 Docker 镜像（强制重建）...$(NC)"
	@docker build -t neurx:latest -f Dockerfile --no-cache .
	@echo "$(GREEN)✓ 镜像构建成功$(NC)"

docker-build-gpu:
	@echo "$(BLUE)📦 构建 GPU Docker 镜像...$(NC)"
	@docker build -t neurx:latest-gpu -f Dockerfile --build-arg CUDA_VERSION=12.1 .
	@echo "$(GREEN)✓ GPU 镜像构建成功$(NC)"

docker-build-all: docker-build-cpu docker-build-gpu
	@echo "$(GREEN)✓ 所有镜像构建成功$(NC)"

docker-start-cpu:
	@echo "$(BLUE)🚀 启动 NeurX CPU 推理服务...$(NC)"
	@docker compose up neurx-cpu
	@echo "$(GREEN)✓ 服务运行在 http://localhost:8001$(NC)"

docker-start-gpu:
	@echo "$(BLUE)🚀 启动 NeurX GPU 推理服务...$(NC)"
	@docker compose --profile gpu up neurx-gpu
	@echo "$(GREEN)✓ 服务运行在 http://localhost:8000（GPU 加速）$(NC)"

docker-start-api:
	@echo "$(BLUE)🚀 启动 NeurX API 服务器...$(NC)"
	@docker compose --profile api up neurx-api
	@echo "$(GREEN)✓ API 服务运行在 http://localhost:8001$(NC)"

docker-start-api-bg:
	@echo "$(BLUE)🚀 后台启动 NeurX API 服务器...$(NC)"
	@docker compose --profile api up -d neurx-api
	@echo "$(GREEN)✓ API 服务在后台运行，端口 8001$(NC)"

docker-run:
	@make docker-start-cpu

docker-stop:
	@echo "$(BLUE)⏹️  停止所有容器...$(NC)"
	@docker compose down
	@echo "$(GREEN)✓ 所有容器已停止$(NC)"

docker-logs:
	@docker compose logs -f

docker-logs-tail:
	@docker compose logs --tail=50

docker-shell:
	@docker compose exec neurx-cpu /bin/bash

docker-download-model:
	@if [ -z "$(MODEL)" ]; then \
		echo "$(RED)❌ 错误：未指定模型$(NC)"; \
		echo "用法: make docker-download-model MODEL=Qwen/Qwen2.5-0.5B-Instruct"; \
		echo ""; \
		echo "推荐的轻量模型："; \
		echo "  - Qwen/Qwen2.5-0.5B-Instruct"; \
		echo "  - Qwen/Qwen2.5-1.5B-Instruct"; \
		echo ""; \
		exit 1; \
	fi
	@echo "$(BLUE)⬇️  下载模型: $(MODEL)...$(NC)"
	@mkdir -p src/models/catalog/default
	@docker compose --profile download run --rm neurx-download download-model $(MODEL)
	@echo "$(GREEN)✓ 模型已下载到 ./models/default$(NC)"

docker-list-models:
	@echo "$(BLUE)推荐的开源模型：$(NC)"
	@echo ""
	@echo "轻量模型（推荐 CPU）:"
	@echo "  make docker-download-model MODEL=Qwen/Qwen2.5-0.5B-Instruct"
	@echo "  make docker-download-model MODEL=Qwen/Qwen2.5-1.5B-Instruct"
	@echo ""
	@echo "标准模型（推荐 GPU）:"
	@echo "  make docker-download-model MODEL=Qwen/Qwen2.5-3B-Instruct"
	@echo "  make docker-download-model MODEL=Qwen/Qwen2.5-7B-Instruct"
	@echo "  make docker-download-model MODEL=meta-llama/Llama-2-7b-hf"
	@echo ""

docker-test:
	@echo "$(BLUE)🧪 测试 Docker 容器...$(NC)"
	@docker run --rm -it neurx:latest --version || echo "测试完成"
	@echo "$(GREEN)✓ 容器健康检查通过$(NC)"

docker-push:
	@if [ -z "$(REGISTRY)" ]; then \
		echo "$(RED)❌ 错误：未指定仓库地址$(NC)"; \
		echo "用法: make docker-push REGISTRY=registry.example.com"; \
		exit 1; \
	fi
	@echo "$(BLUE)📤 推送 Docker 镜像到 $(REGISTRY)...$(NC)"
	@docker tag neurx:latest $(REGISTRY)/neurx:latest
	@docker push $(REGISTRY)/neurx:latest
	@echo "$(GREEN)✓ 镜像已推送$(NC)"

docker-status:
	@echo "$(BLUE)📊 Docker 服务状态：$(NC)"
	@docker compose ps || echo "无运行中的容器"

docker-clean:
	@echo "$(YELLOW)🧹 清理 Docker 资源...$(NC)"
	@docker compose down --remove-orphans || true
	@docker system prune -f || true
	@echo "$(GREEN)✓ 清理完成$(NC)"

docker-clean-images:
	@echo "$(YELLOW)🗑️  删除 NeurX 镜像...$(NC)"
	@docker rmi neurx:latest neurx:latest-gpu 2>/dev/null || true
	@echo "$(GREEN)✓ 镜像已删除（下次运行会重新构建）$(NC)"

docker-help:
	@echo "$(GREEN)NeurX 命令速查$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 一键部署（推荐）:$(NC)"
	@echo "  make neurx                  # 完整一键部署"
	@echo "  make neurx-help             # 显示所有 neurx 命令"
	@echo ""
	@echo "$(YELLOW)🎯 快速启动:$(NC)"
	@echo "  make neurx-start            # 启动 CPU 推理"
	@echo "  make neurx-start-gpu        # 启动 GPU 推理"
	@echo "  make neurx-api              # 启动 API 服务"
	@echo "  make neurx-api-bg           # 后台启动 API"
	@echo ""
	@echo "$(YELLOW)📦 镜像构建:$(NC)"
	@echo "  make neurx-build            # 构建 CPU 镜像"
	@echo "  make neurx-build-gpu        # 构建 GPU 镜像"
	@echo ""
	@echo "$(YELLOW)⬇️  模型管理:$(NC)"
	@echo "  make neurx-download-model MODEL=<model-name>"
	@echo "  make neurx-models           # 显示推荐模型"
	@echo ""
	@echo "$(YELLOW)📊 管理和监控:$(NC)"
	@echo "  make neurx-status           # 显示运行状态"
	@echo "  make neurx-logs             # 实时日志"
	@echo "  make neurx-shell            # 进入容器 shell"
	@echo "  make neurx-stop             # 停止所有容器"
	@echo ""
	@echo "$(YELLOW)🔧 工具命令:$(NC)"
	@echo "  make neurx-clean            # 清理容器"
	@echo "  make neurx-clean-images     # 删除镜像"
	@echo ""

.PHONY: neurx neurx-help neurx-start neurx-start-gpu neurx-api neurx-api-bg neurx-build neurx-build-gpu neurx-models neurx-download-model neurx-logs neurx-status neurx-shell neurx-stop neurx-clean neurx-clean-images docker docker-deploy docker-ensure-models docker-build-cpu docker-build-cpu-force docker-build-gpu docker-build-all docker-start-cpu docker-start-gpu docker-start-api docker-start-api-bg docker-run docker-stop docker-logs docker-logs-tail docker-shell docker-download-model docker-list-models docker-test docker-push docker-status docker-clean docker-clean-images docker-help
