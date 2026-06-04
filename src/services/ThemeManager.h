#pragma once

#include <QObject>
#include <QString>
#include <QColor>
#include <QMap>

/**
 * @class ThemeManager
 * @brief Manages editor themes
 * 
 * Features:
 * - Built-in themes
 * - Custom theme loading
 * - Dynamic theme switching
 * - Theme persistence
 */

struct Theme {
    QString id;
    QString name;
    QString description;
    bool isDark;
    
    QMap<QString, QColor> tokenColors;
    QMap<QString, QColor> editorColors;
};

class ThemeManager : public QObject {
    Q_OBJECT

public:
    static ThemeManager* instance();
    
    // Theme management
    void registerTheme(const Theme& theme);
    void loadThemeFromFile(const QString& filePath);
    
    // Query
    Theme getTheme(const QString& themeId) const;
    QList<Theme> getAllThemes() const;
    Theme currentTheme() const { return m_currentTheme; }
    
    // Theme switching
    void setCurrentTheme(const QString& themeId);
    void applyTheme(const Theme& theme);

signals:
    void themeChanged(const Theme& theme);
    void themesUpdated();

private:
    ThemeManager();
    ~ThemeManager() override = default;
    
    Q_DISABLE_COPY_MOVE(ThemeManager)
    
    QMap<QString, Theme> m_themes;
    Theme m_currentTheme;
    
    void initializeBuiltInThemes();
};
