#!/bin/bash

# NeurX Docker Build Script
# 便捷构建 Docker 镜像的脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_IMAGE_CPU="${DOCKER_IMAGE_CPU:-neurx:latest}"
DOCKER_IMAGE_GPU="${DOCKER_IMAGE_GPU:-neurx:latest-gpu}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
DOCKERFILE="${NEURX_ROOT}/Dockerfile"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

show_help() {
    cat <<EOF
NeurX Docker Builder

Usage: $0 [OPTIONS] [COMMAND]

Commands:
  cpu                Build CPU image (default)
  gpu                Build GPU image
  all                Build all images
  clean              Clean up images
  push               Push images to registry

Options:
  -h, --help         Show this help message
  -t, --tag TAG      Custom image tag (default: neurx:latest)
  -r, --registry REG Docker registry URL
  --no-cache         Build without using cache
  -v, --verbose      Verbose output

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        exit 1
    fi
    print_success "Docker found: $(docker --version)"
}

build_cpu() {
    print_info "Building CPU image: $DOCKER_IMAGE_CPU"
    
    local build_cmd="docker build"
    [ "$NO_CACHE" == "true" ] && build_cmd="$build_cmd --no-cache"
    
    cd "$NEURX_ROOT"
    
    $build_cmd \
        -t "$DOCKER_IMAGE_CPU" \
        -f "$DOCKERFILE" \
        .
    
    print_success "CPU image built: $DOCKER_IMAGE_CPU"
}

build_gpu() {
    print_info "Building GPU image: $DOCKER_IMAGE_GPU"
    
    local build_cmd="docker build"
    [ "$NO_CACHE" == "true" ] && build_cmd="$build_cmd --no-cache"
    
    cd "$NEURX_ROOT"
    
    $build_cmd \
        -t "$DOCKER_IMAGE_GPU" \
        -f "$DOCKERFILE" \
        --build-arg CUDA_VERSION=12.1 \
        .
    
    print_success "GPU image built: $DOCKER_IMAGE_GPU"
}

build_all() {
    build_cpu
    build_gpu
}

clean() {
    print_info "Cleaning up images..."
    docker rmi "$DOCKER_IMAGE_CPU" 2>/dev/null || true
    docker rmi "$DOCKER_IMAGE_GPU" 2>/dev/null || true
    docker image prune -f || true
    print_success "Cleanup completed"
}

push() {
    if [ -z "$DOCKER_REGISTRY" ]; then
        print_error "Registry not specified. Use -r option."
        exit 1
    fi
    
    print_info "Pushing to registry: $DOCKER_REGISTRY"
    docker tag "$DOCKER_IMAGE_CPU" "$DOCKER_REGISTRY/neurx:latest"
    docker push "$DOCKER_REGISTRY/neurx:latest"
    print_success "Pushed successfully"
}

# Parse arguments
COMMAND="cpu"
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--tag)
            DOCKER_IMAGE_CPU="$2"
            shift 2
            ;;
        -r|--registry)
            DOCKER_REGISTRY="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        cpu|gpu|all|clean|push)
            COMMAND="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeurX Docker Builder${NC}"
echo -e "${GREEN}========================================${NC}"

check_docker

print_info "Building: $COMMAND"
print_info "Root: $NEURX_ROOT"

case "$COMMAND" in
    cpu)
        build_cpu
        ;;
    gpu)
        build_gpu
        ;;
    all)
        build_all
        ;;
    clean)
        clean
        ;;
    push)
        build_all
        push
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        exit 1
        ;;
esac

echo ""
print_success "Build completed!"
echo ""
print_info "Next steps:"
echo "  CPU:  docker run -v ./models:/models $DOCKER_IMAGE_CPU start"
echo "  GPU:  docker run --gpus all -v ./models:/models $DOCKER_IMAGE_GPU start"
echo ""
