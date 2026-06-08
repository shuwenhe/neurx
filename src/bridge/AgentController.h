#pragma once
#include <QObject>
#include <QVariant>
#include <QVariantList>
#include <QJsonObject>
#include <QAbstractListModel>
#include <QVector>
#include <QSettings>
#include <QDateTime>
#include "agent/AgentEngine.h"
#include "agent/TaskSession.h"
#include "agent/AgentToolRegistry.h"
#include "llm/LLMProvider.h"
#include "code/DefaultCodeMagic.h"
#include "context/WorkspaceContext.h"
#include "context/WorkspaceIndex.h"
#include "skills/ClaudeSkillManager.h"
#include "sandbox/DefaultSandboxManager.h"
#include "approvals/DefaultApprovalManager.h"
#include "thread/store/FileBasedThreadStore.h"
#include "thread/ThreadId.h"
#include "tools/ReminderTool.h"

// VS Code Integration Services
#include "services/NotificationService.h"
#include "services/ProgressService.h"
#include "services/StorageService.h"
#include "services/FileService.h"
#include "services/WorkspaceService.h"
#include "services/SearchService.h"
#include "services/TasksManager.h"
#include "services/TerminalService.h"
#include "services/DebugSession.h"
#include "services/KeyBindingManager.h"
#include "workbench/QuickAccessManager.h"
#include "languages/LanguageClient.h"
#include "languages/GitService.h"

// Phase 2: Advanced Features
#include "features/FeatureProviders.h"
#include "features/NavigationProviders.h"
#include "features/EditingProviders.h"

// Phase 3 & Beyond: Extended Editor Features
#include "editor/FindAndReplace.h"
#include "editor/FoldingManager.h"
#include "editor/SnippetManager.h"
#include "editor/CommentManager.h"
#include "editor/BracketMatcher.h"
#include "editor/CaseConverter.h"
#include "editor/EditorHistory.h"
#include "editor/GoToDefinition.h"
#include "editor/InlineRename.h"
#include "editor/LineOperations.h"
#include "editor/MultiCursor.h"
#include "editor/OutlineProvider.h"
#include "editor/SelectToBracket.h"
#include "editor/SmartSelection.h"
#include "editor/WordHighlight.h"
#include "editor/WordOperations.h"

class LocalGatewayServer;

// ── ChatMessage (QML-visible model item) ─────────────────────────────────────

struct ChatMessage {
    Q_GADGET
    Q_PROPERTY(QString role    MEMBER role)
    Q_PROPERTY(QString content MEMBER content)
    Q_PROPERTY(bool    thinking MEMBER thinking)
    Q_PROPERTY(QVariantList toolCalls MEMBER toolCalls)
    Q_PROPERTY(QVariantList attachments MEMBER attachments)
public:
    QString      role;       // "user" | "assistant" | "tool"
    QString      content;
    bool         thinking{false};
    QVariantList toolCalls;  // list of QVariantMap{id, name, status, result}
    QVariantList attachments; // list of QVariantMap attachments for multimodal messages
};

// ── ChatModel ─────────────────────────────────────────────────────────────────

class ChatModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { RoleRole = Qt::UserRole, ContentRole, ThinkingRole, ToolCallsRole, AttachmentsRole };

    explicit ChatModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex & = {}) const override { return m_msgs.size(); }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int,QByteArray> roleNames() const override;

    void append(const ChatMessage &msg);
    void updateLastContent(const QString &delta);
    void replaceLast(const ChatMessage &msg);
    void appendToolCallToLastAssistant(const QVariantMap &card);
    void updateToolCall(const QString &callId, const QVariantMap &card);
    void clear();

private:
    QList<ChatMessage> m_msgs;
};

// ── AgentController ───────────────────────────────────────────────────────────
//  The single QML-exposed C++ object. Registered as a singleton context property.

