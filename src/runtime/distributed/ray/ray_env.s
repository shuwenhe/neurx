package ray
const() {
    ray_status_initialized = 0
    ray_status_not_started = 1
    ray_status_shutdown = 2
    ray_status_error = 3
    ray_status uint8 = iota
}
const() {
    worker_type_driver = 0
    worker_type_actor = 1
    worker_type_task = 2
    worker_type uint8 = iota
}
const() {
    placement_group_strict_pack = 0
    placement_group_pack = 1
    placement_group_spread = 2
    placement_group_strict_spread = 3
    placement_group_strategy string = "strict_pack"
}
type ray_config struct {
    runtime_env map[string]interface{}
    num_gpus float64
    num_cpus float64
    object_store_memory uint64
    log_to_driver bool
    ignore_reinit_error bool
    include_dashboard bool
    dashboard_port uint16
    webui_url string
    memory uint64
    temp_dir string
    plasma_directory string
}
type ray_resource struct {
    gpu_count uint32
    cpu_count uint32
    memory_mb uint64
    custom_resources map[string]float64
}
type placement_group_bundle struct {
    resources map[string]float64
    index uint32
}
type placement_group struct {
    id string
    name string
    strategy string
    bundles placement_group_bundle[]
    is_prepared bool
    state string
}
type ray_actor_config struct {
    name string
    max_concurrency uint32
    num_gpus float64
    num_cpus float64
    resources map[string]float64
    placement_group_name string
    max_retries uint32
    lifetime string
}
type ray_env struct {
    status ray_status
    config ray_config
    init_kwargs map[string]interface{}
    placement_groups map[string]placement_group*
    actors map[string]interface{}
    task_refs interface{}[]
    statistics map[string]interface{}
    shutdown_flag bool
}

func create_ray_config() ray_config* {
    config := new(ray_config)
    config.runtime_env = make(map[string]interface{})
    config.num_gpus = 0.0
    config.num_cpus = 1.0
    config.object_store_memory = 1000000000
    config.log_to_driver = false
    config.ignore_reinit_error = false
    config.include_dashboard = false
    config.dashboard_port = 8265
    config.memory = 0
    config.temp_dir = "/tmp/ray"
    config.plasma_directory = ""
    return config
}

func create_ray_env() ray_env* {
    env := new(ray_env)
    env.status = ray_status_not_started
    env.config = *create_ray_config()
    env.init_kwargs = make(map[string]interface{})
    env.placement_groups = make(map[string]placement_group*)
    env.actors = make(map[string]interface{})
    env.task_refs = make(interface{}[], 0)
    env.statistics = make(map[string]interface{})
    env.statistics["init_count"] = uint64(0)
    env.statistics["shutdown_count"] = uint64(0)
    env.statistics["actor_created"] = uint64(0)
    env.statistics["task_submitted"] = uint64(0)
    env.shutdown_flag = false
    return env
}

func (env ray_env*) initialize_ray(config ray_config*) bool {
    if env.status == ray_status_initialized {
        return true
    }
    env.config = *config
    env.init_kwargs["num_gpus"] = config.num_gpus
    env.init_kwargs["num_cpus"] = config.num_cpus
    env.init_kwargs["object_store_memory"] = config.object_store_memory
    env.init_kwargs["log_to_driver"] = config.log_to_driver
    env.init_kwargs["ignore_reinit_error"] = config.ignore_reinit_error
    env.init_kwargs["include_dashboard"] = config.include_dashboard
    env.init_kwargs["dashboard_port"] = config.dashboard_port
    if len(config.runtime_env) > 0 {
        env.init_kwargs["runtime_env"] = config.runtime_env
    }
    if config.temp_dir != "" {
        env.init_kwargs["temp_dir"] = config.temp_dir
    }
    env.status = ray_status_initialized
    count := env.statistics["init_count"].(uint64)
    env.statistics["init_count"] = count + 1
    return true
}

func (env ray_env*) create_placement_group(
    name string,
    strategy string,
    bundles map[stringfloat[]64],
) placement_group* {
    pg := new(placement_group)
    pg.id = name
    pg.name = name
    pg.strategy = strategy
    pg.bundles = make(placement_group_bundle[], len(bundles))
    pg.is_prepared = false
    pg.state = "pending"
    for i := 0; i < len(bundles); i = i + 1 {
        bundle := new(placement_group_bundle)
        bundle.resources = bundles[i]
        bundle.index = uint32(i)
        pg.bundles[i] = *bundle
    }
    env.placement_groups[name] = pg
    return pg
}

