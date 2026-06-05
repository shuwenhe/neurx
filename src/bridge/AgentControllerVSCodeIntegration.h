/*
 * @file AgentControllerVSCodeIntegration.h
 * @brief VS Code 功能集成头文件
 * 
 * 这个文件包含所有 VS Code 风格服务的声明，需要添加到 AgentController
 */

#pragma once

// 基础服务
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

// 工作台服务
#include "workbench/QuickAccessManager.h"

// 语言服务
#include "languages/LanguageClient.h"
#include "languages/GitService.h"

/**
 * @brief 在 AgentController 私有部分添加以下成员
 */

/*
private:
    // 第 1 阶段: 基础通知和进度
    NotificationService* m_notificationService = NotificationService::instance();
    ProgressService* m_progressService = ProgressService::instance();
    StorageService* m_storageService = StorageService::instance();
    
    // 第 2 阶段: 工作区和文件管理
    FileService* m_fileService = FileService::instance();
    WorkspaceService* m_workspaceService = WorkspaceService::instance();
    SearchService* m_searchService = SearchService::instance();
    QuickAccessManager* m_quickAccessManager = QuickAccessManager::instance();
    
    // 第 3 阶段: 高级功能
    LanguageClient* m_languageClient = LanguageClient::instance();
    GitService* m_gitService = GitService::instance();
    TasksManager* m_tasksManager = TasksManager::instance();
    TerminalService* m_terminalService = TerminalService::instance();
    DebugSession* m_debugSession = DebugSession::instance();
    KeyBindingManager* m_keyBindingManager = KeyBindingManager::instance();
*/

/**
 * @brief 在 AgentController 公共接口中添加以下方法
 */

/*
public:
    // 通知接口
    QString notify(const QString& message);
    QString warn(const QString& message);
    QString error(const QString& message);
    
    // 进度接口
    QString startProgress(const QString& title);
    void updateProgress(const QString& progressId, int current);
    void finishProgress(const QString& progressId);
    
    // 快速访问
    QList<QuickAccessItem> searchQuickAccess(const QString& query);
    bool executeQuickAccessItem(const QString& itemId);
    
    // 搜索接口
    QList<SearchResult> search(const SearchQuery& query);
    
    // Git 接口
    QList<GitFileStatus> getGitStatus();
    QString getCurrentGitBranch();
    bool commitChanges(const QString& message);
    
    // 任务接口
    QString executeTask(const QString& taskId);
    
    // 终端接口
    QString createTerminal();
    void sendTerminalCommand(const QString& terminalId, const QString& command);
    
    // LSP 接口
    void registerLanguageServer(const LanguageServer& server);
    Hover requestHover(const QString& file, int line, int column);

    // Keybindings
    QVariantList getAllKeyBindings() const;
    QVariantMap getKeyBinding(const QString& commandId) const;
    bool registerKeyBinding(const QString& commandId, const QString& keys,
                            const QString& when = QString(),
                            const QString& description = QString());
    bool unregisterKeyBinding(const QString& commandId);
    QVariantList findKeyBindingConflicts(const QString& keys) const;
    bool resetKeyBindings();
    bool saveKeyBindings(const QString& filePath) const;
    bool loadKeyBindings(const QString& filePath);

    // Debugger
    bool debugStepOver(const QString& sessionId);
    bool debugStepInto(const QString& sessionId);
    bool debugStepOut(const QString& sessionId);
    QVariantList getDebugStackTrace(const QString& sessionId) const;
    QVariantList getDebugVariables(const QString& sessionId, int frameId) const;
    QString evaluateDebugExpression(const QString& sessionId, const QString& expression);
    bool setDebugBreakpoint(const QString& sessionId, const QString& filePath, int line,
                            int column = 0, const QString& condition = QString(),
                            const QString& hitCondition = QString());
    bool removeDebugBreakpoint(const QString& sessionId, const QString& breakpointId);
    QVariantList getDebugBreakpoints(const QString& sessionId) const;
*/
