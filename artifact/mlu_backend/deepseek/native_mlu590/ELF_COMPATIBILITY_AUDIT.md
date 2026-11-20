# ELF Compatibility Audit

## System GLIBC

```text
ldd: GLIBC 2.31
dpkg architecture: amd64
```

## Cached CNRT 6.12.1

Package:

```text
/var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb
```

Package metadata:

```text
Architecture=amd64
Depends=libc6 >=2.34
```

ELF extraction showed:

```text
highest GLIBC symbol: GLIBC_2.34
library: libcnrt.so.6.12.1
```

Result: **BLOCKED** on GLIBC 2.31.

## Cached CNCC 4.13.3

Package:

```text
/var/cntoolkit-3.13.6/cncc_4.13.3-1.ubuntu22.04_amd64.deb
```

Package metadata:

```text
Depends=libc6 >=2.34
Depends=libstdc++6 >=12
```

Extracted ELF tools include `cncc` and `clangd`.

```text
highest inspected GLIBC symbol: GLIBC_2.34
program interpreter: /lib64/ld-linux-x86-64.so.2
```

Result: **BLOCKED** on Ubuntu 20.04 GLIBC/libstdc++.

## Cached CNDev 3.12.6

Package:

```text
/var/cntoolkit-3.13.6/cndev_3.12.6-1.ubuntu22.04_amd64.deb
```

ELF extraction showed:

```text
highest GLIBC symbol: GLIBC_2.34
library: libcndev.so.3.12.6
```

Result: **BLOCKED**.

The installed CNDev 3.12.4 package remains usable and was not replaced.

## Cached CNBIN/CNAS

Debian metadata requires GLIBC >=2.34.

ELF package extraction was not treated as sufficient compatibility evidence. Package metadata alone already fails the Focal GLIBC requirement.

## Conclusion

No Ubuntu 22.04 package was staged into `/usr/local`, `/usr`, or `/opt`.

No package maintainer script was run.

No candidate passed offline ELF compatibility validation.