class AgentController : public QObject {
    Q_OBJECT
    Q_PROPERTY(ChatModel*  chatModel       READ chatModel     CONSTANT)
    Q_PROPERTY(QString     currentProvider READ currentProvider WRITE setCurrentProvider NOTIFY currentProviderChanged)
    Q_PROPERTY(QString     currentModel    READ currentModel    WRITE setCurrentModel    NOTIFY currentModelChanged)
    Q_PROPERTY(QStringList providers       READ providers       CONSTANT)
    Q_PROPERTY(QStringList models          READ models          NOTIFY currentProviderChanged)
    Q_PROPERTY(bool        busy            READ busy            NOTIFY busyChanged)
    Q_PROPERTY(QString     workspacePath   READ workspacePath   WRITE setWorkspacePath   NOTIFY workspacePathChanged)
    Q_PROPERTY(QString     workspaceSummary READ workspaceSummary NOTIFY workspaceSummaryChanged)
    Q_PROPERTY(int         workspaceFileCount READ workspaceFileCount NOTIFY workspaceSummaryChanged)
    Q_PROPERTY(QStringList workspaceTopExtensions READ workspaceTopExtensions NOTIFY workspaceSummaryChanged)
    Q_PROPERTY(QStringList workspaceRecentFiles READ workspaceRecentFiles NOTIFY workspaceSummaryChanged)
    Q_PROPERTY(QString     anthropicEndpoint READ anthropicEndpoint WRITE setAnthropicEndpoint NOTIFY anthropicEndpointChanged)
    Q_PROPERTY(QString     openaiEndpoint  READ openaiEndpoint  WRITE setOpenaiEndpoint  NOTIFY openaiEndpointChanged)
    Q_PROPERTY(QString     anthropicApiKey  READ anthropicApiKey  WRITE setAnthropicApiKey  NOTIFY anthropicApiKeyChanged)
    Q_PROPERTY(QString     openaiApiKey     READ openaiApiKey     WRITE setOpenaiApiKey     NOTIFY openaiApiKeyChanged)
    Q_PROPERTY(QString     geminiApiKey     READ geminiApiKey     WRITE setGeminiApiKey     NOTIFY geminiApiKeyChanged)
    Q_PROPERTY(QString     braveApiKey      READ braveApiKey      WRITE setBraveApiKey      NOTIFY braveApiKeyChanged)
    Q_PROPERTY(QString     currentFilePath READ currentFilePath NOTIFY currentFilePathChanged)
    Q_PROPERTY(QString     currentFileContent READ currentFileContent WRITE setCurrentFileContent NOTIFY currentFileContentChanged)
    Q_PROPERTY(bool        currentFileDirty READ currentFileDirty NOTIFY openFilesChanged)
    Q_PROPERTY(QVariantList openFiles READ openFiles NOTIFY openFilesChanged)
    Q_PROPERTY(bool        autoApproveTools READ autoApproveTools WRITE setAutoApproveTools NOTIFY autoApproveToolsChanged)
    Q_PROPERTY(bool        canUndoWorkspaceAction READ canUndoWorkspaceAction NOTIFY undoWorkspaceActionChanged)
    Q_PROPERTY(QString     streamingText   READ streamingText   NOTIFY streamingTextChanged)
    Q_PROPERTY(QVariantList todoItems READ todoItems NOTIFY todoItemsChanged)
    Q_PROPERTY(QVariantList recentCheckpoints READ recentCheckpoints NOTIFY recentCheckpointsChanged)
    Q_PROPERTY(QVariantList recentSessions READ recentSessions NOTIFY recentSessionsChanged)
    Q_PROPERTY(QStringList recentSlashCommands READ recentSlashCommands NOTIFY recentSlashCommandsChanged)
    Q_PROPERTY(QString currentThreadId READ currentThreadId NOTIFY currentThreadIdChanged)
    Q_PROPERTY(QVariantList executionTimeline READ executionTimeline NOTIFY executionTimelineChanged)
    Q_PROPERTY(QVariantList pendingAttachments READ pendingAttachments NOTIFY pendingAttachmentsChanged)
    Q_PROPERTY(QVariantList localSkills READ localSkills NOTIFY localSkillsChanged)
    Q_PROPERTY(QString currentSelectionPath READ currentSelectionPath NOTIFY currentSelectionChanged)
    Q_PROPERTY(QString currentSelectionText READ currentSelectionText NOTIFY currentSelectionChanged)
    Q_PROPERTY(int currentSelectionStartLine READ currentSelectionStartLine NOTIFY currentSelectionChanged)
    Q_PROPERTY(int currentSelectionEndLine READ currentSelectionEndLine NOTIFY currentSelectionChanged)
    Q_PROPERTY(QVariantMap codeMagicResult READ codeMagicResult NOTIFY codeMagicResultChanged)
    Q_PROPERTY(QString codeMagicTargetLabel READ codeMagicTargetLabel NOTIFY codeMagicResultChanged)
    Q_PROPERTY(QVariantList toolCatalog READ toolCatalog NOTIFY toolCatalogChanged)
    Q_PROPERTY(QStringList mcpToolNames READ mcpToolNames NOTIFY mcpToolsChanged)
    Q_PROPERTY(QVariantList knowledgeSources READ knowledgeSources NOTIFY knowledgeSourcesChanged)
    Q_PROPERTY(QString knowledgeSearchQuery READ knowledgeSearchQuery NOTIFY knowledgeSearchResultsChanged)
    Q_PROPERTY(QVariantList knowledgeSearchResults READ knowledgeSearchResults NOTIFY knowledgeSearchResultsChanged)
    Q_PROPERTY(QVariantList scheduledTasks READ scheduledTasks NOTIFY scheduledTasksChanged)
    Q_PROPERTY(QString localGatewayUrl READ localGatewayUrl NOTIFY localGatewayUrlChanged)

public:
    explicit AgentController(QObject *parent = nullptr);

