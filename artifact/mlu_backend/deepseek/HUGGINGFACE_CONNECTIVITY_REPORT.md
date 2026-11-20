# Hugging Face Connectivity Report

Audit date: 2026-11-20

## Final Status

**CONNECTIVITY_READY**

Direct IPv4 and IPv6 access to `huggingface.co` and `api.huggingface.co` is blocked or timing out, but the server already has a working local Clash HTTP/SOCKS proxy. A session-level proxy test successfully reached the repository and API. This report does not download model weights or change system proxy configuration.

## Repository

- Repository: `deepseek-ai/DeepSeek-V2-Lite`
- Repository API result: HTTP 200
- API revision SHA: `604d5664dddd88a0433dbae533b7fe9472482de0`
- Repository siblings: 15
- Weight shards: 4 safetensors files
- Weight index: `model.safetensors.index.json`
- Configuration: `config.json`
- Generation configuration: `generation_config.json`
- Tokenizer: `tokenizer.json`
- Tokenizer configuration: `tokenizer_config.json`

## DNS

The following commands resolved valid public addresses:

```text
getent ahostsv4 huggingface.co
exit=0

getent ahostsv6 huggingface.co
exit=0
```

Resolved addresses included:

| Host | IPv4 |
|---|---|
| `huggingface.co` | `69.171.229.73` |
| `api.huggingface.co` | `108.160.170.33` |
| `cdn-lfs.hf.co` | `13.226.244.21`, `13.226.244.34`, `13.226.244.36` |
| `transfer.xethub.hf.co` | `18.164.52.31`, `18.164.52.4`, `18.164.52.52` |
| `cas-bridge.xethub.hf.co` | `52.222.154.39`, `52.222.154.60`, `52.222.154.70` |

`resolv.conf` contains no custom proxy setting and uses:

```text
nameserver 114.114.114.114
nameserver 119.29.29.29
```

## Direct outbound TCP 443

Commands used:

```bash
timeout 12 bash -c 'exec 3<>/dev/tcp/huggingface.co/443'
exit=124

timeout 12 bash -c 'exec 3<>/dev/tcp/api.huggingface.co/443'
exit=124

timeout 12 bash -c 'exec 3<>/dev/tcp/cdn-lfs.hf.co/443'
exit=0

timeout 12 bash -c 'exec 3<>/dev/tcp/transfer.xethub.hf.co/443'
exit=0

timeout 12 bash -c 'exec 3<>/dev/tcp/cas-bridge.xethub.hf.co/443'
exit=0

timeout 12 bash -c 'exec 3<>/dev/tcp/github.com/443'
exit=0
```

Direct HTTPS tests returned:

```text
curl -4 -I https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite
exit=28
error: connection timeout after 8-10 seconds

curl -4 -I https://api.huggingface.co
exit=28
error: connection timeout
```

GitHub and Cloudflare HTTPS control requests both returned HTTP 200:

```text
curl -4 -I https://github.com
exit=0, HTTP/2 200

curl -4 -I https://www.cloudflare.com
exit=0, HTTP/2 200
```

This indicates DNS and general Internet routing are functioning, but direct access to the primary Hugging Face hosts is blocked or its route is unavailable.

## Existing local proxy

No proxy environment variables or GNOME system proxy were configured:

```text
HTTP_PROXY=not set
HTTPS_PROXY=not set
ALL_PROXY=not set
SOCKS_PROXY=not set
Gnome system proxy mode=none
```

An existing `clash-linux-amd64-v1.10.0` process is running and listening on:

```text
127.0.0.1:7890 HTTP proxy
127.0.0.1:7891 SOCKS proxy
```

No proxy configuration or process was changed.

## Proxy verification

HTTP proxy test:

```bash
curl --proxy http://127.0.0.1:7890 \
  https://huggingface.co/api/models/deepseek-ai/DeepSeek-V2-Lite
```

Result:

```text
exit=0
HTTP=200
downloaded bytes=3478
revision SHA=604d5664dddd88a0433dbae533b7fe9472482de0
siblings=15
```

Repository test:

```bash
curl --proxy http://127.0.0.1:7890 -I \
  https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite
```

Result:

```text
exit=0
HTTP/2 200
```

SOCKS proxy test:

```bash
curl --proxy socks5h://127.0.0.1:7891 -I \
  https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite
```

Result:

```text
exit=0
HTTP/2 200
```

## Xet and CDN endpoints

TCP 443 is reachable for:

- `cdn-lfs.hf.co`
- `transfer.xethub.hf.co`
- `cas-bridge.xethub.hf.co`

TLS certificate verification succeeded:

```text
openssl s_client -4 -connect cdn-lfs.hf.co:443 \
  -servername cdn-lfs.hf.co
exit=0
Verify return code: 0

openssl s_client -4 -connect transfer.xethub.hf.co:443 \
  -servername transfer.xethub.hf.co
exit=0
Verify return code: 0
```

Root-path HTTP checks returned CloudFront HTTP 403 for CDN and Xet. This is expected for unauthenticated root paths and is not evidence that specific signed model-object URLs fail.

## Routing and firewall

The default route is:

```text
default via 10.1.1.1 dev bond0 src 10.1.1.27
```

The server has working bonded management interfaces and no route was added or changed.

The local user could not inspect privileged firewall state:

```text
nft: command not found
sudo -n iptables -S
exit=1
error=sudo: a password is required
```

Therefore, local evidence cannot determine whether firewall policy, ISP policy, or upstream policy blocks direct Hugging Face hosts. The local proxy provides a working session-level route.

## Writable destinations

Recommended destination: `/local/nvme6n1/models/deepseek/DeepSeek-V2-Lite`

That NVMe currently provides:

```text
Size: 3.5T
Used: 1.5T
Available: 1.9T
Owner/mode: root:root, drwxrwxrwx
Writable as gaozhi: yes
```

Other writable alternatives:

| Mount | Available |
|---|---:|
| `/local/nvme0n1` | 2.8T |
| `/local/nvme1n1` | 398G |
| `/local/nvme2n1` | 2.6T |
| `/local/nvme4n1` | 1.2T |
| `/local/nvme5n1` | 2.5T |
| `/local/nvme6n1` | 1.9T |
| `/local/nvme7n1` | 544G |
| `/srv` | 2.0T |

`/data` remains root-owned and unwritable by `gaozhi`.

## Recommended download invocation

Use the existing local proxy only for the download process and do not add proxy variables system-wide:

```bash
HTTP_PROXY=http://127.0.0.1:7890 \
HTTPS_PROXY=http://127.0.0.1:7890 \
ALL_PROXY=socks5h://127.0.0.1:7891 \
hf download deepseek-ai/DeepSeek-V2-Lite \
  --revision 604d5664dddd88a0433dbae533b7fe9472482de0 \
  --local-dir /local/nvme6n1/models/deepseek/DeepSeek-V2-Lite
```

The exact revision is recommended to reproduce the verified repository state. `hf` remains uninstalled, so tooling must be installed in an isolated virtual environment before the download.

## Administrator actions

No weight download was started.

For direct-network operation, an administrator should verify:

1. egress firewall policy for `huggingface.co` and `api.huggingface.co`;
2. route/DNS policy for Hugging Face;
3. whether a corporate proxy is mandatory;
4. TLS interception/trust configuration;
5. whether Hugging Face DNS, API, and CDN/Xet access are permitted;
6. privileged `iptables`/`nftables` or upstream firewall logs.

No network security restriction should be bypassed outside the existing approved local proxy.
