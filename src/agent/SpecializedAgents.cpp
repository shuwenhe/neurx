#include "SpecializedAgents.h"
#include <QDebug>
#include <QDateTime>

namespace neurx {

SpecializedAgent::SpecializedAgent(const AgentConfig& config, QObject* parent)
    : QObject(parent), m_config(config), m_llmProvider(nullptr), m_toolRegistry(nullptr)
{
}

// CodeExplorerAgent implementation
CodeExplorerAgent::CodeExplorerAgent(QObject* parent)
    : SpecializedAgent(AgentConfig{
        "code-explorer",
        "Code Explorer",
        "Expert in exploring and analyzing codebases",
        AgentExpertise::CodeExploration,
        "You are an expert in codebase exploration...",
        "gpt-4o",
        0.2,
        2000,
        128000,
        {"search", "read_file", "list_dir"},
        {},
        {},
        true,
        120,
        2,
        true,
        "What part of the code should I explore?",
        {},
        {}
    }, parent)
{
}

void CodeExplorerAgent::executeTask(const AgentTask& task,
                                   std::function<void(const AgentResult&)> callback)
{
    // Basic implementation
    AgentResult result;
    result.success = true;
    result.taskId = task.taskId;
    result.agentId = id();
    result.result = "Exploring code for: " + task.query;
    callback(result);
}

void CodeExplorerAgent::cancelTask(const QString& taskId) {}

// CodeArchitectAgent implementation
CodeArchitectAgent::CodeArchitectAgent(QObject* parent)
    : SpecializedAgent(AgentConfig{
        "code-architect",
        "Code Architect",
        "Expert in system design and architecture",
        AgentExpertise::Architecture,
        "You are an expert software architect...",
        "gpt-4o",
        0.3,
        4000,
        128000,
        {"read_file", "list_dir"},
        {},
        {},
        false,
        300,
        1,
        true,
        "What feature should I design?",
        {},
        {}
    }, parent)
{
}

void CodeArchitectAgent::executeTask(const AgentTask& task,
                                    std::function<void(const AgentResult&)> callback)
{
    AgentResult result;
    result.success = true;
    result.taskId = task.taskId;
    result.agentId = id();
    result.result = "Designing architecture for: " + task.query;
    callback(result);
}

void CodeArchitectAgent::cancelTask(const QString& taskId) {}

// CodeReviewerAgent implementation
CodeReviewerAgent::CodeReviewerAgent(QObject* parent)
    : SpecializedAgent(AgentConfig{
        "code-reviewer",
        "Code Reviewer",
        "Expert in code quality and security review",
        AgentExpertise::CodeReview,
        "You are an expert code reviewer...",
        "gpt-4o",
        0.2,
        2000,
        128000,
        {"read_file", "diff_tool"},
        {},
        {},
        true,
        180,
        2,
        true,
        "What code should I review?",
        {},
        {}
    }, parent)
{
}

void CodeReviewerAgent::executeTask(const AgentTask& task,
                                   std::function<void(const AgentResult&)> callback)
{
    AgentResult result;
    result.success = true;
    result.taskId = task.taskId;
    result.agentId = id();
    result.result = "Reviewing code for: " + task.query;
    callback(result);
}

void CodeReviewerAgent::cancelTask(const QString& taskId) {}

// TestAnalyzerAgent implementation
TestAnalyzerAgent::TestAnalyzerAgent(QObject* parent)
    : SpecializedAgent(AgentConfig{
        "test-analyzer",
        "Test Analyzer",
        "Expert in testing and validation",
        AgentExpertise::Testing,
        "You are an expert in software testing...",
        "gpt-4o",
        0.2,
        2000,
        128000,
        {"read_file", "run_tests"},
        {},
        {},
        true,
        240,
        2,
        true,
        "What should I test?",
        {},
        {}
    }, parent)
{
}

void TestAnalyzerAgent::executeTask(const AgentTask& task,
                                   std::function<void(const AgentResult&)> callback)
{
    AgentResult result;
    result.success = true;
    result.taskId = task.taskId;
    result.agentId = id();
    result.result = "Analyzing tests for: " + task.query;
    callback(result);
}

void TestAnalyzerAgent::cancelTask(const QString& taskId) {}

// AgentOrchestrator implementation
AgentOrchestrator::AgentOrchestrator(QObject* parent)
    : QObject(parent), m_llmProvider(nullptr), m_toolRegistry(nullptr)
{
}

void AgentOrchestrator::registerAgent(std::shared_ptr<SpecializedAgent> agent)
{
    if (agent) {
        m_agents[agent->id()] = agent;
        emit agentRegistered(agent->id());
    }
}

void AgentOrchestrator::unregisterAgent(const QString& agentId)
{
    if (m_agents.remove(agentId)) {
        emit agentUnregistered(agentId);
    }
}

std::shared_ptr<SpecializedAgent> AgentOrchestrator::getAgent(const QString& agentId) const
{
    return m_agents.value(agentId);
}

QList<AgentConfig> AgentOrchestrator::getAllAgents() const
{
    QList<AgentConfig> configs;
    for (const auto& agent : m_agents) {
        configs.append(agent->config());
    }
    return configs;
}

void AgentOrchestrator::executeTask(const AgentTask& task,
                                   std::function<void(const AgentResult&)> callback)
{
    auto agent = getAgent(task.agentId);
    if (agent) {
        emit taskStarted(task.taskId, task.agentId);
        agent->executeTask(task, [this, task, callback](const AgentResult& result) {
            emit taskCompleted(task.taskId, result.success);
            callback(result);
        });
    } else {
        AgentResult result;
        result.success = false;
        result.taskId = task.taskId;
        result.error = "Agent not found: " + task.agentId;
        callback(result);
    }
}

void AgentOrchestrator::executeParallel(const QList<AgentTask>& tasks,
                                       std::function<void(const QList<AgentResult>&)> callback)
{
    // Simplified parallel execution
    auto results = std::make_shared<QList<AgentResult>>();
    auto counter = std::make_shared<int>(tasks.size());

    for (const auto& task : tasks) {
        executeTask(task, [results, counter, tasks, callback](const AgentResult& result) {
            results->append(result);
            (*counter)--;
            if (*counter == 0) {
                callback(*results);
            }
        });
    }
}

void AgentOrchestrator::executeSequential(const QList<AgentTask>& tasks,
                                         std::function<void(const QList<AgentResult>&)> callback)
{
    // Simplified sequential execution
    auto results = std::make_shared<QList<AgentResult>>();

    std::function<void(int)> runNext = [this, tasks, results, callback, &runNext](int index) {
        if (index >= tasks.size()) {
            callback(*results);
            return;
        }

        executeTask(tasks[index], [results, index, tasks, &runNext](const AgentResult& result) {
            results->append(result);
            runNext(index + 1);
        });
    };

    runNext(0);
}

void AgentOrchestrator::setLLMProvider(LLMProvider* provider)
{
    m_llmProvider = provider;
    for (auto& agent : m_agents) {
        agent->setLLMProvider(provider);
    }
}

void AgentOrchestrator::setToolRegistry(ToolRegistry* registry)
{
    m_toolRegistry = registry;
    for (auto& agent : m_agents) {
        agent->setToolRegistry(registry);
    }
}

} // namespace neurx

