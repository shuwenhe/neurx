#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <functional>
#include <memory>

/**
 * @class NotificationService
 * @brief Manages notifications similar to VS Code's notification system
 * 
 * Features:
 * - Info, warning, error notifications
 * - Notification actions (buttons)
 * - Progress notifications
 * - Notification history
 * - Auto-dismiss configuration
 */

struct NotificationAction {
    QString label;
    std::function<void()> callback;
};

struct Notification {
    enum Severity {
        Info,
        Warning,
        Error,
        Success
    };
    
    QString id;
    Severity severity = Info;
    QString message;
    QList<NotificationAction> actions;
    int timeoutMs = 0;  // 0 = no auto-dismiss
    bool sticky = false;
    QString source;     // Extension or service name
    qint64 timestamp = 0;
};

class NotificationService : public QObject {
    Q_OBJECT

public:
    static NotificationService* instance();
    
    // Show notifications
    QString notify(const QString& message, Notification::Severity severity = Notification::Info);
    QString info(const QString& message);
    QString warning(const QString& message);
    QString error(const QString& message);
    QString success(const QString& message);
    
    // With actions
    QString notifyWithActions(const QString& message, const QList<NotificationAction>& actions,
                             Notification::Severity severity = Notification::Info);
    
    // Progress notification
    QString showProgress(const QString& message);
    void updateProgress(const QString& notificationId, int value, int total);
    void closeProgress(const QString& notificationId);
    
    // Management
    void dismissNotification(const QString& notificationId);
    void dismissAll();
    void clearHistory();
    
    // Query
    QList<Notification> activeNotifications() const;
    QList<Notification> history(int maxCount = 100) const;
    bool hasNotification(const QString& notificationId) const;

signals:
    void notificationShown(const Notification& notification);
    void notificationDismissed(const QString& notificationId);
    void notificationActionTriggered(const QString& notificationId, int actionIndex);
    void progressUpdated(const QString& notificationId, int value, int total);

private:
    NotificationService();
    ~NotificationService() override;
    
    class Impl;
    std::unique_ptr<Impl> m_impl;
};
