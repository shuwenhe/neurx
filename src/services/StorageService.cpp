#include "StorageService.h"
#include <QStandardPaths>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDebug>

class StorageService::Impl {
public:
    QJsonObject globalStorage;
    QJsonObject workspaceStorage;
    QJsonObject sessionStorage;
    QString workspacePath;
    
    QString getStoragePath(StorageScope scope) {
        switch (scope) {
            case Global:
                return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) 
                       + "/storage/global.json";
            case Workspace:
                if (!workspacePath.isEmpty()) {
                    return workspacePath + "/.vscode/storage.json";
                }
                return QString();
            case Session:
                return QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                       + "/neurx_session_storage.json";
            case Temporary:
            default:
                return QString();
        }
    }
    
    void ensurePath(const QString& filePath) {
        QFileInfo fileInfo(filePath);
        QDir().mkpath(fileInfo.absolutePath());
    }
};

StorageService* StorageService::instance() {
    static StorageService s_instance;
    return &s_instance;
}

StorageService::StorageService()
    : m_impl(std::make_unique<Impl>()) {
    // Load global storage on startup
    auto globalPath = m_impl->getStoragePath(Global);
    if (!globalPath.isEmpty()) {
        loadFromFile(globalPath, Global);
    }
}

StorageService::~StorageService() = default;

QVariant StorageService::get(const QString& key, const QVariant& defaultValue, StorageScope scope) {
    QJsonObject* storage = nullptr;
    
    switch (scope) {
        case Global:
            storage = &m_impl->globalStorage;
            break;
        case Workspace:
            storage = &m_impl->workspaceStorage;
            break;
        case Session:
            storage = &m_impl->sessionStorage;
            break;
        case Temporary:
        default:
            return defaultValue;
    }
    
    if (storage->contains(key)) {
        return storage->value(key).toVariant();
    }
    return defaultValue;
}

void StorageService::set(const QString& key, const QVariant& value, StorageScope scope) {
    QJsonObject* storage = nullptr;
    
    switch (scope) {
        case Global:
            storage = &m_impl->globalStorage;
            break;
        case Workspace:
            storage = &m_impl->workspaceStorage;
            break;
        case Session:
            storage = &m_impl->sessionStorage;
            break;
        case Temporary:
        default:
            return;
    }
    
    storage->insert(key, QJsonValue::fromVariant(value));
    emit storageChanged(key, value, scope);
    
    // Auto-save global and workspace storage
    if (scope == Global || scope == Workspace) {
        auto path = m_impl->getStoragePath(scope);
        if (!path.isEmpty()) {
            saveToFile(path, scope);
        }
    }
}

bool StorageService::has(const QString& key, StorageScope scope) const {
    switch (scope) {
        case Global:
            return m_impl->globalStorage.contains(key);
        case Workspace:
            return m_impl->workspaceStorage.contains(key);
        case Session:
            return m_impl->sessionStorage.contains(key);
        case Temporary:
        default:
            return false;
    }
}

void StorageService::remove(const QString& key, StorageScope scope) {
    switch (scope) {
        case Global:
            m_impl->globalStorage.remove(key);
            saveToFile(m_impl->getStoragePath(Global), scope);
            break;
        case Workspace:
            m_impl->workspaceStorage.remove(key);
            saveToFile(m_impl->getStoragePath(Workspace), scope);
            break;
        case Session:
            m_impl->sessionStorage.remove(key);
            break;
        case Temporary:
        default:
            break;
    }
}

void StorageService::clear(StorageScope scope) {
    switch (scope) {
        case Global:
            m_impl->globalStorage = QJsonObject();
            break;
        case Workspace:
            m_impl->workspaceStorage = QJsonObject();
            break;
        case Session:
            m_impl->sessionStorage = QJsonObject();
            break;
        case Temporary:
        default:
            break;
    }
    emit storageCleared(scope);
}

QJsonObject StorageService::getAll(StorageScope scope) const {
    switch (scope) {
        case Global:
            return m_impl->globalStorage;
        case Workspace:
            return m_impl->workspaceStorage;
        case Session:
            return m_impl->sessionStorage;
        case Temporary:
        default:
            return QJsonObject();
    }
}

void StorageService::loadFromJson(const QJsonObject& obj, StorageScope scope) {
    switch (scope) {
        case Global:
            m_impl->globalStorage = obj;
            break;
        case Workspace:
            m_impl->workspaceStorage = obj;
            break;
        case Session:
            m_impl->sessionStorage = obj;
            break;
        case Temporary:
        default:
            break;
    }
}

bool StorageService::loadFromFile(const QString& filePath, StorageScope scope) {
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();
    
    if (!doc.isObject()) {
        return false;
    }
    
    loadFromJson(doc.object(), scope);
    return true;
}

bool StorageService::saveToFile(const QString& filePath, StorageScope scope) {
    if (filePath.isEmpty()) {
        return false;
    }
    
    m_impl->ensurePath(filePath);
    
    QJsonDocument doc(getAll(scope));
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
    return true;
}

QString StorageService::globalStoragePath() const {
    return m_impl->getStoragePath(Global);
}

QString StorageService::workspaceStoragePath(const QString& workspacePath) const {
    return workspacePath + "/.vscode/storage.json";
}

QString StorageService::sessionStoragePath() const {
    return m_impl->getStoragePath(Session);
}

int StorageService::storageSize(StorageScope scope) const {
    return getAll(scope).size();
}

QStringList StorageService::keys(StorageScope scope) const {
    return getAll(scope).keys();
}
