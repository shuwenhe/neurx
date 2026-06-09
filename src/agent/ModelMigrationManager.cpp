#include "ModelMigrationManager.h"
#include <QDebug>

ModelMigrationManager::ModelMigrationManager(QObject* parent)
    : QObject(parent), m_currentModel(ClaudeOpus4) {
    m_stats = {0, 0, 0, 0.0f, {}};
    initializeDefaultModels();
}

ModelMigrationManager::~ModelMigrationManager() {
}

void ModelMigrationManager::initializeDefaultModels() {
    // Register default models
    ModelCapabilities opus4;
    opus4.modelName = "Claude 3 Opus";
    opus4.type = ClaudeOpus4;
    opus4.maxTokens = 200000;
    opus4.costPer1K = 0.015f;
    opus4.level = Premium;
    opus4.supportedFeatures = {"vision", "streaming", "tools", "caching"};
    opus4.supportsVision = true;
    opus4.supportsStreaming = true;
    registerModel(opus4);
}

void ModelMigrationManager::registerModel(const ModelCapabilities& capabilities) {
    m_capabilities[capabilities.type] = capabilities;
}

ModelMigrationManager::ModelCapabilities ModelMigrationManager::getModelCapabilities(ModelType type) {
    return m_capabilities.value(type);
}

void ModelMigrationManager::setCurrentModel(ModelType model) {
    if (m_capabilities.contains(model)) {
        m_currentModel = model;
        emit modelChanged(model);
    }
}

ModelMigrationManager::ModelType ModelMigrationManager::getCurrentModel() const {
    return m_currentModel;
}

void ModelMigrationManager::registerVersion(const VersionConfig& config) {
    m_versions[config.versionId] = config;
}

ModelMigrationManager::VersionConfig ModelMigrationManager::getVersionConfig(const QString& versionId) {
    return m_versions.value(versionId);
}

bool ModelMigrationManager::isVersionCompatible(const QString& versionId, ModelType targetModel) {
    auto version = m_versions.value(versionId);
    return version.targetModel == targetModel;
}

QStringList ModelMigrationManager::getAvailableVersions() {
    return m_versions.keys();
}

bool ModelMigrationManager::hasCapability(const QString& feature) {
    auto caps = m_capabilities[m_currentModel];
    return caps.supportedFeatures.contains(feature);
}

QStringList ModelMigrationManager::getSupportedFeatures() {
    return m_capabilities[m_currentModel].supportedFeatures;
}

bool ModelMigrationManager::supportsStreaming() {
    return m_capabilities[m_currentModel].supportsStreaming;
}

bool ModelMigrationManager::supportsVision() {
    return m_capabilities[m_currentModel].supportsVision;
}

int ModelMigrationManager::getMaxTokens() {
    return m_capabilities[m_currentModel].maxTokens;
}

void ModelMigrationManager::registerFeatureFlag(const FeatureFlag& flag) {
    m_flags[flag.name] = flag;
}

bool ModelMigrationManager::isFeatureFlagEnabled(const QString& flagName) {
    auto flag = m_flags.value(flagName);
    return flag.enabled;
}

void ModelMigrationManager::setFeatureFlag(const QString& flagName, bool enabled) {
    if (m_flags.contains(flagName)) {
        m_flags[flagName].enabled = enabled;
        emit featureFlagChanged(flagName, enabled);
    }
}

QStringList ModelMigrationManager::getAllFeatureFlags() {
    return m_flags.keys();
}

QString ModelMigrationManager::migratePrompt(const QString& originalPrompt, ModelType sourceModel, ModelType targetModel) {
    // Adapt prompt for target model
    QString adapted = originalPrompt;
    if (targetModel == ClaudeHaiku) {
        // Simplify for Haiku
        adapted = "Concise: " + originalPrompt;
    } else if (targetModel == ClaudeOpus4) {
        // Enhance for Opus
        adapted = "Detailed and thorough: " + originalPrompt;
    }
    return adapted;
}

QJsonObject ModelMigrationManager::migrateConfiguration(const QString& versionId) {
    auto version = m_versions.value(versionId);
    return version.settings;
}

QString ModelMigrationManager::getAdaptedBehavior(const QString& feature) {
    return QString("Adapted behavior for %1").arg(feature);
}

bool ModelMigrationManager::checkBackwardCompatibility(const QString& fromVersion, const QString& toVersion) {
    auto from = m_versions.value(fromVersion);
    auto to = m_versions.value(toVersion);
    return from.breakingChanges.isEmpty() || to.deprecatedFeatures.isEmpty();
}

QStringList ModelMigrationManager::getBreakingChanges(const QString& version) {
    return m_versions.value(version).breakingChanges;
}

QStringList ModelMigrationManager::getDeprecationWarnings() {
    QStringList warnings;
    for (const auto& version : m_versions.values()) {
        if (version.isDeprecated) {
            warnings.append(version.versionId);
        }
    }
    return warnings;
}

ModelMigrationManager::ModelPerformance ModelMigrationManager::getModelPerformance(ModelType model) {
    ModelPerformance perf;
    perf.model = model;
    perf.avgResponseTimeMs = 500;
    perf.costEfficiency = 0.85f;
    perf.successRate = 95;
    perf.reliabilityScore = 98;
    return perf;
}

ModelMigrationManager::ModelType ModelMigrationManager::suggestBestModelForTask(const QString& taskDescription) {
    // Return best model based on task
    return ClaudeOpus4;
}

void ModelMigrationManager::registerFallbackModel(ModelType primary, ModelType fallback) {
    m_fallbacks[primary] = fallback;
}

ModelMigrationManager::ModelType ModelMigrationManager::getFallbackModel(ModelType model) {
    return m_fallbacks.value(model, ClaudeHaiku);
}

bool ModelMigrationManager::switchToFallback() {
    auto fallback = getFallbackModel(m_currentModel);
    if (m_capabilities.contains(fallback)) {
        setCurrentModel(fallback);
        return true;
    }
    return false;
}

ModelMigrationManager::MigrationStats ModelMigrationManager::getStatistics() {
    return m_stats;
}
