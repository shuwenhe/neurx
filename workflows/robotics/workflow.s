package neurx.workflows.robotics

use neurx.workflows.robotics.sim.{robotics_sim_state, robotics_sim_state_dict, robotics_sim_load_state_dict, robotics_sim_enable_domain_randomization, new_robotics_sim_state}
use neurx.workflows.robotics.real.{robotics_real_state, robotics_real_state_dict, robotics_real_load_state_dict, robotics_real_connect, robotics_real_trigger_emergency_stop, new_robotics_real_state}
use neurx.workflows.robotics.policy.{robotics_policy_state, robotics_policy_state_dict, robotics_policy_load_state_dict, robotics_policy_mark_trained, new_robotics_policy_state}
use neurx.workflows.robotics.train.{robotics_train_state, robotics_train_state_dict, robotics_train_load_state_dict, robotics_train_start, robotics_train_stop, new_robotics_train_state}
use neurx.workflows.robotics.eval.{robotics_eval_state, robotics_eval_state_dict, robotics_eval_load_state_dict, robotics_eval_update, new_robotics_eval_state}
use neurx.workflows.robotics.deploy.{robotics_deploy_state, robotics_deploy_state_dict, robotics_deploy_load_state_dict, robotics_deploy_start, robotics_deploy_stop, robotics_deploy_trigger_emergency_stop, new_robotics_deploy_state}
use neurx.workflows.robotics.data.{robotics_dataset_state, robotics_dataset_state_dict, robotics_dataset_load_state_dict, robotics_dataset_mark_normalized, new_robotics_dataset_state}

struct robotics_workflow_pipeline_state {
    robotics_workflow_state workflow
    robotics_sim_state sim
    robotics_real_state real
    robotics_policy_state policy
    robotics_train_state train
    robotics_eval_state eval
    robotics_deploy_state deploy
    robotics_dataset_state data
    bool simulation_ready
    bool policy_ready
    bool training_ready
    bool evaluation_ready
    bool deployment_ready
}

func new_robotics_workflow_pipeline_state(
    string name,
    string mode,
    string env_name,
    string robot_name,
    string policy_name,
    int obs_dim,
    int act_dim,
    string strategy,
    string metric_name,
    string target_name,
    string source_name,
    int sample_count
) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: new_robotics_workflow_state(name, mode),
        sim: new_robotics_sim_state(env_name, 0, false),
        real: new_robotics_real_state(robot_name),
        policy: new_robotics_policy_state(policy_name, obs_dim, act_dim),
        train: new_robotics_train_state(strategy, 0),
        eval: new_robotics_eval_state(metric_name),
        deploy: new_robotics_deploy_state(target_name),
        data: new_robotics_dataset_state(source_name, sample_count),
        simulation_ready: false,
        policy_ready: false,
        training_ready: false,
        evaluation_ready: false,
        deployment_ready: false,
    }
}

func robotics_workflow_pipeline_state_dict(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_state_dict(state.workflow),
        sim: robotics_sim_state_dict(state.sim),
        real: robotics_real_state_dict(state.real),
        policy: robotics_policy_state_dict(state.policy),
        train: robotics_train_state_dict(state.train),
        eval: robotics_eval_state_dict(state.eval),
        deploy: robotics_deploy_state_dict(state.deploy),
        data: robotics_dataset_state_dict(state.data),
        simulation_ready: state.simulation_ready,
        policy_ready: state.policy_ready,
        training_ready: state.training_ready,
        evaluation_ready: state.evaluation_ready,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_pipeline_load_state_dict(robotics_workflow_pipeline_state state, robotics_workflow_pipeline_state other) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_load_state_dict(state.workflow, other.workflow),
        sim: robotics_sim_load_state_dict(state.sim, other.sim),
        real: robotics_real_load_state_dict(state.real, other.real),
        policy: robotics_policy_load_state_dict(state.policy, other.policy),
        train: robotics_train_load_state_dict(state.train, other.train),
        eval: robotics_eval_load_state_dict(state.eval, other.eval),
        deploy: robotics_deploy_load_state_dict(state.deploy, other.deploy),
        data: robotics_dataset_load_state_dict(state.data, other.data),
        simulation_ready: other.simulation_ready,
        policy_ready: other.policy_ready,
        training_ready: other.training_ready,
        evaluation_ready: other.evaluation_ready,
        deployment_ready: other.deployment_ready,
    }
}

