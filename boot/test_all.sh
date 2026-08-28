#!/bin/bash
# Comprehensive G0+G1 Boot Ownership Verification
# Tests both bare-metal execution and UEFI boot paths

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║     NeurX Boot Ownership Verification Suite (G0+G1)    ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

G0_PASSED=0
G1_PASSED=0

# Test G0: Bare-metal Multiboot2 execution
echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ G0: Bare-Metal Execution (Multiboot2 + QEMU)           │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
echo ""

if [ -x "boot/test_g0.sh" ]; then
    bash boot/test_g0.sh
    G0_RESULT=$?
    if [ $G0_RESULT -eq 0 ]; then
        G0_PASSED=1
    fi
else
    echo -e "${RED}[SKIP]${NC} test_g0.sh not found"
fi

echo ""
echo ""

# Test G1: UEFI boot ownership
echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│ G1: UEFI Boot Ownership (OVMF + BOOTX64.EFI)          │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
echo ""

if [ -x "boot/test_g1.sh" ]; then
    bash boot/test_g1.sh
    G1_RESULT=$?
    if [ $G1_RESULT -eq 0 ]; then
        G1_PASSED=1
    fi
else
    echo -e "${RED}[SKIP]${NC} test_g1.sh not found"
fi

echo ""
echo ""

# Summary
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                    TEST SUMMARY                        ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "G0 Bare-Metal Execution:  "
if [ $G0_PASSED -eq 1 ]; then
    echo -e "${GREEN}PASS ✅${NC}"
else
    echo -e "${RED}FAIL or PENDING ❌${NC}"
fi

echo -e "G1 UEFI Boot Ownership:   "
if [ $G1_PASSED -eq 1 ]; then
    echo -e "${GREEN}PASS ✅${NC}"
else
    echo -e "${RED}FAIL or PENDING ❌${NC}"
fi

echo ""
echo "Boot evidence paths:"
echo "  G0: /tmp/neurx_g0_serial.log (Multiboot2 markers)"
echo "  G1: /tmp/neurx_g1_serial.log (UEFI markers + ExitBootServices)"
echo ""

# Overall status
if [ $G0_PASSED -eq 1 ] && [ $G1_PASSED -eq 1 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ALL GATES PASSED ✅ — NeurX Boot Chain Verified   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    exit 0
elif [ $G0_PASSED -eq 1 ]; then
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}   G0 PASSED — Proceed to G1 when environment ready   ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    exit 1
else
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}         Install dependencies and retry          ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    exit 1
fi
