package neurx.registry.skill_registry
use neurx.agent.observation
use neurx.agent.skill_schema
use neurx.runtime.io.{runtime_write_text_file}

struct agent_skill_registry_state {
    []agent_skill_record records
    int active_index
    int version
    int promote_count
    int retire_count
}

func new_agent_skill_registry_state() agent_skill_registry_state {
    agent_skill_registry_state {
        records: [],
        active_index: -1,
        version: 0,
        promote_count: 0,
        retire_count: 0,
    }
}

func agent_skill_registry_count(agent_skill_registry_state state) int {
    len(state.records)
}

func agent_skill_registry_copy_records([]agent_skill_record records) []agent_skill_record {
    []agent_skill_record out = make([]agent_skill_record, len(records))
    int i = 0
    for i < len(records) {
        out[i] = agent_skill_record_state_dict(records[i])
        i = i + 1
    }
    out
}

func agent_skill_registry_add(agent_skill_registry_state state, agent_skill_record record) agent_skill_registry_state {
    int size = len(state.records)
    []agent_skill_record records = make([]agent_skill_record, size + 1)
    int i = 0
    for i < size {
        records[i] = state.records[i]
        i = i + 1
    }
    records[size] = agent_skill_record_state_dict(record)
    int active_index = state.active_index
    if active_index < 0 {
        active_index = size
    }
    agent_skill_registry_state {
        records: records,
        active_index: active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_find_index(agent_skill_registry_state state, string name) int {
    int i = 0
    for i < len(state.records) {
        if state.records[i].spec.name == name {
            return i
        }
        i = i + 1
    }
    -1
}

func agent_skill_registry_get(agent_skill_registry_state state, string name) agent_skill_record {
    int index = agent_skill_registry_find_index(state, name)
    if index >= 0 {
        return state.records[index]
    }
    agent_skill_record {
        spec: new_agent_skill_spec("", "0", "", "missing"),
        metrics: new_agent_skill_metrics(),
        created_step: 0,
        last_updated_step: 0,
        promote_count: 0,
        fail_count: 0,
        success_count: 0,
        total_steps: 0,
        promoted: false,
        retired: false,
        score: 0.0,
    }
}

func agent_skill_registry_has(agent_skill_registry_state state, string name) bool {
    agent_skill_registry_find_index(state, name) >= 0
}

func agent_skill_registry_upsert(agent_skill_registry_state state, agent_skill_record record) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, record.spec.name)
    if index < 0 {
        return agent_skill_registry_add(state, record)
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    records[index] = agent_skill_record_state_dict(record)
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_record_success(agent_skill_registry_state state, string name, int step, int steps_taken) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    agent_skill_record rec = records[index]
    rec.success_count = rec.success_count + 1
    rec.last_updated_step = step
    rec.total_steps = rec.total_steps + steps_taken
    int total_runs = rec.success_count + rec.fail_count
    if total_runs > 0 {
        rec.metrics.avg_steps = float(rec.total_steps) / float(total_runs)
        rec.metrics.success_rate = float(rec.success_count) / float(total_runs)
    }
    rec.spec.status = "active"
    records[index] = rec
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_observation_matches_failure(agent_skill_record record, string observation) bool {
    string obs = trim(observation)
    if obs == "" {
        return false
    }
    agent_observation_state parsed = agent_observation_parse(obs)
    parsed.blocked || parsed.failed || parsed.no_progress
}

func agent_skill_registry_record_failure(agent_skill_registry_state state, string name, int step, int retire_after_failures) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    int retire_threshold = retire_after_failures
    if retire_threshold <= 0 {
        retire_threshold = 3
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    agent_skill_record rec = records[index]
    rec.fail_count = rec.fail_count + 1
    rec.last_updated_step = step
    int total_runs = rec.success_count + rec.fail_count
    if total_runs > 0 {
        rec.metrics.success_rate = float(rec.success_count) / float(total_runs)
    }
    if rec.fail_count >= retire_threshold {
        rec.retired = true
        rec.spec.status = "retired"
    } else {
        rec.spec.status = "degraded"
    }
    records[index] = rec
    int retire_count = state.retire_count
    if rec.retired {
        retire_count = retire_count + 1
    }
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: retire_count,
    }
}

func agent_skill_registry_promote(agent_skill_registry_state state, string name) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    records[index].promoted = true
    records[index].spec.status = "promoted"
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count + 1,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_retire(agent_skill_registry_state state, string name) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    records[index].retired = true
    records[index].spec.status = "retired"
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count + 1,
    }
}

