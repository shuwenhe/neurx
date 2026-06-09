#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class IntelligentRecommendationEngine
 * @brief ML-based recommendations
 */

class IntelligentRecommendationEngine : public QObject {
    Q_OBJECT

public:
    struct UserProfile {
        QString userId;
        QStringList preferences;
        QMap<QString, float> featureWeights;
        float trustScore;
    };

    struct RecommendationItem {
        QString itemId;
        QString title;
        float relevanceScore;
        QString category;
        QString explanation;
    };

    explicit IntelligentRecommendationEngine(QObject* parent = nullptr);
    ~IntelligentRecommendationEngine();

    void updateUserProfile(const UserProfile& profile);
    QVector<RecommendationItem> getRecommendations(const QString& userId, int count = 10);
    QVector<RecommendationItem> getPersonalizedRecommendations(const QString& userId);

    void recordUserInteraction(const QString& userId, const QString& itemId, const QString& action);
    void trainModel();

    float getPredictionConfidence(const QString& userId, const QString& itemId);

signals:
    void recommendationsGenerated(const QString& userId);
    void modelTrained();

private:
    QMap<QString, UserProfile> m_profiles;
    QVector<RecommendationItem> m_items;
};
