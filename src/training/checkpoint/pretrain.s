package neurx.checkpoint.pretrain
use neurx.runtime.io.{runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}

struct pretrain_checkpoint_state {
    string run_name
    string root
    int keep_last
    int keep_every_n_steps
    bool save_best_only
    int last_saved_step
    int best_step
    float best_metric
    int save_count
    int prune_count
    int next_save_step
    bool has_best
}

struct pretrain_checkpoint_bundle_state {
    pretrain_checkpoint_state checkpoint
    string checkpoint_path
    string checkpoint_meta_path
    string optimizer_manifest_path
    string data_manifest_path
    string tokenizer_manifest_path
    bool resumable
}

func new_pretrain_checkpoint_state(string run_name, string root) pretrain_checkpoint_state {
    int next_save_step = 1000
    pretrain_checkpoint_state {
        run_name: run_name,
        root: root,
        keep_last: 5,
        keep_every_n_steps: 1000,
        save_best_only: false,
        last_saved_step: -1,
        best_step: -1,
        best_metric: 1e30,
        save_count: 0,
        prune_count: 0,
        next_save_step: next_save_step,
        has_best: false
    }
}

func new_pretrain_checkpoint_bundle_state(checkpoint pretrain_checkpoint_state, string checkpoint_path, string optimizer_manifest_path, string data_manifest_path, string tokenizer_manifest_path) pretrain_checkpoint_bundle_state {
    pretrain_checkpoint_bundle_state {
        checkpoint: checkpoint,
        checkpoint_path: checkpoint_path,
        checkpoint_meta_path: checkpoint_path + ".meta",
        optimizer_manifest_path: optimizer_manifest_path,
        data_manifest_path: data_manifest_path,
        tokenizer_manifest_path: tokenizer_manifest_path,
        resumable: true,
    }
}

func pretrain_checkpoint_trim(string s) string {
    int i = 0
    for i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    for j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    for k <= j {
        out = out + pretrain_checkpoint_chr(s[k])
        k = k + 1
    }
    out
}

func pretrain_checkpoint_chr(int c) string {
    string(c)
}

func pretrain_checkpoint_split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current = ""
    bool ends_with_newline = false
    int i = 0
    for i < len(text) {
        int ch = text[i]
        if ch == 10 {
            lines = append(lines, current)
            current = ""
            ends_with_newline = true
        } else if ch != 13 {
            current = current + pretrain_checkpoint_chr(ch)
            ends_with_newline = false
        }
        i = i + 1
    }
    if current != "" || len(text) == 0 || ends_with_newline {
        lines = append(lines, current)
    }
    lines
}

