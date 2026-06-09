#include "agent/EventBus.h"
#include <QDebug>
#include <QUuid>
#include <QtConcurrent/QtConcurrentRun>
#include <QJsonArray>

EventBus::EventBus(QObject *parent)
    : QObject(parent)
{
}

EventBus::~EventBus() = default;

// ── Event Publishing ────────────────────────────────────────────────────

QString EventBus::publishEvent(AgentEvent::Type type, const QString &source,
                               const QJsonObject &data, bool async)
{
    AgentEvent event;
    event.id = generateEventId();
    event.type = type;
    event.source = source;
    event.data = data;
    event.timestamp = QDateTime::currentDateTime();
    
    publishEvent(event, async);
    return event.id;
}

QString EventBus::publishCustomEvent(const QString &typeName, const QString &source,
                                     const QJsonObject &data, bool async)
{
    AgentEvent event;
    event.id = generateEventId();
    event.type = AgentEvent::Type::Custom;
    event.typeName = typeName;
    event.source = source;
    event.data = data;
    event.timestamp = QDateTime::currentDateTime();
    
    publishEvent(event, async);
    return event.id;
}

void EventBus::publishEvent(const AgentEvent &event, bool async)
{
    AgentEvent evt = event;
    if (evt.id.isEmpty()) {
        evt.id = generateEventId();
    }
    if (evt.timestamp.isNull()) {
        evt.timestamp = QDateTime::currentDateTime();
    }
    
    if (async) {
        deliverEventAsync(evt);
    } else {
        deliverEvent(evt);
    }
}

// ── Event Subscription ───────────────────────────────────────────────────

QString EventBus::subscribe(AgentEvent::Type type,
                           std::function<void(const AgentEvent &)> handler,
                           int priority)
{
    EventListener listener;
    listener.id = generateEventId();
    listener.eventType = type;
    listener.handler = handler;
    listener.priority = priority;
    
    m_listeners[listener.id] = listener;
    return listener.id;
}

QString EventBus::subscribeCustom(const QString &typeName,
                                 std::function<void(const AgentEvent &)> handler,
                                 int priority)
{
    EventListener listener;
    listener.id = generateEventId();
    listener.eventType = AgentEvent::Type::Custom;
    listener.eventTypeName = typeName;
    listener.handler = handler;
    listener.priority = priority;
    
    m_listeners[listener.id] = listener;
    return listener.id;
}

QString EventBus::subscribeOnce(AgentEvent::Type type,
                               std::function<void(const AgentEvent &)> handler,
                               int priority)
{
    EventListener listener;
    listener.id = generateEventId();
    listener.eventType = type;
    listener.handler = handler;
    listener.priority = priority;
    listener.oneTime = true;
    
    m_listeners[listener.id] = listener;
    return listener.id;
}

QString EventBus::subscribeToSource(const QString &source,
                                   std::function<void(const AgentEvent &)> handler,
                                   int priority)
{
    EventListener listener;
    listener.id = generateEventId();
    listener.eventType = AgentEvent::Type::Custom;  // Use as wildcard
    listener.eventTypeName = QString("source:%1").arg(source);
    listener.handler = handler;
    listener.priority = priority;
    
    m_listeners[listener.id] = listener;
    return listener.id;
}

bool EventBus::unsubscribe(const QString &listenerId)
{
    return m_listeners.remove(listenerId) > 0;
}

void EventBus::unsubscribeAll()
{
    m_listeners.clear();
}

// ── Event Filtering and Routing ─────────────────────────────────────────

QList<AgentEvent> EventBus::getEventsByType(AgentEvent::Type type) const
{
    QList<AgentEvent> result;
    for (const auto &event : m_eventHistory) {
        if (event.type == type) {
            result.append(event);
        }
    }
    return result;
}

QList<AgentEvent> EventBus::getEventsBySource(const QString &source) const
{
    QList<AgentEvent> result;
    for (const auto &event : m_eventHistory) {
        if (event.source == source) {
            result.append(event);
        }
    }
    return result;
}

QList<AgentEvent> EventBus::getEventsByTimeRange(const QDateTime &start,
                                                const QDateTime &end) const
{
    QList<AgentEvent> result;
    for (const auto &event : m_eventHistory) {
        if (event.timestamp >= start && event.timestamp <= end) {
            result.append(event);
        }
    }
    return result;
}

QList<AgentEvent> EventBus::eventHistory(int maxItems) const
{
    if (maxItems <= 0) {
        return m_eventHistory;
    }
    
    int start = qMax(0, m_eventHistory.size() - maxItems);
    return m_eventHistory.mid(start);
}

// ── Event History Management ────────────────────────────────────────────

AgentEvent EventBus::getEvent(const QString &eventId) const
{
    for (const auto &event : m_eventHistory) {
        if (event.id == eventId) {
            return event;
        }
    }
    return AgentEvent();
}

void EventBus::clearHistory()
{
    m_eventHistory.clear();
    emit historyCleared();
}

int EventBus::historySize() const
{
    return m_eventHistory.size();
}

void EventBus::setMaxHistorySize(int size)
{
    m_maxHistorySize = size;
    
    // Trim history if needed
    while (m_eventHistory.size() > m_maxHistorySize) {
        m_eventHistory.removeFirst();
    }
}

// ── Event Statistics ────────────────────────────────────────────────────