func robotics_workflow_prepare_sim(robotics_workflow_pipeline_state state, bool enable_domain_randomization) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_mark_ready(state.workflow),
        sim: robotics_sim_enable_domain_randomization(state.sim),
        real: state.real,
        policy: state.policy,
        train: state.train,
        eval: state.eval,
        deploy: state.deploy,
        data: robotics_dataset_mark_normalized(state.data),
        simulation_ready: enable_domain_randomization || state.sim.domain_randomization,
        policy_ready: state.policy_ready,
        training_ready: state.training_ready,
        evaluation_ready: state.evaluation_ready,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_train_policy(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_mark_ready(state.workflow),
        sim: state.sim,
        real: state.real,
        policy: robotics_policy_mark_trained(state.policy),
        train: robotics_train_start(state.train),
        eval: state.eval,
        deploy: state.deploy,
        data: state.data,
        simulation_ready: state.simulation_ready,
        policy_ready: true,
        training_ready: true,
        evaluation_ready: state.evaluation_ready,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_finish_training(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: state.workflow,
        sim: state.sim,
        real: state.real,
        policy: state.policy,
        train: robotics_train_stop(state.train),
        eval: state.eval,
        deploy: state.deploy,
        data: state.data,
        simulation_ready: state.simulation_ready,
        policy_ready: state.policy_ready,
        training_ready: false,
        evaluation_ready: state.evaluation_ready,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_evaluate(robotics_workflow_pipeline_state state, float score, int episodes) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: state.workflow,
        sim: state.sim,
        real: state.real,
        policy: state.policy,
        train: state.train,
        eval: robotics_eval_update(state.eval, score, episodes),
        deploy: state.deploy,
        data: state.data,
        simulation_ready: state.simulation_ready,
        policy_ready: state.policy_ready,
        training_ready: state.training_ready,
        evaluation_ready: true,
        deployment_ready: state.deployment_ready,
    }
}

func robotics_workflow_deploy(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: robotics_workflow_mark_ready(state.workflow),
        sim: state.sim,
        real: robotics_real_connect(state.real),
        policy: state.policy,
        train: state.train,
        eval: state.eval,
        deploy: robotics_deploy_start(state.deploy),
        data: state.data,
        simulation_ready: state.simulation_ready,
        policy_ready: state.policy_ready,
        training_ready: state.training_ready,
        evaluation_ready: state.evaluation_ready,
        deployment_ready: true,
    }
}

func robotics_workflow_shutdown(robotics_workflow_pipeline_state state) robotics_workflow_pipeline_state {
    robotics_workflow_pipeline_state {
        workflow: state.workflow,
        sim: state.sim,
        real: robotics_real_trigger_emergency_stop(state.real),
        policy: state.policy,
        train: robotics_train_stop(state.train),
        eval: state.eval,
        deploy: robotics_deploy_trigger_emergency_stop(state.deploy),
        data: state.data,
        simulation_ready: false,
        policy_ready: false,
        training_ready: false,
        evaluation_ready: false,
        deployment_ready: false,
    }
}

func robotics_workflow_pipeline_complete(robotics_workflow_pipeline_state state) bool {
    state.workflow.ready && state.policy.trained && state.deploy.running && !state.deploy.emergency_stop
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
    string policy_name,
    int obs_dim,
    int act_dim,
    string strategy,
    string metric_name,
    string target_name,
    string source_name,
    int sample_count
) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: new_robotics_workflow_pipeline_state(
            name,
            mode,
            env_name,
            robot_name,
            policy_name,
            obs_dim,
            act_dim,
            strategy,
            metric_name,
            target_name,
            source_name,
            sample_count,
        ),
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

func robotics_workflow_example_train(robotics_workflow_example_state state) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_train_policy(state.pipeline),
        stage: 2,
        finished: false,
    }
}

func robotics_workflow_example_evaluate(robotics_workflow_example_state state, float score, int episodes) robotics_workflow_example_state {
    robotics_workflow_pipeline_state pipeline = robotics_workflow_evaluate(robotics_workflow_example_pipeline(state), score, episodes)
    pipeline = robotics_workflow_finish_training(pipeline)
    robotics_workflow_example_state {
        pipeline: pipeline,
        stage: 3,
        finished: false,
    }
}

func robotics_workflow_example_deploy(robotics_workflow_example_state state) robotics_workflow_example_state {
    robotics_workflow_example_state {
        pipeline: robotics_workflow_deploy(state.pipeline),
        stage: 4,
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

func robotics_workflow_example_step(robotics_workflow_example_state state, bool enable_domain_randomization, float score, int episodes) robotics_workflow_example_state {
    if state.finished {
        return state
    }
    if state.stage == 0 {
        return robotics_workflow_example_prepare(state, enable_domain_randomization)
    }
    if state.stage == 1 {
        return robotics_workflow_example_train(state)
    }
    if state.stage == 2 {
        return robotics_workflow_example_evaluate(state, score, episodes)
    }
    if state.stage == 3 {
        return robotics_workflow_example_deploy(state)
    }
    robotics_workflow_example_shutdown(state)
}

func robotics_workflow_example_run(robotics_workflow_example_state state, int steps, bool enable_domain_randomization, float score, int episodes) robotics_workflow_example_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    robotics_workflow_example_state current = state
    int i = 0
    while i < loops {
        current = robotics_workflow_example_step(current, enable_domain_randomization, score, episodes)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}