func pretrain_checkpoint_string_to_int(string s, int fallback) int {
    string text = pretrain_checkpoint_trim(s)
    if text == "" {
        return fallback
    }
    bool neg = false
    int i = 0
    if text[0] == 45 {
        neg = true
        i = 1
    }
    int value = 0
    for i < len(text) {
        int digit = text[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    if neg {
        value = -value
    }
    value
}

func pretrain_checkpoint_int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string out = ""
    for value > 0 {
        int digit = value % 10
        out = pretrain_checkpoint_chr(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func pretrain_checkpoint_float_to_string(float value) string {
    float x = value
    if x == 0.0 {
        return "0.0"
    }
    bool neg = x < 0.0
    if neg {
        x = -x
    }
    int whole = 0
    for x >= 1.0 {
        x = x - 1.0
        whole = whole + 1
    }
    int frac = int(x * 1000000.0)
    string out = ""
    if neg {
        out = "-"
    }
    out = out + pretrain_checkpoint_int_to_string(whole) + "."
    int pad = 6
    if frac == 0 {
        out = out + "000000"
        return out
    }
    int digits = 0
    int tmp = frac
    for tmp > 0 {
        digits = digits + 1
        tmp = tmp / 10
    }
    int leading = pad - digits
    int j = 0
    for j < leading {
        out = out + "0"
        j = j + 1
    }
    out = out + pretrain_checkpoint_int_to_string(frac)
    out
}

func pretrain_checkpoint_metadata_text(pretrain_checkpoint_state state) string {
    string out = "pretrain_checkpoint_v1\n"
    out = out + "run_name=" + state.run_name + "\n"
    out = out + "root=" + state.root + "\n"
    out = out + "keep_last=" + pretrain_checkpoint_int_to_string(state.keep_last) + "\n"
    out = out + "keep_every_n_steps=" + pretrain_checkpoint_int_to_string(state.keep_every_n_steps) + "\n"
    int save_best_only = 0
    if state.save_best_only {
        save_best_only = 1
    }
    out = out + "save_best_only=" + pretrain_checkpoint_int_to_string(save_best_only) + "\n"
    out = out + "last_saved_step=" + pretrain_checkpoint_int_to_string(state.last_saved_step) + "\n"
    out = out + "best_step=" + pretrain_checkpoint_int_to_string(state.best_step) + "\n"
    out = out + "best_metric=" + pretrain_checkpoint_float_to_string(state.best_metric) + "\n"
    out = out + "save_count=" + pretrain_checkpoint_int_to_string(state.save_count) + "\n"
    out = out + "prune_count=" + pretrain_checkpoint_int_to_string(state.prune_count) + "\n"
    out = out + "next_save_step=" + pretrain_checkpoint_int_to_string(state.next_save_step) + "\n"
    int has_best = 0
    if state.has_best {
        has_best = 1
    }
    out = out + "has_best=" + pretrain_checkpoint_int_to_string(has_best) + "\n"
    out
}

func pretrain_checkpoint_bundle_text(pretrain_checkpoint_bundle_state state) string {
    string out = "pretrain_checkpoint_bundle_v1\n"
    out = out + "checkpoint_path=" + state.checkpoint_path + "\n"
    out = out + "checkpoint_meta_path=" + state.checkpoint_meta_path + "\n"
    out = out + "optimizer_manifest_path=" + state.optimizer_manifest_path + "\n"
    out = out + "data_manifest_path=" + state.data_manifest_path + "\n"
    out = out + "tokenizer_manifest_path=" + state.tokenizer_manifest_path + "\n"
    int resumable = 0
    if state.resumable {
        resumable = 1
    }
    out = out + "resumable=" + pretrain_checkpoint_int_to_string(resumable) + "\n"
    out
}

func pretrain_checkpoint_metadata_value(string text, string key, string fallback) string {
    []string lines = pretrain_checkpoint_split_lines(text)
    string prefix = key + "="
    int i = 0
    for i < len(lines) {
        string line = pretrain_checkpoint_trim(lines[i])
        if len(line) >= len(prefix) {
            bool match = true
            int j = 0
            for j < len(prefix) && match {
                if line[j] != prefix[j] {
                    match = false
                } else {
                    j = j + 1
                }
            }
            if match {
                string value = ""
                int k = len(prefix)
                for k < len(line) {
                    value = value + pretrain_checkpoint_chr(line[k])
                    k = k + 1
                }
                return value
            }
        }
        i = i + 1
    }
    fallback
}

func pretrain_checkpoint_metadata_int(string text, string key, int fallback) int {
    pretrain_checkpoint_string_to_int(pretrain_checkpoint_metadata_value(text, key, pretrain_checkpoint_int_to_string(fallback)), fallback)
}

func pretrain_checkpoint_metadata_float(string text, string key, float fallback) float {
    string raw = pretrain_checkpoint_trim(pretrain_checkpoint_metadata_value(text, key, pretrain_checkpoint_float_to_string(fallback)))
    if raw == "" {
        return fallback
    }
    bool neg = false
    int i = 0
    if raw[0] == 45 {
        neg = true
        i = 1
    }
    float whole = 0.0
    for i < len(raw) && raw[i] != 46 {
        int digit = raw[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        whole = whole * 10.0 + digit
        i = i + 1
    }
    float frac = 0.0
    float denom = 10.0
    if i < len(raw) && raw[i] == 46 {
        i = i + 1
        for i < len(raw) {
            int digit = raw[i] - 48
            if digit < 0 || digit > 9 {
                return fallback
            }
            frac = frac + float(digit) / denom
            denom = denom * 10.0
            i = i + 1
        }
    }
    float out = whole + frac
    if neg {
        out = -out
    }
    out
}

func pretrain_checkpoint_path_dir(string path) string {
    int i = len(path) - 1
    for i >= 0 {
        if path[i] == 47 {
            break
        }
        i = i - 1
    }
    if i < 0 {
        return "."
    }
    if i == 0 {
        return "/"
    }
    string out = ""
    int j = 0
    for j < i {
        out = out + pretrain_checkpoint_chr(path[j])
        j = j + 1
    }
    out
}

func save_pretrain_checkpoint(pretrain_checkpoint_bundle_state bundle) pretrain_checkpoint_bundle_state {
    runtime_make_dirs(bundle.checkpoint.root)
    runtime_make_dirs(pretrain_checkpoint_path_dir(bundle.checkpoint_path))
    runtime_write_text_file(bundle.checkpoint_path, pretrain_checkpoint_bundle_text(bundle))
    runtime_write_text_file(bundle.checkpoint_meta_path, pretrain_checkpoint_metadata_text(bundle.checkpoint))
    runtime_write_text_file(bundle.checkpoint.root + "/latest_checkpoint.txt", bundle.checkpoint_path)
    bundle
}

func load_pretrain_checkpoint(pretrain_checkpoint_bundle_state bundle) pretrain_checkpoint_bundle_state {
    pretrain_checkpoint_bundle_state next = bundle
    if !runtime_file_exists(bundle.checkpoint_path) {
        return bundle
    }
    string bundle_text = runtime_read_text_file(bundle.checkpoint_path)
    string meta_text = ""
    if runtime_file_exists(bundle.checkpoint_meta_path) {
        meta_text = runtime_read_text_file(bundle.checkpoint_meta_path)
    }
    next.checkpoint_path = pretrain_checkpoint_metadata_value(bundle_text, "checkpoint_path", bundle.checkpoint_path)
    next.checkpoint_meta_path = pretrain_checkpoint_metadata_value(bundle_text, "checkpoint_meta_path", bundle.checkpoint_meta_path)
    next.optimizer_manifest_path = pretrain_checkpoint_metadata_value(bundle_text, "optimizer_manifest_path", bundle.optimizer_manifest_path)
    next.data_manifest_path = pretrain_checkpoint_metadata_value(bundle_text, "data_manifest_path", bundle.data_manifest_path)
    next.tokenizer_manifest_path = pretrain_checkpoint_metadata_value(bundle_text, "tokenizer_manifest_path", bundle.tokenizer_manifest_path)
    next.resumable = pretrain_checkpoint_metadata_int(bundle_text, "resumable", 1) != 0
    pretrain_checkpoint_state state = next.checkpoint
    state.run_name = pretrain_checkpoint_metadata_value(meta_text, "run_name", state.run_name)
    state.root = pretrain_checkpoint_metadata_value(meta_text, "root", state.root)
    state.keep_last = pretrain_checkpoint_metadata_int(meta_text, "keep_last", state.keep_last)
    state.keep_every_n_steps = pretrain_checkpoint_metadata_int(meta_text, "keep_every_n_steps", state.keep_every_n_steps)
    state.save_best_only = pretrain_checkpoint_metadata_int(meta_text, "save_best_only", 0) != 0
    state.last_saved_step = pretrain_checkpoint_metadata_int(meta_text, "last_saved_step", state.last_saved_step)
    state.best_step = pretrain_checkpoint_metadata_int(meta_text, "best_step", state.best_step)
    state.best_metric = pretrain_checkpoint_metadata_float(meta_text, "best_metric", state.best_metric)
    state.save_count = pretrain_checkpoint_metadata_int(meta_text, "save_count", state.save_count)
    state.prune_count = pretrain_checkpoint_metadata_int(meta_text, "prune_count", state.prune_count)
    state.next_save_step = pretrain_checkpoint_metadata_int(meta_text, "next_save_step", state.next_save_step)
    state.has_best = pretrain_checkpoint_metadata_int(meta_text, "has_best", 0) != 0
    next.checkpoint = state
    next
}

func pretrain_checkpoint_should_save(pretrain_checkpoint_state state, int step) bool {
    if state.save_best_only {
        return false
    }
    if state.keep_every_n_steps <= 0 {
        return true
    }
    step >= state.next_save_step
}

func pretrain_checkpoint_should_save_best(pretrain_checkpoint_state state, float metric) bool {
    if !state.has_best {
        return true
    }
    metric < state.best_metric
}

func pretrain_checkpoint_next_save_step(pretrain_checkpoint_state state) int {
    state.next_save_step
}

func pretrain_checkpoint_has_best(pretrain_checkpoint_state state) bool {
    state.has_best
}

func pretrain_checkpoint_prune_count(pretrain_checkpoint_state state) int {
    state.prune_count
}

func mark_saved(pretrain_checkpoint_state state, int step) pretrain_checkpoint_state {
    int save_count = state.save_count + 1
    int prune_count = state.prune_count
    if state.keep_last > 0 && save_count > state.keep_last {
        prune_count = save_count - state.keep_last
    }
    int next_save_step = state.next_save_step
    if state.keep_every_n_steps > 0 {
        next_save_step = step + state.keep_every_n_steps
    } else {
        next_save_step = step + 1
    }
    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: step,
        best_step: state.best_step,
        best_metric: state.best_metric,
        save_count: save_count,
        prune_count: prune_count,
        next_save_step: next_save_step,
        has_best: state.has_best,
    }
}

func mark_best(pretrain_checkpoint_state state, int step, float metric) pretrain_checkpoint_state {
    if state.has_best && metric >= state.best_metric {
        return state
    }
    pretrain_checkpoint_state {
        run_name: state.run_name,
        root: state.root,
        keep_last: state.keep_last,
        keep_every_n_steps: state.keep_every_n_steps,
        save_best_only: state.save_best_only,
        last_saved_step: state.last_saved_step,
        best_step: step,
        best_metric: metric,
        save_count: state.save_count,
        prune_count: state.prune_count,
        next_save_step: state.next_save_step,
        has_best: true,
    }
}

func pretrain_checkpoint_state_dict(pretrain_checkpoint_state state) pretrain_checkpoint_state {
    state
}

func pretrain_checkpoint_load_state_dict(pretrain_checkpoint_state state, pretrain_checkpoint_state other) pretrain_checkpoint_state {
    other
}

func pretrain_checkpoint_bundle_state_dict(pretrain_checkpoint_bundle_state state) pretrain_checkpoint_bundle_state {
    pretrain_checkpoint_bundle_state {
        checkpoint: pretrain_checkpoint_state_dict(state.checkpoint),
        checkpoint_path: state.checkpoint_path,
        checkpoint_meta_path: state.checkpoint_meta_path,
        optimizer_manifest_path: state.optimizer_manifest_path,
        data_manifest_path: state.data_manifest_path,
        tokenizer_manifest_path: state.tokenizer_manifest_path,
        resumable: state.resumable,
    }
}

func pretrain_checkpoint_bundle_load_state_dict(pretrain_checkpoint_bundle_state state, pretrain_checkpoint_bundle_state other) pretrain_checkpoint_bundle_state {
    pretrain_checkpoint_bundle_state {
        checkpoint: pretrain_checkpoint_load_state_dict(state.checkpoint, other.checkpoint),
        checkpoint_path: other.checkpoint_path,
        checkpoint_meta_path: other.checkpoint_meta_path,
        optimizer_manifest_path: other.optimizer_manifest_path,
        data_manifest_path: other.data_manifest_path,
        tokenizer_manifest_path: other.tokenizer_manifest_path,
        resumable: other.resumable,
    }
}