QJsonObject EventBus::getStatistics() const
{
    QJsonObject stats;
    stats["totalEvents"] = m_eventHistory.size();
    stats["maxHistorySize"] = m_maxHistorySize;
    stats["listenersCount"] = m_listeners.size();
    
    // Count by type
    QJsonObject byType;
    for (const auto &event : m_eventHistory) {
        QString typeName;
        switch (event.type) {
            case AgentEvent::Type::ExecutionStarted: typeName = "ExecutionStarted"; break;
            case AgentEvent::Type::ExecutionCompleted: typeName = "ExecutionCompleted"; break;
            case AgentEvent::Type::ExecutionFailed: typeName = "ExecutionFailed"; break;
            case AgentEvent::Type::ToolCalled: typeName = "ToolCalled"; break;
            case AgentEvent::Type::ToolCompleted: typeName = "ToolCompleted"; break;
            case AgentEvent::Type::ToolFailed: typeName = "ToolFailed"; break;
            case AgentEvent::Type::Custom: typeName = event.typeName; break;
            default: typeName = "Other"; break;
        }
        
        int count = byType[typeName].toInt(0);
        byType[typeName] = count + 1;
    }
    stats["byType"] = byType;
    
    return stats;
}

QMap<QString, int> EventBus::eventCountByType() const
{
    QMap<QString, int> counts;
    for (const auto &event : m_eventHistory) {
        QString typeName;
        switch (event.type) {
            case AgentEvent::Type::ExecutionStarted: typeName = "ExecutionStarted"; break;
            case AgentEvent::Type::ExecutionCompleted: typeName = "ExecutionCompleted"; break;
            case AgentEvent::Type::ExecutionFailed: typeName = "ExecutionFailed"; break;
            case AgentEvent::Type::ToolCalled: typeName = "ToolCalled"; break;
            case AgentEvent::Type::ToolCompleted: typeName = "ToolCompleted"; break;
            case AgentEvent::Type::ToolFailed: typeName = "ToolFailed"; break;
            case AgentEvent::Type::Custom: typeName = event.typeName; break;
            default: typeName = "Other"; break;
        }
        counts[typeName]++;
    }
    return counts;
}

QMap<QString, int> EventBus::eventCountBySource() const
{
    QMap<QString, int> counts;
    for (const auto &event : m_eventHistory) {
        counts[event.source]++;
    }
    return counts;
}

// ── Event Replay (for debugging) ────────────────────────────────────────

void EventBus::replayEvents(int startIndex, int count)
{
    if (startIndex < 0 || startIndex >= m_eventHistory.size()) {
        return;
    }
    
    int endIndex = (count <= 0) ? m_eventHistory.size() 
                                 : qMin(startIndex + count, m_eventHistory.size());
    
    for (int i = startIndex; i < endIndex; ++i) {
        deliverEvent(m_eventHistory[i]);
    }
}

void EventBus::replayEventsForSource(const QString &source)
{
    auto events = getEventsBySource(source);
    for (const auto &event : events) {
        deliverEvent(event);
    }
}

// ── Private helper methods ───────────────────────────────────────────────

QString EventBus::generateEventId()
{
    return QString("evt_%1_%2").arg(++m_eventCounter).arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
}

void EventBus::deliverEvent(const AgentEvent &event)
{
    // Add to history
    m_eventHistory.append(event);
    if (m_eventHistory.size() > m_maxHistorySize) {
        m_eventHistory.removeFirst();
    }
    
    emit eventPublished(event);
    
    // Find and notify listeners
    auto listeners = findListeners(event);
    
    // Sort by priority (higher first)
    std::sort(listeners.begin(), listeners.end(),
              [](const EventListener &a, const EventListener &b) {
                  return a.priority > b.priority;
              });
    
    // Deliver to listeners
    QStringList toRemove;
    for (const auto &listener : listeners) {
        try {
            listener.handler(event);
            if (listener.oneTime) {
                toRemove.append(listener.id);
            }
        } catch (const std::exception &e) {
            qWarning() << "Listener error:" << e.what();
        }
    }
    
    // Remove one-time listeners
    for (const auto &id : toRemove) {
        m_listeners.remove(id);
    }
}

void EventBus::deliverEventAsync(const AgentEvent &event)
{
    // Run async delivery in thread pool
    (void)QtConcurrent::run([this, event]() {
        deliverEvent(event);
    });
}

QList<EventListener> EventBus::findListeners(const AgentEvent &event) const
{
    QList<EventListener> result;
    
    for (const auto &listener : m_listeners.values()) {
        // Check type match
        bool typeMatch = false;
        
        if (listener.eventType == AgentEvent::Type::Custom) {
            if (listener.eventTypeName.startsWith("source:")) {
                // Source-based listener
                QString source = listener.eventTypeName.mid(7);
                if (event.source == source) {
                    typeMatch = true;
                }
            } else if (event.type == AgentEvent::Type::Custom &&
                      listener.eventTypeName == event.typeName) {
                // Custom event type match
                typeMatch = true;
            } else if (listener.eventTypeName == "*") {
                // Wildcard
                typeMatch = true;
            }
        } else if (listener.eventType == event.type) {
            typeMatch = true;
        }
        
        if (typeMatch) {
            result.append(listener);
        }
    }
    
    return result;
}