    ChatModel   *chatModel()         const { return m_chatModel; }
    QString      currentProvider()   const { return m_currentProvider; }
    QString      currentModel()      const { return m_currentModel; }
    QStringList  providers()         const;
    QStringList  models()            const;
    bool         busy()              const { return m_busy; }
    QString      workspacePath()     const { return m_workspacePath; }
    QString      workspaceSummary()  const;
    int          workspaceFileCount() const;
    QStringList  workspaceTopExtensions() const;
    QStringList  workspaceRecentFiles() const;
    QString      anthropicEndpoint()    const { return m_anthropicEndpoint; }
    QString      openaiEndpoint()    const { return m_openaiEndpoint; }
    QString      anthropicApiKey()    const { return m_anthropicApiKey; }
    QString      openaiApiKey()    const { return m_openaiApiKey; }
    QString      geminiApiKey()    const { return m_geminiApiKey; }
    QString      braveApiKey()     const { return m_braveApiKey; }
    QString      currentFilePath()    const { return m_currentFilePath; }
    QString      currentFileContent() const { return m_currentFileContent; }
    bool         currentFileDirty() const;
    QVariantList  openFiles() const;
    bool         autoApproveTools()  const;
    bool         canUndoWorkspaceAction() const;
    QString      streamingText()     const { return m_streamingText; }
    QVariantList todoItems() const;
    QVariantList recentCheckpoints() const;
    QVariantList recentSessions() const;
    QStringList recentSlashCommands() const { return m_recentSlashCommands; }
    QString currentThreadId() const { return m_sessionId; }
    QVariantList executionTimeline() const { return m_executionTimeline; }
    QVariantList pendingAttachments() const { return m_pendingAttachments; }
    QVariantList localSkills() const { return m_localSkills; }
    QString currentSelectionPath() const { return m_selectedFilePath; }
    QString currentSelectionText() const { return m_selectedText; }
    int currentSelectionStartLine() const { return m_selectedStartLine; }
    int currentSelectionEndLine() const { return m_selectedEndLine; }
    QVariantMap codeMagicResult() const { return m_codeMagicResult; }
    QString codeMagicTargetLabel() const { return m_codeMagicTargetLabel; }
    QVariantList toolCatalog() const;
    QStringList mcpToolNames() const { return m_mcpToolNames; }
    QVariantList knowledgeSources() const;
    QString knowledgeSearchQuery() const { return m_knowledgeSearchQuery; }
    QVariantList knowledgeSearchResults() const { return m_knowledgeSearchResults; }
    QVariantList scheduledTasks() const;
    QString localGatewayUrl() const { return m_localGatewayUrl; }

