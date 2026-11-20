# Hardware Report

Audit date: 2026-11-20
Hostname: tza-0a09-ai01-em9

## Findings

| Card | PCI BDF | Model | SN | NUMA | IOMMU group | PCIe current | PCIe max | Card memory |
|---|---|---|---|---:|---|---|---|---:|
| 0 | 0000:4f:00.0 | MLU590-M9 | 8003002249300066 | 2 | 72 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 1 | 0000:53:00.0 | MLU590-M9 | 8003002249300130 | 2 | 75 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 2 | 0000:6f:00.0 | MLU590-M9 | 8003002249300089 | 3 | 113 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 3 | 0000:73:00.0 | MLU590-M9 | 8003002249300041 | 3 | 116 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 4 | 0000:af:00.0 | MLU590-M9 | 8003002249300067 | 5 | 170 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 5 | 0000:b3:00.0 | MLU590-M9 | 8003002249300101 | 5 | 173 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 6 | 0000:cf:00.0 | MLU590-M9 | 8003002249300168 | 6 | 211 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |
| 7 | 0000:d3:00.0 | MLU590-M9 | 8003002249300112 | 6 | 214 | x16 / 16 GT/s | x16 / 32 GT/s | 98304 MiB |

All values are based on `lspci -vv -s`, `/sys/bus/pci/devices/`, `cnmon all -l`, `cnmon info -m -g`, and the executed CNDev `devicequery` sample.

## PCI identity

- Quantity: 8
- Vendor: Cambricon (`0xcabc`)
- Device ID: `0x0590`
- Subsystem vendor/device: `0xcabc:0x8003`
- PCI class: `0x120000` (processing accelerator)
- Firmware: `v1.3.1` for all cards
- MCU name report: MLU590-M9
- CNMon card model: MLU590-M9
- CNDev card model: MLU590-M9

## Memory interpretation

- `cnmon` reports 98304 MiB global physical memory per card.
- The CNDev sample reports 97060 MiB physical memory and 98304 MiB global memory per card. This report uses 98304 MiB as the vendor-reported global card capacity and does not claim more than the tool evidence.
- At audit time, all cards reported approximately 93666 MiB physical memory used, with 3395 MiB free. Existing `VLLM::Worker_TP*` processes correspond to this usage.

## PCIe and topology

- Each card is currently negotiating PCIe 16 GT/s on x16.
- Each card advertises a maximum of 32 GT/s on x16.
- NUMA placement is 2/2/3/3/5/5/6/6 for cards 0 through 7.
- CNMon topology pairs cards 0/1, 2/3, 4/5, and 6/7 as SGL; other relationships are reported as SYS.

## Classification

- **CONFIRMED:** exact model, card count, PCIe width/speed, NUMA nodes, IOMMU groups, memory capacity, health, and firmware.
- **PARTIALLY CONFIRMED:** PCIe topology relationships.
- **NOT TESTED:** native kernel launch, host/device transfers, and benchmarked bandwidth.
