#pragma once

#include <QString>
#include <QList>
#include <QJsonObject>
#include <QObject>
#include <functional>

/**
 * @class Rule
 * @brief Represents a validation or execution rule
 */
struct Rule {
    QString id;                      ///< Unique rule ID
    QString name;                    ///< Human-readable name
    QString description;             ///< Rule description
    
    enum class RuleType {
        Validation,    ///< Validation rule (checks conditions)
        Action,        ///< Action rule (performs actions)
        Transform      ///< Transform rule (modifies data)
    } type{RuleType::Validation};
    
    enum class Trigger {
        Always,
        OnToolCall,
        OnCommandExecution,
        OnContextChange,
        OnEventPublished,
        Custom
    } trigger{Trigger::Always};
    
    QString customTrigger;           ///< Custom trigger name
    
    // Rule conditions
    QString condition;               ///< Condition expression (e.g., "tool == 'shell_tool'")
    QStringList applicableTools;     ///< Tools this rule applies to
    QStringList applicableCommands;  ///< Commands this rule applies to
    
    // Rule actions
    QString action;                  ///< Action to execute
    QJsonObject actionParams;        ///< Action parameters
    
    // Configuration
    bool enabled{true};              ///< Whether rule is enabled
    int priority{0};                 ///< Rule priority (higher = executed first)
    bool stopOnMatch{false};         ///< Stop processing other rules on match
    int timeoutMs{5000};             ///< Action timeout
    
    // Metadata
    QString author;                  ///< Rule author
    QString version;                 ///< Rule version
    QJsonObject metadata;            ///< Custom metadata
};

/**
 * @class RuleEvaluationContext
 * @brief Context for rule evaluation
 */
struct RuleEvaluationContext {
    QString eventType;               ///< Type of event triggering rule
    QString source;                  ///< Event source (tool name, command, etc.)
    QJsonObject data;                ///< Event data
    QJsonObject variables;           ///< Available variables for expressions
    QString userId;                  ///< User ID
    QDateTime timestamp;             ///< Evaluation time
};

/**
 * @class RuleResult
 * @brief Result of rule evaluation
 */
struct RuleResult {
    bool matched{false};             ///< Whether rule condition matched
    bool allowed{true};              ///< Whether action is allowed
    QString reason;                  ///< Reason for allow/block
    QJsonObject actionResult;        ///< Result of rule action
    int executionTimeMs{0};          ///< Time taken to evaluate
    QString message;                 ///< Message to display to user
};

/**
 * @class RuleEngine
 * @brief Evaluates and applies rules for validation and transformation
 * 
 * Inspired by claude-code's hookify system, provides:
 * - Rule registration and management
 * - Expression evaluation
 * - Rule ordering and priority
 * - Action execution
 * - Audit logging
 */
class RuleEngine : public QObject {
    Q_OBJECT

public:
    explicit RuleEngine(QObject *parent = nullptr);
    ~RuleEngine();

    // ── Rule Management ────────────────────────────────────────────────────
    
    /**
     * @brief Register a rule
     */
    void registerRule(const Rule &rule, 
                     std::function<RuleResult(const RuleEvaluationContext &)> evaluator);
    
    /**
     * @brief Unregister a rule
     */
    bool unregisterRule(const QString &ruleId);
    
    /**
     * @brief Enable/disable a rule
     */
    void setRuleEnabled(const QString &ruleId, bool enabled);
    
    /**
     * @brief Get all rules
     */
    QList<Rule> allRules() const;
    
    /**
     * @brief Get rules by trigger
     */
    QList<Rule> rulesByTrigger(Rule::Trigger trigger) const;

    // ── Rule Evaluation ────────────────────────────────────────────────────
    
    /**
     * @brief Evaluate all rules for a context
     */
    QList<RuleResult> evaluateRules(const RuleEvaluationContext &context);
    
    /**
     * @brief Evaluate rules with a specific trigger
     */
    QList<RuleResult> evaluateRulesByTrigger(Rule::Trigger trigger,
                                            const RuleEvaluationContext &context);
    
    /**
     * @brief Evaluate specific rule
     */
    RuleResult evaluateRule(const QString &ruleId, const RuleEvaluationContext &context);
    
    /**
     * @brief Check if operation is allowed by rules
     * @return False if any rule blocks the operation
     */
    bool isOperationAllowed(const RuleEvaluationContext &context, QString &blockReason);

    // ── Built-in Rules ────────────────────────────────────────────────────
    
    /**
     * @brief Register common validation rules
     */
    void registerCommonValidationRules();
    
    /**
     * @brief Create a tool validation rule
     */
    Rule createToolValidationRule(const QString &toolName, const QString &condition);
    
    /**
     * @brief Create a command permission rule
     */
    Rule createCommandPermissionRule(const QString &commandName, bool allowed);

    // ── Rule Statistics ────────────────────────────────────────────────────
    
    /**
     * @brief Get rule evaluation statistics
     */
    QJsonObject getStatistics() const;
    
    /**
     * @brief Get rules that were frequently triggered
     */
    QList<QString> getFrequentlyTriggeredRules(int topN = 10) const;

    // ── Rule Import/Export ─────────────────────────────────────────────────
    
    /**
     * @brief Load rules from JSON file
     */
    bool loadRulesFromFile(const QString &filePath);
    
    /**
     * @brief Save rules to JSON file
     */
    bool saveRulesToFile(const QString &filePath) const;
    
    /**
     * @brief Export rule as JSON
     */
    QJsonObject exportRule(const QString &ruleId) const;
    
    /**
     * @brief Import rule from JSON
     */
    QString importRule(const QJsonObject &ruleJson);

signals:
    /**
     * @brief Emitted when rule is registered
     */
    void ruleRegistered(const Rule &rule);
    
    /**
     * @brief Emitted when rule is evaluated
     */
    void ruleEvaluated(const QString &ruleId, const RuleResult &result);
    
    /**
     * @brief Emitted when rule blocks operation
     */
    void operationBlocked(const QString &reason);
    
    /**
     * @brief Emitted when rule allows operation
     */
    void operationAllowed(const QString &reason);

private:
    /**
     * @brief Evaluate a condition expression
     */
    bool evaluateCondition(const QString &expression, const QJsonObject &variables) const;
    
    /**
     * @brief Execute rule action
     */
    QJsonObject executeAction(const Rule &rule, const RuleEvaluationContext &context);
    
    /**
     * @brief Match context against rule
     */
    bool contextMatchesRule(const RuleEvaluationContext &context, const Rule &rule) const;

    // ── Data members ────────────────────────────────────────────────────────
    QMap<QString, Rule> m_rules;
    QMap<QString, std::function<RuleResult(const RuleEvaluationContext &)>> m_evaluators;
    QMap<QString, int> m_triggerCounts;  // For statistics
    QMap<QString, int> m_blockCounts;
};
