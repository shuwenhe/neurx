// DEPRECATED: See kernel/boot/uefi/entry.s and kernel/arch/x86_64/entry.s
//
// This file structure has been separated into:
// 1. kernel/boot/uefi/entry.s  - UEFI handoff logic
// 2. kernel/arch/x86_64/entry.s - Bare-metal x86_64 entry
//
// G1 (bare-metal boot) is now minimal:
// UEFI → Serial → Halt
//
// Memory/IRQ/Timer moved to G2/G3
//
// See kernel/GATE_G1_BARE_METAL_BOOT.md for current spec
