#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <functional>
#include <memory>

/**
 * @file SpecializedAgents.h
 * @brief Specialized AI agents inspired by Claude Code
 * 
 * Implements specialized agents for:
 * - Code exploration and analysis
 * - Architecture design
 * - Code review and quality
 * - Testing and validation
 * - Refactoring and optimization
 */

namespace neurx {

// Forward declarations
class LLMProvider;
class ToolRegistry;

/**
 * @enum AgentExpertise
 * @brief Agent expertise areas
 */
enum class AgentExpertise {
    CodeExploration,    // Finding and analyzing code
    Architecture,       // System design and architecture
    CodeReview,         // Code quality and review
    Testing,            // Test creation and validation
    Refactoring,        // Code improvement
    Documentation,      // Documentation generation
    Security,           // Security analysis
    Performance,        // Performance optimization
    Debugging,          // Bug finding and fixing
    General             // General purpose
};

/**
 * @struct AgentConfig
 * @brief Configuration for a specialized agent
 */
struct AgentConfig {
    QString id;                     // Unique agent ID
    QString name;                   // Display name
    QString description;            // What the agent does
    AgentExpertise expertise;       // Expertise area
    
    // LLM Configuration
    QString systemPrompt;           // System prompt
    QString model;                  // Preferred model
    double temperature;             // Temperature (0.0-1.0)
    int maxTokens;                  // Max output tokens
    int contextWindow;              // Context window size
    
    // Capabilities
    QStringList skills;             // Skill IDs
    QStringList tools;              // Tool names
    QStringList requiredCapabilities; // Required capabilities
    
    // Behavior
    bool parallel;                  // Can run in parallel?
    int timeout;                    // Timeout in seconds
    int maxRetries;                 // Max retry attempts
    bool streaming;                 // Use streaming?
    
    // Instructions
    QString argumentHint;           // Argument hint
    QStringList examples;           // Usage examples
    QVariantMap metadata;           // Additional metadata
};

/**
 * @struct AgentTask
 * @brief Task for an agent to perform
 */
struct AgentTask {
    QString taskId;                 // Unique task ID
    QString agentId;                // Target agent ID
    QString query;                  // Query/instruction
    QVariantMap context;            // Execution context
    QVariantMap parameters;         // Task parameters
    
    // Constraints
    int maxSteps;                   // Max execution steps
    int timeoutMs;                  // Timeout in milliseconds
    QStringList allowedTools;       // Allowed tools
    
    // Callbacks
    std::function<void(const QString&)> onProgress;
    std::function<void(const QString&)> onThinking;
    std::function<void(const QVariantMap&)> onToolUse;
};

/**
 * @struct AgentResult
 * @brief Result from agent execution
 */
struct AgentResult {
    bool success;                   // Was successful?
    QString taskId;                 // Task ID
    QString agentId;                // Agent ID
    QString result;                 // Main result
    QVariantMap data;               // Structured data
    QString error;                  // Error message
    
    // Execution info
    int stepsExecuted;              // Steps executed
    int toolsUsed;                  // Tools used
    qint64 executionTimeMs;         // Execution time
    int tokensUsed;                 // Tokens used
    
    // Artifacts
    QStringList filesCreated;       // Files created
    QStringList filesModified;      // Files modified
    QVariantMap artifacts;          // Additional artifacts
};

/**
 * @class SpecializedAgent
 * @brief Base class for specialized agents
 */
class SpecializedAgent : public QObject {
    Q_OBJECT
    
public:
    explicit SpecializedAgent(const AgentConfig& config, QObject* parent = nullptr);
    virtual ~SpecializedAgent() = default;
    
    // Configuration
    QString id() const { return m_config.id; }
    QString name() const { return m_config.name; }
    AgentConfig config() const { return m_config; }
    
    // Setup
    void setLLMProvider(LLMProvider* provider) { m_llmProvider = provider; }
    void setToolRegistry(ToolRegistry* registry) { m_toolRegistry = registry; }
    
    // Execution
    virtual void executeTask(const AgentTask& task,
                            std::function<void(const AgentResult&)> callback) = 0;
    virtual void cancelTask(const QString& taskId) = 0;
    
signals:
    void taskStarted(const QString& taskId);
    void taskCompleted(const QString& taskId, bool success);
    void progressUpdated(const QString& taskId, const QString& progress);
    void thinkingUpdate(const QString& taskId, const QString& thinking);
    void toolUsed(const QString& taskId, const QString& toolName);
    
protected:
    AgentConfig m_config;
    LLMProvider* m_llmProvider;
    ToolRegistry* m_toolRegistry;
};

/**
 * @class CodeExplorerAgent
 * @brief Agent for exploring and analyzing codebases
 */
class CodeExplorerAgent : public SpecializedAgent {
    Q_OBJECT
    
public:
    explicit CodeExplorerAgent(QObject* parent = nullptr);
    
    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback) override;
    void cancelTask(const QString& taskId) override;
    
