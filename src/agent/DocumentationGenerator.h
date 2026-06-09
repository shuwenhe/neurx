#pragma once

#include <QString>
#include <QObject>
#include <QJsonObject>
#include <memory>
#include <vector>

/**
 * @class DocumentationGenerator
 * @brief Automatic documentation generation
 */

class DocumentationGenerator : public QObject {
    Q_OBJECT

public:
    enum DocFormat {
        Markdown,
        HTML,
        PDF,
        PlainText,
        Confluence,
        Sphinx
    };

    struct DocumentationConfig {
        QString projectName;
        QString description;
        DocFormat format;
        bool generateTOC;
        bool generateIndex;
        bool includeCodeExamples;
        bool generateAPIReference;
    };

    struct DocumentationSection {
        QString title;
        QString content;
        int level;  // heading level 1-6
        QStringList relatedSections;
    };

    explicit DocumentationGenerator(QObject* parent = nullptr);
    ~DocumentationGenerator();

    void configureDocumentation(const DocumentationConfig& config);
    void addSection(const DocumentationSection& section);
    void addCodeExample(const QString& title, const QString& code, const QString& language);

    QString generateDocumentation();
    QString generateAPIDocumentation(const QStringList& apiEndpoints);
    QString generateUserGuide(const QStringList& topics);
    QString generateTroubleshootingGuide();

    void exportToFile(const QString& filePath);
    void publishToWiki(const QString& wikiURL);

    struct DocumentationStats {
        int totalSections;
        int totalCodeExamples;
        int estimatedReadTimeMinutes;
        int wordCount;
    };
    DocumentationStats getStatistics();

signals:
    void documentationGenerated();
    void exportCompleted(const QString& filePath);

private:
    DocumentationConfig m_config;
    QVector<DocumentationSection> m_sections;
    QVector<QString> m_codeExamples;
};
