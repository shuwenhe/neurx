#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QFont>
#include <QDebug>

#include "../bridge/AgentListModel.h"
#include "../bridge/LogModel.h"
#include "../bridge/neurx_bridge.h"

#if defined(Q_OS_ANDROID)
#include <android/log.h>
#endif

namespace {

void mobile_log_info(const QString& message) {
#if defined(Q_OS_ANDROID)
    __android_log_print(ANDROID_LOG_INFO, "NeurXMobile", "%s", qPrintable(message));
#else
    qInfo().noquote() << message;
#endif
}

void mobile_log_error(const QString& message) {
#if defined(Q_OS_ANDROID)
    __android_log_print(ANDROID_LOG_ERROR, "NeurXMobile", "%s", qPrintable(message));
#else
    qCritical().noquote() << message;
#endif
}

}

int main(int argc, char* argv[]) {
    QQuickStyle::setStyle("Material");
    QGuiApplication app(argc, argv);
    app.setApplicationName("NeurX Mobile");
    app.setOrganizationName("NeurX");

    QFont ui_font = app.font();
    ui_font.setPointSize(10);
    ui_font.setStyleHint(QFont::SansSerif);
    app.setFont(ui_font);

    NeurxBridge bridge;
    AgentListModel agent_model;
    LogModel log_model;

    QObject::connect(&bridge, &NeurxBridge::runtime_status_changed,
        &agent_model, &AgentListModel::set_primary_agent_status);
    QObject::connect(&bridge, &NeurxBridge::log_message,
        &log_model, &LogModel::append);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app,
        [&](const QList<QQmlError>& warnings) {
            for (const QQmlError& warning : warnings) {
                mobile_log_error(QStringLiteral("QML warning: %1").arg(warning.toString()));
            }
        });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
        [&](QObject* object, const QUrl& url) {
            mobile_log_info(QStringLiteral("Mobile QML objectCreated %1 ok=%2")
                .arg(url.toString(), object ? QStringLiteral("true") : QStringLiteral("false")));
        });
    QQmlContext* root_ctx = engine.rootContext();
    if (!root_ctx) {
        mobile_log_error(QStringLiteral("QQmlApplicationEngine: rootContext() is null"));
        return -1;
    }
    root_ctx->setContextProperty("Runtime", &bridge);
    root_ctx->setContextProperty("AgentModel", &agent_model);
    root_ctx->setContextProperty("LogModel", &log_model);
    mobile_log_info(QStringLiteral("Loading mobile QML entrypoint"));
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/neurx/mobile/qml/MobileMain.qml")));
    mobile_log_info(QStringLiteral("Mobile root object count %1").arg(engine.rootObjects().size()));

    if (engine.rootObjects().isEmpty()) {
        mobile_log_error(QStringLiteral("Mobile QML root object creation failed"));
        return -1;
    }

    mobile_log_info(QStringLiteral("Entering mobile event loop"));
    return app.exec();
}
