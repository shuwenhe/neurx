# CNRT glibc analysis

**CONFIRMED.** The cached official CNRT is an x86-64 ELF DSO with SONAME `libcnrt.so`, package version `6.12.1-1.ubuntu22.04` and build ID `c8d076c4b0008684a68db48bfd9994c0ef12686d`. Its ELF comment identifies Ubuntu GCC 9.5.0. Host GCC is 9.4.0. The cached toolkit repository is 3.13.6-1.ubuntu22.04. CNCC 4.13.3-1.ubuntu22.04 exists as a cached package and no CNCC executable was found on PATH.

The direct ELF dependencies are `libstdc++.so.6`, `libm.so.6`, `libc.so.6` and `ld-linux-x86-64.so.2`. `ldd` found these paths and exited 0 while explicitly reporting the missing symbol version. An actual loader attempt exited 1. The host provides glibc 2.31. `GLIBC_2.34` is a required libc version in the ELF metadata. CNDrv is also a package dependency and was absent from the inspected loader cache. CNDrv initialization was never reached.

The extracted SDK provides `artifact/build/cnrt_integration/sdk/usr/local/neuware/include/cnrt.h`. The two other workspace objects named `libcnrt.so` are loader-test fixtures. The system search found no other vendor CNRT in the readable paths and was incomplete under `/opt/containerd`, which denied access.

## Exact command output

The shell variable used below was `p="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so"`, with the current directory `/app/shuwen/neurx`.

