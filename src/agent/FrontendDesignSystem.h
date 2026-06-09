#pragma once

#include <QString>
#include <QStringList>
#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <memory>
#include <map>

/**
 * @class FrontendDesignSystem
 * @brief Premium frontend design guidance and patterns
 * 
 * Features:
 * - Design system creation and management
 * - Color palette management
 * - Typography system
 * - Component library
 * - Animation guidelines
 * - Responsive design patterns
 * - Accessibility guidance
 * - Design tokens management
 */

class FrontendDesignSystem : public QObject {
    Q_OBJECT

public:
    enum DesignSystem {
        MaterialDesign,
        AppleHIG,
        Fluent,
        Bootstrap,
        Tailwind,
        Custom
    };

    struct ColorPalette {
        QString name;
        QMap<QString, QString> colors;  // name -> hex
        QString primaryColor;
        QString accentColor;
        QStringList themeVariants;
        bool isDarkMode;
    };

    struct TypographySystem {
        QString fontFamily;
        QMap<QString, int> fontSizes;    // heading1, body, etc.
        QMap<QString, int> fontWeights;
        QMap<QString, float> lineHeights;
        int baseLineHeight;
    };

    struct DesignToken {
        QString key;
        QString value;
        QString category;  // color, spacing, font, etc.
        QString description;
        bool isGlobal;
    };

    struct ComponentSpec {
        QString name;
        QString description;
        QStringList variants;
        QStringList states;  // normal, hover, active, disabled
        QString designFilePath;
        QJsonObject designTokens;
    };

    explicit FrontendDesignSystem(QObject* parent = nullptr);
    ~FrontendDesignSystem();

    // Design system management
    void createDesignSystem(DesignSystem system);
    void customizeDesignSystem(const QString& name);
    QString exportDesignSystem(DesignSystem system);
    bool importDesignSystem(const QString& filepath);

    // Color management
    void defineColorPalette(const ColorPalette& palette);
    ColorPalette getColorPalette() const;
    QString getColorByName(const QString& name);
    QStringList suggestContrastingColor(const QString& color);
    bool validateColorAccessibility(const QString& foreground, const QString& background);

    // Typography
    void defineTypographySystem(const TypographySystem& system);
    TypographySystem getTypographySystem() const;
    QString getTypographyCSS();
    QJsonObject getTypographyTokens();

    // Design tokens
    void registerDesignToken(const DesignToken& token);
    DesignToken getDesignToken(const QString& key);
    QVector<DesignToken> getAllDesignTokens();
    QVector<DesignToken> getTokensByCategory(const QString& category);
    QString generateTokensFile(const QString& format);  // JSON, CSS, SCSS, etc.

    // Component library
    void registerComponent(const ComponentSpec& component);
    ComponentSpec getComponent(const QString& name);
    QVector<ComponentSpec> getAllComponents();
    QStringList getComponentsByCategory(const QString& category);

    // Design patterns
    QStringList getResponsiveBreakpoints();
    QJsonObject getAnimationGuidelines();
    QStringList getAccessibilityGuidelines();
    QString generateAccessibilityReport();

    // Code generation
    QString generateComponentCode(const QString& componentName, const QString& framework);
    QString generateCSSFromDesignTokens();
    QString generateTailwindConfig();

    // Brand consistency
    struct BrandGuidelines {
        QString brandName;
        QStringList fontFamilies;
        QStringList approvedColors;
        QStringList logoVariants;
        QString brandVoice;
        QStringList useCases;
    };
    void setBrandGuidelines(const BrandGuidelines& guidelines);
    BrandGuidelines getBrandGuidelines() const;
    bool validateBrandCompliance(const QString& design);

    // Theme management
    void createTheme(const QString& themeName, const ColorPalette& palette);
    void switchTheme(const QString& themeName);
    QStringList getAvailableThemes();
    QString exportThemeAsCSS(const QString& themeName);

    // Statistics
    struct DesignStats {
        int totalComponents;
        int totalTokens;
        int colorCount;
        int fontCount;
        float brandCompliance;
    };
    DesignStats getStatistics() const;

signals:
    void designSystemCreated(const QString& name);
    void colorPaletteUpdated();
    void componentRegistered(const QString& componentName);
    void themeChanged(const QString& themeName);

private:
    DesignSystem m_currentSystem;
    ColorPalette m_colorPalette;
    TypographySystem m_typography;
    QMap<QString, DesignToken> m_tokens;
    QMap<QString, ComponentSpec> m_components;
    BrandGuidelines m_brandGuidelines;
    DesignStats m_stats;

    bool validateColorFormat(const QString& color);
};
