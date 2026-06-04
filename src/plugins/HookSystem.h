#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QStringList>
#include <functional>
#include <memory>

/**
 * @file HookSystem.h
 * @brief Event hook system inspired by Claude Code
 * 
 * Implements:
 * - Pre/post event hooks
 * - Session lifecycle hooks
 * - Tool execution hooks
 * - File change hooks
 * - Custom event hooks
 */

namespace neurx {

/**
 * @enum HookType
 * @brief Types of hooks
 */
enum class HookType {
    // Session lifecycle
    SessionStart,       // When session starts
    SessionEnd,         // When session ends
    SessionResume,      // When session is resumed
    SessionPause,       // When session is paused
    
    // Message hooks
    PreMessage,         // Before sending to LLM
    PostMessage,        // After receiving from LLM
    MessageModified,    // When message is edited
    
    // Tool execution hooks
    PreToolUse,         // Before tool execution
    PostToolUse,        // After tool execution
    ToolApproval,       // When tool needs approval
    ToolRejected,       // When tool is rejected
    
    // Command hooks
    PreCommand,         // Before command execution
    PostCommand,        // After command execution
    
    // File system hooks
    FileCreated,        // When file is created
    FileModified,       // When file is modified
    FileDeleted,        // When file is deleted
    FileOpened,         // When file is opened
    FileSaved,          // When file is saved
    
    // Workspace hooks
    WorkspaceOpened,    // When workspace opens
    WorkspaceClosed,    // When workspace closes
    WorkspaceChanged,   // When workspace changes
    
    // Agent hooks
    AgentThinking,      // When agent is thinking
    AgentPlanning,      // When agent is planning
    AgentExecuting,     // When agent is executing
    
    // Stop hooks
    Stop,               // On stop/exit signal
    Emergency,          // On emergency stop
    
    // Custom
    Custom              // Custom hook type
};

/**
 * @enum HookPriority
 * @brief Hook execution priority
 */
enum class HookPriority {
    Lowest = 0,
    Low = 25,
    Normal = 50,
    High = 75,
    Highest = 100,
    Critical = 200
};

/**
 * @struct HookDefinition
 * @brief Complete hook definition
 */
struct HookDefinition {
    QString id;                     // Unique hook ID
    QString name;                   // Display name
    QString description;            // What the hook does
    HookType type;                  // Hook type
    HookPriority priority;          // Execution priority
    
    // Filtering
    QVariantMap filters;            // Event filters
    QStringList filePatterns;       // File patterns to match (glob)
    QStringList excludePatterns;    // Patterns to exclude
    QStringList toolPatterns;       // Tool patterns to match
    
    // Behavior
    bool async;                     // Run asynchronously
    bool cancellable;               // Can cancel/prevent event
    bool continueOnError;           // Continue if hook fails
    int timeout;                    // Timeout in ms (0 = no timeout)
    
    // Execution
    QString action;                 // Action to perform
    QString promptTemplate;         // Prompt template
    QString agentId;                // Agent to invoke
    QString scriptPath;             // Script to execute
    
    // Conditions
    QString condition;              // JS condition expression
    QVariantMap metadata;           // Additional metadata
    
    // UI
    QString category;               // Category for grouping
    QStringList tags;               // Tags
    
    QJsonObject toJson() const;
    static HookDefinition fromJson(const QJsonObject& json);
};

/**
 * @struct HookEvent
 * @brief Event passed to hooks
 */
struct HookEvent {
    HookType type;                  // Event type
    QString source;                 // Event source
    QDateTime timestamp;            // When event occurred
    
    // Context
    QVariantMap data;               // Event data
    QVariantMap context;            // Execution context
    
    // State
    bool cancelled;                 // Is event cancelled?
    bool preventDefault;            // Should prevent default action?
    QString cancelReason;           // Why cancelled
    
    // Results
    QVariantMap results;            // Hook results
    QStringList errors;             // Hook errors
    
    HookEvent() : cancelled(false), preventDefault(false) {}
    explicit HookEvent(HookType t) : type(t), cancelled(false), preventDefault(false) {}
    
    QJsonObject toJson() const;
    static HookEvent fromJson(const QJsonObject& json);
};

/**
 * @struct HookResult
 * @brief Result from hook execution
 */
struct HookResult {
    bool success;                   // Was successful?
    bool preventDefault;            // Should prevent default action?
    bool stopPropagation;           // Should stop other hooks?
    QString message;                // Result message
    QString error;                  // Error message
    QVariantMap data;               // Result data
    int executionTimeMs;            // Execution time
    