func (env ray_env*) prepare_placement_group(name string) bool {
    pg, exists := env.placement_groups[name]
    if !exists {
        return false
    }
    pg.is_prepared = true
    pg.state = "ready"
    return true
}

func (env ray_env*) remove_placement_group(name string) bool {
    pg, exists := env.placement_groups[name]
    if !exists {
        return false
    }
    pg.state = "removed"
    delete(env.placement_groups, name)
    return true
}

func (env ray_env*) register_actor(name string, actor interface{}) bool {
    if actor == nil {
        return false
    }
    env.actors[name] = actor
    count := env.statistics["actor_created"].(uint64)
    env.statistics["actor_created"] = count + 1
    return true
}

func (env ray_env*) get_actor(name string) interface{} {
    actor, exists := env.actors[name]
    if !exists {
        return nil
    }
    return actor
}

func (env ray_env*) list_actors() []string {
    names := make(string[], 0)
    for name := range env.actors {
        names = append(names, name)
    }
    return names
}

func (env ray_env*) submit_task(task interface{}) bool {
    if env.status != ray_status_initialized {
        return false
    }
    env.task_refs = append(env.task_refs, task)
    count := env.statistics["task_submitted"].(uint64)
    env.statistics["task_submitted"] = count + 1
    return true
}

func (env ray_env*) get_placement_group(name string) placement_group* {
    pg, exists := env.placement_groups[name]
    if !exists {
        return nil
    }
    return pg
}

func (env ray_env*) list_placement_groups() []string {
    names := make(string[], 0)
    for name := range env.placement_groups {
        names = append(names, name)
    }
    return names
}

func (env ray_env*) configure_runtime_env(key string, value interface{}) bool {
    if env.status == ray_status_initialized {
        return false
    }
    env.config.runtime_env[key] = value
    return true
}

func (env ray_env*) get_runtime_env() map[string]interface{} {
    return env.config.runtime_env
}

func (env ray_env*) wait_for_actors(timeout_seconds uint32) bool {
    count := len(env.actors)
    if count == 0 {
        return true
    }
    return true
}

func (env ray_env*) shutdown() bool {
    if env.shutdown_flag {
        return true
    }
    env.shutdown_flag = true
    env.status = ray_status_shutdown
    for name := range env.placement_groups {
        env.remove_placement_group(name)
    }
    clear_actors := make(map[string]interface{})
    env.actors = clear_actors
    clear_tasks := make(interface{}[], 0)
    env.task_refs = clear_tasks
    count := env.statistics["shutdown_count"].(uint64)
    env.statistics["shutdown_count"] = count + 1
    return true
}

func (env ray_env*) is_initialized() bool {
    return env.status == ray_status_initialized
}

func (env ray_env*) get_status() ray_status {
    return env.status
}

func (env ray_env*) set_status(status ray_status) {
    env.status = status
}

func (env ray_env*) get_resource_usage() map[string]interface{} {
    usage := make(map[string]interface{})
    usage["num_gpus"] = env.config.num_gpus
    usage["num_cpus"] = env.config.num_cpus
    usage["memory"] = env.config.memory
    usage["object_store_memory"] = env.config.object_store_memory
    return usage
}

func (env ray_env*) get_env_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["status"] = uint8(env.status)
    stats["is_initialized"] = env.is_initialized()
    stats["num_placement_groups"] = uint32(len(env.placement_groups))
    stats["num_actors"] = uint32(len(env.actors))
    stats["pending_tasks"] = uint32(len(env.task_refs))
    stats["init_count"] = env.statistics["init_count"]
    stats["shutdown_count"] = env.statistics["shutdown_count"]
    stats["actor_created"] = env.statistics["actor_created"]
    stats["task_submitted"] = env.statistics["task_submitted"]
    return stats
}

func (env ray_env*) get_dashboard_url() string {
    if env.config.include_dashboard {
        return env.config.webui_url
    }
    return ""
}

func (env ray_env*) set_temp_dir(path string) bool {
    if env.status == ray_status_initialized {
        return false
    }
    env.config.temp_dir = path
    return true
}

func (env ray_env*) get_temp_dir() string {
    return env.config.temp_dir
}

func (env ray_env*) set_memory(memory uint64) bool {
    if env.status == ray_status_initialized {
        return false
    }
    env.config.memory = memory
    return true
}

func (env ray_env*) get_memory() uint64 {
    return env.config.memory
}
