cmake_minimum_required(VERSION 3.21.1)

option(LINK_INSIGHT "Link Qt Insight Tracker library" ON)
# Qt Design Studio components pull a remote repository during configure.
# Keep them opt-in so ordinary local builds do not fail when offline or
# behind a restricted network.
option(BUILD_QDS_COMPONENTS "Build design studio components" OFF)
option(NEURX_ALLOW_QDS_FETCH "Allow fetching Qt Design Studio components from the network" OFF)

project(neurx-codeApp LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick Network Concurrent)
find_package(Qt6 OPTIONAL_COMPONENTS WebSockets)

find_path(SQLITE3_INCLUDE_DIR
    NAMES sqlite3.h
    HINTS
        "C:/Users/Public/qt/Tools/mingw1310_64/opt/include"
        "C:/Program Files/msys64/mingw64/include"
)

find_library(SQLITE3_LIBRARY
    NAMES sqlite3 libsqlite3
    HINTS
        "C:/Users/Public/qt/Tools/mingw1310_64/opt/lib"
        "C:/Program Files/msys64/mingw64/lib"
)

if(NOT SQLITE3_INCLUDE_DIR OR NOT SQLITE3_LIBRARY)
    message(FATAL_ERROR
        "[neurx] SQLite3 development files were not found. "
        "Expected sqlite3.h and a sqlite3 library in a configured toolchain path.")
endif()

add_library(sqlite3 UNKNOWN IMPORTED)
set_target_properties(sqlite3 PROPERTIES
    IMPORTED_LOCATION "${SQLITE3_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SQLITE3_INCLUDE_DIR}"
)

if (Qt6_VERSION VERSION_GREATER_EQUAL 6.3)
    qt_standard_project_setup()
endif()

# ── Phase 1: Framework Sources (neurx_core) ───────────────────────────────────
# Use GLOB_RECURSE to find all sources, then filter out problematic files
file(GLOB_RECURSE NEURX_CORE_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/**/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/**/*.h"
)
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/main\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/bridge/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/editor/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/features/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/services/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/languages/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/workbench/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/security/")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/plugins/")
# Exclude files that will be compiled in neurx_ui
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "NotificationService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ProgressService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SearchService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WorkspaceService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TasksManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TerminalService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "StorageService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ConfigService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DiagnosticsService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DebugSession\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "KeyBindingManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "OperationCache\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PerformanceOptimizer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ThemeManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitService\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FeatureProviders\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "NavigationProviders\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "EditingProviders\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "QuickAccessManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FindAndReplace\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FoldingManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SnippetManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CommentManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "BracketMatcher\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CaseConverter\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "EditorHistory\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileWatcher\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GoToDefinition\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "InlineRename\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "LineOperations\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "MultiCursor\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "OutlineProvider\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SelectToBracket\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SmartSelection\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WordHighlight\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WordOperations\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GoToError\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PeekView\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "StickyScroll\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "HookManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SecurityScanner\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitWorkflowTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "Tool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "EditFileTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileMetadataTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "BatchFileOperationsTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "AdvancedSearchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileSyncTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PermissionsManagerTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DirectoryTreeTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TextProcessingTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GeminiReadFileTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GeminiWriteFileTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PatchGeneratorTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CompilerIntegrationTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ConfigGeneratorTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CodeMigrationTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SecurityAnalysisTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitHubAutomationTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ClaudeToolSystem\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ClaudeStandardTools\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultTool.*\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "Tool.*Manager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ToolMetricsCollector\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ToolCacheManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "McpClient\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CheckpointManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "LocalGatewayServer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SessionStore\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SmartFileCreator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WebFetchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WebSearchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitHubTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitLabTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DockerShellTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ApplyPatchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CodexApplyPatchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CodexFileSystemTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GeminiGroundingTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "RiskAssessor\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ApprovalStrategyManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GuardianAgentTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CommandRegistry\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "EditorCommandManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CommandPalette\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ContextMenuIntegration\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PluginLoader\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PluginSandbox\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PluginValidator\\.cpp$")

