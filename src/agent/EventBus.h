#pragma once

#include <QString>
#include <QMap>
#include <QList>
#include <QJsonObject>
#include <QObject>
#include <QDateTime>
#include <functional>

/**
 * @class AgentEvent
 * @brief Represents an event in the agent system
 */
struct AgentEvent {
    enum class Type {
        // Execution events
        ExecutionStarted,
        ExecutionCompleted,
        ExecutionFailed,
        
        // Tool events
        ToolCalled,
        ToolCompleted,
        ToolFailed,
        
        // Agent events
        AgentThinking,
        AgentPlanning,
        AgentExecuting,
        
        // Context events
        ContextAdded,
        ContextCleared,
        
        // Hook events
        HookExecuting,
        HookCompleted,
        
        // Plugin events
        PluginLoaded,
        PluginUnloaded,
        PluginActivated,
        PluginDeactivated,
        
        // Custom event
        Custom
    };
    
    QString id;                    ///< Event ID
    Type type;                     ///< Event type
    QString typeName;              ///< Custom type name (for Custom events)
    QDateTime timestamp;           ///< When the event occurred
    QString source;                ///< Event source (tool name, plugin id, etc.)
    QJsonObject data;              ///< Event data/payload
    QString userId;                ///< User who triggered the event
    int priority{0};               ///< Event priority (higher = more important)
    bool isAsync{false};           ///< Whether this is an async event
};

/**
 * @class EventListener
 * @brief A registered event listener callback
 */
struct EventListener {
    QString id;
    AgentEvent::Type eventType;
    QString eventTypeName;  // For custom events
    std::function<void(const AgentEvent &)> handler;
    bool oneTime{false};    // Execute only once
    int priority{0};        // Higher priority executes first
};

/**
 * @class EventBus
 * @brief Central event publishing and subscription system
 * 
 * Features:
 * - Event publishing with automatic ID and timestamp
 * - Event subscription with filtering
 * - Priority-based event delivery
 * - Event history and replay
 * - Event filtering and routing
 * - Async event support
 */
class EventBus : public QObject {
    Q_OBJECT

public:
    explicit EventBus(QObject *parent = nullptr);
    ~EventBus();

    // ── Event Publishing ────────────────────────────────────────────────────
    
    /**
     * @brief Publish an event
     * @param type Event type
     * @param source Event source
     * @param data Event data
     * @param async Whether to publish asynchronously
     */
    QString publishEvent(AgentEvent::Type type, const QString &source, 
                        const QJsonObject &data = {}, bool async = false);
    
    /**
     * @brief Publish a custom event
     */
    QString publishCustomEvent(const QString &typeName, const QString &source,
                               const QJsonObject &data = {}, bool async = false);
    
    /**
     * @brief Publish a full event object
     */
    void publishEvent(const AgentEvent &event, bool async = false);

    // ── Event Subscription ───────────────────────────────────────────────────
    
    /**
     * @brief Subscribe to events
     * @param type Event type to listen for
     * @param handler Callback function
     * @param priority Listener priority (higher = called first)
     * @return Listener ID for unsubscribing
     */
    QString subscribe(AgentEvent::Type type, 
                     std::function<void(const AgentEvent &)> handler,
                     int priority = 0);
    
    /**
     * @brief Subscribe to custom events
     */
    QString subscribeCustom(const QString &typeName,
                           std::function<void(const AgentEvent &)> handler,
                           int priority = 0);
    
    /**
     * @brief Subscribe to one event
     */
    QString subscribeOnce(AgentEvent::Type type,
                         std::function<void(const AgentEvent &)> handler,
                         int priority = 0);
    
    /**
     * @brief Subscribe to specific source events
     */
    QString subscribeToSource(const QString &source,
                             std::function<void(const AgentEvent &)> handler,
                             int priority = 0);
    
    /**
     * @brief Unsubscribe from events
     */
    bool unsubscribe(const QString &listenerId);
    
    /**
     * @brief Unsubscribe all listeners
     */
    void unsubscribeAll();

    // ── Event Filtering and Routing ─────────────────────────────────────────
    
    /**
     * @brief Filter events by type
     */
    QList<AgentEvent> getEventsByType(AgentEvent::Type type) const;
    
    /**
     * @brief Filter events by source
     */
    QList<AgentEvent> getEventsBySource(const QString &source) const;
    
    /**
     * @brief Filter events by time range
     */
    QList<AgentEvent> getEventsByTimeRange(const QDateTime &start, 
                                          const QDateTime &end) const;
    
    /**
     * @brief Get all events in history
     */
    QList<AgentEvent> eventHistory(int maxItems = 1000) const;

    // ── Event History Management ────────────────────────────────────────────
    
    /**
     * @brief Get event by ID
     */
    AgentEvent getEvent(const QString &eventId) const;
    
    /**
     * @brief Clear event history
     */
    void clearHistory();
    
    /**
     * @brief Get history size
     */
    int historySize() const;
    
    /**
     * @brief Set maximum history size (older events discarded)
     */
    void setMaxHistorySize(int size);

    // ── Event Statistics ────────────────────────────────────────────────────
    
    /**
     * @brief Get event statistics
     */
    QJsonObject getStatistics() const;
    
    /**
     * @brief Get events per type
     */
    QMap<QString, int> eventCountByType() const;
    
    /**
     * @brief Get events per source
     */
    QMap<QString, int> eventCountBySource() const;

    // ── Event Replay (for debugging) ────────────────────────────────────────
    
    /**
     * @brief Replay events from history
     * @param startIndex Starting index
     * @param count Number of events to replay
     */
    void replayEvents(int startIndex = 0, int count = -1);
    
    /**
     * @brief Replay events for a specific source
     */
    void replayEventsForSource(const QString &source);

signals:
    /**
     * @brief Emitted when any event is published
     */
    void eventPublished(const AgentEvent &event);
    
    /**
     * @brief Emitted for specific event types
     */
    void eventReceived(AgentEvent::Type type, const AgentEvent &event);
    
    /**
     * @brief Emitted when event history is cleared
     */
    void historyCleared();

private:
    /**
     * @brief Generate unique event ID
     */
    QString generateEventId();
    
    /**
     * @brief Deliver event to subscribers
     */
    void deliverEvent(const AgentEvent &event);
    
    /**
     * @brief Deliver event asynchronously
     */
    void deliverEventAsync(const AgentEvent &event);
    
    /**
     * @brief Find applicable listeners for an event
     */
    QList<EventListener> findListeners(const AgentEvent &event) const;

    // ── Data members ────────────────────────────────────────────────────────
    QList<AgentEvent> m_eventHistory;
    QMap<QString, EventListener> m_listeners;
    int m_maxHistorySize{10000};
    int m_eventCounter{0};
};