func agent_skill_registry_set_active(agent_skill_registry_state state, string name) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    agent_skill_registry_state {
        records: agent_skill_registry_copy_records(state.records),
        active_index: index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_active(agent_skill_registry_state state) agent_skill_record {
    if state.active_index >= 0 && state.active_index < len(state.records) {
        return state.records[state.active_index]
    }
    if len(state.records) > 0 {
        return state.records[0]
    }
    agent_skill_registry_get(state, "")
}

func agent_skill_registry_snapshot(agent_skill_registry_state state) string {
    string out = "skills=" + string(len(state.records)) + " version=" + string(state.version)
    int i = 0
    for i < len(state.records) {
        agent_skill_record rec = state.records[i]
    out = out + "\nskill[" + string(i) + "]=" + rec.spec.name + " status=" + rec.spec.status + " success=" + string(rec.success_count) + " fail=" + string(rec.fail_count)
        i = i + 1
    }
    out
}

func agent_skill_registry_best_promoted_index(agent_skill_registry_state state) int {
    int best = -1
    float best_score = -1000000.0
    int i = 0
    for i < len(state.records) {
        agent_skill_record rec = state.records[i]
        if rec.promoted && !rec.retired && rec.score >= best_score {
            best = i
            best_score = rec.score
        }
        i = i + 1
    }
    best
}

func agent_skill_registry_set_score(agent_skill_registry_state state, string name, float score) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    records[index].score = score
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_activate_best(agent_skill_registry_state state) agent_skill_registry_state {
    int best = agent_skill_registry_best_promoted_index(state)
    if best < 0 {
        return state
    }
    agent_skill_registry_state {
        records: agent_skill_registry_copy_records(state.records),
        active_index: best,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_state_dict(agent_skill_registry_state state) agent_skill_registry_state {
    agent_skill_registry_state {
        records: agent_skill_registry_copy_records(state.records),
        active_index: state.active_index,
        version: state.version,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_load_state_dict(agent_skill_registry_state state, agent_skill_registry_state other) agent_skill_registry_state {
    agent_skill_registry_state {
        records: agent_skill_registry_copy_records(other.records),
        active_index: other.active_index,
        version: other.version,
        promote_count: other.promote_count,
        retire_count: other.retire_count,
    }
}

func agent_skill_registry_names(agent_skill_registry_state state) []string {
    []string names = make([]string, len(state.records))
    int i = 0
    for i < len(state.records) {
        names[i] = state.records[i].spec.name
        i = i + 1
    }
    names
}

func agent_skill_registry_success_rate(agent_skill_registry_state state, string name) float {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return 0.0
    }
    agent_skill_record rec = state.records[index]
    int total = rec.success_count + rec.fail_count
    if total <= 0 {
        return 0.0
    }
    float(rec.success_count) / float(total)
}

func agent_skill_registry_promoted_names(agent_skill_registry_state state) []string {
    int count = 0
    int i = 0
    for i < len(state.records) {
        if state.records[i].promoted && !state.records[i].retired {
            count = count + 1
        }
        i = i + 1
    }
    []string names = make([]string, count)
    i = 0
    int out_i = 0
    for i < len(state.records) {
        if state.records[i].promoted && !state.records[i].retired {
            names[out_i] = state.records[i].spec.name
            out_i = out_i + 1
        }
        i = i + 1
    }
    names
}

func agent_skill_registry_prune(agent_skill_registry_state state) agent_skill_registry_state {
    int keep = 0
    int i = 0
    for i < len(state.records) {
        if !state.records[i].retired {
            keep = keep + 1
        }
        i = i + 1
    }
    []agent_skill_record records = make([]agent_skill_record, keep)
    i = 0
    int out_i = 0
    int active_index = -1
    for i < len(state.records) {
        if !state.records[i].retired {
            records[out_i] = agent_skill_record_state_dict(state.records[i])
            if i == state.active_index {
                active_index = out_i
            }
            out_i = out_i + 1
        }
        i = i + 1
    }
    agent_skill_registry_state {
        records: records,
        active_index: active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_force_retire(agent_skill_registry_state state, string name) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    records[index].retired = true
    records[index].spec.status = "retired"
    int active_index = state.active_index
    if active_index == index {
        active_index = -1
    }
    agent_skill_registry_state {
        records: records,
        active_index: active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count + 1,
    }
}

func agent_skill_registry_persist(agent_skill_registry_state state, string path) string {
    runtime_write_text_file(path, agent_skill_registry_snapshot(state))
    path
}

func agent_skill_registry_avg_steps(agent_skill_registry_state state, string name) float {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return 0.0
    }
    state.records[index].avg_steps
}

func agent_skill_registry_stability(agent_skill_registry_state state, string name) float {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return 0.0
    }
    agent_skill_record rec = state.records[index]
    int total = rec.success_count + rec.fail_count
    if total <= 0 {
        return 0.0
    }
    float(rec.success_count - rec.fail_count) / float(total)
}

func agent_skill_registry_version(agent_skill_registry_state state, string name) string {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return ""
    }
    state.records[index].spec.version
}
