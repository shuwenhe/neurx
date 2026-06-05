#include "LanguageClient.h"
#include <QProcess>
#include <QLocalSocket>
#include <QJsonDocument>
#include <QJsonArray>
#include <QMap>

class LanguageClient::Impl {
public:
    QList<LanguageServer> servers;
    QMap<QString, QProcess*> processes;
    QMap<QString, bool> connectionStates;
    
    bool matchesLanguage(const LanguageServer& server, const QString& language) {
        return server.languages.contains(language) || server.languages.contains("*");
    }
};

LanguageClient* LanguageClient::instance() {
    static LanguageClient s_instance;
    return &s_instance;
}

LanguageClient::LanguageClient()
    : m_impl(std::make_unique<Impl>()) {
}

LanguageClient::~LanguageClient() = default;

void LanguageClient::registerLanguageServer(const LanguageServer& server) {
    // Check if already registered
    for (auto& srv : m_impl->servers) {
        if (srv.id == server.id) {
            srv = server;
            return;
        }
    }
    
    m_impl->servers.append(server);
}

void LanguageClient::unregisterLanguageServer(const QString& serverId) {
    disconnect(serverId);
    
    m_impl->servers.erase(
        std::remove_if(m_impl->servers.begin(), m_impl->servers.end(),
                      [&serverId](const LanguageServer& srv) {
                          return srv.id == serverId;
                      }),
        m_impl->servers.end()
    );
}

QList<LanguageServer> LanguageClient::getServers() const {
    return m_impl->servers;
}

LanguageServer LanguageClient::getServerForLanguage(const QString& language) {
    for (const auto& server : m_impl->servers) {
        if (m_impl->matchesLanguage(server, language) && server.enabled) {
            return server;
        }
    }
    return LanguageServer();
}

Hover LanguageClient::requestHover(const QString& filePath, int line, int column) {
    // This would typically send a request to the LSP server
    // For now, return empty hover
    return Hover();
}

QList<CodeAction> LanguageClient::requestCodeActions(const QString& filePath, int line, int column) {
    return QList<CodeAction>();
}

QString LanguageClient::requestDefinition(const QString& filePath, int line, int column) {
    return QString();
}

QStringList LanguageClient::requestReferences(const QString& filePath, int line, int column) {
    return QStringList();
}

QList<Diagnostic> LanguageClient::requestDiagnostics(const QString& filePath) {
    return QList<Diagnostic>();
}

QStringList LanguageClient::requestCompletion(const QString& filePath, int line, int column) {
    return QStringList();
}

QString LanguageClient::requestSignatureHelp(const QString& filePath, int line, int column) {
    return QString();
}

bool LanguageClient::requestRename(const QString& filePath, int line, int column, const QString& newName) {
    return false;
}

QJsonObject LanguageClient::requestFormat(const QString& filePath, int tabSize, bool insertSpaces) {
    return QJsonObject();
}

void LanguageClient::notifyOpen(const QString& filePath, const QString& language,
                               const QString& version, const QString& text) {
    auto server = getServerForLanguage(language);
    if (server.id.isEmpty()) {
        return;
    }
    
    // Send textDocument/didOpen notification
}

void LanguageClient::notifyChange(const QString& filePath, const QString& text) {
    // Send textDocument/didChange notification
}

void LanguageClient::notifyClose(const QString& filePath) {
    // Send textDocument/didClose notification
}

void LanguageClient::notifySave(const QString& filePath) {
    // Send textDocument/didSave notification
}

bool LanguageClient::connect(const LanguageServer& server) {
    if (m_impl->connectionStates.value(server.id, false)) {
        return true;
    }
    
    auto process = new QProcess();
    process->setProgram(server.command);
    process->setArguments(server.args);
    
    process->start();
    if (!process->waitForStarted()) {
        delete process;
        emit serverError(server.id, "Failed to start language server");
        return false;
    }
    
    m_impl->processes[server.id] = process;
    m_impl->connectionStates[server.id] = true;
    
    emit serverConnected(server.id);
    return true;
}

void LanguageClient::disconnect(const QString& serverId) {
    auto it = m_impl->processes.find(serverId);
    if (it != m_impl->processes.end()) {
        auto process = it.value();
        process->terminate();
        if (!process->waitForFinished(3000)) {
            process->kill();
        }
        delete process;
        m_impl->processes.erase(it);
    }
    
    m_impl->connectionStates[serverId] = false;
    emit serverDisconnected(serverId);
}

bool LanguageClient::isConnected(const QString& serverId) const {
    return m_impl->connectionStates.value(serverId, false);
}
