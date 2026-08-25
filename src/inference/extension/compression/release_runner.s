package main
use neurx.compression.release.{compression_release_config, prepare_compression_release}
use neurx.exporter.{default_model_export_config}
use neurx.deployment.chain.{default_model_deployment_config}

func main() {
    compression_release_config config = compression_release_config {
        release_dir: "artifact/release",
        quantization_manifest_path: "artifact/quantized_model/quantized_model.manifest",
        distillation_manifest_path: "artifact/distillation/distillation.manifest",
        export_config: default_model_export_config(),
        deployment_config: default_model_deployment_config(),
    }
    artifact := prepare_compression_release(config)
    println("Compression release prepared at: " + artifact.release_dir)
    println("  export: " + artifact.export_artifact.export_dir)
    println("  deployment: " + artifact.deployment_artifact.deployment_dir)
    println("  summary: " + artifact.summary_path)
    0
}
