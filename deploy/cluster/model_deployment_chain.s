package neurx.deployment.chain
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
use neurx.strings

struct model_deployment_config {
    string cluster_name
    string image_name
    string backend
    string export_dir
    string deployment_dir
    string checkpoint_dir
    string data_dir
    string output_dir
    int num_nodes
    int gpus_per_node
    int batch_size_per_gpu
    int sequence_length
    int num_epochs
    float learning_rate
    int warmup_steps
    string master_addr
    int master_port
    string export_format
    string model_name
}

struct model_deployment_artifact {
    string deployment_dir
    string slurm_path
    string docker_compose_path
    string kubernetes_path
    string cluster_config_path
    string startup_env_path
    string launch_plan_path
    string summary_path
}

func default_model_deployment_config() model_deployment_config {
    model_deployment_config {
        cluster_name: "neurx-prod",
        image_name: "neurx:latest",
        backend: "nccl",
        export_dir: "artifacts/export",
        deployment_dir: "artifacts/deployment",
        checkpoint_dir: "artifacts/checkpoints",
        data_dir: "data",
        output_dir: "artifacts/results",
        num_nodes: 2,
        gpus_per_node: 4,
        batch_size_per_gpu: 16,
        sequence_length: 2048,
        num_epochs: 3,
        learning_rate: 0.0005,
        warmup_steps: 1000,
        master_addr: "127.0.0.1",
        master_port: 12355,
        export_format: "custom",
        model_name: "neurx-model",
    }
}

func model_deployment_artifact_paths(string deployment_dir) model_deployment_artifact {
    model_deployment_artifact {
        deployment_dir: deployment_dir,
        slurm_path: deployment_dir + "/slurm_submit.sh",
        docker_compose_path: deployment_dir + "/docker-compose.yml",
        kubernetes_path: deployment_dir + "/kubernetes_deployment.yaml",
        cluster_config_path: deployment_dir + "/cluster_config.json",
        startup_env_path: deployment_dir + "/training_startup.env",
        launch_plan_path: deployment_dir + "/launch_plan.txt",
        summary_path: deployment_dir + "/deployment_summary.txt",
    }
}

func model_deployment_slurm_text(model_deployment_config config) string {
    string out = ""
    out = out + "#!/bin/bash\n"
    out = out + "#SBATCH --nodes=" + strings.from_i32(config.num_nodes) + "\n"
    out = out + "#SBATCH --ntasks-per-node=" + strings.from_i32(config.gpus_per_node) + "\n"
    out = out + "#SBATCH --gpus-per-node=" + strings.from_i32(config.gpus_per_node) + "\n"
    out = out + "#SBATCH --job-name=neurx-training\n"
    out = out + "#SBATCH --time=48:00:00\n"
    out = out + "#SBATCH --output=logs/slurm-%j.out\n"
    out = out + "#SBATCH --error=logs/slurm-%j.err\n\n"
    out = out + "export MASTER_ADDR=" + config.master_addr + "\n"
    out = out + "export MASTER_PORT=" + strings.from_i32(config.master_port) + "\n"
    out = out + "export WORLD_SIZE=" + strings.from_i32(config.num_nodes * config.gpus_per_node) + "\n"
    out = out + "export MODEL_EXPORT_DIR=" + config.export_dir + "\n"
    out = out + "export MODEL_EXPORT_FORMAT=" + config.export_format + "\n"
    out = out + "mkdir -p logs\n"
    out = out + "neurx run scaled_training_system \\\n"
    out = out + "  --epochs=" + strings.from_i32(config.num_epochs) + " \\\n"
    out = out + "  --batch_size=" + strings.from_i32(config.batch_size_per_gpu) + " \\\n"
    out = out + "  --seq_length=" + strings.from_i32(config.sequence_length) + " \\\n"
    out = out + "  --learning_rate=" + strings.format("%.6f", config.learning_rate) + " \\\n"
    out = out + "  --warmup_steps=" + strings.from_i32(config.warmup_steps) + " \\\n"
    out = out + "  --checkpoint_dir=" + config.checkpoint_dir + " \\\n"
    out = out + "  --data_dir=" + config.data_dir + " \\\n"
    out = out + "  --output=" + config.output_dir + " \\\n"
    out = out + "  --device=cuda\n"
    out
}

