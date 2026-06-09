#include "ThematicContentGenerator.h"
#include <QDebug>
#include <QDateTime>

ThematicContentGenerator::ThematicContentGenerator(QObject* parent)
    : QObject(parent) {
}

ThematicContentGenerator::~ThematicContentGenerator() {
}

void ThematicContentGenerator::registerTemplate(const ContentTemplate& template_) {
    m_templates[template_.id] = template_;
    emit templateRegistered(template_.id);
}

QString ThematicContentGenerator::generateContent(ContentType type, ContentTheme theme, const QJsonObject& context) {
    QString content = "Generated content for ";
    content += QString::number(static_cast<int>(type));
    content += " theme ";
    content += QString::number(static_cast<int>(theme));
    
    GeneratedContent gen;
    gen.id = QString::number(QDateTime::currentMSecsSinceEpoch());
    gen.type = type;
    gen.theme = theme;
    gen.content = content;
    gen.qualityScore = 0.85f;
    gen.generatedAt = QDateTime::currentDateTime();
    
    m_generationHistory.append(gen);
    emit contentGenerated(gen);
    
    return content;
}

QString ThematicContentGenerator::adaptContent(const QString& originalContent, ContentTheme targetTheme) {
    QString adapted = originalContent;
    
    switch (targetTheme) {
    case Technical:
        adapted = "Technical: " + adapted;
        break;
    case Educational:
        adapted = "Educational explanation: " + adapted;
        break;
    case Creative:
        adapted = "Creative perspective: " + adapted;
        break;
    default:
        break;
    }
    
    return adapted;
}

QVector<ThematicContentGenerator::GeneratedContent> ThematicContentGenerator::getGenerationHistory() {
    return m_generationHistory;
}

float ThematicContentGenerator::assessContentQuality(const QString& content) {
    float score = 0.8f;
    if (content.length() > 1000) score += 0.05f;
    if (content.contains("example")) score += 0.1f;
    return score > 1.0f ? 1.0f : score;
}

QVector<ThematicContentGenerator::ThemeCharacteristics> ThematicContentGenerator::getThemeCharacteristics() {
    QVector<ThemeCharacteristics> themes;
    
    ThemeCharacteristics tech;
    tech.theme = Technical;
    tech.tone = "Professional";
    tech.formality = 0.9f;
    themes.append(tech);
    
    ThemeCharacteristics edu;
    edu.theme = Educational;
    edu.tone = "Instructive";
    edu.formality = 0.7f;
    themes.append(edu);
    
    return themes;
}
