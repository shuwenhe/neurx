#include <QApplication>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>
#include <QWidget>

#include "bridge/neurx_bridge.h"

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);

    NeurxBridge bridge;
    QWidget window;
    window.setWindowTitle("Neurx Qt Agent Shell");
    auto* layout = new QVBoxLayout(&window);

    auto* intro = new QLabel("Enter a prompt and run agent");
    auto* prompt = new QLineEdit();
    prompt->setPlaceholderText("e.g. summarize dataset status");
    auto* button = new QPushButton("Run Agent");
    auto* status = new QLabel(QString("Status: %1").arg(bridge.ping()));
    status->setWordWrap(true);

    layout->addWidget(intro);
    layout->addWidget(prompt);
    layout->addWidget(button);
    layout->addWidget(status);

    QObject::connect(button, &QPushButton::clicked, [&bridge, prompt, status]() {
        QString input = prompt->text().trimmed();
        if (input.isEmpty()) {
            input = "hello";
        }
        const QString result = bridge.run_agent(input, 4);
        status->setText(QString("Result: %1").arg(result));
    });

    window.resize(720, 220);
    window.show();

    return app.exec();
}
