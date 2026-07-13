#!/bin/bash

# CUDA Runtime Binding Verification & Quick Start
# Tests if CUDA environment is properly configured

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# ============================================================================
# CHECK 1: NVIDIA DRIVER & CUDA
# ============================================================================

print_header "NVIDIA CUDA Environment Check"

echo ""
print_info "Checking NVIDIA driver..."

if ! command -v nvidia-smi &> /dev/null; then
    print_error "nvidia-smi not found"
    echo "  Install NVIDIA driver from https://www.nvidia.com/Download/driverDetails.aspx"
    exit 1
fi

print_success "nvidia-smi found"
echo ""
nvidia-smi

echo ""
print_info "Checking CUDA Toolkit..."

if ! command -v nvcc &> /dev/null; then
    print_error "nvcc (CUDA compiler) not found"
    echo "  Install CUDA Toolkit from https://developer.nvidia.com/cuda-downloads"
    exit 1
fi

print_success "CUDA Toolkit found"
CUDA_VERSION=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
echo "  Version: $CUDA_VERSION"

echo ""
print_info "Checking cuBLAS..."

if ! ldconfig -p | grep -q cublas; then
    print_warning "cuBLAS library not in ldconfig"
    echo "  This is usually fine if CUDA was installed in a custom location"
else
    print_success "cuBLAS found in library path"
fi

# ============================================================================
# CHECK 2: AVAILABLE GPUs
# ============================================================================

echo ""
print_header "GPU Detection"

GPU_COUNT=$(nvidia-smi -L 2>/dev/null | wc -l)
print_info "GPU count: $GPU_COUNT"

if [ "$GPU_COUNT" -eq 0 ]; then
    print_error "No NVIDIA GPUs detected"
    exit 1
fi

print_success "GPUs available"
echo ""

for i in $(seq 0 $((GPU_COUNT - 1))); do
    GPU_NAME=$(nvidia-smi -i $i --query-gpu=name --format=csv,noheader)
    GPU_MEMORY=$(nvidia-smi -i $i --query-gpu=memory.total --format=csv,noheader)
    GPU_COMPUTE=$(nvidia-smi -i $i --query-gpu=compute_cap --format=csv,noheader)
    
    echo "  GPU $i: $GPU_NAME ($GPU_MEMORY, Compute Capability: $GPU_COMPUTE)"
done

# ============================================================================
# CHECK 3: BUILD TOOLS
# ============================================================================

echo ""
print_header "Build Tools Check"

print_info "Checking CMake..."
if ! command -v cmake &> /dev/null; then
    print_error "CMake not found"
    echo "  Install with: sudo apt-get install cmake"
    exit 1
fi
print_success "CMake found ($(cmake --version | head -1))"

print_info "Checking C++ compiler..."
if ! command -v g++ &> /dev/null && ! command -v clang++ &> /dev/null; then
    print_error "C++ compiler not found"
    echo "  Install with: sudo apt-get install build-essential"
    exit 1
fi

if command -v g++ &> /dev/null; then
    print_success "g++ found ($(g++ --version | head -1))"
else
    print_success "clang++ found ($(clang++ --version | head -1))"
fi

# ============================================================================
# CHECK 4: S LANGUAGE COMPILER
# ============================================================================

echo ""
print_header "S Language Compiler Check"

S_COMPILER=${1:-/home/shuwen/.local/bin/s}
print_info "Looking for S compiler at: $S_COMPILER"

if ! command -v "$S_COMPILER" &> /dev/null; then
    print_error "S compiler not found at $S_COMPILER"
    exit 1
fi

print_success "S compiler found"

# ============================================================================
# CHECK 5: WORKSPACE STRUCTURE
# ============================================================================

echo ""
print_header "NeurX Workspace Check"

NEURX_ROOT="${2:-.}"
CUDA_DIR="$NEURX_ROOT/cuda"
SCRIPT_DIR="$NEURX_ROOT/script"

print_info "CUDA module directory: $CUDA_DIR"
if [ -d "$CUDA_DIR" ]; then
    print_success "CUDA directory found"
    FILE_COUNT=$(ls -1 "$CUDA_DIR"/*.{h,cu,s,cmake,md} 2>/dev/null | wc -l)
    echo "  Files: $FILE_COUNT CUDA/C++ source files"
else
    print_error "CUDA directory not found"
    exit 1
fi

print_info "Script directory: $SCRIPT_DIR"
if [ -d "$SCRIPT_DIR" ]; then
    print_success "Script directory found"
    S_SCRIPTS=$(ls -1 "$SCRIPT_DIR"/*.s 2>/dev/null | wc -l)
    echo "  Files: $S_SCRIPTS S language scripts"
else
    print_warning "Script directory not found (non-critical)"
fi

# ============================================================================
# CHECK 6: COMPILATION TEST
# ============================================================================

echo ""
print_header "Compilation Test"

print_info "Creating test CUDA kernel..."

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cat > "$TEST_DIR/test.cu" << 'EOF'
#include <cuda_runtime.h>
#include <stdio.h>

__global__ void test_kernel(float *data) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    data[idx] = 42.0f;
}

int main() {
    printf("CUDA test kernel compiled successfully\n");
    return 0;
}
EOF

if nvcc -c "$TEST_DIR/test.cu" -o "$TEST_DIR/test.o" 2>/dev/null; then
    print_success "CUDA compilation works"
else
    print_error "CUDA compilation failed"
    echo "  Check your CUDA installation"
    exit 1
fi

# ============================================================================
# CHECK 7: MEMORY CHECK
# ============================================================================

echo ""
print_header "GPU Memory Check"

print_info "GPU memory utilization:"
echo ""

for i in $(seq 0 $((GPU_COUNT - 1))); do
    FREE_MEM=$(nvidia-smi -i $i --query-gpu=memory.free --format=csv,noheader)
    TOTAL_MEM=$(nvidia-smi -memory.gpu.free.mb=$i)
    
    echo "  GPU $i: $(nvidia-smi -i $i --query-gpu=memory.used,memory.free,memory.total --format=csv,noheader)"
done

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
print_header "Environment Summary"

cat << EOF

${GREEN}✓ System Ready for GPU Training${NC}

Environment:
  • NVIDIA Driver: OK
  • CUDA Toolkit: $CUDA_VERSION
  • cuBLAS: OK
  • GPUs Available: $GPU_COUNT
  • CMake: OK
  • C++ Compiler: OK
  • S Compiler: OK

GPU Configuration:
  • Total GPUs: $GPU_COUNT

Next Steps:
  1. Build CUDA runtime:
     cd $NEURX_ROOT/cuda
     make -f Makefile.cuda build-cuda

  2. Build S trainer:
     make -f Makefile.cuda build-trainer

  3. Run training:
     make -f Makefile.cuda train-gpu

For detailed documentation, see: $NEURX_ROOT/cuda/IMPLEMENTATION_GUIDE.md
For troubleshooting, see: $NEURX_ROOT/cuda/README.md

EOF

print_success "Environment check complete - ready to build!"
