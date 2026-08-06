struct world_state {
    string                 snapshot_id
    []string               entity_ids
    []string               entity_types
    []string               entity_values
    []string               relation_ids
    []string               relation_types
    []string               relation_src
    []string               relation_dst
    int                    step
    string                 last_action
    string                 last_observation
}

struct world_model_state {
    world_state            current
    []world_state          history
    int                    max_history
    bool                   initialized
}

func new_world_model() world_model_state {
    world_state init = world_state{
        snapshot_id:      "init",
        entity_ids:       [],
        entity_types:     [],
        entity_values:    [],
        relation_ids:     [],
        relation_types:   [],
        relation_src:     [],
        relation_dst:     [],
        step:             0,
        last_action:      "",
        last_observation: "",
    }
    return world_model_state{
        current:     init,
        history:     [],
        max_history: 64,
        initialized: true,
    }
}

func world_model_update(wm world_model_state, action string, observation string) world_model_state {
    world_state next = wm.current
    next.step             = wm.current.step + 1
    next.last_action      = action
    next.last_observation = observation
    next.snapshot_id      = "step_" + string(next.step)
    []world_state hist = wm.history
    hist = append(hist, wm.current)
    if len(hist) > wm.max_history {
        hist = hist[len(hist) - wm.max_history:]
    }
    return world_model_state{
        current:     next,
        history:     hist,
        max_history: wm.max_history,
        initialized: wm.initialized,
    }
}

func world_model_predict(wm world_model_state, hypothetical_action string) world_state {
    world_state predicted = wm.current
    predicted.step             = wm.current.step + 1
    predicted.last_action      = hypothetical_action
    predicted.last_observation = "(predicted)"
    predicted.snapshot_id      = "predicted_" + string(predicted.step)
    return predicted
}

func world_model_rollback(wm world_model_state, target_step int) world_model_state {
    for i = len(wm.history) - 1; i >= 0; i-- {
        if wm.history[i].step == target_step {
            return world_model_state{
                current:     wm.history[i],
                history:     wm.history[:i],
                max_history: wm.max_history,
                initialized: wm.initialized,
            }
        }
    }
    return wm
}

