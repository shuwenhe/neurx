package neurx.exporter
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}

struct model_export_config {
    string model_name
    string source_model_dir
    string export_dir
    string export_format
    string target_runtime
    bool include_tokenizer
    bool include_checkpoint
    bool quantized
    bool distilled
    string quantization_manifest_path
    string distillation_manifest_path
    string version
}

struct model_export_artifact {
    string export_dir
    string manifest_path
    string model_card_path
    string metadata_path
    string bundle_summary_path
    string deployment_hint_path
}

func default_model_export_config() model_export_config {
    model_export_config {
        model_name: "neurx-model",
        source_model_dir: "artifact/model",
        export_dir: "artifact/export",
        export_format: "custom",
        target_runtime: "neurx",
        include_tokenizer: true,
        include_checkpoint: true,
        quantized: false,
        distilled: false,
        quantization_manifest_path: "",
        distillation_manifest_path: "",
        version: "1.0",
    }
}

func model_export_artifact_paths(string export_dir) model_export_artifact {
    model_export_artifact {
        export_dir: export_dir,
        manifest_path: export_dir + "/model_export.manifest",
        model_card_path: export_dir + "/model_card.txt",
        metadata_path: export_dir + "/metadata.txt",
        bundle_summary_path: export_dir + "/export_summary.txt",
        deployment_hint_path: export_dir + "/deployment_hint.txt",
    }
}

func model_export_load_optional_text(string path) string {
    if path == "" {
        return ""
    }
    if !runtime_file_exists(path) {
        return ""
    }
    runtime_read_text_file(path)
}

func model_export_format_suffix(string export_format) string {
    if export_format == "onnx" {
        return ".onnx"
    }
    if export_format == "tensorrt" {
        return ".engine"
    }
    if export_format == "huggingface" {
        return ".hf"
    }
    if export_format == "custom" {
        return ".neurx"
    }
    ".bin"
}

func model_export_bundle_summary_text(model_export_config config, string quant_text, string distill_text) string {
    string out = ""
    out = out + "model.name=" + config.model_name + "\n"
    out = out + "model.source_dir=" + config.source_model_dir + "\n"
    out = out + "model.export_format=" + config.export_format + "\n"
    out = out + "model.target_runtime=" + config.target_runtime + "\n"
    out = out + "model.quantized=" + bool_text(config.quantized) + "\n"
    out = out + "model.distilled=" + bool_text(config.distilled) + "\n"
    out = out + "model.include_tokenizer=" + bool_text(config.include_tokenizer) + "\n"
    out = out + "model.include_checkpoint=" + bool_text(config.include_checkpoint) + "\n"
    out = out + "model.version=" + config.version + "\n"
    if quant_text != "" {
        out = out + "\n[quantization]\n" + quant_text + "\n"
    }
    if distill_text != "" {
        out = out + "\n[distillation]\n" + distill_text + "\n"
    }
    out
}

func model_export_metadata_text(model_export_config config, string manifest_path) string {
    string out = ""
    out = out + "manifest_path=" + manifest_path + "\n"
    out = out + "model_name=" + config.model_name + "\n"
    out = out + "export_format=" + config.export_format + "\n"
    out = out + "target_runtime=" + config.target_runtime + "\n"
    out = out + "artifact_suffix=" + model_export_format_suffix(config.export_format) + "\n"
    out = out + "quantized=" + bool_text(config.quantized) + "\n"
    out = out + "distilled=" + bool_text(config.distilled) + "\n"
    out
}

func model_export_card_text(model_export_config config, string quant_text, string distill_text) string {
    string out = ""
    out = out + "# model Export Card\n"
    out = out + "name: " + config.model_name + "\n"
    out = out + "format: " + config.export_format + "\n"
    out = out + "runtime: " + config.target_runtime + "\n"
    out = out + "source: " + config.source_model_dir + "\n"
    out = out + "include_tokenizer: " + bool_text(config.include_tokenizer) + "\n"
    out = out + "include_checkpoint: " + bool_text(config.include_checkpoint) + "\n"
    out = out + "quantized: " + bool_text(config.quantized) + "\n"
    out = out + "distilled: " + bool_text(config.distilled) + "\n"
    if quant_text != "" {
        out = out + "\nQuantization manifest is attached in model_export.manifest.\n"
    }
    if distill_text != "" {
        out = out + "Distillation manifest is attached in model_export.manifest.\n"
    }
    out
}

func model_export_deployment_hint_text(model_export_config config) string {
    string out = ""
    out = out + "deploy.export_dir=" + config.export_dir + "\n"
    out = out + "deploy.model_name=" + config.model_name + "\n"
    out = out + "deploy.target_runtime=" + config.target_runtime + "\n"
    out = out + "deploy.export_format=" + config.export_format + "\n"
    out = out + "deploy.quantized=" + bool_text(config.quantized) + "\n"
    out = out + "deploy.distilled=" + bool_text(config.distilled) + "\n"
    out = out + "deploy.suggested_backend=" + model_export_suggest_backend(config) + "\n"
    out
}

func model_export_suggest_backend(model_export_config config) string {
    if config.export_format == "tensorrt" {
        return "nvidia-tensorrt"
    }
    if config.export_format == "onnx" {
        return "onnxruntime"
    }
    if config.quantized {
        return "cuda-int8"
    }
    "neurx-runtime"
}

func prepare_model_export_bundle(model_export_config config) model_export_artifact {
    string root = trim(config.export_dir)
    if root == "" {
        root = "artifact/export"
    }
    runtime_make_dirs(root)
    model_export_artifact artifact = model_export_artifact_paths(root)
    string quant_text = model_export_load_optional_text(config.quantization_manifest_path)
    string distill_text = model_export_load_optional_text(config.distillation_manifest_path)
    string summary_text = model_export_bundle_summary_text(config, quant_text, distill_text)
    runtime_write_text_file(artifact.manifest_path, summary_text)
    runtime_write_text_file(artifact.metadata_path, model_export_metadata_text(config, artifact.manifest_path))
    runtime_write_text_file(artifact.model_card_path, model_export_card_text(config, quant_text, distill_text))
    runtime_write_text_file(artifact.bundle_summary_path, summary_text)
    runtime_write_text_file(artifact.deployment_hint_path, model_export_deployment_hint_text(config))
    artifact
}

func model_export_summary_text(model_export_artifact artifact, model_export_config config) string {
    string out = ""
    out = out + "export_dir=" + artifact.export_dir + "\n"
    out = out + "manifest_path=" + artifact.manifest_path + "\n"
    out = out + "metadata_path=" + artifact.metadata_path + "\n"
    out = out + "model_card_path=" + artifact.model_card_path + "\n"
    out = out + "bundle_summary_path=" + artifact.bundle_summary_path + "\n"
    out = out + "deployment_hint_path=" + artifact.deployment_hint_path + "\n"
    out = out + "export_format=" + config.export_format + "\n"
    out = out + "target_runtime=" + config.target_runtime + "\n"
    out
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}
