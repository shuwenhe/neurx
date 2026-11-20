# Package Acquisition

## Result

**STOPPED - NO APPROVED ACQUISITION**

No package was downloaded or installed.

## Local search

Commands searched:

```bash
find /var/cache/apt /var/cntoolkit-3.13.6 /var/tmp /tmp /app/shuwen \
  -type f -name '*.deb'

find /var/cache/apt /var/cntoolkit-3.13.6 /var/tmp /tmp /app/shuwen \
  -type f -name '*.tar.gz'

dpkg -l
```

Exit results:

- Ubuntu 22.04 CNToolkit cache packages were found.
- No CNNL or CNCL package was found.
- No approved Ubuntu 20.04 CNRT/CNCC/CNNL/CNCL package set was found.
- No package maintainer script was run.

## Official-source attempt

Official Cambricon SDK URL checks were performed for historical Ubuntu 20.04 package names:

```text
https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cntoolkit_3.8.4-1.ubuntu20.04_amd64.deb
https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cnnl_1.23.2-1.ubuntu20.04_amd64.deb
https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cncl_1.13.0-1.ubuntu20.04_amd64.deb
```

All returned HTTP 502 Bad Gateway. No download was accepted or staged.

A fresh recheck on 2026-11-20 also returned HTTP 502 for CNTookit 3.8.4-1, CNNL 1.23.2-1 and CNCL 1.13.0-1 Focal package URLs.

Official documented enterprise download channels were identified:

- Cambricon SDK download portal: `https://sdk.cambricon.com/download`
- Enterprise SDK catalog: `https://cair.cambricon.com/#/home/catalog?type=SDK%20Release`
- Cambricon developer portal: `https://developer.cambricon.com/`
- Cambricon official MLU-OPS repository: `https://github.com/Cambricon/mlu-ops`

Public SDK documentation states that SDK resources may require the official enterprise account and sales/after-sales support approval.

## Official package source requirement

Package acquisition should come from Cambricon's official SDK repository or a vendor-signed/offline package channel. The vendor package names must:

- explicitly declare Ubuntu 20.04 support;
- explicitly declare amd64 support;
- list MLU590-M9 support;
- provide CNRT, CNCC/CNAS/CNBIN, CNNL, CNCL, CNDev and CNMon versions;
- include official SHA-256 metadata;
- declare compatibility with driver 6.5.52;
- declare firmware compatibility.

## Explicit authorization required

No system package installation is authorized by this phase.

Installation requires a separate explicit user authorization after:

1. package set and checksums are obtained;
2. package metadata is staged and inspected;
3. GLIBC requirements pass;
4. official compatibility is established.

## Official endpoint recheck

Observed during **2026-11-20 17:27–17:30 Asia/Shanghai**. Initial sandboxed requests to the toolkit directory, toolkit archive, MD5 sidecar and AI Repo each returned curl exit 7 and HTTP 000. Authorized read-only HEAD checks then produced these results.

| Exact URL | HTTP | curl exit |
| --- | ---: | ---: |
| `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/` | 502 | 0 |
| `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cntoolkit_3.8.4-1.ubuntu20.04_amd64.deb` | 502 | 0 |
| `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cntoolkit_3.8.4-1.ubuntu20.04_amd64.deb.md5sum` | 502 | 0 |
| `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cnnl_1.23.2-1.ubuntu20.04_amd64.deb` | 502 | 0 |
| `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cncl_1.13.0-1.ubuntu20.04_amd64.deb` | 502 | 0 |
| `https://cair.cambricon.com/` | 000 | 35, TLS connect failure |

Command was `curl -q -sSIL --connect-timeout 5 --max-time 12 -o /dev/null -w '%{http_code} %{url_effective}\n' "$url"`. It intentionally omitted `--fail` to record HTTP status. Exit 0 means an HTTP response was received. Public endpoint failure is from this network vantage, and the AI Repo TLS failure does not establish a portal outage.

**BLOCKED.** No archive or checksum was downloaded. The documented enterprise route is Cambricon AI Repo. Sign in, choose the account privilege upgrade under the profile icon, provide enterprise account information, and wait for approval. An approved account should request the exact Focal/M9 tuple and official SHA-256 manifest through the enterprise catalog or vendor support. If authenticated downloading is unavailable here, request vendor-approved offline delivery. Keep authorization and temporary download tokens outside Git and reports. The drafted support request was not sent. [Cambricon AI Repo and account requirement](https://cair.cambricon.com/) · [Draft support request](CAMBRICON_OFFICIAL_SUPPORT_REQUEST.md) · [Workspace staging and offline checklist](sdk_staging/README.md)