# Exclude new Tier 15 systems (Interactive Workflows)
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CommitCommandManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "LearningModeSystem\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "RalphIterationEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "InteractivePromptSystem\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitCommandIntegration\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitWorkflowAgent\\.cpp$")

# Exclude Tier 5-6 systems that are in neurx_ui only
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CodeReviewEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitAutomationManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SecurityAnalyzer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FeatureDevelopmentWorkflow\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PluginSystemRegistry\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "OutputStyleManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "HookifyManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SkillSystem\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WorkspaceAnalyzer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TypeDesignValidator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IterativeExecutor\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IssueLifecycleManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "AdvancedHookManager\\.cpp$")

# Exclude Tier 3 systems that are in neurx_ui only  
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SlashCommandManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "EventBus\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "RuleEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "MCPManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ContextManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ExecutionStrategyManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "JitContext\\.cpp$")

# Exclude Tier 4 systems that are in neurx_ui only
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ToolDiscoveryManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ConversationManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ProgressTracker\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ErrorRecoveryManager\\.cpp$")

# Exclude new utility systems for automation and analysis
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ExplanatoryOutputStyleManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IssueDuplicateAutoCloser\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitHubSweepAutomation\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "WorkspaceHealthAnalyzer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GitHubIssueLabelManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IssueLifecycleRulesEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "AutoCommentGenerator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DuplicateDetectionBackfill\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IssueActivityMonitor\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "PullRequestAutoReviewer\\.cpp$")

# Wave 4: Security and Testing Systems
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SecurityPatternDetector\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TestCoverageAnalyzer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "ErrorHandlingAnalyzer\\.cpp$")

# Wave 5: Code Quality and Design Systems
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CodeSimplificationSuggester\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "CommentQualityAnalyzer\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "TypeDesignValidator\\.cpp$")

