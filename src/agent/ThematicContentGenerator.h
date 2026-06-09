#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QDateTime>
#include <QJsonObject>
#include <QMap>
#include <QVector>
#include <memory>
#include <vector>

/**
 * @class ThematicContentGenerator
 * @brief Thematic content generation and adaptation
 */

class ThematicContentGenerator : public QObject {
    Q_OBJECT

public:
    enum ContentTheme {
        Technical,
        Educational,
        Creative,
        Business,
        Casual,
        Formal,
        Humorous,
        Inspirational
    };

    enum ContentType {
        Explanation,
        Tutorial,
        Guide,
        Documentation,
        BlogPost,
        CodeComment,
        NewsArticle,
        Feedback
    };

    struct ContentTemplate {
        QString id;
        ContentType type;
        ContentTheme theme;
        QString template_text;
        QStringList variablePlaceholders;
    };

    struct GeneratedContent {
        QString id;
        ContentType type;
        ContentTheme theme;
        QString content;
        float qualityScore;
        QDateTime generatedAt;
    };

    explicit ThematicContentGenerator(QObject* parent = nullptr);
    ~ThematicContentGenerator();

    void registerTemplate(const ContentTemplate& template_);
    QString generateContent(ContentType type, ContentTheme theme, const QJsonObject& context);
    QString adaptContent(const QString& originalContent, ContentTheme targetTheme);

    QVector<GeneratedContent> getGenerationHistory();
    float assessContentQuality(const QString& content);

    struct ThemeCharacteristics {
        ContentTheme theme;
        QStringList keyTerms;
        QString tone;
        float formality;  // 0-1.0
        QStringList preferredStructures;
    };
    QVector<ThemeCharacteristics> getThemeCharacteristics();

signals:
    void contentGenerated(const GeneratedContent& content);
    void templateRegistered(const QString& templateId);

private:
    QMap<QString, ContentTemplate> m_templates;
    QVector<GeneratedContent> m_generationHistory;
};
