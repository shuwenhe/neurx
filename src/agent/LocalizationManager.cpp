#include "LocalizationManager.h"
#include <QDebug>

LocalizationManager::LocalizationManager(QObject* parent)
    : QObject(parent), m_currentLocale("en_US") {
}

LocalizationManager::~LocalizationManager() {
}

void LocalizationManager::registerLocale(const LocaleInfo& locale) {
    m_locales[locale.locale] = locale;
}

void LocalizationManager::setCurrentLocale(const QString& locale) {
    if (m_locales.contains(locale)) {
        m_currentLocale = locale;
        emit localeChanged(locale);
    }
}

QString LocalizationManager::getCurrentLocale() const {
    return m_currentLocale;
}

QString LocalizationManager::translate(const QString& key, const QString& context) {
    if (m_translations.contains(m_currentLocale)) {
        return m_translations[m_currentLocale].value(key, key);
    }
    return key;
}

QString LocalizationManager::formatNumber(double value) {
    return QString::number(value);
}

QString LocalizationManager::formatCurrency(double value, const QString& currencyCode) {
    return QString("%1 %2").arg(currencyCode).arg(value);
}

QString LocalizationManager::formatDate(const QString& date, const QString& format) {
    return date;
}