# Ensure ThreadId and LoggingManager are included even if they match filters
file(GLOB THREAD_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/thread/*.cpp")
file(GLOB LOGGING_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/logging/*.cpp")
# Include base class implementations in core as well
file(GLOB TOOL_BASE_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/tools/Tool*.cpp")
list(APPEND NEURX_CORE_SOURCES ${THREAD_SOURCES} ${LOGGING_SOURCES} ${TOOL_BASE_SOURCES})
list(REMOVE_DUPLICATES NEURX_CORE_SOURCES)

# Exclude tools and services that are in neurx_ui only
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "GeminiEditTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileSearchTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "IncrementalEditTool\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "FileSafetyValidator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "AgentController\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "SyntaxHighlighter\\.cpp$")

# Temporarily exclude files with known compilation issues in core
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "LanguageClient\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultExecutionEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultIntegrationOrchestrator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultGoalManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultLLMExtensions\\.cpp$")

add_library(neurx_core STATIC
    ${NEURX_CORE_SOURCES}
)

target_sources(neurx_core PRIVATE
    src/filesystem/ExecutorFileSystem.h
)

target_include_directories(neurx_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_core PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Concurrent
    sqlite3
)

set_target_properties(neurx_core PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

add_library(neurx_ui STATIC
    # Phase 2: Core Features
    src/bridge/AgentController.cpp
    src/bridge/SyntaxHighlighter.cpp
    src/bridge/EditorCommandBridge.cpp
    src/features/FeatureProviders.cpp
    src/features/NavigationProviders.cpp
    src/features/EditingProviders.cpp

    # Phase 3: Quick Access & Edit Features
    src/workbench/QuickAccessManager.cpp
    src/editor/FindAndReplace.cpp
    src/editor/FoldingManager.cpp
    src/editor/SnippetManager.cpp
    src/editor/CommentManager.cpp
    src/editor/FileWatcher.cpp

    # Phase 3+: Advanced Editor Features
    src/editor/BracketMatcher.cpp
    src/editor/CaseConverter.cpp
    src/editor/EditorHistory.cpp
    src/editor/GoToDefinition.cpp
    src/editor/InlineRename.cpp
    src/editor/LineOperations.cpp
    src/editor/MultiCursor.cpp
    src/editor/OutlineProvider.cpp
    src/editor/SelectToBracket.cpp
    src/editor/SmartSelection.cpp

    # Phase 4: Extensibility & Advanced Features
    src/agent/HookManager.cpp
    src/security/SecurityScanner.cpp
    src/tools/GitWorkflowTool.cpp
    src/editor/WordHighlight.cpp
    src/editor/WordOperations.cpp

    # Phase 4: Advanced Navigation & UI
    src/editor/GoToError.cpp
    src/editor/PeekView.cpp
    src/editor/StickyScroll.cpp

    # Framework & Tool System
    src/tools/ClaudeToolSystem.cpp
    src/tools/ClaudeStandardTools.cpp
    src/tools/FileSystemTool.cpp
    src/tools/SearchTool.cpp
    src/tools/ShellTool.cpp
    src/tools/DockerShellTool.cpp
    src/tools/PatchTool.cpp
    src/tools/ApplyPatchTool.cpp
    src/tools/CodexApplyPatchTool.cpp
    src/tools/CodexTool.cpp
    src/tools/CodexFileSystemTool.cpp
    src/tools/DelegationTool.cpp
    src/tools/KnowledgeTool.cpp
    src/tools/WebSearchTool.cpp
    src/tools/WebFetchTool.cpp
    src/tools/GitHubTool.cpp
    src/tools/GitLabTool.cpp
    src/tools/JiraTool.cpp
    src/tools/TodoTool.cpp
    src/tools/ReminderTool.cpp
    src/tools/MemoryTool.cpp
    src/tools/CheckpointTool.cpp
    src/tools/CheckpointManager.cpp
    src/tools/UpdatePlanTool.cpp
    src/tools/SkillTool.cpp
    src/tools/NeurxSkillCreatorTool.cpp
    src/tools/CustomScriptTool.cpp
    src/tools/PlanModeTools.cpp
    src/tools/SmartFileCreator.cpp
    src/tools/McpClient.cpp
    src/tools/DefaultToolDiscovery.cpp
    src/tools/DefaultToolExecutor.cpp
    src/tools/DefaultToolPermissionManager.cpp
    src/tools/DefaultToolRegistry.cpp
    src/tools/DefaultToolSchemaRegistry.cpp
    src/tools/ToolCacheManager.cpp
    src/tools/ToolChainManager.cpp
    src/tools/ToolMetricsCollector.cpp
    src/tools/ToolVersionManager.cpp
    src/tools/LocalGatewayServer.cpp
    src/tools/SessionStore.cpp
    src/tools/McpProxyTool.cpp
    src/tools/GeminiGroundingTool.cpp
    
    # Abstract base class implementations for vtable emission
    src/tools/ToolExecutor.cpp
    src/tools/ToolDiscovery.cpp
    src/tools/ToolSchemaRegistry.cpp
    src/tools/ToolPermissionManager.cpp

    # Services: Required for AgentController integration
    src/services/NotificationService.cpp
    src/services/ProgressService.cpp
    src/services/FileService.cpp
    src/services/SearchService.cpp
    src/services/WorkspaceService.cpp
    src/services/TasksManager.cpp
    src/services/TerminalService.cpp
    src/services/StorageService.cpp
    src/services/ConfigService.cpp
    src/services/DiagnosticsService.cpp
    src/services/DebugSession.cpp
    src/services/KeyBindingManager.cpp
    src/services/OperationCache.cpp
    src/services/PerformanceOptimizer.cpp
    src/services/ThemeManager.cpp
    src/languages/GitService.cpp

    # Language Server & Other Infrastructure
    src/languages/LanguageClient.cpp
    src/tools/GeminiReadFileTool.cpp
    src/tools/GeminiWriteFileTool.cpp
    src/tools/GeminiListFilesTool.cpp
    src/tools/GeminiStatFileTool.cpp
    src/tools/GeminiReadManyFilesTool.cpp
    src/tools/GeminiGlobTool.cpp
    src/tools/GeminiRemoveFileTool.cpp
    src/tools/GeminiMkdirTool.cpp
    src/tools/GeminiAppendFileTool.cpp
    src/tools/GeminiExistsFileTool.cpp
    src/tools/GeminiGrepTool.cpp
    src/tools/GeminiRgTool.cpp
    src/tools/GeminiHashTool.cpp
    src/tools/GeminiSymlinkTool.cpp
    src/tools/GeminiChmodTool.cpp
    src/tools/GeminiMoveFileTool.cpp
    src/tools/GeminiCopyFileTool.cpp
    src/tools/GeminiWriteBatchTool.cpp
    src/tools/GeminiEditTool.cpp
    src/tools/GeminiWriteTodosTool.cpp
    src/tools/GeminiUpdateTopicTool.cpp
    src/tools/GeminiAskUserTool.cpp
    src/tools/GeminiGetInternalDocsTool.cpp
    src/tools/GeminiCompleteTaskTool.cpp
    src/tools/CodeMigrationTool.cpp
    src/tools/SecurityAnalysisTool.cpp
    src/tools/GitHubAutomationTool.cpp

    # File Operation Tools (Phase 2)
    src/tools/EditFileTool.cpp
    src/tools/FileMetadataTool.cpp
    src/tools/BatchFileOperationsTool.cpp
    src/tools/AdvancedSearchTool.cpp
    src/tools/FileSyncTool.cpp
    src/tools/PermissionsManagerTool.cpp
    src/tools/DirectoryTreeTool.cpp
    src/tools/TextProcessingTool.cpp

    # File Operation Tools (Phase 3: Compiler & Config)
    src/tools/PatchGeneratorTool.cpp
    src/tools/CompilerIntegrationTool.cpp
    src/tools/ConfigGeneratorTool.cpp


    # Guardian Agent System (Automated Approval & Risk Assessment)
    src/agent/runtime/RiskAssessor.cpp
    src/agent/runtime/ApprovalStrategyManager.cpp
    src/agent/tools/GuardianAgentTool.cpp

    # Agent Runtime Enhancement (Tier 3: Slash Commands, Events, Rules, MCP, Context, Strategy)
    src/agent/SlashCommandManager.cpp
    src/agent/EventBus.cpp
    src/agent/RuleEngine.cpp
    src/agent/MCPManager.cpp
    src/agent/ContextManager.cpp
    src/agent/ExecutionStrategyManager.cpp
    src/agent/JitContext.cpp

    # Agent System Enhancement (Tier 4: Tool Discovery, Conversations, Progress Tracking, Error Recovery)
    src/agent/ToolDiscoveryManager.cpp
    src/agent/ConversationManager.cpp
    src/agent/ProgressTracker.cpp
    src/agent/ErrorRecoveryManager.cpp

    # Claude Code Migration (Tier 5: Code Review, Git Automation, Security Analysis, Feature Development, Plugin System)
    src/agent/CodeReviewEngine.cpp
    src/agent/GitAutomationManager.cpp
    src/agent/SecurityAnalyzer.cpp
    src/agent/FeatureDevelopmentWorkflow.cpp
    src/agent/PluginSystemRegistry.cpp

    # Claude Code Migration (Tier 6: Output Styles, Hooks, Skills, Workspace Analysis, Type Validation, Iteration)
    src/agent/OutputStyleManager.cpp
    src/agent/HookifyManager.cpp
    src/agent/SkillSystem.cpp
    src/agent/WorkspaceAnalyzer.cpp
    src/agent/TypeDesignValidator.cpp
    src/agent/IterativeExecutor.cpp

    # Claude Code Migration (Tier 7: Frontend Design, Model Migration, PR Review, SDK Dev, Knowledge Base)
    # TEMPORARILY DISABLED FOR FAST BUILD - ENABLE AFTER CORE COMPILES
    # src/agent/FrontendDesignSystem.cpp
    # src/agent/ModelMigrationManager.cpp
    # src/agent/PRReviewAgents.cpp
    # src/agent/AgentSDKDeveloper.cpp
    # src/agent/KnowledgebaseManager.cpp

    # Claude Code Migration (Tier 8: Automation, Analytics, Localization, Optimization, Webhooks)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/AutomationOrchestrator.cpp
    # src/agent/AnalyticsEngine.cpp
    # src/agent/LocalizationManager.cpp
    # src/agent/PerformanceOptimizer.cpp
    # src/agent/CustomWebhookManager.cpp

    # Claude Code Migration (Tier 9: Extensions, Marketplace, Collaboration, Cost Optimization)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/CustomExtensionManager.cpp
    # src/agent/AppMarketplaceManager.cpp
    # src/agent/RealtimeCollaborationEngine.cpp
    # src/agent/CostOptimizationEngine.cpp

    # Claude Code Migration (Tier 10: Compliance, Disaster Recovery, Metrics, Documentation)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/ComplianceFramework.cpp
    # src/agent/DisasterRecoveryManager.cpp
    # src/agent/MetricsTrackingEngine.cpp
    # src/agent/DocumentationGenerator.cpp

    # Claude Code Migration (Tier 11: Data Pipelines, Recommendations, Enterprise Integration)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/DataPipelineOrchestrator.cpp
    # src/agent/IntelligentRecommendationEngine.cpp
    # src/agent/EnterpriseIntegrationPlatform.cpp

    # Claude Code Migration (Tier 12: Issue Management, Iteration, Security, Output Styling)
    src/agent/IssueLifecycleManager.cpp
    src/agent/IssueLifecycleRulesEngine.cpp
    src/agent/AutoCommentGenerator.cpp
    src/agent/IssueActivityMonitor.cpp
    # DISABLED: src/agent/AutonomousIterationEngine.cpp
    # DISABLED: src/agent/SecurityGuidelineEnforcer.cpp
    # DISABLED: src/agent/InteractiveOutputStyler.cpp

    # Claude Code Migration (Tier 13: Code Analysis, Code Exploration, Conversation Analysis, Advanced Hooks)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/CodeArchitectureAnalyzer.cpp
    # src/agent/InteractiveCodeExplorer.cpp
    # src/agent/ConversationAnalyzer.cpp
    src/agent/AdvancedHookManager.cpp

    # Claude Code Migration (Tier 14: Thematic Content, Code Snippets, Prompt Optimization)
    # TEMPORARILY DISABLED FOR FAST BUILD
    # src/agent/ThematicContentGenerator.cpp
    # src/agent/CodeSnippetLibraryManager.cpp
    # src/agent/DynamicPromptOptimizer.cpp

    # File Operation Tools (Phase 4: Migration & Security)
    # src/tools/CodeMigrationTool.cpp
    # src/tools/SecurityAnalysisTool.cpp
    # src/tools/GitHubAutomationTool.cpp

    # File Operation Tools (Phase 5: Advanced File Operations from claude-code)
    # src/tools/FileSearchTool.cpp
    # src/tools/FileSafetyValidator.cpp
    src/tools/IncrementalEditTool.cpp
    src/tools/FileStateManager.cpp
    src/tools/FileCreationTool.cpp

    # Editor Command Integration (Tier 2: Editor Commands)
    src/editor/CommandRegistry.cpp
    src/editor/EditorCommandManager.cpp
    src/editor/CommandPalette.cpp
    src/editor/ContextMenuIntegration.cpp

    # Plugin System Upgrade (Tier 2: Dynamic Loading & Hot Reload)
    src/plugins/PluginLoader.cpp
    src/plugins/PluginSandbox.cpp
    src/plugins/PluginValidator.cpp

    # Claude Code Advanced Features (Tier 15: Interactive Workflows)
    src/agent/CommitCommandManager.cpp
    src/agent/LearningModeSystem.cpp
    src/agent/RalphIterationEngine.cpp
    src/agent/InteractivePromptSystem.cpp
    src/agent/GitCommandIntegration.cpp

    # Wave 4: Security and Testing Systems
    src/agent/SecurityPatternDetector.cpp
    src/agent/TestCoverageAnalyzer.cpp
    src/agent/ErrorHandlingAnalyzer.cpp

    # Wave 5: Code Quality and Design Systems
    src/agent/CodeSimplificationSuggester.cpp
    src/agent/CommentQualityAnalyzer.cpp
    src/agent/TypeDesignValidator.cpp
)

target_include_directories(neurx_ui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_ui PUBLIC
    neurx_core
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

set_target_properties(neurx_ui PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

qt_add_executable(neurx-codeApp
    src/main.cpp
)

target_link_libraries(neurx-codeApp PRIVATE
    neurx_ui
    content
    NeurXCode
)

qt_add_resources(neurx-codeApp "configuration"
    PREFIX "/"
    FILES
        qtquickcontrols2.conf
)

target_link_libraries(neurx-codeApp PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::Concurrent
)

# Optional WebSockets support
if(Qt6WebSockets_FOUND)
    target_link_libraries(neurx-codeApp PRIVATE Qt6::WebSockets)
    target_compile_definitions(neurx-codeApp PRIVATE NEURX_HAS_WEBSOCKETS)
endif()

# ── Platform-specific packaging ───────────────────────────────────────────────
if(APPLE)
    # Set macOS bundle properties
    set_target_properties(neurx-codeApp PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "NeurX Code"
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_GUI_IDENTIFIER "ai.neurx.code"
        MACOSX_BUNDLE_ICON_FILE "AppIcon"
    )

    # Copy app icon into the bundle if it exists
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/AppIcon.icns")
        set_source_files_properties(
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/AppIcon.icns"
            PROPERTIES
            MACOSX_PACKAGE_LOCATION Resources
        )
        target_sources(neurx-codeApp PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/assets/AppIcon.icns")
    endif()

    # Embed Qt plugins into the .app bundle
    qt_generate_deploy_app_script(
        TARGET neurx-codeApp
        OUTPUT_SCRIPT deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})
elseif(WIN32)
    set_target_properties(neurx-codeApp PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.rc")
        target_sources(neurx-codeApp PRIVATE assets/app.rc)
    endif()
    # Windows deploy via windeployqt (called from build-windows.bat)
endif()

# ── Codex CLI (Rust) ──────────────────────────────────────────────────────────
# Builds the bundled Codex CLI Rust workspace and copies the resulting binary
# into the app output directory so CodexTool can invoke it at runtime.
#
# Disable with:  cmake ... -DBUILD_CODEX_CLI=OFF
# ─────────────────────────────────────────────────────────────────────────────
option(BUILD_CODEX_CLI "Build the Codex CLI from the bundled Rust workspace" ON)

set(CODEX_RS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/codex/codex-rs")

if(BUILD_CODEX_CLI)
    find_program(CARGO_EXECUTABLE cargo
        HINTS
            "$ENV{HOME}/.cargo/bin"
            "/opt/homebrew/bin"
            "/usr/local/bin"
            "$ENV{CARGO_HOME}/bin"
        DOC "Rust Cargo build tool (https://rustup.rs)")

    if(NOT CARGO_EXECUTABLE)
        message(WARNING
            "[neurx] BUILD_CODEX_CLI=ON but 'cargo' was not found. "
            "Install Rust via https://rustup.rs, or pass -DBUILD_CODEX_CLI=OFF to skip. "
            "Disabling Codex CLI build for this configuration.")
        set(BUILD_CODEX_CLI OFF CACHE BOOL "" FORCE)
    endif()
endif()

if(BUILD_CODEX_CLI)
    # Map CMake build type → Cargo profile.
    set(_codex_cargo_args "build" "-p" "codex-cli")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(CODEX_CARGO_PROFILE "debug")
    else()
        set(CODEX_CARGO_PROFILE "release")
        list(APPEND _codex_cargo_args "--release")
    endif()

    set(CODEX_CLI_BINARY
        "${CODEX_RS_DIR}/target/${CODEX_CARGO_PROFILE}/codex${CMAKE_EXECUTABLE_SUFFIX}")

    # Cargo is incremental; always invoke it — it will only recompile changed crates.
    # Force RUSTUP_TOOLCHAIN=stable so rustup does not attempt to sync/install
    # the pinned 1.95.0 toolchain from rust-toolchain.toml on every build.
    # stable (1.96.0) satisfies the 1.95.0 minimum requirement.
    add_custom_target(codex_cli ALL
        COMMAND ${CMAKE_COMMAND} -E env RUSTUP_TOOLCHAIN=stable
            "${CARGO_EXECUTABLE}" ${_codex_cargo_args}
        BYPRODUCTS "${CODEX_CLI_BINARY}"
        WORKING_DIRECTORY "${CODEX_RS_DIR}"
        COMMENT "[neurx] Building Codex CLI (Rust, profile=${CODEX_CARGO_PROFILE})…"
        USES_TERMINAL
        VERBATIM
    )

    # neurx_core must wait for codex_cli and receives the binary path as a macro.
    add_dependencies(neurx_core codex_cli)
    target_compile_definitions(neurx_core PRIVATE
        CODEX_CLI_BINARY_PATH="${CODEX_CLI_BINARY}"
    )

    # ── Copy the binary into the runtime output tree ──────────────────────────
    if(APPLE)
        # macOS: place inside the .app bundle's Contents/MacOS/
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_BUNDLE_DIR:neurx-codeApp>/Contents/MacOS/codex"
            COMMENT "[neurx] Copying Codex CLI into .app bundle…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "neurx-codeApp.app/Contents/MacOS"
                COMPONENT Runtime)
    elseif(WIN32)
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_FILE_DIR:neurx-codeApp>/codex.exe"
            COMMENT "[neurx] Copying Codex CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "."
                COMPONENT Runtime)
    else()
        # Linux: place in the same directory as the app binary.
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_FILE_DIR:neurx-codeApp>/codex"
            COMMENT "[neurx] Copying Codex CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "bin"
                COMPONENT Runtime)
    endif()

    message(STATUS "[neurx] Codex CLI: cargo=${CARGO_EXECUTABLE}, profile=${CODEX_CARGO_PROFILE}")
    message(STATUS "[neurx] Codex CLI binary: ${CODEX_CLI_BINARY}")
endif()

# ── Gemini CLI (C++) ──────────────────────────────────────────────────────────
# Builds the bundled Gemini CLI C++ workspace and copies the resulting binary
# into the app output directory so GeminiTool can invoke it at runtime.
#
# Disable with:  cmake ... -DBUILD_GEMINI_CLI=OFF
# ─────────────────────────────────────────────────────────────────────────────
# Note: gemini-cli directory does not exist in this workspace, so disable by default
option(BUILD_GEMINI_CLI "Build the Gemini CLI from the bundled C++ workspace" OFF)
set(GEMINI_CLI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/gemini-cli")
if(BUILD_GEMINI_CLI)
    # Map CMake build type → Gemini profile.
    set(_gemini_cli_args "build" "-p" "gemini-cli")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(GEMINI_CLI_PROFILE "debug")
    else()
        set(GEMINI_CLI_PROFILE "release")
        list(APPEND _gemini_cli_args "--release")
    endif()

    set(GEMINI_CLI_BINARY
        "${GEMINI_CLI_DIR}/target/${GEMINI_CLI_PROFILE}/gemini${CMAKE_EXECUTABLE_SUFFIX}")

    set(GEMINI_COPY_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/CopyGeminiCliIfExists.cmake")
    file(WRITE "${GEMINI_COPY_SCRIPT}" [=[
if(EXISTS "${src}")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${src}" "${dst}"
        RESULT_VARIABLE copy_result
    )
    if(NOT copy_result EQUAL 0)
        message(FATAL_ERROR "[neurx] Failed to copy Gemini CLI from ${src} to ${dst}")
    endif()
else()
    message(STATUS "[neurx] Gemini CLI binary not found at ${src}; skipping bundle copy.")
endif()
]=])

    # ── Copy the binary into the runtime output tree ──────────────────────────
    if(APPLE)
        # macOS: place inside the .app bundle's Contents/MacOS/
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND}
                -Dsrc="${GEMINI_CLI_BINARY}"
                -Ddst="$<TARGET_BUNDLE_DIR:neurx-codeApp>/Contents/MacOS/gemini"
                -P "${GEMINI_COPY_SCRIPT}"
            COMMENT "[neurx] Copying Gemini CLI into .app bundle…"
            VERBATIM
        )
        install(PROGRAMS "${GEMINI_CLI_BINARY}"
                DESTINATION "neurx-codeApp.app/Contents/MacOS"
                COMPONENT Runtime)
    elseif(WIN32)
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND}
                -Dsrc="${GEMINI_CLI_BINARY}"
                -Ddst="$<TARGET_FILE_DIR:neurx-codeApp>/gemini.exe"
                -P "${GEMINI_COPY_SCRIPT}"
            COMMENT "[neurx] Copying Gemini CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${GEMINI_CLI_BINARY}"
                DESTINATION "."
                COMPONENT Runtime)
    else()
        # Linux: place in the same directory as the app binary.
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND}
                -Dsrc="${GEMINI_CLI_BINARY}"
                -Ddst="$<TARGET_FILE_DIR:neurx-codeApp>/gemini"
                -P "${GEMINI_COPY_SCRIPT}"
            COMMENT "[neurx] Copying Gemini CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${GEMINI_CLI_BINARY}"
                DESTINATION "bin"
                COMPONENT Runtime)
    endif()
    message(STATUS "[neurx] Gemini CLI binary: ${GEMINI_CLI_BINARY}")
endif()

set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)
set(QML_IMPORT_PATH ${QT_QML_OUTPUT_DIRECTORY}
    CACHE STRING "Import paths for Qt Creator's code model"
    FORCE
)

if (BUILD_QDS_COMPONENTS AND NOT NEURX_ALLOW_QDS_FETCH)
    message(WARNING
        "[neurx] BUILD_QDS_COMPONENTS is ON but NEURX_ALLOW_QDS_FETCH is OFF. "
        "Skipping Qt Design Studio components to avoid configure failures when network access is unavailable. "
        "Enable both options explicitly if you want CMake to fetch them.")
    set(BUILD_QDS_COMPONENTS OFF CACHE BOOL "" FORCE)
endif()

if (BUILD_QDS_COMPONENTS)
    include(${CMAKE_CURRENT_SOURCE_DIR}/qmlcomponents)
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/qmlmodules)

if (LINK_INSIGHT)
    include(${CMAKE_CURRENT_SOURCE_DIR}/insight)
endif ()

# Enable testing
enable_testing()
add_subdirectory(tests)

include(GNUInstallDirs)
install(TARGETS neurx-codeApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# make IDEs aware of the QML import path
set(QML_IMPORT_PATH ${PROJECT_BINARY_DIR}/qml CACHE PATH
    "Path to the custom QML components defined by the project")