func model_deployment_docker_text(model_deployment_config config) string {
    string out = ""
    out = out + "version: '3.8'\n\nservices:\n"
    int node = 0
    while node < config.num_nodes {
        string service = "  training-node-" + strings.from_i32(node) + ":\n"
        service = service + "    image: " + config.image_name + "\n"
        service = service + "    environment:\n"
        service = service + "      - MASTER_ADDR=training-node-0\n"
        service = service + "      - MASTER_PORT=" + strings.from_i32(config.master_port) + "\n"
        service = service + "      - WORLD_SIZE=" + strings.from_i32(config.num_nodes * config.gpus_per_node) + "\n"
        service = service + "      - RANK=" + strings.from_i32(node * config.gpus_per_node) + "\n"
        service = service + "      - MODEL_EXPORT_DIR=/workspace/export\n"
        service = service + "      - MODEL_EXPORT_FORMAT=" + config.export_format + "\n"
        service = service + "    volumes:\n"
        service = service + "      - ./" + config.export_dir + ":/workspace/export\n"
        service = service + "      - ./" + config.checkpoint_dir + ":/workspace/checkpoints\n"
        service = service + "      - ./" + config.data_dir + ":/workspace/data\n"
        out = out + service
        node = node + 1
    }
    out = out + "\nnetworks:\n  neurx_network:\n    driver: bridge\n"
    out
}

func model_deployment_kubernetes_text(model_deployment_config config) string {
    string out = ""
    out = out + "apiVersion: batch/v1\nkind: Job\nmetadata:\n"
    out = out + "  name: neurx-training\n"
    out = out + "spec:\n"
    out = out + "  parallelism: " + strings.from_i32(config.num_nodes) + "\n"
    out = out + "  completions: " + strings.from_i32(config.num_nodes) + "\n"
    out = out + "  template:\n"
    out = out + "    spec:\n"
    out = out + "      restartPolicy: Never\n"
    out = out + "      containers:\n"
    out = out + "      - name: neurx-trainer\n"
    out = out + "        image: " + config.image_name + "\n"
    out = out + "        env:\n"
    out = out + "        - name: MASTER_ADDR\n"
    out = out + "          value: " + config.master_addr + "\n"
    out = out + "        - name: MASTER_PORT\n"
    out = out + "          value: \"" + strings.from_i32(config.master_port) + "\"\n"
    out = out + "        - name: WORLD_SIZE\n"
    out = out + "          value: \"" + strings.from_i32(config.num_nodes * config.gpus_per_node) + "\"\n"
    out = out + "        - name: MODEL_EXPORT_DIR\n"
    out = out + "          value: " + config.export_dir + "\n"
    out = out + "        - name: MODEL_EXPORT_FORMAT\n"
    out = out + "          value: " + config.export_format + "\n"
    out = out + "        command:\n"
    out = out + "        - /bin/bash\n"
    out = out + "        - -c\n"
    out = out + "        - |\n"
    out = out + "          neurx run scaled_training_system --device=cuda \\\n"
    out = out + "            --epochs=" + strings.from_i32(config.num_epochs) + " \\\n"
    out = out + "            --batch_size=" + strings.from_i32(config.batch_size_per_gpu) + " \\\n"
    out = out + "            --seq_length=" + strings.from_i32(config.sequence_length) + " \\\n"
    out = out + "            --learning_rate=" + strings.format("%.6f", config.learning_rate) + " \\\n"
    out = out + "            --checkpoint_dir=" + config.checkpoint_dir + " \\\n"
    out = out + "            --output=" + config.output_dir + "\n"
    out
}

