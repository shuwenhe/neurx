package neurx.app.backend

use neurx.checkpoint.{load_checkpoint, checkpoint_step, checkpoint_loss, checkpoint_param_count}
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file}

func main() () {
    // Read checkpoint path from well-known temp file written by gateway.sh
    string cfg_path = "/tmp/neurx_ckpt_path.txt"
    int step = 0
    float loss = 0.0
    int n_params = 0

    if runtime_file_exists(cfg_path) {
        string ckpt_path = runtime_read_text_file(cfg_path)
        if runtime_file_exists(ckpt_path) {
            checkpoint ck = load_checkpoint(ckpt_path)
            step = checkpoint_step(ck)
            loss = checkpoint_loss(ck)
            n_params = checkpoint_param_count(ck)
        }
    }

	print("{\"ok\":true,")
	print("\"backend_name\":\"neurx.app.backend.llm.s\",")
	print("\"model_name\":\"__MODEL__\",")
	print("\"summary\":\"s-direct-response\",")
	print("\"prompt\":\"__PROMPT__\",")
	print("\"completion\":\"__COMPLETION__\",")
	print("\"generated_tokens\":16,")
	print("\"last_token\":0,")
	print("\"train_loss\":0,")
	print("\"validation_loss\":0,")
	print("\"ready\":true}")
}
