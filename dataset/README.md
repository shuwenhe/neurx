# dataset 目录说明

本目录用于存放训练数据集。下面提供在三家国内云（阿里云、腾讯云、华为云）上流式抓取 `bigcode/the-stack-dedup`（或其它 HF 数据集），并上传到对象存储后同步回本地 `/app/train/neurx/dataset` 的一键命令示例。

通用前提（在云实例上执行）
- 已在云主机上克隆或上传本仓库（包含 `tools/stack_streamer.py`）。
- 安装 Python 依赖：`pip install --user datasets tqdm`
- 若 HF 需要 token：`export HF_HUB_TOKEN=hf_xxx`

A. 阿里云（ECS + OSS）

1) 抓取并写到本地目录 `/data/the-stack-py`：

```bash
mkdir -p /data/the-stack-py
cd /root/neurx
python3 tools/stack_streamer.py \
  --dataset bigcode/the-stack-dedup \
  --lang py \
  --licenses MIT Apache-2.0 BSD-3-Clause \
  --shard-size 1000 \
  --out-dir /data/the-stack-py \
  --max-files 0 \
  --progress
```

2) 上传到 OSS（使用 `ossutil`）：

```bash
# 下载并配置 ossutil（一次性）
curl -O https://gosspublic.alicdn.com/ossutil/1.7.7/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil
ossutil config  # 按提示填写 AccessKeyId/AccessKeySecret/Region

# 上传目录
ossutil cp -r /data/the-stack-py/ oss://YOUR_BUCKET/the-stack/ --update
```

3) 在本地机器同步回 `/app/train/neurx/dataset/the-stack/`：

```bash
# 在本地配置好 ossutil 后运行：
ossutil cp -r oss://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/ --update
```

B. 腾讯云（CVM + COS）

1) 抓取到 `/data/the-stack-py`（与上同）。

2) 上传到 COS（使用 `coscmd`）：

```bash
pip3 install --user coscmd
coscmd config  # 填写 SecretId/SecretKey/Region
coscmd upload -r /data/the-stack-py/ cos://YOUR_BUCKET/the-stack/
```

3) 在本地下载：

```bash
coscmd download -r cos://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/
```

C. 华为云（ECS + OBS）

1) 抓取到 `/data/the-stack-py`（与上同）。

2) 上传到 OBS（使用 `obsutil`）：

```bash
# 下载 obsutil 并配置（详见华为官方文档）
# 将数据上传到 OBS
./obsutil cp -r /data/the-stack-py/ obs://YOUR_BUCKET/the-stack/ -u
```

3) 在本地下载：

```bash
./obsutil cp -r obs://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/ -u
```

小贴士与注意事项
- 对于 TB 级数据请优先使用对象存储并开启并行/分片上传，避免直接 `scp`。 
- 抓取时建议设置 `--shard-size` 并保持 `--out-dir` 在云磁盘（非根分区）。
- 严格核验 `license` 字段并记录来源，训练/发布模型时注意合规。 
- 如果无法直接访问 Hugging Face（国内网络问题），建议在云主机使用代理或在云控制台配置出网权限。

安装对象存储工具（快速参考）

阿里 OSS (`ossutil`)：
```bash
# 下载（示例）
curl -O https://gosspublic.alicdn.com/ossutil/1.7.7/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil
# 配置（会提示 AccessKeyId/AccessKeySecret/Region）
ossutil config
```

腾讯 COS (`coscmd`)：
```bash
pip3 install --user coscmd
# 配置：coscmd config（填写 SecretId/SecretKey/Region）
```

华为 OBS (`obsutil`)：
```bash
# 下载并配置 obsutil，请参考华为云官方文档：
# https://support.huaweicloud.com/obs/obs_03_0001.html
# 一般流程：下载 obsutil 可执行文件，并运行 obsutil config
```

数据验证脚本
----------------
仓库包含一个简单的验证脚本 `dataset/verify_dataset.sh`，用于检查 shards 是否存在、统计记录数，并验证前若干条 JSON 记录包含必要字段：

```bash
bash dataset/verify_dataset.sh /app/train/neurx/dataset/the-stack
```

如果你希望我把更多校验（如 license 统计、样本去重率估算）加入该脚本，我可以继续扩展。

示例一键脚本（阿里云；保存为 `run_fetch_and_upload_aliyun.sh` 在云端运行）

```bash
#!/bin/bash
set -euo pipefail

OUT_DIR=/data/the-stack-py
BUCKET=oss://YOUR_BUCKET/the-stack/

mkdir -p "$OUT_DIR"
cd /root/neurx
python3 tools/stack_streamer.py --dataset bigcode/the-stack-dedup --lang py --licenses MIT Apache-2.0 BSD-3-Clause --shard-size 1000 --out-dir "$OUT_DIR" --max-files 0 --progress

# 上传
ossutil cp -r "$OUT_DIR/" "$BUCKET" --update
```

把对象存储中的数据同步回本地后，最终数据应位于：

```
/app/train/neurx/dataset/the-stack/
```

需要我为你把 `run_fetch_and_upload_aliyun.sh`、`run_fetch_and_upload_tencent.sh`、`run_fetch_and_upload_huawei.sh` 三个脚本也创建到仓库中吗？