    HookResult() : success(true), preventDefault(false), stopPropagation(false), executionTimeMs(0) {}
    explicit HookResult(bool ok) : success(ok), preventDefault(false), stopPropagation(false), executionTimeMs(0) {}
    
    QJsonObject toJson() const;
    static HookResult fromJson(const QJsonObject& json);
};

/**
 * @typedef HookHandler
 * @brief Function signature for hook handlers
 */
using HookHandler = std::function<HookResult(HookEvent&)>;

/**
 * @class HookSystem
 * @brief Manages event hooks
 */
class HookSystem : public QObject {
    Q_OBJECT
    
public:
    explicit HookSystem(QObject* parent = nullptr);
    virtual ~HookSystem() = default;
    
    // ── Registration ────────────────────────────────────────────
    
    /**
     * @brief Register a hook
     * @param definition Hook definition
     * @param handler Hook handler function
     * @return Hook ID (empty on failure)
     */
    virtual QString registerHook(const HookDefinition& definition,
                                HookHandler handler) = 0;
    
    /**
     * @brief Unregister a hook
     * @param hookId Hook ID
     * @return true if unregistered successfully
     */
    virtual bool unregisterHook(const QString& hookId) = 0;
    
    /**
     * @brief Check if hook is registered
     * @param hookId Hook ID
     * @return true if registered
     */
    virtual bool hasHook(const QString& hookId) const = 0;
    
    /**
     * @brief Enable/disable a hook
     * @param hookId Hook ID
     * @param enabled Enable state
     * @return true if changed successfully
     */
    virtual bool setHookEnabled(const QString& hookId, bool enabled) = 0;
    
    // ── Discovery ───────────────────────────────────────────────
    
    /**
     * @brief Get all registered hooks
     * @return List of hook definitions
     */
    virtual QList<HookDefinition> getAllHooks() const = 0;
    
    /**
     * @brief Get hooks by type
     * @param type Hook type
     * @return List of matching hooks
     */
    virtual QList<HookDefinition> getHooksByType(HookType type) const = 0;
    
    /**
     * @brief Get hook definition
     * @param hookId Hook ID
     * @return Hook definition (empty if not found)
     */
    virtual HookDefinition getHookDefinition(const QString& hookId) const = 0;
    
    // ── Execution ───────────────────────────────────────────────
    
    /**
     * @brief Trigger a hook
     * @param event Hook event
     * @return true if event should continue
     */
    virtual bool triggerHook(HookEvent& event) = 0;
    
    /**
     * @brief Trigger hooks by type
     * @param type Hook type
     * @param data Event data
     * @return true if event should continue
     */
    virtual bool triggerHooksByType(HookType type, const QVariantMap& data = QVariantMap()) = 0;
    
    /**
     * @brief Check if event matches hook filters
     * @param definition Hook definition
     * @param event Hook event
     * @return true if matches
     */
    virtual bool matchesFilters(const HookDefinition& definition,
                               const HookEvent& event) const = 0;
    
    // ── Statistics ──────────────────────────────────────────────
    
    /**
     * @brief Get hook execution stats
     * @param hookId Hook ID
     * @return Statistics map
     */
    virtual QVariantMap getHookStats(const QString& hookId) const = 0;
    
    /**
     * @brief Get all hooks statistics
     * @return Statistics map
     */
    virtual QVariantMap getAllHooksStats() const = 0;
    
signals:
    /**
     * @brief Emitted when hook is triggered
     * @param type Hook type
     * @param hookId Hook ID
     */
    void hookTriggered(HookType type, const QString& hookId);
    
    /**
     * @brief Emitted when hook execution completes
     * @param hookId Hook ID
     * @param success Whether execution was successful
     */
    void hookExecuted(const QString& hookId, bool success);
    
    /**
     * @brief Emitted when hook is registered
     * @param hookId Hook ID
     */
    void hookRegistered(const QString& hookId);
    
    /**
     * @brief Emitted when hook is unregistered
     * @param hookId Hook ID
     */
    void hookUnregistered(const QString& hookId);
    
    /**
     * @brief Emitted when event is cancelled by hook
     * @param type Hook type
     * @param reason Cancel reason
     */
    void eventCancelled(HookType type, const QString& reason);
};

// Utility functions
QString hookTypeToString(HookType type);
HookType stringToHookType(const QString& str);
QString hookPriorityToString(HookPriority priority);
HookPriority stringToHookPriority(const QString& str);

} // namespace neurx
