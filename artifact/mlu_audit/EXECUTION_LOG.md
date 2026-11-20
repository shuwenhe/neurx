# Execution Log

All commands in this log were read-only except:
- creation of `/app/shuwen/neurx/artifact/mlu_audit/build/devicequery`,
- compilation of the vendor C sample into that artifact directory,
- creation of this audit report directory and markdown files.

No system configuration, devices, kernels, drivers, packages, compiler installation, or network configuration was changed.

## 2026-11-20 11:51-12:04 UTC+08

| Exit | Command or operation |
|---:|---|
| 0 | `cat /etc/os-release`, `uname -a`, `hostnamectl` |
| 0 | `lscpu`, `free -h` |
| 0 | `df`, `lsblk` |
| 0 | `nvidia-smi` (no executable/result), `lspci` accelerator filter |
| 0 | `cd /app/shuwen && pwd; find . -maxdepth 1` |
| 0 | `git status --short --branch` in `/app/shuwen/neurx` |
| 0 | `lspci -nnk` |
| 0 | `lspci -vv -s` for cards 4f,53,6f,73,af,b3,cf,d3 |
| 0 | `/sys/bus/pci/devices/*` vendor, device, class, NUMA, driver, subsystem, link, IOMMU reads |
| 0 | `lsmod` |
| 1 | `modinfo cambricon-pci-drv_s1m1` because binding name is not module name |
| 0 | `dmesg` Cambricon substring search |
| 0 | `id`, `find /dev`, device-node ownership reads |
| 0 | `/proc/1/cgroup`, capability/status, group reads |
| 0 | `which cnmon cncc cnas cnperf cnrt` |
| 1 | `ldconfig -p` grep for CNRT/CNDRV/CNNL/CNCL |
| 1 | `find /usr/local /opt` SDK headers/tool search |
| 0 | `find /usr/local /opt /usr/lib` Cambricon/Neuware path search |
| 0 | NeurX source inventory |
| 0 | `cnmon -h` |
| 0 | `cnmon all -l` |
| 0 | `cnmon info -t`, `cnmon info -m -g` |
| 0 | `cnmon info -e -p -u -q` |
| 0 | `cnmon info -pcie`, `cnmon topo -p` |
| 0 | `cnmon mlulink -n`, `cnmon mlulink -s` |
| 0 | Cndev sample file and CMake/README reads |
| 0 | `gcc --version`, `cmake --version` check |
| 0 | `gcc ... devicequery.c -lcndev` compile into NeurX artifact |
| 0 | `LD_LIBRARY_PATH=/usr/local/neuware/lib64 devicequery` execution; returned card num=8 |
| 1 | Environment-variable search; no matching variables found |
| 0 | `find /usr/local/neuware/lib64` |
| 0 | `ps` and `/proc` checks for existing VLLM workers |
| 0 | Host search for CNRT/CNNL/CNCL/CNDRV libraries |
| 0 | `dpkg -l` Cambricon package checks |
| 0 | `modinfo cambricon_drv` |
| 0 | `cnmon` per-card memory and health loop |
| 0 | `cnmon mlulink -c 0 -s` |
| 0 | `cnmon mlulink -c 0 -n` |
| 0 | `dpkg -L cntoolkit` |
| 0 | `dpkg -L cndev` |
| 0 | NeurX source reads for device ABI, tensors, GEMM, attention, tensor parallel, NCCL-shaped communication |

## Summary

No destructive command was executed. No existing NeurX or S compiler files were changed outside the created audit artifact, and the pre-audit NeurX Git status was clean.
