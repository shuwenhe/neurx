package neurx.compression.release
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
use neurx.exporter.{model_export_config, model_export_artifact, prepare_model_export_bundle}
use neurx.deployment.chain.{model_deployment_config, model_deployment_artifact, prepare_model_deployment_bundle}

struct compression_release_config {
    string release_dir
    string quantization_manifest_path
    string distillation_manifest_path
    model_export_config export_config
    model_deployment_config deployment_config
}

struct compression_release_artifact {
    string release_dir
    model_export_artifact export_artifact
    model_deployment_artifact deployment_artifact
    string summary_path
}

func default_compression_release_config() compression_release_config {
    compression_release_config {
        release_dir: "artifact/release",
        quantization_manifest_path: "",
        distillation_manifest_path: "",
        export_config: model_export_config {},
        deployment_config: model_deployment_config {},
    }
}

func prepare_compression_release(compression_release_config config) compression_release_artifact {
    string root = trim(config.release_dir)
    if root == "" {
        root = "artifact/release"
    }
    runtime_make_dirs(root)
    model_export_config export_cfg = config.export_config
    export_cfg.export_dir = root + "/export"
    export_cfg.quantization_manifest_path = config.quantization_manifest_path
    export_cfg.distillation_manifest_path = config.distillation_manifest_path
    model_export_artifact export_artifact = prepare_model_export_bundle(export_cfg)
    model_deployment_config deploy_cfg = config.deployment_config
    deploy_cfg.export_dir = export_artifact.export_dir
    deploy_cfg.deployment_dir = root + "/deployment"
    model_deployment_artifact deployment_artifact = prepare_model_deployment_bundle(deploy_cfg)
    string summary = compression_release_summary_text(root, export_cfg, deploy_cfg, export_artifact, deployment_artifact)
    string summary_path = root + "/release_summary.txt"
    runtime_write_text_file(summary_path, summary)
    compression_release_artifact {
        release_dir: root,
        export_artifact: export_artifact,
        deployment_artifact: deployment_artifact,
        summary_path: summary_path,
    }
}

func compression_release_summary_text(
    string release_dir,
    model_export_config export_cfg,
    model_deployment_config deploy_cfg,
    model_export_artifact export_artifact,
    model_deployment_artifact deployment_artifact
) string {
    string out = ""
    out = out + "release_dir=" + release_dir + "\n"
    out = out + "export_dir=" + export_artifact.export_dir + "\n"
    out = out + "deployment_dir=" + deployment_artifact.deployment_dir + "\n"
    out = out + "quantized=" + bool_text(export_cfg.quantized) + "\n"
    out = out + "distilled=" + bool_text(export_cfg.distilled) + "\n"
    out = out + "export_format=" + export_cfg.export_format + "\n"
    out = out + "backend=" + deploy_cfg.backend + "\n"
    out = out + "model_name=" + export_cfg.model_name + "\n"
    out = out + "export_summary_path=" + export_artifact.bundle_summary_path + "\n"
    out = out + "deployment_summary_path=" + deployment_artifact.summary_path + "\n"
    out
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}