func model_deployment_cluster_config_text(model_deployment_config config) string {
    string out = ""
    out = out + "{\n"
    out = out + "  \"cluster_name\": \"" + config.cluster_name + "\",\n"
    out = out + "  \"image_name\": \"" + config.image_name + "\",\n"
    out = out + "  \"backend\": \"" + config.backend + "\",\n"
    out = out + "  \"export_dir\": \"" + config.export_dir + "\",\n"
    out = out + "  \"model_name\": \"" + config.model_name + "\",\n"
    out = out + "  \"num_nodes\": " + strings.from_i32(config.num_nodes) + ",\n"
    out = out + "  \"gpus_per_node\": " + strings.from_i32(config.gpus_per_node) + ",\n"
    out = out + "  \"batch_size_per_gpu\": " + strings.from_i32(config.batch_size_per_gpu) + ",\n"
    out = out + "  \"sequence_length\": " + strings.from_i32(config.sequence_length) + ",\n"
    out = out + "  \"learning_rate\": " + strings.format("%.6f", config.learning_rate) + "\n"
    out = out + "}\n"
    out
}

func model_deployment_startup_env_text(model_deployment_config config) string {
    string out = ""
    out = out + "NEURX_CLUSTER_NAME=" + config.cluster_name + "\n"
    out = out + "NEURX_EXPORT_DIR=" + config.export_dir + "\n"
    out = out + "NEURX_EXPORT_FORMAT=" + config.export_format + "\n"
    out = out + "NEURX_MODEL_NAME=" + config.model_name + "\n"
    out = out + "NEURX_CHECKPOINT_DIR=" + config.checkpoint_dir + "\n"
    out = out + "NEURX_DATA_DIR=" + config.data_dir + "\n"
    out = out + "NEURX_OUTPUT_DIR=" + config.output_dir + "\n"
    out = out + "NEURX_WORLD_SIZE=" + strings.from_i32(config.num_nodes * config.gpus_per_node) + "\n"
    out = out + "NEURX_BATCH_SIZE_PER_GPU=" + strings.from_i32(config.batch_size_per_gpu) + "\n"
    out = out + "NEURX_SEQUENCE_LENGTH=" + strings.from_i32(config.sequence_length) + "\n"
    out = out + "NEURX_LEARNING_RATE=" + strings.format("%.6f", config.learning_rate) + "\n"
    out
}

func model_deployment_launch_plan_text(model_deployment_config config) string {
    string out = ""
    out = out + "1. export model bundle from " + config.export_dir + "\n"
    out = out + "2. stage checkpoint directory at " + config.checkpoint_dir + "\n"
    out = out + "3. launch distributed training with backend " + config.backend + "\n"
    out = out + "4. monitor logs and verify exported artifact path\n"
    out
}

func model_deployment_summary_text(model_deployment_config config, model_deployment_artifact artifact) string {
    string out = ""
    out = out + "deployment_dir=" + artifact.deployment_dir + "\n"
    out = out + "slurm_path=" + artifact.slurm_path + "\n"
    out = out + "docker_compose_path=" + artifact.docker_compose_path + "\n"
    out = out + "kubernetes_path=" + artifact.kubernetes_path + "\n"
    out = out + "cluster_config_path=" + artifact.cluster_config_path + "\n"
    out = out + "startup_env_path=" + artifact.startup_env_path + "\n"
    out = out + "launch_plan_path=" + artifact.launch_plan_path + "\n"
    out = out + "cluster_name=" + config.cluster_name + "\n"
    out = out + "export_dir=" + config.export_dir + "\n"
    out = out + "model_name=" + config.model_name + "\n"
    out
}

func prepare_model_deployment_bundle(model_deployment_config config) model_deployment_artifact {
    string root = trim(config.deployment_dir)
    if root == "" {
        root = "artifacts/deployment"
    }
    runtime_make_dirs(root)
    model_deployment_artifact artifact = model_deployment_artifact_paths(root)
    runtime_write_text_file(artifact.slurm_path, model_deployment_slurm_text(config))
    runtime_write_text_file(artifact.docker_compose_path, model_deployment_docker_text(config))
    runtime_write_text_file(artifact.kubernetes_path, model_deployment_kubernetes_text(config))
    runtime_write_text_file(artifact.cluster_config_path, model_deployment_cluster_config_text(config))
    runtime_write_text_file(artifact.startup_env_path, model_deployment_startup_env_text(config))
    runtime_write_text_file(artifact.launch_plan_path, model_deployment_launch_plan_text(config))
    runtime_write_text_file(artifact.summary_path, model_deployment_summary_text(config, artifact))
    artifact
}

func bool_text(bool value) string {
    if value {
        return "true"
    }
    "false"
}