    void setCurrentProvider(const QString &id);
    void setCurrentModel(const QString &model);
    void setWorkspacePath(const QString &path);
    void setAnthropicEndpoint(const QString &url);
    void setOpenaiEndpoint(const QString &url);
    void setAnthropicApiKey(const QString &key);
    void setOpenaiApiKey(const QString &key);
    void setGeminiApiKey(const QString &key);
    void setBraveApiKey(const QString &key);
    void setCurrentFileContent(const QString &text);
    void setAutoApproveTools(bool v);
    Q_INVOKABLE bool attachImageFromPath(const QString &filePath);
    Q_INVOKABLE bool attachImageFromClipboard();
    Q_INVOKABLE void clearPendingAttachments();
    Q_INVOKABLE QStringList searchWorkspacePaths(const QString &needle) const;
    Q_INVOKABLE QVariantList checkpointPreview(const QString &checkpointId) const;
    Q_INVOKABLE QVariantMap analyzeCurrentFileWithCodeMagic();
    Q_INVOKABLE QVariantMap reviewCurrentFileWithCodeMagic();
    Q_INVOKABLE QVariantMap explainCurrentFileWithCodeMagic();
    Q_INVOKABLE void setCurrentSelection(const QString &filePath, const QString &code,
                                        int startLine, int endLine);
    Q_INVOKABLE void clearCurrentSelection();
    Q_INVOKABLE QVariantList discoverTools(const QString &query = QString()) const;
    Q_INVOKABLE QVariantMap toolSchema(const QString &toolName) const;
    Q_INVOKABLE QVariantMap toolPermissionState(const QString &toolName,
                                               const QVariantMap &context = {}) const;
    Q_INVOKABLE QVariantMap executeToolByName(const QString &toolName,
                                              const QVariantMap &arguments = {});
    Q_INVOKABLE QVariantMap delegateToCodex(const QString &task,
                                            const QString &model = QString(),
                                            const QString &workingDir = QString());
    Q_INVOKABLE QVariantMap writeFileWithCodex(const QString &filePath,
                                               const QString &content,
                                               const QString &model = QString(),
                                               const QString &workingDir = QString());
    Q_INVOKABLE QVariantMap toolExecutionStats(const QString &toolName) const;
    Q_INVOKABLE QVariantList toolExecutionHistory(const QString &toolName, int limit = 20) const;
    Q_INVOKABLE QVariantList commandPaletteCommands(const QString &query = QString()) const;
    Q_INVOKABLE bool executeCommand(const QString &commandId);
    Q_INVOKABLE bool openWorkspaceFolder(const QString &path = QString());
    Q_INVOKABLE bool openWorkspaceFile(const QString &path = QString());
    Q_INVOKABLE bool resumeTaskSession(const QString &sessionId);
    Q_INVOKABLE bool forkCurrentThread();
    Q_INVOKABLE bool indexWorkspaceKnowledge();
    Q_INVOKABLE bool indexCurrentFileKnowledge();
    Q_INVOKABLE bool indexRecentFilesKnowledge();
    Q_INVOKABLE QString searchWorkspaceKnowledge(const QString &query);
    Q_INVOKABLE bool removeKnowledgeSource(const QString &path);
    Q_INVOKABLE bool createReminder(const QString &title, int dueInMinutes, int repeatMinutes = 0);
    Q_INVOKABLE bool cancelReminder(const QString &id);

    // VS Code Integration Service Access
    Q_INVOKABLE QString notifyInfo(const QString& message);
    Q_INVOKABLE QString notifyWarning(const QString& message);
    Q_INVOKABLE QString notifyError(const QString& message);
    Q_INVOKABLE QString notifySuccess(const QString& message);
    Q_INVOKABLE bool dismissNotification(const QString& notificationId);

    Q_INVOKABLE QString startProgress(const QString& title);
    Q_INVOKABLE void updateProgress(const QString& progressId, int current);
    Q_INVOKABLE void finishProgress(const QString& progressId);

    Q_INVOKABLE QVariantList searchQuickAccess(const QString& query);
    Q_INVOKABLE bool executeQuickAccessItem(const QString& itemId);

    Q_INVOKABLE QVariantList performSearch(const QString& text, bool useRegex = false);
    Q_INVOKABLE int replaceAllMatches(const QString& searchText, const QString& replacement);

    Q_INVOKABLE QStringList findFilesInWorkspace(const QString& pattern);
    Q_INVOKABLE QStringList getRecentFiles(int maxCount = 20);

    Q_INVOKABLE QStringList getGitStatus();
    Q_INVOKABLE QString getCurrentGitBranch();
    Q_INVOKABLE bool commitGitChanges(const QString& message);
    Q_INVOKABLE bool pushToGit(const QString& remote = "origin");
    Q_INVOKABLE bool pullFromGit(const QString& remote = "origin");

    Q_INVOKABLE QString executeTask(const QString& taskId);
    Q_INVOKABLE bool terminateTask(const QString& executionId);
    Q_INVOKABLE QString getTaskOutput(const QString& executionId);

    Q_INVOKABLE QString createTerminal(const QString& name = QString());
    Q_INVOKABLE QString createTerminalWithPath(const QString& name, const QString& path);
    Q_INVOKABLE void revealInExplorer(const QString& path);
    Q_INVOKABLE void sendTerminalCommand(const QString& terminalId, const QString& command);
    Q_INVOKABLE void closeTerminal(const QString& terminalId);

    Q_INVOKABLE QString startDebugSession(const QString& configuration);
    Q_INVOKABLE void stopDebugSession(const QString& sessionId);
    Q_INVOKABLE bool debugPause(const QString& sessionId);
    Q_INVOKABLE bool debugContinue(const QString& sessionId);
    Q_INVOKABLE bool debugStepOver(const QString& sessionId);
    Q_INVOKABLE bool debugStepInto(const QString& sessionId);
    Q_INVOKABLE bool debugStepOut(const QString& sessionId);
    Q_INVOKABLE QVariantList getDebugStackTrace(const QString& sessionId) const;
    Q_INVOKABLE QVariantList getDebugVariables(const QString& sessionId, int frameId) const;
    Q_INVOKABLE QString evaluateDebugExpression(const QString& sessionId, const QString& expression);
    Q_INVOKABLE bool setDebugBreakpoint(const QString& sessionId, const QString& filePath, int line,
                                        int column = 0, const QString& condition = QString(),
                                        const QString& hitCondition = QString());
    Q_INVOKABLE bool removeDebugBreakpoint(const QString& sessionId, const QString& breakpointId);
    Q_INVOKABLE QVariantList getDebugBreakpoints(const QString& sessionId) const;

