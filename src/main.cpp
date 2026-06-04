// Copyright (C) 2024 NeurX Code
// SPDX-License-Identifier: GPL-3.0-only

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QDir>
#include <QFont>
#include <QScreen>
#include <QtQml/qqml.h>

#include "app_environment.h"
#include "import_qml_components_plugins.h"
#include "import_qml_plugins.h"
#include "bridge/AgentController.h"
#include "bridge/SyntaxHighlighter.h"
#include "bridge/EditorCommandBridge.h"

// New editor features (Phase 2)
#include "editor/BracketMatcher.h"
#include "editor/WordOperations.h"
#include "editor/CaseConverter.h"
#include "editor/LineOperations.h"
#include "editor/CommentManager.h"

// New editor features (Phase 3)
#include "editor/SmartSelection.h"
#include "editor/WordHighlight.h"
#include "editor/InlineRename.h"
#include "editor/GoToDefinition.h"
#include "editor/SelectToBracket.h"

// New editor features (Phase 4 - Workbench)
#include "editor/FindAndReplace.h"
#include "editor/MultiCursor.h"

int main(int argc, char *argv[])
{
    set_qt_environment();

    QGuiApplication app(argc, argv);
    app.setApplicationName("NeurX Code");
    app.setOrganizationName("NeurX");
    app.setOrganizationDomain("neurx.ai");
    app.setWindowIcon(QIcon(":/assets/icon.png"));

    // Scale default font proportionally to screen DPI (base: 13px @ 96 DPI).
    if (QScreen *screen = app.primaryScreen()) {
        const qreal dpi = screen->logicalDotsPerInch();
        const int px = qBound(12, qRound(13.0 * dpi / 96.0), 32);
        QFont f = app.font();
        f.setPixelSize(px);
        app.setFont(f);
    }

    // Register C++ types exposed to QML.
    qmlRegisterType<SyntaxHighlighter>("NeurXCode", 1, 0, "SyntaxHighlighter");

    // Register AgentController as a QML context property (singleton-style).
    AgentController agentController;
    
    // Initialize Phase 2 editor features
    auto* bracketMatcher = new BracketMatcher();
    auto* wordOperations = new WordOperations();
    auto* caseConverter = new CaseConverter();
    auto* lineOperations = new LineOperations();
    auto* commentManager = new CommentManager();

    // Initialize Phase 3 editor features
    auto* smartSelection = new SmartSelection();
    auto* wordHighlight = new WordHighlight();
    auto* inlineRename = new InlineRename();
    auto* goToDefinition = new GoToDefinition();
    auto* selectToBracket = new SelectToBracket();

    // Initialize Phase 4 workbench features
    auto* findAndReplace = new FindAndReplace();
    auto* multiCursor = new MultiCursor();

    // Initialize editor command bridge (connects keybindings to features)
    auto* commandBridge = new EditorCommandBridge();
    commandBridge->setBracketMatcher(bracketMatcher);
    commandBridge->setWordOperations(wordOperations);
    commandBridge->setCaseConverter(caseConverter);
    commandBridge->setLineOperations(lineOperations);
    commandBridge->setCommentManager(commentManager);
    commandBridge->setSmartSelection(smartSelection);
    commandBridge->setWordHighlight(wordHighlight);
    commandBridge->setInlineRename(inlineRename);
    commandBridge->setGoToDefinition(goToDefinition);
    commandBridge->setSelectToBracket(selectToBracket);

    // Set workspace to the first command-line argument if provided.
    // Otherwise, only default to the current directory when there is no saved workspace.
    const QString workspaceArg = (app.arguments().size() > 1) ? app.arguments().at(1) : QString{};
    if (!workspaceArg.isEmpty()) {
        agentController.setWorkspacePath(workspaceArg);
    } else if (agentController.workspacePath().isEmpty()) {
        agentController.setWorkspacePath(QDir::currentPath());
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("agent", &agentController);
    
    // Expose Phase 2 features to QML
    engine.rootContext()->setContextProperty("bracketMatcher", bracketMatcher);
    engine.rootContext()->setContextProperty("wordOperations", wordOperations);
    engine.rootContext()->setContextProperty("caseConverter", caseConverter);
    engine.rootContext()->setContextProperty("lineOperations", lineOperations);
    engine.rootContext()->setContextProperty("commentManager", commentManager);

    // Expose Phase 3 features to QML
    engine.rootContext()->setContextProperty("smartSelection", smartSelection);
    engine.rootContext()->setContextProperty("wordHighlight", wordHighlight);
    engine.rootContext()->setContextProperty("inlineRename", inlineRename);
    engine.rootContext()->setContextProperty("goToDefinition", goToDefinition);
    engine.rootContext()->setContextProperty("selectToBracket", selectToBracket);
    
    // Expose Phase 4 features to QML
    engine.rootContext()->setContextProperty("findAndReplace", findAndReplace);
    engine.rootContext()->setContextProperty("multiCursor", multiCursor);
    
    // Expose command bridge to QML
    engine.rootContext()->setContextProperty("editorCommandBridge", commandBridge);

    const QUrl url(u"qrc:/qt/qml/Main/main.qml"_qs);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    engine.addImportPath(":/");

    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
