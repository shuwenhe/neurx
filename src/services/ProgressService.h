#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <functional>

/**
 * @class ProgressService
 * @brief Manages long-running operations with progress reporting
 * 
 * Features:
 * - Progress tracking for operations
 * - Cancellation support
 * - Progress state machine
 * - Multiple concurrent operations
 */

struct ProgressReport {
    QString id;
    QString title;
    QString message;
    int current = 0;
    int total = 100;
    float percentage() const {
        return total > 0 ? (float)current / total * 100 : 0;
    }
    bool canCancel = false;
    std::function<void()> onCancel;
    qint64 startTime = 0;
    qint64 estimatedRemainingMs = -1;
    
    bool operator==(const ProgressReport& other) const {
        return id == other.id;
    }
};

class ProgressService : public QObject {
    Q_OBJECT

public:
    static ProgressService* instance();
    
    // Start a progress operation
    QString startProgress(const QString& title, int total = 100, bool canCancel = false);
    
    // Update progress
    void updateProgress(const QString& progressId, int current, const QString& message = QString());
    void incrementProgress(const QString& progressId, const QString& message = QString());
    
    // Cancel operation
    bool cancelProgress(const QString& progressId);
    
    // End operation
    void finishProgress(const QString& progressId);
    void failProgress(const QString& progressId, const QString& errorMessage);
    
    // Query
    QList<ProgressReport> activeProgress() const;
    ProgressReport getProgress(const QString& progressId) const;
    bool hasProgress(const QString& progressId) const;
    
    // With callbacks
    template<typename Func>
    QString withProgress(const QString& title, int total, Func&& operation) {
        auto id = startProgress(title, total);
        try {
            operation([this, id](int current, const QString& msg) {
                updateProgress(id, current, msg);
            });
            finishProgress(id);
        } catch (const std::exception& e) {
            failProgress(id, QString::fromStdString(e.what()));
        }
        return id;
    }

signals:
    void progressStarted(const ProgressReport& report);
    void progressUpdated(const ProgressReport& report);
    void progressFinished(const QString& progressId);
    void progressFailed(const QString& progressId, const QString& error);
    void progressCanceled(const QString& progressId);

private:
    ProgressService();
    ~ProgressService() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
