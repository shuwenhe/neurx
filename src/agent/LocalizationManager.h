#pragma once

#include <QString>
#include <QObject>
#include <QMap>
#include <memory>

/**
 * @class LocalizationManager
 * @brief Multi-language support and localization
 */

class LocalizationManager : public QObject {
    Q_OBJECT

public:
    struct LocaleInfo {
        QString locale;
        QString language;
        QString country;
        QString nativeLanguage;
    };

    explicit LocalizationManager(QObject* parent = nullptr);
    ~LocalizationManager();

    void registerLocale(const LocaleInfo& locale);
    void setCurrentLocale(const QString& locale);
    QString getCurrentLocale() const;
    QString translate(const QString& key, const QString& context = "");
    QString formatNumber(double value);
    QString formatCurrency(double value, const QString& currencyCode);
    QString formatDate(const QString& date, const QString& format);

signals:
    void localeChanged(const QString& locale);
    void translationsLoaded();

private:
    QString m_currentLocale;
    QMap<QString, LocaleInfo> m_locales;
    QMap<QString, QMap<QString, QString>> m_translations;
};
