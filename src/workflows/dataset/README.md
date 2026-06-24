# Dataset Workflows

Shared dataset manifests and preprocessing flows belong here.

## Data Directory Convention

Raw training data and preprocessed shards live under `artifacts/data/`.
Manifests in this directory point to those paths via `dataset_name`.

Example layout:

```
artifacts/data/
    openwebtext/          # raw or tokenized shards
    pile/
    custom_corpus/
```

Pass the dataset name at launch:

```
dataset_name: "artifacts/data/openwebtext"
```