```text

$ getconf GNU_LIBC_VERSION
glibc 2.31
exit=0

$ file -L "$p"
/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, BuildID[sha1]=c8d076c4b0008684a68db48bfd9994c0ef12686d, stripped
exit=0

$ readelf -d "$p"

Dynamic section at offset 0xc7d60 contains 28 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [libstdc++.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [ld-linux-x86-64.so.2]
 0x000000000000000e (SONAME)             Library soname: [libcnrt.so]
 0x000000000000000c (INIT)               0x9000
 0x000000000000000d (FINI)               0xacc30
 0x0000000000000019 (INIT_ARRAY)         0xc8bc0
 0x000000000000001b (INIT_ARRAYSZ)       32 (bytes)
 0x000000000000001a (FINI_ARRAY)         0xc8be0
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x328
 0x0000000000000005 (STRTAB)             0x2100
 0x0000000000000006 (SYMTAB)             0x888
 0x000000000000000a (STRSZ)              6481 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000003 (PLTGOT)             0xc9000
 0x0000000000000002 (PLTRELSZ)           1728 (bytes)
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000017 (JMPREL)             0x80d8
 0x0000000000000007 (RELA)               0x3da0
 0x0000000000000008 (RELASZ)             17208 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffffe (VERNEED)            0x3c60
 0x000000006fffffff (VERNEEDNUM)         4
 0x000000006ffffff0 (VERSYM)             0x3a52
 0x000000006ffffff9 (RELACOUNT)          704
 0x0000000000000000 (NULL)               0x0
exit=0

$ readelf --version-info "$p" | sed -n "/Version needs section/,$ p"
Version needs section '.gnu.version_r' contains 4 entries:
 Addr: 0x0000000000003c60  Offset: 0x003c60  Link: 5 (.dynstr)
  000000: Version: 1  File: ld-linux-x86-64.so.2  Cnt: 1
  0x0010:   Name: GLIBC_2.3  Flags: none  Version: 15
  0x0020: Version: 1  File: libstdc++.so.6  Cnt: 6
  0x0030:   Name: CXXABI_1.3.7  Flags: none  Version: 17
  0x0040:   Name: GLIBCXX_3.4.26  Flags: none  Version: 14
  0x0050:   Name: GLIBCXX_3.4.9  Flags: none  Version: 9
  0x0060:   Name: CXXABI_1.3  Flags: none  Version: 8
  0x0070:   Name: GLIBCXX_3.4.21  Flags: none  Version: 7
  0x0080:   Name: GLIBCXX_3.4  Flags: none  Version: 6
  0x0090: Version: 1  File: libm.so.6  Cnt: 2
  0x00a0:   Name: GLIBC_2.29  Flags: none  Version: 16
  0x00b0:   Name: GLIBC_2.2.5  Flags: none  Version: 4
  0x00c0: Version: 1  File: libc.so.6  Cnt: 7
  0x00d0:   Name: GLIBC_2.4  Flags: none  Version: 13
  0x00e0:   Name: GLIBC_2.7  Flags: none  Version: 12
  0x00f0:   Name: GLIBC_2.14  Flags: none  Version: 11
  0x0100:   Name: GLIBC_2.34  Flags: none  Version: 10
  0x0110:   Name: GLIBC_2.2.5  Flags: none  Version: 5
  0x0120:   Name: GLIBC_2.3.2  Flags: none  Version: 3
  0x0130:   Name: GLIBC_2.3.4  Flags: none  Version: 2
exit=0

$ ldd "$p"
/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by /app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so)
	linux-vdso.so.1 (0x00007ffc9df39000)
	libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f0a1dfbe000)
	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f0a1de6f000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f0a1dc7d000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f0a1e29b000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f0a1dc62000)
exit=0

$ python3 -S -c 'import ctypes,sys; ctypes.CDLL(sys.argv[1])' "$p"
Traceback (most recent call last):
  File "<string>", line 1, in <module>
  File "/usr/lib/python3.8/ctypes/__init__.py", line 373, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by /app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so)
exit=1

$ readelf -p .comment "$p"

String dump of section '.comment':
  [     0]  GCC: (Ubuntu 9.5.0-1ubuntu1~22.04) 9.5.0

exit=0

$ find /usr/local/neuware /usr/include /usr/lib /opt "$PWD/artifact/build" \( -name cnrt.h -o -name "libcnrt.so*" \) -print
find: ‘/opt/containerd’: Permission denied
/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/include/cnrt.h
/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so.6.12.1
/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so
/app/shuwen/neurx/artifact/build/cnrt_integration/loader-only/libcnrt.so
/app/shuwen/neurx/artifact/build/mlu_boundary/loader-fixture/libcnrt.so
exit=1

$ ldconfig -p | grep -Ei "cnrt|cndrv|cnnl|cncl|cndev"
	libcndev.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libcndev.so
exit=0

$ find /var/cntoolkit-3.13.6 -maxdepth 1 -name "cn*.deb" | grep -E "/(cnrt|cncc|cndrv|cndev|cncl|cnnl)_"
/var/cntoolkit-3.13.6/cncc_4.13.3-1.ubuntu22.04_amd64.deb
/var/cntoolkit-3.13.6/cndev_3.12.6-1.ubuntu22.04_amd64.deb
/var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb
/var/cntoolkit-3.13.6/cndrv_2.13.2-1.ubuntu22.04_amd64.deb
exit=0

$ for pkg in /var/cntoolkit-3.13.6/{cnrt,cncc,cndrv,cndev}_*.deb; do dpkg-deb -f "$pkg" Package Version Architecture Depends; done
Package: cnrt
Version: 6.12.1-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libstdc++6 (>= 9), cndrv
Package: cncc
Version: 4.13.3-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libgcc-s1 (>= 3.4), libstdc++6 (>= 12), cnas, libc6-dev, libc6-dev-i386
Package: cndrv
Version: 2.13.2-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libstdc++6 (>= 5.2), cnbin
Package: cndev
Version: 3.12.6-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libgcc-s1 (>= 3.0), libstdc++6 (>= 5.2)
exit=0

$ command -v cncc
exit=1

$ gcc -dumpfullversion
9.4.0
exit=0

$ findmnt -t cgroup,cgroup2 -o TARGET,FSTYPE,OPTIONS
TARGET                          FSTYPE  OPTIONS
/sys/fs/cgroup/unified          cgroup2 ro,nosuid,nodev,noexec,relatime,nsdelegate
/sys/fs/cgroup/systemd          cgroup  ro,nosuid,nodev,noexec,relatime,xattr,name=systemd
/sys/fs/cgroup/freezer          cgroup  ro,nosuid,nodev,noexec,relatime,freezer
/sys/fs/cgroup/perf_event       cgroup  ro,nosuid,nodev,noexec,relatime,perf_event
/sys/fs/cgroup/pids             cgroup  ro,nosuid,nodev,noexec,relatime,pids
/sys/fs/cgroup/cpu,cpuacct      cgroup  ro,nosuid,nodev,noexec,relatime,cpu,cpuacct
/sys/fs/cgroup/hugetlb          cgroup  ro,nosuid,nodev,noexec,relatime,hugetlb
/sys/fs/cgroup/rdma             cgroup  ro,nosuid,nodev,noexec,relatime,rdma
/sys/fs/cgroup/cpuset           cgroup  ro,nosuid,nodev,noexec,relatime,cpuset
/sys/fs/cgroup/misc             cgroup  ro,nosuid,nodev,noexec,relatime,misc
/sys/fs/cgroup/devices          cgroup  ro,nosuid,nodev,noexec,relatime,devices
/sys/fs/cgroup/blkio            cgroup  ro,nosuid,nodev,noexec,relatime,blkio
/sys/fs/cgroup/memory           cgroup  ro,nosuid,nodev,noexec,relatime,memory
/sys/fs/cgroup/net_cls,net_prio cgroup  ro,nosuid,nodev,noexec,relatime,net_cls,net_prio
exit=0

$ cat /sys/fs/cgroup/devices/user.slice/devices.list
a *:* rwm
exit=0

$ find -L /sys/bus/pci/devices -maxdepth 2 -name vendor -exec grep -il "^0xcabc$" {} +
/sys/bus/pci/devices/0000:af:00.0/vendor
/sys/bus/pci/devices/0000:6f:00.0/vendor
/sys/bus/pci/devices/0000:d3:00.0/vendor
/sys/bus/pci/devices/0000:53:00.0/vendor
/sys/bus/pci/devices/0000:cf:00.0/vendor
/sys/bus/pci/devices/0000:4f:00.0/vendor
/sys/bus/pci/devices/0000:b3:00.0/vendor
/sys/bus/pci/devices/0000:73:00.0/vendor
exit=0

$ objdump -T "$p" | grep GLIBC_2.34
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  dlclose
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  pthread_rwlock_rdlock
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  pthread_once
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  dlsym
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  dlerror
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  pthread_rwlock_unlock
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  dlopen
0000000000000000      DF *UND*	0000000000000000  GLIBC_2.34  pthread_rwlock_wrlock
exit=0
```
