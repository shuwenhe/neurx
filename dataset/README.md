# dataset directoryexplanation

English textdirectoryEnglish texttrainingdataEnglish text.English text(English text, English text, English text)English text `bigcode/the-stack-dedup`(English text HF dataEnglish text), English textstepEnglish text `/app/train/neurx/dataset` English textexample.

English text(English text)
- English textmainEnglish text(English text `tools/stack_streamer.py`).
- English text Python English text: `pip install --user datasets tqdm`
- English text HF Required token: `export HF_HUB_TOKEN=hf_xxx`

A. English text(ECS + OSS)

1) English textdirectory `/data/the-stack-py`:

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

2) English text OSS(use `ossutil`):

```bash
# English textconfiguration ossutil(English text)
curl -O https://gosspublic.alicdn.com/ossutil/1.7.7/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil
ossutil config  # English textpromptEnglish text AccessKeyId/AccessKeySecret/Region

# English textdirectory
ossutil cp -r /data/the-stack-py/ oss://YOUR_BUCKET/the-stack/ --update
```

3) English textstepEnglish text `/app/train/neurx/dataset/the-stack/`:

```bash
# English textconfigurationEnglish text ossutil English textrun:
ossutil cp -r oss://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/ --update
```

B. English text(CVM + COS)

1) English text `/data/the-stack-py`(English text).

2) English text COS(use `coscmd`):

```bash
pip3 install --user coscmd
coscmd config  # English text SecretId/SecretKey/Region
coscmd upload -r /data/the-stack-py/ cos://YOUR_BUCKET/the-stack/
```

3) English text:

```bash
coscmd download -r cos://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/
```

C. English text(ECS + OBS)

1) English text `/data/the-stack-py`(English text).

2) English text OBS(use `obsutil`):

```bash
# English text obsutil English textconfiguration(English text)
# English textdataEnglish text OBS
./obsutil cp -r /data/the-stack-py/ obs://YOUR_BUCKET/the-stack/ -u
```

3) English text:

```bash
./obsutil cp -r obs://YOUR_BUCKET/the-stack/ /app/train/neurx/dataset/the-stack/ -u
```

English text
- English text TB English textdataEnglish textuseEnglish text/English text, English text `scp`.
- English text `--shard-size` English text `--out-dir` English text(English text).
- English text `license` English textSource, training/English textmodelEnglish text.
- English text Hugging Face(English text), English textmainEnglish textuseEnglish textconfigurationEnglish text.

English texttool(quickEnglish text)

English text OSS (`ossutil`):
```bash
# English text(example)
curl -O https://gosspublic.alicdn.com/ossutil/1.7.7/ossutil64
chmod +x ossutil64
sudo mv ossutil64 /usr/local/bin/ossutil
# configuration(English textprompt AccessKeyId/AccessKeySecret/Region)
ossutil config
```

English text COS (`coscmd`):
```bash
pip3 install --user coscmd
# configuration: coscmd config(English text SecretId/SecretKey/Region)
```

English text OBS (`obsutil`):
```bash
# English textconfiguration obsutil, English text:
# https://support.huaweicloud.com/obs/obs_03_0001.html
# English textpipeline: English text obsutil English textfile, English textrun obsutil config
```

dataEnglish text
----------------
English text `dataset/verify_dataset.sh`, English text shards English text, statisticsEnglish text, English text JSON English text:

```bash
bash dataset/verify_dataset.sh /app/train/neurx/dataset/the-stack
```

English text(English text license statistics, English textdeduplicationEnglish text)English text, English textAllowedEnglish textextension.

exampleEnglish text(English text; saveEnglish text `run_fetch_and_upload_aliyun.sh` English textrun)

```bash
#!/bin/bash
set -euo pipefail

OUT_DIR=/data/the-stack-py
BUCKET=oss://YOUR_BUCKET/the-stack/

mkdir -p "$OUT_DIR"
cd /root/neurx
python3 tools/stack_streamer.py --dataset bigcode/the-stack-dedup --lang py --licenses MIT Apache-2.0 BSD-3-Clause --shard-size 1000 --out-dir "$OUT_DIR" --max-files 0 --progress

# English text
ossutil cp -r "$OUT_DIR/" "$BUCKET" --update
```

English textdataEnglish textstepEnglish text, English textdataEnglish text:

```
/app/train/neurx/dataset/the-stack/
```

RequiredEnglish text `run_fetch_and_upload_aliyun.sh`, `run_fetch_and_upload_tencent.sh`, `run_fetch_and_upload_huawei.sh` English text?
