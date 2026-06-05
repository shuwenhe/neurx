#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QJsonObject>
#include <functional>

/**
 * @class LanguageClient
 * @brief LSP (Language Server Protocol) client
 * 
 * Features:
 * - Language server communication
 * - Semantic tokens
 * - Hover information
 * - Code actions
 * - Refactoring
 */

struct LanguageServer {
    QString id;
    QString name;
    QString command;
    QStringList args;
    QStringList languages;
    QJsonObject capabilities;
    bool enabled = true;
};

struct Hover {
    QString contents;
    QString markedString;
};

struct CodeAction {
    QString title;
    QString kind;
    QJsonObject edit;
    std::function<void()> command;
};

struct Diagnostic {
    int line = 0;
    int column = 0;
    int endLine = 0;
    int endColumn = 0;
    QString message;
    int severity = 0;  // 1=Error, 2=Warning, 3=Information, 4=Hint
    QString source;
    QString code;
};

class LanguageClient : public QObject {
    Q_OBJECT

public:
    static LanguageClient* instance();
    
    // Server management
    void registerLanguageServer(const LanguageServer& server);
    void unregisterLanguageServer(const QString& serverId);
    QList<LanguageServer> getServers() const;
    LanguageServer getServerForLanguage(const QString& language);
    
    // Language features
    Hover requestHover(const QString& filePath, int line, int column);
    QList<CodeAction> requestCodeActions(const QString& filePath, int line, int column);
    QString requestDefinition(const QString& filePath, int line, int column);
    QStringList requestReferences(const QString& filePath, int line, int column);
    QList<Diagnostic> requestDiagnostics(const QString& filePath);
    
    // Completion
    QStringList requestCompletion(const QString& filePath, int line, int column);
    QString requestSignatureHelp(const QString& filePath, int line, int column);
    
    // Refactoring
    bool requestRename(const QString& filePath, int line, int column, const QString& newName);
    QJsonObject requestFormat(const QString& filePath, int tabSize = 4, bool insertSpaces = true);
    
    // Document sync
    void notifyOpen(const QString& filePath, const QString& language, const QString& version, const QString& text);
    void notifyChange(const QString& filePath, const QString& text);
    void notifyClose(const QString& filePath);
    void notifySave(const QString& filePath);
    
    // Connection management
    bool connect(const LanguageServer& server);
    void disconnect(const QString& serverId);
    bool isConnected(const QString& serverId) const;

signals:
    void serverConnected(const QString& serverId);
    void serverDisconnected(const QString& serverId);
    void diagnosticsPublished(const QString& filePath, const QList<Diagnostic>& diagnostics);
    void completionAvailable(const QString& filePath);
    void serverError(const QString& serverId, const QString& error);

private:
    LanguageClient();
    ~LanguageClient() override;
    
    class Impl;
    std::unique_ptr<class Impl> m_impl;
};
