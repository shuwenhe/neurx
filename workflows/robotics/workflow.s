package neurx.workflows.robotics
use neurx.workflows.robotics.sim.{robotics_sim_state, robotics_sim_state_dict, robotics_sim_load_state_dict, robotics_sim_enable_domain_randomization, new_robotics_sim_state}
use neurx.workflows.robotics.real.{robotics_real_state, robotics_real_state_dict, robotics_real_load_state_dict, robotics_real_connect, robotics_real_trigger_emergency_stop, new_robotics_real_state}
use neurx.workflows.robotics.deploy.{robotics_deploy_state, robotics_deploy_state_dict, robotics_deploy_load_state_dict, robotics_deploy_start, robotics_deploy_trigger_emergency_stop, new_robotics_deploy_state}

struct robotics_workflow_pipeline_state {
    robotics_workflow_state workflow
    robotics_sim_state sim
    robotics_real_state real
    robotics_deploy_state deploy
    bool simulation_ready
    bool deployment_ready
}

func new_robotics_workflow_pipeline_state(
    string name,
    string mode,
    string env_name,
    string robot_name,
    string target_name
) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: new_robotics_workflow_state(name, mode),
        sim: new_robotics_sim_state(env_name, 0, false),
        real: new_robotics_real_state(robot_name),
        deploy: new_robotics_deploy_state(target_name),
        simulation_ready: false,
        deployment_ready: false,
    }
}

func robotics_workflow_pipeline_state_dict(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_state_dict(state.workflow),
        sim: robotics_sim_state_dict(state.sim),
        real: robotics_real_state_dict(state.real),
        deploy: robotics_deploy_state_dict(state.deploy),
        simulation_ready: state.simulation_ready,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_pipeline_load_state_dict(robotics_workflow_pipeline_state state, robotics_workflow_pipeline_state other) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_load_state_dict(state.workflow, other.workflow),
        sim: robotics_sim_load_state_dict(state.sim, other.sim),
        real: robotics_real_load_state_dict(state.real, other.real),
        deploy: robotics_deploy_load_state_dict(state.deploy, other.deploy),
        simulation_ready: other.simulation_ready,
        deployment_ready: other.deployment_ready,
    }
}

func robotics_workflow_prepare_sim(robotics_workflow_pipeline_state state, bool enable_domain_randomization) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_mark_ready(state.workflow),
        sim: robotics_sim_enable_domain_randomization(state.sim),
        real: state.real,
        deploy: state.deploy,
        simulation_ready: enable_domain_randomization || state.sim.domain_randomization,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_deploy(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_mark_ready(state.workflow),
        sim: state.sim,
        real: robotics_real_connect(state.real),
        deploy: robotics_deploy_start(state.deploy),
        simulation_ready: state.simulation_ready,
        deployment_ready: true,
    }
}

func robotics_workflow_shutdown(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: state.workflow,
        sim: state.sim,
        real: robotics_real_trigger_emergency_stop(state.real),
        deploy: robotics_deploy_trigger_emergency_stop(state.deploy),
        simulation_ready: false,
        deployment_ready: false,
    }
}

func robotics_workflow_pipeline_complete(robotics_workflow_pipeline_state state) bool {
    state.workflow.ready && state.deploy.running && !state.deploy.emergency_stop
}

struct robotics_workflow_example_state {
    robotics_workflow_pipeline_state pipeline
    int stage
    bool finished
}

func new_robotics_workflow_example_state(
    string name,
    string mode,
    string env_name,
    string robot_name,
    string target_name
) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: new_robotics_workflow_pipeline_state(name, mode, env_name, robot_name, target_name),
        stage: 0,
        finished: false,
    }
}

func robotics_workflow_example_state_dict(robotics_workflow_example_state state) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_pipeline_state_dict(state.pipeline),
        stage: state.stage,
        finished: state.finished,
    }
}

func robotics_workflow_example_load_state_dict(robotics_workflow_example_state state, robotics_workflow_example_state other) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_pipeline_load_state_dict(state.pipeline, other.pipeline),
        stage: other.stage,
        finished: other.finished,
    }
}

func robotics_workflow_example_prepare(robotics_workflow_example_state state, bool enable_domain_randomization) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_prepare_sim(state.pipeline, enable_domain_randomization),
        stage: 1,
        finished: false,
    }
}

func robotics_workflow_example_deploy(robotics_workflow_example_state state) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_deploy(state.pipeline),
        stage: 2,
        finished: true,
    }
}

func robotics_workflow_example_shutdown(robotics_workflow_example_state state) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_shutdown(state.pipeline),
        stage: state.stage,
        finished: true,
    }
}

func robotics_workflow_example_complete(robotics_workflow_example_state state) bool {
    state.finished && robotics_workflow_pipeline_complete(state.pipeline)
}

func robotics_workflow_example_pipeline(robotics_workflow_example_state state) robotics_workflow_pipeline_state {
    state.pipeline
}

func robotics_workflow_example_step(robotics_workflow_example_state state, bool enable_domain_randomization) robotics_workflow_example_state {
    if state.finished {
        return state
    }
    if state.stage == 0 {
        return robotics_workflow_example_prepare(state, enable_domain_randomization)
    }
    if state.stage == 1 {
        return robotics_workflow_example_deploy(state)
    }
    robotics_workflow_example_shutdown(state)
}

func robotics_workflow_example_run(robotics_workflow_example_state state, int steps, bool enable_domain_randomization) robotics_workflow_example_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    robotics_workflow_example_state current = state
    int i = 0
    while i < loops {
        current = robotics_workflow_example_step(current, enable_domain_randomization)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}