    Q_INVOKABLE void registerLanguageServer(const QString& name, const QString& command);
    Q_INVOKABLE QVariantMap requestHover(const QString& filePath, int line, int column);

    Q_INVOKABLE QVariantList getAllKeyBindings() const;
    Q_INVOKABLE QVariantMap getKeyBinding(const QString& commandId) const;
    Q_INVOKABLE bool registerKeyBinding(const QString& commandId, const QString& keys,
                                        const QString& when = QString(),
                                        const QString& description = QString());
    Q_INVOKABLE bool unregisterKeyBinding(const QString& commandId);
    Q_INVOKABLE QVariantList findKeyBindingConflicts(const QString& keys) const;
    Q_INVOKABLE bool resetKeyBindings();
    Q_INVOKABLE bool saveKeyBindings(const QString& filePath) const;
    Q_INVOKABLE bool loadKeyBindings(const QString& filePath);

    // Phase 2: Advanced Features API
    // Basic Editing (Week 1)
    Q_INVOKABLE QString trimTrailingWhitespace(const QString& text);
    Q_INVOKABLE QVariantList formatDocument(const QString& filePath, const QVariantMap& options = {});
    Q_INVOKABLE QVariantMap getTypeDefinition(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantMap goToDeclaration(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantList getPathCompletions(const QString& text, int cursorPosition);

    // Navigation Features (Week 2)
    Q_INVOKABLE QVariantList getBreadcrumbs(const QString& filePath, int line);
    Q_INVOKABLE QVariantList findAllReferences(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantMap getCurrentSymbol(const QString& filePath, int line);
    Q_INVOKABLE QVariantList searchWorkspaceSymbols(const QString& query);
    Q_INVOKABLE bool startFileWatching(const QString& path);
    Q_INVOKABLE bool stopFileWatching(const QString& path);
    Q_INVOKABLE QVariantList getFileChanges();

    // Editing Enhancement Features
    Q_INVOKABLE QVariantList getInlineCompletions(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantMap getParameterHints(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantList getCodeActions(const QString& filePath, int line, int column);
    Q_INVOKABLE bool applyCodeAction(const QString& filePath, const QVariantMap& action);
    Q_INVOKABLE QVariantList getSemanticTokens(const QString& filePath);
    Q_INVOKABLE QVariantList getSemanticTokensRange(const QString& filePath, int startLine, int endLine);
    Q_INVOKABLE QVariantList getLinkedEditingRanges(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantList searchWorkspace(const QString& pattern, const QVariantMap& options = {});
    Q_INVOKABLE int replaceInWorkspace(const QString& pattern, const QString& replacement, const QVariantMap& options = {});

    // Phase 3 & Beyond: Extended Editor Features API
    // Find & Replace
    Q_INVOKABLE QVariantList findMatches(const QString& query, const QJsonObject& options);
    Q_INVOKABLE QVariantMap findNext(const QString& query, int currentLine, int currentColumn);
    Q_INVOKABLE QVariantMap findPrevious(const QString& query, int currentLine, int currentColumn);
    Q_INVOKABLE int replaceAll(const QString& pattern, const QString& replacement);
    Q_INVOKABLE bool replaceSingle(const QString& pattern, const QString& replacement, int line, int column);

    // Code Folding
    Q_INVOKABLE QVariantList computeFoldRanges(const QString& code, const QString& language);
    Q_INVOKABLE void toggleFold(int line);
    Q_INVOKABLE void foldAll();
    Q_INVOKABLE void unfoldAll();
    Q_INVOKABLE void foldLevel(int level);

    // Snippets
    Q_INVOKABLE QVariantList getSnippets(const QString& language);
    Q_INVOKABLE QVariantList searchSnippets(const QString& query);
    Q_INVOKABLE bool insertSnippet(const QJsonObject& snippet);
    Q_INVOKABLE QString resolveSnippetVariables(const QString& snippet);

    // Comments
    Q_INVOKABLE void toggleLineComment(int line);
    Q_INVOKABLE void toggleBlockComment(int startLine, int endLine);
    Q_INVOKABLE void addLineComment(const QVariantList& lines);
    Q_INVOKABLE void removeLineComment(const QVariantList& lines);

    // Bracket Matching & Selection
    Q_INVOKABLE QVariantMap getBracketPair(const QString& filePath, int line, int column);
    Q_INVOKABLE void highlightBrackets(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantMap selectToBracket(const QString& filePath, int line, int column);

    // Case & Text Operations
    Q_INVOKABLE QString convertToUpperCase(const QString& text);
    Q_INVOKABLE QString convertToLowerCase(const QString& text);
    Q_INVOKABLE QString convertToCamelCase(const QString& text);
    Q_INVOKABLE QString convertToSnakeCase(const QString& text);

    // Editor History & Navigation
    Q_INVOKABLE QVariantList getEditHistory();
    Q_INVOKABLE bool canUndo();
    Q_INVOKABLE bool canRedo();
    Q_INVOKABLE QVariantMap goToDefinitionEx(const QString& filePath, int line, int column);
    Q_INVOKABLE bool performInlineRename(const QString& filePath, int line, int column, const QString& newName);

    // Line & Cursor Operations
    Q_INVOKABLE void copyLine(int line);
    Q_INVOKABLE void deleteLine(int line);
    Q_INVOKABLE void moveLinesUp(int startLine, int endLine);
    Q_INVOKABLE void moveLinesDown(int startLine, int endLine);
    Q_INVOKABLE void duplicateLine(int line);
    Q_INVOKABLE QVariantList getCursorPositions();
    Q_INVOKABLE void addCursorAtLine(int line, int column);
    Q_INVOKABLE void removeCursor(int index);
    Q_INVOKABLE void clearCursors();

    // Outline & Navigation
    Q_INVOKABLE QVariantList getOutlineSymbols(const QString& filePath);
    Q_INVOKABLE bool navigateToSymbol(const QString& symbolName);

    // Smart Selection & Highlighting
    Q_INVOKABLE QVariantMap selectWord(const QString& filePath, int line, int column);
    Q_INVOKABLE QVariantList selectScope(const QString& filePath, int line, int column);
    Q_INVOKABLE void highlightAllOccurrences(const QString& word);
    Q_INVOKABLE void clearHighlights();
    Q_INVOKABLE QVariantList getWordOccurrences(const QString& word, const QString& filePath);

    // Word Operations
    Q_INVOKABLE void deleteWord(int line, int column);
    Q_INVOKABLE void deleteWordBackward(int line, int column);

public slots:
    void sendMessage(const QString &text);
    void injectFile(const QString &filePath);
    void injectSelection(const QString &filePath, const QString &code,
                         int startLine, int endLine);
    void openEditorFile(const QString &filePath);
    bool createWorkspaceEntry(const QString &parentPath, const QString &name, bool directory);
    bool renameWorkspacePath(const QString &path, const QString &newName);
    bool deleteWorkspacePath(const QString &path);
    bool moveWorkspacePath(const QString &path, const QString &destinationDir);
    Q_INVOKABLE bool undoLastWorkspaceAction();
    Q_INVOKABLE bool rollbackCheckpoint(const QString &checkpointId);
    void saveCurrentFile();
    void closeEditorTab(int index);
    void forceCloseEditorTab(int index);
    void setCurrentEditorIndex(int index);
    void copyPathToClipboard(const QString &path);
    void interrupt();
    void clearHistory();
    void approveTool(const QString &callId);
    void rejectTool(const QString &callId);

signals:
    void currentProviderChanged();
    void currentModelChanged();
    void busyChanged();
    void workspacePathChanged();
    void workspaceSummaryChanged();
    void anthropicEndpointChanged();
    void openaiEndpointChanged();
    void anthropicApiKeyChanged();
    void openaiApiKeyChanged();
    void geminiApiKeyChanged();
    void braveApiKeyChanged();
    void currentFilePathChanged();
    void currentFileContentChanged();
    void openFilesChanged();
    void currentEditorIndexChanged();
    void autoApproveToolsChanged();
    void undoWorkspaceActionChanged();
    void streamingTextChanged();
    void todoItemsChanged();
    void recentCheckpointsChanged();
    void recentSessionsChanged();
    void recentSlashCommandsChanged();
    void currentThreadIdChanged();
    void openWorkspaceFolderRequested();
    void openWorkspaceFileRequested();
    void executionTimelineChanged();
    void pendingAttachmentsChanged();
    void localSkillsChanged();
    void currentSelectionChanged();
    void codeMagicResultChanged();
    void toolCatalogChanged();
    void mcpToolsChanged();
    void knowledgeSourcesChanged();
    void knowledgeSearchResultsChanged();
    void scheduledTasksChanged();
    void localGatewayUrlChanged();
    void toolApprovalRequired(const QString &callId, const QString &toolName,
                              const QString &summary, const QString &riskLevel,
                              const QString &reason);
    void checkpointRestoreRequested(const QString &checkpointId,
                                    const QString &description,
                                    const QVariantList &files);
    void errorOccurred(const QString &message);
    void successOccurred(const QString &message);

private:
    void restoreTaskSession();
    void applyTaskSession(const TaskSessionSnapshot &snapshot);
    void rebuildChatModelFromHistory();
    void saveTaskSession();
    void appendSessionStoreMessage(const QString &role, const QString &content);
    void unloadMcpTools();
    void syncKnowledgeForPathChange(const QString &oldPath, const QString &newPath, bool wasDirectory);
    void unloadReminderTool();
    void processScheduledReminderQueue();
    bool shouldTrackSlashCommand(const QString &text) const;
    void recordSlashCommand(const QString &text);
    void startLocalGateway();
    QJsonObject localGatewayState() const;
    void closeEditorTabInternal(int index, bool allowDirtyClose);
    void setupEngine();
    bool handleSlashCommand(const QString &text);
    void submitToAgent(const QString &text, const QVariantList &attachments = {});
    QString buildSlashHelp() const;
    QString buildReviewPrompt(const QString &topic) const;
    QVariantList buildPlanItems(const QStringList &items) const;
    QStringList parseSlashListItems(const QString &text) const;
    void refreshWorkspaceSkills();
    void discoverCustomTools(const QString &workspacePath);
    struct CodeMagicInput {
        QString path;
        QString code;
        ProgrammingLanguage language{ProgrammingLanguage::Unknown};
        QString targetLabel;
        bool hasSelection{false};
    };
    CodeMagicInput resolveCodeMagicInput() const;
    void updateCodeMagicResult(const QVariantMap &result, const QString &targetLabel);
    struct PendingToolExecution {
        QString toolName;
        QVariantMap arguments;
        QString summary;
        QString riskLevel;
    };
    QString approvalRiskLevelForTool(const QString &toolName, const QVariantMap &arguments) const;
    bool toolNeedsApproval(const QString &toolName, const QVariantMap &arguments,
                           QString *riskLevel = nullptr, QString *reason = nullptr) const;
    QVariantMap buildToolCatalogEntry(BaseTool *tool) const;
    QVariantMap buildToolPermissionState(const QString &toolName, const QVariantMap &context) const;
    QVariantMap executePendingTool(const QString &approvalId);
    void configurePolicyManagers();
    void syncThreadStore();
    StoredThread buildStoredThreadSnapshot() const;
    void loadSettings();
    void saveSettings() const;
    void refreshSystemPrompt();
    void setBusy(bool b);
    void onTokenReceived(const TokenEvent &ev);
    void onMessageAdded(const AgentMessage &msg);
    void onToolExecuting(const ToolCall &call);
    void onToolFinished(const ToolResult &result);
    void onToolOutputChunk(const QString &callId, const QString &chunk);
    void onSandboxExecutionEvent(const QVariantMap &event);
    void onCodeMagicAnalysisCompleted(const CodeAnalysisResult &result);
    void onCodeMagicGenerationCompleted(const GeneratedCode &code);
    void onCodeMagicRefactoringCompleted(const RefactoringResult &result);
    void onCodeMagicTestsGenerated(const GeneratedTests &tests);
    void onCodeMagicErrorOccurred(const QString &error);
    void appendExecutionEvent(const QString &kind,
                              const QString &title,
                              const QString &status,
                              const QString &details = {},
                              const QString &toolName = {},
                              const QString &callId = {});
    QString inferExecutionKind(const QString &toolName) const;

    AgentEngine    *m_engine{nullptr};
    AgentToolRegistry *m_registry{nullptr};
    ChatModel      *m_chatModel{nullptr};
    WorkspaceContext *m_workspaceContext{nullptr};
    WorkspaceIndex   *m_workspaceIndex{nullptr};
    ClaudeSkillManager *m_skillManager{nullptr};
    DefaultSandboxManager *m_sandboxManager{nullptr};
    DefaultApprovalManager *m_approvalManager{nullptr};
    DefaultCodeMagic *m_codeMagic{nullptr};
    FileBasedThreadStore *m_threadStore{nullptr};

    QHash<QString, LLMProvider *> m_providers;
    QString  m_currentProvider;
    QString  m_currentModel;
    QString  m_workspacePath;
    QString  m_anthropicEndpoint;
    QString  m_openaiEndpoint;
    QString  m_anthropicApiKey;
    QString  m_openaiApiKey;
    QString  m_geminiApiKey;
    QString  m_braveApiKey;
    bool     m_openaiEndpointFromRuntime{false};
    bool     m_openaiApiKeyFromRuntime{false};
    QString  m_currentFilePath;
    QString  m_currentFileContent;
    QString  m_selectedFilePath;
    QString  m_selectedText;
    int      m_selectedStartLine{-1};
    int      m_selectedEndLine{-1};
    QVariantMap m_codeMagicResult;
    QString  m_codeMagicTargetLabel;
    QHash<QString, PendingToolExecution> m_pendingToolExecutions;
    QHash<QString, QString> m_runningToolOutput;  // callId -> accumulated streaming output
    int      m_currentEditorIndex{-1};
    bool     m_autoApproveTools{false};
    bool     m_busy{false};
    bool     m_engineSignalsConnected{false};
    QString  m_streamingText;
    bool     m_streamingAssistantActive{false};
    bool     m_restoringSessionHistory{false};
    QString  m_sessionId;
    QString  m_parentThreadId;
    QDateTime m_threadCreatedAt;
    QVariantList m_executionTimeline;
    QVariantList m_pendingAttachments;
    QVariantList m_localSkills;
    QString  m_lastWorkspaceActionType;
    QString  m_lastWorkspaceActionSource;
    QString  m_lastWorkspaceActionDestination;
    QStringList m_mcpToolNames;
    QStringList m_recentSlashCommands;
    QString  m_reminderSummary;
    QStringList m_pendingReminderPrompts;
    QString m_knowledgeSearchQuery;
    QVariantList m_knowledgeSearchResults;
    QString m_localGatewayUrl;
    quint16 m_localGatewayPort{0};
    LocalGatewayServer *m_gatewayServer{nullptr};

    // VS Code Integration Services
    NotificationService* m_notificationService{nullptr};
    ProgressService* m_progressService{nullptr};
    StorageService* m_storageService{nullptr};
    FileService* m_fileService{nullptr};
    WorkspaceService* m_workspaceService{nullptr};
    SearchService* m_searchService{nullptr};
    TasksManager* m_tasksManager{nullptr};
    TerminalService* m_terminalService{nullptr};
    DebugSession* m_debugSession{nullptr};
    KeyBindingManager* m_keyBindingManager{nullptr};
    QuickAccessManager* m_quickAccessManager{nullptr};
    LanguageClient* m_languageClient{nullptr};
    GitService* m_gitService{nullptr};

    // Phase 2: Advanced Features Providers
    // Basic Features (Week 1)
    TrimTrailingWhitespaceProvider* m_trimWhitespaceProvider{nullptr};
    FormatDocumentProvider* m_formatDocumentProvider{nullptr};
    TypeDefinitionProvider* m_typeDefinitionProvider{nullptr};
    GoToDeclarationProvider* m_goToDeclarationProvider{nullptr};
    PathCompletionProvider* m_pathCompletionProvider{nullptr};

    // Navigation Features (Week 2)
    BreadcrumbProvider* m_breadcrumbProvider{nullptr};
    FindReferencesProvider* m_findReferencesProvider{nullptr};
    SymbolNavigationProvider* m_symbolNavigationProvider{nullptr};
    WorkspaceSymbolProvider* m_workspaceSymbolProvider{nullptr};
    FileWatcherProvider* m_fileWatcherProvider{nullptr};

    // Editing Enhancement Features
    InlineCompletionProvider* m_inlineCompletionProvider{nullptr};
    ParameterHintProvider* m_parameterHintProvider{nullptr};
    CodeActionProvider* m_codeActionProvider{nullptr};
    SemanticHighlightProvider* m_semanticHighlightProvider{nullptr};
    LinkedEditingProvider* m_linkedEditingProvider{nullptr};
    SearchOptimizerProvider* m_searchOptimizerProvider{nullptr};

    // Phase 3 & Beyond: Extended Editor Features
    FindAndReplace* m_findAndReplace{nullptr};
    FoldingManager* m_foldingManager{nullptr};
    SnippetManager* m_snippetManager{nullptr};
    CommentManager* m_commentManager{nullptr};
    BracketMatcher* m_bracketMatcher{nullptr};
    CaseConverter* m_caseConverter{nullptr};
    EditorHistory* m_editorHistory{nullptr};
    GoToDefinition* m_goToDefinition{nullptr};
    InlineRename* m_inlineRename{nullptr};
    LineOperations* m_lineOperations{nullptr};
    MultiCursor* m_multiCursor{nullptr};
    OutlineProvider* m_outlineProvider{nullptr};
    SelectToBracket* m_selectToBracket{nullptr};
    SmartSelection* m_smartSelection{nullptr};
    WordHighlight* m_wordHighlight{nullptr};
    WordOperations* m_wordOperations{nullptr};

    struct EditorDocument {
        QString path;
        QString content;
        QString savedContent;
        bool dirty{false};
    };
    QVector<EditorDocument> m_documents;
};
