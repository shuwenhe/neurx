#include "ProgressService.h"
#include <QDateTime>
#include <QUuid>
#include <QTimer>

class ProgressService::Impl {
public:
    QList<ProgressReport> activeProgress;
    
    QString generateId() {
        return QUuid::createUuid().toString(QUuid::WithoutBraces);
    }
    
    ProgressReport createProgress(const QString& title, int total, bool canCancel) {
        ProgressReport report;
        report.id = generateId();
        report.title = title;
        report.total = total;
        report.canCancel = canCancel;
        report.startTime = QDateTime::currentMSecsSinceEpoch();
        return report;
    }
    
    qint64 estimateRemaining(const ProgressReport& report) {
        if (report.current == 0) return -1;
        
        qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - report.startTime;
        float rate = (float)report.current / elapsed;
        if (rate <= 0) return -1;
        
        return (qint64)((report.total - report.current) / rate);
    }
};

ProgressService* ProgressService::instance() {
    static ProgressService s_instance;
    return &s_instance;
}

ProgressService::ProgressService()
    : m_impl(std::make_unique<Impl>()) {
}

ProgressService::~ProgressService() = default;

QString ProgressService::startProgress(const QString& title, int total, bool canCancel) {
    auto report = m_impl->createProgress(title, total, canCancel);
    m_impl->activeProgress.append(report);
    emit progressStarted(report);
    return report.id;
}

void ProgressService::updateProgress(const QString& progressId, int current, const QString& message) {
    for (auto& report : m_impl->activeProgress) {
        if (report.id == progressId) {
            report.current = qMin(current, report.total);
            report.message = message;
            report.estimatedRemainingMs = m_impl->estimateRemaining(report);
            emit progressUpdated(report);
            return;
        }
    }
}

void ProgressService::incrementProgress(const QString& progressId, const QString& message) {
    for (auto& report : m_impl->activeProgress) {
        if (report.id == progressId) {
            report.current = qMin(report.current + 1, report.total);
            report.message = message;
            report.estimatedRemainingMs = m_impl->estimateRemaining(report);
            emit progressUpdated(report);
            return;
        }
    }
}

bool ProgressService::cancelProgress(const QString& progressId) {
    for (int i = 0; i < m_impl->activeProgress.size(); ++i) {
        auto& report = m_impl->activeProgress[i];
        if (report.id == progressId && report.canCancel) {
            if (report.onCancel) {
                report.onCancel();
            }
            emit progressCanceled(progressId);
            m_impl->activeProgress.removeAt(i);
            return true;
        }
    }
    return false;
}

void ProgressService::finishProgress(const QString& progressId) {
    for (int i = 0; i < m_impl->activeProgress.size(); ++i) {
        if (m_impl->activeProgress[i].id == progressId) {
            m_impl->activeProgress.removeAt(i);
            emit progressFinished(progressId);
            return;
        }
    }
}

void ProgressService::failProgress(const QString& progressId, const QString& errorMessage) {
    for (int i = 0; i < m_impl->activeProgress.size(); ++i) {
        if (m_impl->activeProgress[i].id == progressId) {
            m_impl->activeProgress.removeAt(i);
            emit progressFailed(progressId, errorMessage);
            return;
        }
    }
}

QList<ProgressReport> ProgressService::activeProgress() const {
    return m_impl->activeProgress;
}

ProgressReport ProgressService::getProgress(const QString& progressId) const {
    for (const auto& report : m_impl->activeProgress) {
        if (report.id == progressId) {
            return report;
        }
    }
    return ProgressReport();
}

bool ProgressService::hasProgress(const QString& progressId) const {
    for (const auto& report : m_impl->activeProgress) {
        if (report.id == progressId) {
            return true;
        }
    }
    return false;
}
