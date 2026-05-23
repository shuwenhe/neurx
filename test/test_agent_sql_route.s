package neurx.test_agent_sql_route

use neurx.agent.{new_default_agent, run_agent_once, agent_current_task, agent_route, agent_last_observation}

func main() int {
    string prompt = "analyze mysql schema migration for login user table"

    agent_runtime_state state = new_default_agent(prompt)
    state = run_agent_once(state, prompt)
    if agent_route(state) != "sql" {
        println("agent did not classify the request as sql")
        return 1
    }
    if agent_current_task(state) != "plan" {
        println("agent did not advance from analyze to plan for sql route")
        return 1
    }

    state = run_agent_once(state, prompt)
    if agent_current_task(state) != "retrieve" {
        println("agent did not advance from plan to retrieve for sql route")
        return 1
    }

    state = run_agent_once(state, prompt)
    string observation = agent_last_observation(state)
    if observation == "" {
        println("agent did not produce a retrieval observation for sql route")
        return 1
    }
    if observation == "retrieved:route=sql;source=none" {
        println("agent sql retrieval fell back to empty source")
        return 1
    }

    println("agent sql routing test passed")
    0
}
