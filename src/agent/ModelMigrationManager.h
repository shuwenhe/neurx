#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <map>

/**
 * @class ModelMigrationManager
 * @brief Version and model migration orchestration
 * 
 * Features:
 * - Multi-model support management
 * - Version compatibility checking
 * - Model-specific behavior adaptation
 * - Feature flag management
 * - Capability detection
 * - Backward compatibility handling
 */

class ModelMigrationManager : public QObject {
    Q_OBJECT

public:
    enum ModelType {
        ClaudeOpus3,
        ClaudeOpus4,
        ClaudeHaiku,
        ClaudeSonnet,
        GPT4,
        GPT35Turbo,
        Gemini
    };

    enum CapabilityLevel {
        Basic,
        Standard,
        Advanced,
        Premium
    };

    struct ModelCapabilities {
        QString modelName;
        ModelType type;
        int maxTokens;
        float costPer1K;
        QStringList supportedFeatures;
        CapabilityLevel level;
        bool supportsVision;
        bool supportsStreaming;
        bool supportsImageGeneration;
    };

    struct VersionConfig {
        QString versionId;
        QString description;
        ModelType targetModel;
        QJsonObject settings;
        QStringList breakingChanges;
        QStringList deprecatedFeatures;
        QStringList newFeatures;
        bool isDeprecated;
    };

    struct FeatureFlag {
        QString name;
        bool enabled;
        QStringList models;
        float rolloutPercentage;
        QString description;
    };

    explicit ModelMigrationManager(QObject* parent = nullptr);
    ~ModelMigrationManager();

    // Model management
    void registerModel(const ModelCapabilities& capabilities);
    ModelCapabilities getModelCapabilities(ModelType type);
    void setCurrentModel(ModelType model);
    ModelType getCurrentModel() const;

    // Version management
    void registerVersion(const VersionConfig& config);
    VersionConfig getVersionConfig(const QString& versionId);
    bool isVersionCompatible(const QString& versionId, ModelType targetModel);
    QStringList getAvailableVersions();

    // Capability detection
    bool hasCapability(const QString& feature);
    QStringList getSupportedFeatures();
    bool supportsStreaming();
    bool supportsVision();
    int getMaxTokens();

    // Feature flags
    void registerFeatureFlag(const FeatureFlag& flag);
    bool isFeatureFlagEnabled(const QString& flagName);
    void setFeatureFlag(const QString& flagName, bool enabled);
    QStringList getAllFeatureFlags();

    // Migration utilities
    QString migratePrompt(const QString& originalPrompt, ModelType sourceModel, ModelType targetModel);
    QJsonObject migrateConfiguration(const QString& versionId);
    QString getAdaptedBehavior(const QString& feature);

    // Compatibility checking
    bool checkBackwardCompatibility(const QString& fromVersion, const QString& toVersion);
    QStringList getBreakingChanges(const QString& version);
    QStringList getDeprecationWarnings();

    // Performance optimization
    struct ModelPerformance {
        ModelType model;
        int avgResponseTimeMs;
        float costEfficiency;
        int successRate;  // 0-100
        int reliabilityScore;  // 0-100
    };
    ModelPerformance getModelPerformance(ModelType model);
    ModelType suggestBestModelForTask(const QString& taskDescription);

    // Fallback management
    void registerFallbackModel(ModelType primary, ModelType fallback);
    ModelType getFallbackModel(ModelType model);
    bool switchToFallback();

    // Analytics
    struct MigrationStats {
        int totalMigrations;
        int successfulMigrations;
        int failedMigrations;
        float avgMigrationTime;
        QMap<QString, int> featureFlagUsage;
    };
    MigrationStats getStatistics();

signals:
    void modelChanged(ModelType newModel);
    void versionMigrationStarted(const QString& fromVersion, const QString& toVersion);
    void versionMigrationCompleted(const QString& toVersion);
    void featureFlagChanged(const QString& flagName, bool enabled);
    void capabilityDetected(const QString& capability);
    void incompatibilityDetected(const QString& issue);

private:
    ModelType m_currentModel;
    QMap<ModelType, ModelCapabilities> m_capabilities;
    QMap<QString, VersionConfig> m_versions;
    QMap<QString, FeatureFlag> m_flags;
    QMap<ModelType, ModelType> m_fallbacks;
    MigrationStats m_stats;

    void initializeDefaultModels();
};
