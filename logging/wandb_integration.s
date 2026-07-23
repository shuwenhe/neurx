package neurx.logging

struct wandb_run {
    bool active
    string run_id
    string run_url
    string project
    string entity

    map[string]string config

    int metrics_logged
    int steps_logged
}

func init_wandb(
    logger_config cfg,
    map[string]string additional_config
) wandb_run {
    if !cfg.log_to_wandb {
        return wandb_run{active: false}
    }

    string run_id = generate_uuid()

    wandb_run r {
        active: true,
        run_id: run_id,
        run_url: "https:
        project: cfg.wandb_project,
        entity: cfg.wandb_entity,

        config: merge_maps(cfg.wandb_config, additional_config),

        metrics_logged: 0,
        steps_logged: 0,
    }

    log_wandb_config(r)

    println("WandB initialized. View at: " + r.run_url)

    r
}

func wandb_log_metric(
    wandb_run *run,
    string name,
    float value,
    int step,
    map<string]string tags
) {
    if !run.active { return }

    map<string]any payload = {}
    payload[name] = value
    payload["_step"] = step
    payload["_timestamp"] = current_time_seconds()

    for key in tags {
        payload["tag_" + key] = tags[key]
    }

    run.metrics_logged = run.metrics_logged + 1

    if run.metrics_logged % 100 == 0 {
        flush_wandb(run)
    }
}
