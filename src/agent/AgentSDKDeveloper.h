#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <memory>

/**
 * @class AgentSDKDeveloper
 * @brief Specialized agent SDK development and generation
 * 
 * Features:
 * - Multi-language SDK generation
 * - API contract generation
 * - SDK documentation generation
 * - Example code generation
 * - Test suite scaffolding
 * - SDK versioning
 * - Backward compatibility management
 */

class AgentSDKDeveloper : public QObject {
    Q_OBJECT

public:
    enum SDKLanguage {
        Python,
        JavaScript,
        TypeScript,
        Java,
        CSharp,
        Golang,
        Rust,
        Cpp
    };

    enum DocumentationStyle {
        Minimal,
        Standard,
        Comprehensive,
        Academic
    };

    struct APIContract {
        QString endpoint;
        QString method;  // GET, POST, PUT, DELETE
        QJsonObject requestSchema;
        QJsonObject responseSchema;
        QStringList requiredHeaders;
        QStringList errorCodes;
        QString description;
    };

    struct SDKConfig {
        QString name;
        QString version;
        QString description;
        QStringList supportedLanguages;
        QString baseURL;
        QString authType;  // "api_key", "oauth2", "bearer"
        int rateLimit;
        bool includeWebhooks;
    };

    struct GeneratedSDK {
        SDKLanguage language;
        QString baseDir;
        QStringList files;
        QString README;
        QString examples;
        QString tests;
        QString changelog;
    };

    struct CodeExample {
        QString title;
        QString description;
        QString code;
        SDKLanguage language;
        QStringList tags;
    };

    explicit AgentSDKDeveloper(QObject* parent = nullptr);
    ~AgentSDKDeveloper();

    // SDK configuration
    void configureSDK(const SDKConfig& config);
    SDKConfig getSDKConfig();

    // API contract management
    void addAPIEndpoint(const APIContract& contract);
    APIContract getAPIEndpoint(const QString& endpoint);
    QVector<APIContract> getAllEndpoints();

    // SDK generation
    GeneratedSDK generateSDK(SDKLanguage language);
    QString generateSDKForLanguage(SDKLanguage language, const QString& outputDir);

    // Code generation
    QString generateClientCode(SDKLanguage language);
    QString generateAuthenticationCode(SDKLanguage language);
    QString generateErrorHandlingCode(SDKLanguage language);
    QString generateRetryLogicCode(SDKLanguage language);

    // Documentation generation
    QString generateAPIDocumentation();
    QString generateSDKDocumentation(DocumentationStyle style);
    QString generateInstallationGuide(SDKLanguage language);
    QString generateQuickstartGuide(SDKLanguage language);

    // Example code generation
    void addCodeExample(const CodeExample& example);
    QVector<CodeExample> getCodeExamples();
    QString getCodeExample(const QString& title, SDKLanguage language);
    void generateExamplesForAllEndpoints();

    // Test suite generation
    QString generateUnitTests(SDKLanguage language);
    QString generateIntegrationTests(SDKLanguage language);
    QString generateTestFixtures();

    // Versioning and compatibility
    void createNewVersion(const QString& version);
    void addBreakingChange(const QString& description);
    void addDeprecation(const QString& feature, const QString& replacement);
    QString generateMigrationGuide(const QString& fromVersion, const QString& toVersion);

    // SDK distribution
    struct SDKPackage {
        QString name;
        QString version;
        QString language;
        QString packageManager;  // npm, pip, maven, etc.
        QString distributionURL;
        int downloadCount;
    };
    SDKPackage generatePackageConfig(SDKLanguage language);
    QString generatePackageJSON(SDKLanguage language);
    QString generateSetupPy();

    // Webhook generation
    QString generateWebhookHandler(SDKLanguage language);
    QString generateWebhookTypes();

    // Performance and monitoring
    struct PerformanceMetrics {
        QString version;
        float avgResponseTime;
        int errorRate;  // percentage
        int uptime;  // percentage
    };
    PerformanceMetrics getPerformanceMetrics();

    // Validation and compliance
    bool validateSDK();
    bool validateAPIContracts();
    QStringList getValidationErrors();
    bool checkBackwardCompatibility(const QString& withVersion);

    // Analytics
    struct SDKAnalytics {
        int downloadsThisMonth;
        int activeUsers;
        float satisfactionRating;  // 0-5
        QMap<SDKLanguage, int> languageUsage;
    };
    SDKAnalytics getAnalytics();

signals:
    void sdkConfigured();
    void endpointAdded(const QString& endpoint);
    void sdkGenerationStarted(SDKLanguage language);
    void sdkGenerationCompleted(const GeneratedSDK& sdk);
    void documentationGenerated();
    void versionCreated(const QString& version);

private:
    SDKConfig m_config;
    QMap<QString, APIContract> m_endpoints;
    QVector<CodeExample> m_examples;
    QStringList m_validationErrors;
    QMap<SDKLanguage, GeneratedSDK> m_generatedSDKs;

    void initializeDefaultExamples();
    QString generateLanguageSpecificCode(SDKLanguage language, const QString& template_);
};
