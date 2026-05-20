package neurx.agent.skill_registry

use neurx.agent.skill_schema

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
    []agent_skill_record out = []agent_skill_record{cap: len(records)}
    int i = 0
    while i < len(records) {
        out[i] = agent_skill_record_state_dict(records[i])
        i = i + 1
    }
    out
}

func agent_skill_registry_add(agent_skill_registry_state state, agent_skill_record record) agent_skill_registry_state {
    int size = len(state.records)
    []agent_skill_record records = []agent_skill_record{cap: size + 1}
    int i = 0
    while i < size {
        records[i] = state.records[i]
        i = i + 1
    }
    records[size] = record
    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_find_index(agent_skill_registry_state state, string name) int {
    int i = len(state.records) - 1
    while i >= 0 {
        if state.records[i].spec.name == name {
            return i
        }
        i = i - 1
    }
    -1
}

func agent_skill_registry_get(agent_skill_registry_state state, string name) agent_skill_record {
    int index = agent_skill_registry_find_index(state, name)
    if index >= 0 {
        return state.records[index]
    }
    new_agent_skill_record(
        new_agent_skill_spec(name, "v0", "", "missing"),
        new_agent_skill_metrics(),
        0
    )
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
    agent_skill_record next = agent_skill_record_state_dict(record)
    next.created_step = records[index].created_step
    next.promote_count = records[index].promote_count
    next.fail_count = records[index].fail_count
    records[index] = next

    agent_skill_registry_state {
        records: records,
        active_index: state.active_index,
        version: state.version + 1,
        promote_count: state.promote_count,
        retire_count: state.retire_count,
    }
}

func agent_skill_registry_promote(agent_skill_registry_state state, string name) agent_skill_registry_state {
    int index = agent_skill_registry_find_index(state, name)
    if index < 0 {
        return state
    }
    []agent_skill_record records = agent_skill_registry_copy_records(state.records)
    agent_skill_record record = records[index]
    record.spec.status = "promoted"
    record.promote_count = record.promote_count + 1
    records[index] = record
    agent_skill_registry_state {
        records: records,
        active_index: index,
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
    agent_skill_record record = records[index]
    record.spec.status = "retired"
    record.fail_count = record.fail_count + 1
    records[index] = record
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
        records: state.records,
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
    new_agent_skill_record(
        new_agent_skill_spec("none", "v0", "inactive", "idle"),
        new_agent_skill_metrics(),
        0
    )
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
