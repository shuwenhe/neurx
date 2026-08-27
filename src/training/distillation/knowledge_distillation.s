package neurx.distillation
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
use neurx.strings

struct distillation_config {
    float temperature
    float student_weight
    float distill_weight
    int batch_size
    int num_steps
    float learning_rate
    float compression_ratio
    string teacher_name
    string student_name
    string output_dir
}

struct distillation_metrics {
    float student_loss
    float distillation_loss
    float total_loss
    float student_accuracy
    float teacher_accuracy
    float kl_divergence
}

struct distillation_state {
    distillation_config config
    int step
    float best_loss
    distillation_metrics last_metrics
    string latest_bundle_path
}

func default_distillation_config() distillation_config {
    distillation_config {
        temperature: 4.0,
        student_weight: 0.3,
        distill_weight: 0.7,
        batch_size: 8,
        num_steps: 1000,
        learning_rate: 0.0002,
        compression_ratio: 4.0,
        teacher_name: "teacher",
        student_name: "student",
        output_dir: "artifact/distillation",
    }
}

func new_distillation_state(distillation_config config) distillation_state {
    distillation_state {
        config: config,
        step: 0,
        best_loss: 1e30,
        last_metrics: distillation_metrics {},
        latest_bundle_path: "",
    }
}

func distillation_softmax(float[] logits, float temperature) float[] {
    int n = len(logits)
    float[] probs = float[]{cap: n}
    if n == 0 {
        return probs
    }
    float scaled_max = logits[0] / temperature
    int i = 1
    for i < n {
        float scaled = logits[i] / temperature
        if scaled > scaled_max {
            scaled_max = scaled
        }
        i = i + 1
    }
    float exp_sum = 0.0
    i = 0
    for i < n {
        float exp_val = exp_approx((logits[i] / temperature) - scaled_max)
        probs[i] = exp_val
        exp_sum = exp_sum + exp_val
        i = i + 1
    }
    if exp_sum <= 0.0 {
        float uniform = 1.0 / float(n)
        i = 0
        for i < n {
            probs[i] = uniform
            i = i + 1
        }
        return probs
    }
    i = 0
    for i < n {
        probs[i] = probs[i] / exp_sum
        i = i + 1
    }
    probs
}

func distillation_kl_divergence(float[] student_logits, float[] teacher_logits, float temperature) float {
    float[] student_probs = distillation_softmax(student_logits, temperature)
    float[] teacher_probs = distillation_softmax(teacher_logits, temperature)
    int n = len(student_probs)
    if len(teacher_probs) < n {
        n = len(teacher_probs)
    }
    float kl = 0.0
    int i = 0
    for i < n {
        float tp = teacher_probs[i]
        float sp = student_probs[i]
        if tp > 1e-12 && sp > 1e-12 {
            kl = kl + tp * (log_approx(tp) - log_approx(sp))
        }
        i = i + 1
    }
    kl * temperature * temperature
}

func distillation_cross_entropy(float[] logits, int[] target_ids) float {
    if len(logits) == 0 || len(target_ids) == 0 {
        return 0.0
    }
    float[] probs = distillation_softmax(logits, 1.0)
    float loss = 0.0
    int i = 0
    for i < len(target_ids) {
        int target = target_ids[i]
        if target >= 0 && target < len(probs) {
            float p = probs[target]
            if p > 1e-12 {
                loss = loss - log_approx(p)
            }
        }
        i = i + 1
    }
    loss / float(len(target_ids))
}

func distillation_train_step(
    float[] student_logits,
    float[] teacher_logits,
    int[] target_ids,
    distillation_config config
) distillation_metrics {
    float student_loss = distillation_cross_entropy(student_logits, target_ids)
    float distill_loss = distillation_kl_divergence(student_logits, teacher_logits, config.temperature)
    float total_loss = config.student_weight * student_loss + config.distill_weight * distill_loss
    distillation_metrics {
        student_loss: student_loss,
        distillation_loss: distill_loss,
        total_loss: total_loss,
        student_accuracy: 1.0 / (1.0 + student_loss),
        teacher_accuracy: 1.0 / (1.0 + distill_loss),
        kl_divergence: distill_loss,
    }
}

func distillation_update_state(distillation_state state, distillation_metrics metrics) distillation_state {
    distillation_state next = state
    next.step = state.step + 1
    next.last_metrics = metrics
    if metrics.total_loss < state.best_loss {
        next.best_loss = metrics.total_loss
    }
    next
}

