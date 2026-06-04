#include "services/ThemeManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>

ThemeManager* g_themeManager = nullptr;

ThemeManager* ThemeManager::instance()
{
    if (!g_themeManager) {
        g_themeManager = new ThemeManager();
    }
    return g_themeManager;
}

ThemeManager::ThemeManager()
{
    initializeBuiltInThemes();
    m_currentTheme = m_themes["dark"];
}

void ThemeManager::initializeBuiltInThemes()
{
    // Dark theme
    Theme darkTheme;
    darkTheme.id = "dark";
    darkTheme.name = "Dark";
    darkTheme.isDark = true;
    darkTheme.editorColors["background"] = QColor("#1e1e1e");
    darkTheme.editorColors["foreground"] = QColor("#d4d4d4");
    darkTheme.editorColors["lineNumber"] = QColor("#858585");
    darkTheme.editorColors["selection"] = QColor("#094771");
    darkTheme.tokenColors["keyword"] = QColor("#569cd6");
    darkTheme.tokenColors["string"] = QColor("#ce9178");
    darkTheme.tokenColors["comment"] = QColor("#6a9955");
    darkTheme.tokenColors["function"] = QColor("#dcdcaa");
    darkTheme.tokenColors["variable"] = QColor("#9cdcfe");
    m_themes["dark"] = darkTheme;
    
    // Light theme
    Theme lightTheme;
    lightTheme.id = "light";
    lightTheme.name = "Light";
    lightTheme.isDark = false;
    lightTheme.editorColors["background"] = QColor("#ffffff");
    lightTheme.editorColors["foreground"] = QColor("#333333");
    lightTheme.editorColors["lineNumber"] = QColor("#757575");
    lightTheme.editorColors["selection"] = QColor("#add6ff");
    lightTheme.tokenColors["keyword"] = QColor("#0000ff");
    lightTheme.tokenColors["string"] = QColor("#a31515");
    lightTheme.tokenColors["comment"] = QColor("#008000");
    lightTheme.tokenColors["function"] = QColor("#795e26");
    lightTheme.tokenColors["variable"] = QColor("#001080");
    m_themes["light"] = lightTheme;
    
    // High contrast theme
    Theme highContrastTheme;
    highContrastTheme.id = "hc-black";
    highContrastTheme.name = "High Contrast";
    highContrastTheme.isDark = true;
    highContrastTheme.editorColors["background"] = QColor("#000000");
    highContrastTheme.editorColors["foreground"] = QColor("#ffffff");
    highContrastTheme.editorColors["lineNumber"] = QColor("#ffffff");
    highContrastTheme.editorColors["selection"] = QColor("#f3f518");
    highContrastTheme.tokenColors["keyword"] = QColor("#00d4ff");
    highContrastTheme.tokenColors["string"] = QColor("#f1f518");
    highContrastTheme.tokenColors["comment"] = QColor("#7fff00");
    highContrastTheme.tokenColors["function"] = QColor("#ffff00");
    m_themes["hc-black"] = highContrastTheme;
}

void ThemeManager::registerTheme(const Theme& theme)
{
    m_themes[theme.id] = theme;
    emit themesUpdated();
}

void ThemeManager::loadThemeFromFile(const QString& filePath)
{
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        file.close();
        
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            Theme theme;
            theme.id = obj["id"].toString();
            theme.name = obj["name"].toString();
            theme.isDark = obj["isDark"].toBool(true);
            
            registerTheme(theme);
            qDebug() << "Theme loaded from:" << filePath;
        }
    } else {
        qWarning() << "Failed to load theme from:" << filePath;
    }
}

Theme ThemeManager::getTheme(const QString& themeId) const
{
    if (m_themes.contains(themeId)) {
        return m_themes[themeId];
    }
    return m_themes.value("dark");
}

QList<Theme> ThemeManager::getAllThemes() const
{
    QList<Theme> themes;
    for (const auto& theme : m_themes) {
        themes.append(theme);
    }
    return themes;
}

void ThemeManager::setCurrentTheme(const QString& themeId)
{
    if (m_themes.contains(themeId)) {
        m_currentTheme = m_themes[themeId];
        applyTheme(m_currentTheme);
        emit themeChanged(m_currentTheme);
        qDebug() << "Theme changed to:" << themeId;
    } else {
        qWarning() << "Theme not found:" << themeId;
    }
}

void ThemeManager::applyTheme(const Theme& theme)
{
    // TODO: Apply theme to QML components
    qDebug() << "Applying theme:" << theme.name;
}
