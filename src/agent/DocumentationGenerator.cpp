#include "DocumentationGenerator.h"
#include <QDebug>
#include <QFile>

DocumentationGenerator::DocumentationGenerator(QObject* parent)
    : QObject(parent) {
}

DocumentationGenerator::~DocumentationGenerator() {
}

void DocumentationGenerator::configureDocumentation(const DocumentationConfig& config) {
    m_config = config;
}

void DocumentationGenerator::addSection(const DocumentationSection& section) {
    m_sections.append(section);
}

void DocumentationGenerator::addCodeExample(const QString& title, const QString& code, const QString& language) {
    m_codeExamples.append(QString("%1 [%2]\n%3").arg(title, language, code));
}

QString DocumentationGenerator::generateDocumentation() {
    QString doc = QString("# %1\n\n%2\n\n").arg(m_config.projectName, m_config.description);
    
    for (const auto& section : m_sections) {
        for (int i = 0; i < section.level; ++i) {
            doc += "#";
        }
        doc += QString(" %1\n\n%2\n\n").arg(section.title, section.content);
    }
    
    emit documentationGenerated();
    return doc;
}

QString DocumentationGenerator::generateAPIDocumentation(const QStringList& apiEndpoints) {
    QString doc = "# API Reference\n\n";
    for (const auto& endpoint : apiEndpoints) {
        doc += QString("## %1\n\n").arg(endpoint);
    }
    return doc;
}

QString DocumentationGenerator::generateUserGuide(const QStringList& topics) {
    QString guide = "# User Guide\n\n";
    for (const auto& topic : topics) {
        guide += QString("## %1\n\n").arg(topic);
    }
    return guide;
}

QString DocumentationGenerator::generateTroubleshootingGuide() {
    return "# Troubleshooting Guide\n\n";
}

void DocumentationGenerator::exportToFile(const QString& filePath) {
    QString doc = generateDocumentation();
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(doc.toUtf8());
        file.close();
        emit exportCompleted(filePath);
    }
}

void DocumentationGenerator::publishToWiki(const QString& wikiURL) {
    qDebug() << "Publishing to wiki:" << wikiURL;
}

DocumentationGenerator::DocumentationStats DocumentationGenerator::getStatistics() {
    DocumentationStats stats;
    stats.totalSections = m_sections.size();
    stats.totalCodeExamples = m_codeExamples.size();
    stats.estimatedReadTimeMinutes = m_sections.size() * 2;
    stats.wordCount = 0;
    for (const auto& section : m_sections) {
        stats.wordCount += section.content.split(" ").size();
    }
    return stats;
}
