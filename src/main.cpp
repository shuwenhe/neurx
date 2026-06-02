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