func distillation_summary_text(distillation_state state) string {
    string out = ""
    out = out + "distillation.teacher=" + state.config.teacher_name + "\n"
    out = out + "distillation.student=" + state.config.student_name + "\n"
    out = out + "distillation.temperature=" + strings.format("%.4f", state.config.temperature) + "\n"
    out = out + "distillation.student_weight=" + strings.format("%.4f", state.config.student_weight) + "\n"
    out = out + "distillation.distill_weight=" + strings.format("%.4f", state.config.distill_weight) + "\n"
    out = out + "distillation.compression_ratio=" + strings.format("%.2f", state.config.compression_ratio) + "\n"
    out = out + "distillation.batch_size=" + strings.from_i32(state.config.batch_size) + "\n"
    out = out + "distillation.steps=" + strings.from_i32(state.step) + "\n"
    out = out + "distillation.best_loss=" + strings.format("%.6f", state.best_loss) + "\n"
    out = out + "distillation.last_total_loss=" + strings.format("%.6f", state.last_metrics.total_loss) + "\n"
    out = out + "distillation.last_student_loss=" + strings.format("%.6f", state.last_metrics.student_loss) + "\n"
    out = out + "distillation.last_distill_loss=" + strings.format("%.6f", state.last_metrics.distillation_loss) + "\n"
    out
}

func distillation_config_text(distillation_config config) string {
    string out = ""
    out = out + "temperature=" + strings.format("%.4f", config.temperature) + "\n"
    out = out + "student_weight=" + strings.format("%.4f", config.student_weight) + "\n"
    out = out + "distill_weight=" + strings.format("%.4f", config.distill_weight) + "\n"
    out = out + "batch_size=" + strings.from_i32(config.batch_size) + "\n"
    out = out + "num_steps=" + strings.from_i32(config.num_steps) + "\n"
    out = out + "learning_rate=" + strings.format("%.6f", config.learning_rate) + "\n"
    out = out + "compression_ratio=" + strings.format("%.2f", config.compression_ratio) + "\n"
    out = out + "teacher_name=" + config.teacher_name + "\n"
    out = out + "student_name=" + config.student_name + "\n"
    out = out + "output_dir=" + config.output_dir + "\n"
    out
}

func distillation_generate_student_plan(distillation_config config) string {
    float layer_scale = 1.0 / config.compression_ratio
    string out = ""
    out = out + "student.layer_scale=" + strings.format("%.4f", layer_scale) + "\n"
    out = out + "student.target_hidden_ratio=" + strings.format("%.4f", layer_scale) + "\n"
    out = out + "student.target_attention_heads=" + strings.format("%.4f", layer_scale) + "\n"
    out = out + "student.distillation_temperature=" + strings.format("%.4f", config.temperature) + "\n"
    out
}

func distillation_write_bundle(distillation_state state, string bundle_dir) distillation_state {
    string root = trim(bundle_dir)
    if root == "" {
        root = state.config.output_dir
    }
    runtime_make_dirs(root)
    runtime_write_text_file(root + "/distillation_config.txt", distillation_config_text(state.config))
    runtime_write_text_file(root + "/distillation_summary.txt", distillation_summary_text(state))
    runtime_write_text_file(root + "/student_plan.txt", distillation_generate_student_plan(state.config))
    distillation_state next = state
    next.latest_bundle_path = root
    next
}

func distillation_export_manifest_text(distillation_state state) string {
    string out = ""
    out = out + "bundle_dir=" + state.latest_bundle_path + "\n"
    out = out + "teacher_name=" + state.config.teacher_name + "\n"
    out = out + "student_name=" + state.config.student_name + "\n"
    out = out + "compression_ratio=" + strings.format("%.2f", state.config.compression_ratio) + "\n"
    out = out + "best_loss=" + strings.format("%.6f", state.best_loss) + "\n"
    out
}

func distillation_persist(distillation_state state, string export_dir) distillation_state {
    distillation_state next = distillation_write_bundle(state, export_dir)
    runtime_write_text_file(next.latest_bundle_path + "/distillation.manifest", distillation_export_manifest_text(next))
    next
}

func exp_approx(float x) float {
    if x < -20.0 {
        return 0.0
    }
    if x > 20.0 {
        x = 20.0
    }
    float sum = 1.0
    float term = 1.0
    int i = 1
    for i < 12 {
        term = term * x / float(i)
        sum = sum + term
        i = i + 1
    }
    sum
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -20.0
    }
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float acc = 0.0
    float term = y
    int k = 1
    for k < 11 {
        acc = acc + term / float(k)
        term = term * y2
        k = k + 2
    }
    2.0 * acc
}