    // Specialized methods
    struct ExplorationResult {
        QStringList relevantFiles;      // Relevant source files
        QStringList keySymbols;          // Key symbols (classes, functions)
        QVariantMap architecture;        // Architecture insights
        QStringList dependencies;        // Dependencies found
        QString summary;                 // Exploration summary
    };
    
    void exploreFeature(const QString& featureDescription,
                       const QString& workspacePath,
                       std::function<void(const ExplorationResult&)> callback);
    
    void mapArchitecture(const QString& area,
                        const QString& workspacePath,
                        std::function<void(const ExplorationResult&)> callback);
    
    void traceDependencies(const QString& symbol,
                          const QString& workspacePath,
                          std::function<void(const ExplorationResult&)> callback);
};

/**
 * @class CodeArchitectAgent
 * @brief Agent for architecture design
 */
class CodeArchitectAgent : public SpecializedAgent {
    Q_OBJECT
    
public:
    explicit CodeArchitectAgent(QObject* parent = nullptr);
    
    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback) override;
    void cancelTask(const QString& taskId) override;
    
    // Specialized methods
    struct ArchitectureDesign {
        QString overview;                // Design overview
        QVariantMap components;          // Component definitions
        QVariantMap interfaces;          // Interface definitions
        QStringList files;               // Files to create/modify
        QString implementation;          // Implementation plan
        QStringList dependencies;        // External dependencies
    };
    
    void designFeature(const QString& feature,
                      const QVariantMap& requirements,
                      const QString& workspacePath,
                      std::function<void(const ArchitectureDesign&)> callback);
    
    void designRefactoring(const QString& goal,
                          const QStringList& affectedFiles,
                          std::function<void(const ArchitectureDesign&)> callback);
};

/**
 * @class CodeReviewerAgent
 * @brief Agent for code review and quality analysis
 */
class CodeReviewerAgent : public SpecializedAgent {
    Q_OBJECT
    
public:
    explicit CodeReviewerAgent(QObject* parent = nullptr);
    
    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback) override;
    void cancelTask(const QString& taskId) override;
    
    // Specialized methods
    struct ReviewResult {
        QString summary;                 // Review summary
        QList<QVariantMap> issues;       // Issues found
        QList<QVariantMap> suggestions;  // Suggestions
        int qualityScore;                // Quality score (0-100)
        QStringList strengths;           // Code strengths
        QStringList concerns;            // Concerns
    };
    
    void reviewCode(const QStringList& files,
                   const QString& context,
                   std::function<void(const ReviewResult&)> callback);
    
    void reviewDiff(const QString& diff,
                   const QString& context,
                   std::function<void(const ReviewResult&)> callback);
    
    void reviewPR(const QString& prNumber,
                 const QString& repoPath,
                 std::function<void(const ReviewResult&)> callback);
};

/**
 * @class TestAnalyzerAgent
 * @brief Agent for test analysis and generation
 */
class TestAnalyzerAgent : public SpecializedAgent {
    Q_OBJECT
    
public:
    explicit TestAnalyzerAgent(QObject* parent = nullptr);
    
    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback) override;
    void cancelTask(const QString& taskId) override;
    
    // Specialized methods
    struct TestAnalysis {
        int coverage;                    // Coverage percentage
        QStringList missingTests;        // Missing test cases
        QStringList suggestions;         // Test suggestions
        QString testPlan;                // Test plan
        QVariantMap generatedTests;      // Generated test code
    };
    
    void analyzeTestCoverage(const QString& filePath,
                            std::function<void(const TestAnalysis&)> callback);
    
    void generateTests(const QString& sourceFile,
                      const QString& testFramework,
                      std::function<void(const TestAnalysis&)> callback);
};

/**
 * @class AgentOrchestrator
 * @brief Orchestrates multiple specialized agents
 */
class AgentOrchestrator : public QObject {
    Q_OBJECT
    
public:
    explicit AgentOrchestrator(QObject* parent = nullptr);
    ~AgentOrchestrator() = default;
    
    // Agent management
    void registerAgent(std::shared_ptr<SpecializedAgent> agent);
    void unregisterAgent(const QString& agentId);
    std::shared_ptr<SpecializedAgent> getAgent(const QString& agentId) const;
    QList<AgentConfig> getAllAgents() const;
    
    // Task execution
    void executeTask(const AgentTask& task,
                    std::function<void(const AgentResult&)> callback);
    
    // Parallel execution
    void executeParallel(const QList<AgentTask>& tasks,
                        std::function<void(const QList<AgentResult>&)> callback);
    
    // Sequential execution
    void executeSequential(const QList<AgentTask>& tasks,
                          std::function<void(const QList<AgentResult>&)> callback);
    
    // Setup
    void setLLMProvider(LLMProvider* provider);
    void setToolRegistry(ToolRegistry* registry);
    
signals:
    void agentRegistered(const QString& agentId);
    void agentUnregistered(const QString& agentId);
    void taskStarted(const QString& taskId, const QString& agentId);
    void taskCompleted(const QString& taskId, bool success);
    
private:
    QMap<QString, std::shared_ptr<SpecializedAgent>> m_agents;
    LLMProvider* m_llmProvider;
    ToolRegistry* m_toolRegistry;
};

} // namespace neurx
