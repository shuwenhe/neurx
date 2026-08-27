package neurx.kernel.module

struct module_state {
    int value
}

func module_state_live() module_state { module_state { value: 0 } }
func module_state_coming() module_state { module_state { value: 1 } }
func module_state_going() module_state { module_state { value: 2 } }
func module_state_unformed() module_state { module_state { value: 3 } }

struct module_dependency {
    string module_name
    bool required
}

struct kernel_module {
    string name
    string version
    string description
    int refcount
    module_state state
    vec[module_dependency] dependencies
    int init_offset
    int exit_offset
    int data_size
    int code_size
    bool has_init
    bool has_exit
    bool has_modinfo
}

struct module_manager {
    vec[kernel_module] loaded_modules
    int total_loaded
    int total_unloaded
    int total_failed
    int version_requirement_checks
    int dependency_checks_passed
    int dependency_checks_failed
}

func module_manager_create() module_manager {
    return module_manager {
        loaded_modules: vec[kernel_module](),
        total_loaded: 0,
        total_unloaded: 0,
        total_failed: 0,
        version_requirement_checks: 0,
        dependency_checks_passed: 0,
        dependency_checks_failed: 0
    }
}

func (m kernel_module*) init_module() (bool, string) {
    if m.state.value != 1 {
        return false, "Module not in COMING state"
    }
    if m.has_init == false {
        m.state = module_state_live()
        return true, ""
    }
    m.state = module_state_live()
    return true, ""
}

func (m kernel_module*) exit_module() (bool, string) {
    if m.state.value != 0 {
        return false, "Module not in LIVE state"
    }
    if m.refcount > 0 {
        return false, "Module still in use"
    }
    if m.has_exit == false {
        m.state = module_state_going()
        return true, ""
    }
    m.state = module_state_going()
    return true, ""
}

func (m kernel_module) add_reference() (int, string) {
    if m.state.value != 0 {
        return 0, "Module not loaded"
    }
    return m.refcount, ""
}

func (m kernel_module*) remove_reference() (int, string) {
    if m.refcount > 0 {
        m.refcount = m.refcount - 1
    }
    return m.refcount, ""
}

func (mm module_manager*) load_module(string name, string version) (int, string) {
    i := 0
    while i < mm.loaded_modules.len() {
        if mm.loaded_modules[i].name == name {
            return 0, "Module already loaded"
        }
        i = i + 1
    }
    
    module := kernel_module {
        name: name,
        version: version,
        description: "",
        refcount: 0,
        state: module_state_coming(),
        dependencies: vec[module_dependency](),
        init_offset: 0,
        exit_offset: 0,
        data_size: 0,
        code_size: 0,
        has_init: true,
        has_exit: true,
        has_modinfo: true
    }
    
    mm.loaded_modules.push(module)
    mm.total_loaded = mm.total_loaded + 1
    return mm.total_loaded, ""
}

func (mm module_manager*) unload_module(string name) (bool, string) {
    i := 0
    while i < mm.loaded_modules.len() {
        if mm.loaded_modules[i].name == name {
            if mm.loaded_modules[i].refcount > 0 {
                return false, "Module has active references"
            }
            mm.total_unloaded = mm.total_unloaded + 1
            return true, ""
        }
        i = i + 1
    }
    return false, "Module not found"
}

func (mm module_manager*) resolve_dependencies(string module_name) (bool, string) {
    i := 0
    while i < mm.loaded_modules.len() {
        if mm.loaded_modules[i].name == module_name {
            j := 0
            while j < mm.loaded_modules[i].dependencies.len() {
                dep := mm.loaded_modules[i].dependencies[j]
                k := 0
                found := false
                while k < mm.loaded_modules.len() {
                    if mm.loaded_modules[k].name == dep.module_name {
                        found = true
                        break
                    }
                    k = k + 1
                }
                if found == false && dep.required == true {
                    mm.dependency_checks_failed = mm.dependency_checks_failed + 1
                    return false, "Unmet dependency: " + dep.module_name
                }
                j = j + 1
            }
            mm.dependency_checks_passed = mm.dependency_checks_passed + 1
            return true, ""
        }
        i = i + 1
    }
    return false, "Module not found"
}

func (mm module_manager) get_module_stats() string {
    loaded := mm.total_loaded
    unloaded := mm.total_unloaded
    failed := mm.total_failed
    return "Loaded: " + loaded as string + ", Unloaded: " + unloaded as string + ", Failed: " + failed as string
}

func (mm module_manager) find_module(string name) option[int] {
    i := 0
    while i < mm.loaded_modules.len() {
        if mm.loaded_modules[i].name == name {
            return option::some(i)
        }
        i = i + 1
    }
    return option::none()
}
