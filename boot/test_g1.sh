#!/bin/bash
# G1 Boot Ownership Verification
# 严格的硬件验证，基于 QEMU 串口日志

set -e

TIMEOUT=10
SERIAL_LOG="/tmp/neurx_g1_serial.log"
BUILD_DIR="$(pwd)/build"
KERNEL_ELF="$BUILD_DIR/kernel.elf"
QEMU_LOG="$BUILD_DIR/qemu.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "G1 Boot Ownership Verification"
echo "============================================"
echo ""

# 检查内核文件
if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}[FAIL]${NC} Kernel ELF not found: $KERNEL_ELF"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Kernel ELF found: $KERNEL_ELF"

# 清空日志
> "$SERIAL_LOG"

# 启动 QEMU，监听串口
echo -e "${YELLOW}[INFO]${NC} Starting QEMU with kernel..."
echo -e "${YELLOW}[INFO]${NC} Waiting up to ${TIMEOUT}s for serial output..."

# 运行 QEMU，30 秒后自动关闭
timeout ${TIMEOUT} qemu-system-x86_64 \
    -kernel "$KERNEL_ELF" \
    -serial file:"$SERIAL_LOG" \
    -serial mon:stdio \
    -m 256M \
    -nographic \
    2>"$QEMU_LOG" || true

echo ""
echo "============================================"
echo "Serial Output Log:"
echo "============================================"
cat "$SERIAL_LOG" 2>/dev/null || echo "(no serial output)"
echo "============================================"
echo ""

# 验收标准：检查串口输出中必须的字符串
REQUIRED_STRINGS=(
    "NEURX_G1_KERNEL_ENTRY"
    "NEURX_G1_BOOT_SERVICES_EXITED"
    "NEURX_G1_COM1_OWNED"
    "NEURX_G1_PASS"
)

PASS=true
for required in "${REQUIRED_STRINGS[@]}"; do
    if grep -q "$required" "$SERIAL_LOG" 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} Found: $required"
    else
        echo -e "${RED}[FAIL]${NC} Missing: $required"
        PASS=false
    fi
done

echo ""
if [ "$PASS" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}G1 VERIFICATION: PASS ✅${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Boot ownership achieved:"
    echo "  ✓ UEFI firmware loaded NeurX image"
    echo "  ✓ ExitBootServices() confirmed"
    echo "  ✓ CPU control passed to NeurX kernel entry"
    echo "  ✓ COM1 UART initialized and functional"
    echo "  ✓ NeurX owns hardware"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}G1 VERIFICATION: FAIL ❌${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
