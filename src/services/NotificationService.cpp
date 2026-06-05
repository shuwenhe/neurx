#include "NotificationService.h"
#include <QDateTime>
#include <QTimer>
#include <QUuid>

class NotificationService::Impl {
public:
    QList<Notification> activeNotifications;
    QList<Notification> history;
    static constexpr int MAX_HISTORY = 500;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    
    Notification createNotification(const QString& message, Notification::Severity severity) {
        Notification notif;
        notif.id = generateId();
        notif.message = message;
        notif.severity = severity;
        notif.timestamp = QDateTime::currentMSecsSinceEpoch();
        return notif;
    }
};

NotificationService* NotificationService::instance() {
    static NotificationService s_instance;
    return &s_instance;
}

NotificationService::NotificationService()
    : m_impl(std::make_unique<Impl>()) {
}

NotificationService::~NotificationService() = default;

QString NotificationService::notify(const QString& message, Notification::Severity severity) {
    auto notif = m_impl->createNotification(message, severity);
    notif.timeoutMs = 5000;  // Default 5 second timeout
    
    m_impl->activeNotifications.append(notif);
    if (m_impl->history.size() >= m_impl->MAX_HISTORY) {
        m_impl->history.removeFirst();
    }
    m_impl->history.append(notif);
    
    emit notificationShown(notif);
    
    // Auto-dismiss
    QTimer::singleShot(notif.timeoutMs, this, [this, id = notif.id]() {
        dismissNotification(id);
    });
    
    return notif.id;
}

QString NotificationService::info(const QString& message) {
    return notify(message, Notification::Info);
}

QString NotificationService::warning(const QString& message) {
    return notify(message, Notification::Warning);
}

QString NotificationService::error(const QString& message) {
    return notify(message, Notification::Error);
}

QString NotificationService::success(const QString& message) {
    return notify(message, Notification::Success);
}

QString NotificationService::notifyWithActions(const QString& message,
                                               const QList<NotificationAction>& actions,
                                               Notification::Severity severity) {
    auto notif = m_impl->createNotification(message, severity);
    notif.actions = actions;
    notif.sticky = !actions.isEmpty();
    
    m_impl->activeNotifications.append(notif);
    if (m_impl->history.size() >= m_impl->MAX_HISTORY) {
        m_impl->history.removeFirst();
    }
    m_impl->history.append(notif);
    
    emit notificationShown(notif);
    
    return notif.id;
}

QString NotificationService::showProgress(const QString& message) {
    auto notif = m_impl->createNotification(message, Notification::Info);
    notif.sticky = true;  // Don't auto-dismiss progress
    
    m_impl->activeNotifications.append(notif);
    emit notificationShown(notif);
    
    return notif.id;
}

void NotificationService::updateProgress(const QString& notificationId, int value, int total) {
    for (auto& notif : m_impl->activeNotifications) {
        if (notif.id == notificationId) {
            emit progressUpdated(notificationId, value, total);
            break;
        }
    }
}

void NotificationService::closeProgress(const QString& notificationId) {
    dismissNotification(notificationId);
}

void NotificationService::dismissNotification(const QString& notificationId) {
    for (int i = 0; i < m_impl->activeNotifications.size(); ++i) {
        if (m_impl->activeNotifications[i].id == notificationId) {
            m_impl->activeNotifications.removeAt(i);
            emit notificationDismissed(notificationId);
            return;
        }
    }
}

void NotificationService::dismissAll() {
    auto ids = m_impl->activeNotifications;
    m_impl->activeNotifications.clear();
    for (const auto& notif : ids) {
        emit notificationDismissed(notif.id);
    }
}

void NotificationService::clearHistory() {
    m_impl->history.clear();
}

QList<Notification> NotificationService::activeNotifications() const {
    return m_impl->activeNotifications;
}

QList<Notification> NotificationService::history(int maxCount) const {
    return m_impl->history.mid(qMax(0, m_impl->history.size() - maxCount));
}

bool NotificationService::hasNotification(const QString& notificationId) const {
    for (const auto& notif : m_impl->activeNotifications) {
        if (notif.id == notificationId) {
            return true;
        }
    }
    return false;
}
