#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class AppMarketplaceManager
 * @brief Application marketplace and app discovery
 */

class AppMarketplaceManager : public QObject {
    Q_OBJECT

public:
    struct AppListing {
        QString appId;
        QString name;
        QString description;
        QString version;
        QString author;
        QString icon;
        float rating;
        int downloads;
        QString category;
        QStringList tags;
        QString installUrl;
    };

    struct AppReview {
        QString appId;
        QString reviewerName;
        float rating;
        QString content;
        qint64 timestamp;
    };

    explicit AppMarketplaceManager(QObject* parent = nullptr);
    ~AppMarketplaceManager();

    QVector<AppListing> searchApps(const QString& query);
    QVector<AppListing> getAppsByCategory(const QString& category);
    AppListing getAppDetails(const QString& appId);
    QVector<AppListing> getTrendingApps();
    QVector<AppListing> getTopRatedApps();

    void installApp(const QString& appId);
    void uninstallApp(const QString& appId);
    void updateApp(const QString& appId);

    void submitReview(const QString& appId, const AppReview& review);
    QVector<AppReview> getAppReviews(const QString& appId);
    float getAverageRating(const QString& appId);

    void favoriteApp(const QString& appId);
    void unfavoriteApp(const QString& appId);

signals:
    void appInstalled(const QString& appId);
    void appUpdated(const QString& appId);
    void appUninstalled(const QString& appId);

private:
    QVector<AppListing> m_apps;
    QMap<QString, QVector<AppReview>> m_reviews;
};
