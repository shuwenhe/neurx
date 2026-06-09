#include "AppMarketplaceManager.h"
#include <QDebug>

AppMarketplaceManager::AppMarketplaceManager(QObject* parent)
    : QObject(parent) {
}

AppMarketplaceManager::~AppMarketplaceManager() {
}

QVector<AppMarketplaceManager::AppListing> AppMarketplaceManager::searchApps(const QString& query) {
    QVector<AppListing> results;
    return results;
}

QVector<AppMarketplaceManager::AppListing> AppMarketplaceManager::getAppsByCategory(const QString& category) {
    QVector<AppListing> results;
    for (const auto& app : m_apps) {
        if (app.category == category) {
            results.append(app);
        }
    }
    return results;
}

AppMarketplaceManager::AppListing AppMarketplaceManager::getAppDetails(const QString& appId) {
    for (const auto& app : m_apps) {
        if (app.appId == appId) {
            return app;
        }
    }
    return AppListing();
}

QVector<AppMarketplaceManager::AppListing> AppMarketplaceManager::getTrendingApps() {
    return m_apps;
}

QVector<AppMarketplaceManager::AppListing> AppMarketplaceManager::getTopRatedApps() {
    return m_apps;
}

void AppMarketplaceManager::installApp(const QString& appId) {
    qDebug() << "Installing app:" << appId;
    emit appInstalled(appId);
}

void AppMarketplaceManager::uninstallApp(const QString& appId) {
    qDebug() << "Uninstalling app:" << appId;
    emit appUninstalled(appId);
}

void AppMarketplaceManager::updateApp(const QString& appId) {
    qDebug() << "Updating app:" << appId;
    emit appUpdated(appId);
}

void AppMarketplaceManager::submitReview(const QString& appId, const AppReview& review) {
    m_reviews[appId].append(review);
}

QVector<AppMarketplaceManager::AppReview> AppMarketplaceManager::getAppReviews(const QString& appId) {
    return m_reviews.value(appId);
}

float AppMarketplaceManager::getAverageRating(const QString& appId) {
    auto reviews = m_reviews.value(appId);
    if (reviews.isEmpty()) return 0.0f;

    float total = 0.0f;
    for (const auto& review : reviews) {
        total += review.rating;
    }
    return total / reviews.size();
}

void AppMarketplaceManager::favoriteApp(const QString& appId) {
    qDebug() << "Favorited app:" << appId;
}

void AppMarketplaceManager::unfavoriteApp(const QString& appId) {
    qDebug() << "Unfavorited app:" << appId;
}
