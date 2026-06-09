#include "InteractivePromptSystem.h"
#include <QDateTime>
#include <QDebug>
#include <iostream>

InteractivePromptSystem::InteractivePromptSystem(QObject *parent)
    : QObject(parent)
{
}

InteractivePromptSystem::~InteractivePromptSystem() {}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptConfirmation(const QString &message, const QString &title)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = Confirmation;
    options.choices = {"Yes", "No"};
    options.defaultValue = "Yes";

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptChoice(const QString &message,
                                                                             const QStringList &choices,
                                                                             const QString &title)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = Choice;
    options.choices = choices;
    options.required = true;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptMultipleChoice(const QString &message,
                                                                                     const QStringList &choices,
                                                                                     const QString &title)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = MultipleChoice;
    options.choices = choices;
    options.required = true;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptText(const QString &message,
                                                                           const QString &title,
                                                                           const QString &defaultValue)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = TextInput;
    options.defaultValue = defaultValue;
    options.required = false;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptNumber(const QString &message,
                                                                             const QString &title,
                                                                             double defaultValue)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = NumberInput;
    options.defaultValue = QString::number(defaultValue);
    options.required = false;

    auto response = getResponseFromUser(options);
    
    // 验证是否是有效的数字
    bool ok = false;
    response.value.toDouble(&ok);
    response.accepted = ok;
    
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptPassword(const QString &message,
                                                                               const QString &title)
{
    PromptOptions options;
    options.title = title;
    options.message = message;
    options.type = PasswordInput;
    options.required = true;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::promptFileSelection(const QString &title,
                                                                                   const QString &directory)
{
    PromptOptions options;
    options.title = title;
    options.message = "Select a file";
    options.type = FileSelection;
    options.defaultValue = directory;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

void InteractivePromptSystem::showProgress(const QString &message, int current, int total)
{
    if (!m_interactiveMode) return;

    double percentage = (total > 0) ? (static_cast<double>(current) / total) * 100.0 : 0.0;
    
    std::cout << "\r[" << std::string(static_cast<int>(percentage / 5), '=')
              << std::string(20 - static_cast<int>(percentage / 5), ' ') << "] "
              << percentage << "% - " << message.toStdString() << std::flush;

    emit progressUpdated(current, total);
}

void InteractivePromptSystem::hideProgress()
{
    std::cout << std::endl;
}

void InteractivePromptSystem::updateProgressMessage(const QString &message)
{
    if (m_interactiveMode) {
        std::cout << "\r[    ] " << message.toStdString() << std::endl;
    }
}

int InteractivePromptSystem::showMenu(const QString &title, const QStringList &options)
{
    if (!m_interactiveMode || options.isEmpty()) {
        return 0;
    }

    std::cout << "\n" << title.toStdString() << ":\n";
    for (int i = 0; i < options.size(); ++i) {
        std::cout << (i + 1) << ". " << options[i].toStdString() << "\n";
    }
    std::cout << "Select (1-" << options.size() << "): ";

    int choice;
    std::cin >> choice;
    
    return (choice >= 1 && choice <= options.size()) ? choice - 1 : 0;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::collectRating(const QString &message,
                                                                              int minRating,
                                                                              int maxRating)
{
    PromptOptions options;
    options.title = "Rate";
    options.message = message;
    options.type = Rating;
    options.minLength = minRating;
    options.maxLength = maxRating;

    auto response = getResponseFromUser(options);
    m_responseHistory.append(response);
    emit responseReceived(response);
    return response;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::collectFeedback(const QString &prompt)
{
    return promptText(prompt, "Feedback");
}

void InteractivePromptSystem::showInfo(const QString &message, const QString &title)
{
    if (!m_interactiveMode) return;

    std::cout << "\n[INFO] " << title.toStdString() << ": " << message.toStdString() << "\n\n";
}

void InteractivePromptSystem::showWarning(const QString &message, const QString &title)
{
    if (!m_interactiveMode) return;

    std::cout << "\n[WARNING] " << title.toStdString() << ": " << message.toStdString() << "\n\n";
}

void InteractivePromptSystem::showError(const QString &message, const QString &title)
{
    if (!m_interactiveMode) return;

    std::cerr << "\n[ERROR] " << title.toStdString() << ": " << message.toStdString() << "\n\n";
}

void InteractivePromptSystem::showSuccess(const QString &message, const QString &title)
{
    if (!m_interactiveMode) return;

    std::cout << "\n[SUCCESS] " << title.toStdString() << ": " << message.toStdString() << "\n\n";
}

void InteractivePromptSystem::displayTable(const QString &title,
                                         const QStringList &headers,
                                         const QList<QStringList> &rows)
{
    if (!m_interactiveMode) return;

    std::cout << "\n" << title.toStdString() << "\n";
    
    // 打印表头
    for (const auto &header : headers) {
        std::cout << header.toStdString() << " | ";
    }
    std::cout << "\n";
    std::cout << std::string(80, '-') << "\n";

    // 打印行
    for (const auto &row : rows) {
        for (const auto &cell : row) {
            std::cout << cell.toStdString() << " | ";
        }
        std::cout << "\n";
    }
    std::cout << "\n";
}

void InteractivePromptSystem::setDefaultTimeout(int milliseconds)
{
    m_defaultTimeout = qMax(1000, milliseconds);
}

int InteractivePromptSystem::getDefaultTimeout() const
{
    return m_defaultTimeout;
}

void InteractivePromptSystem::setInteractiveMode(bool interactive)
{
    m_interactiveMode = interactive;
}

bool InteractivePromptSystem::isInteractiveMode() const
{
    return m_interactiveMode;
}

QList<InteractivePromptSystem::PromptResponse> InteractivePromptSystem::getResponseHistory()
{
    return m_responseHistory;
}

void InteractivePromptSystem::clearResponseHistory()
{
    m_responseHistory.clear();
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::getResponseFromUser(const PromptOptions &options)
{
    emit promptDisplayed(options);
    
    PromptResponse response;
    response.timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);

    if (!m_interactiveMode) {
        return createDefaultResponse(options);
    }

    std::cout << "\n" << options.title.toStdString() << "\n";
    std::cout << options.message.toStdString() << "\n";

    switch (options.type) {
        case Confirmation: {
            std::string input;
            std::cout << "(yes/no): ";
            std::cin >> input;
            response.accepted = (input == "yes" || input == "y");
            response.value = response.accepted ? "Yes" : "No";
            break;
        }

        case Choice: {
            for (int i = 0; i < options.choices.size(); ++i) {
                std::cout << (i + 1) << ". " << options.choices[i].toStdString() << "\n";
            }
            int choice;
            std::cout << "Select (1-" << options.choices.size() << "): ";
            std::cin >> choice;
            
            if (choice >= 1 && choice <= options.choices.size()) {
                response.selectedIndex = choice - 1;
                response.value = options.choices[choice - 1];
                response.accepted = true;
            }
            break;
        }

        case TextInput: {
            std::string input;
            std::cout << ": ";
            std::getline(std::cin, input);
            
            response.value = QString::fromStdString(input);
            response.accepted = validateInput(response.value, options);
            break;
        }

        case NumberInput: {
            double number;
            std::cout << ": ";
            std::cin >> number;
            
            response.value = QString::number(number);
            response.accepted = true;
            break;
        }

        case PasswordInput: {
            std::string input;
            std::cout << ": ";
            std::getline(std::cin, input);
            
            response.value = QString::fromStdString(input);
            response.accepted = !response.value.isEmpty();
            break;
        }

        default:
            response = createDefaultResponse(options);
            break;
    }

    return response;
}

bool InteractivePromptSystem::validateInput(const QString &input, const PromptOptions &options)
{
    if (options.required && input.isEmpty()) {
        return false;
    }

    if (options.minLength > 0 && input.length() < options.minLength) {
        return false;
    }

    if (options.maxLength > 0 && input.length() > options.maxLength) {
        return false;
    }

    return true;
}

QString InteractivePromptSystem::formatPromptMessage(const PromptOptions &options)
{
    QString formatted = options.title + ": " + options.message;
    
    if (!options.helpText.isEmpty()) {
        formatted += "\n[Help: " + options.helpText + "]";
    }

    return formatted;
}

InteractivePromptSystem::PromptResponse InteractivePromptSystem::createDefaultResponse(const PromptOptions &options)
{
    PromptResponse response;
    response.timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);

    switch (options.type) {
        case Confirmation:
            response.accepted = options.defaultValue == "Yes";
            response.value = options.defaultValue;
            break;

        case Choice:
            if (!options.choices.isEmpty()) {
                response.value = options.choices.first();
                response.selectedIndex = 0;
                response.accepted = true;
            }
            break;

        case TextInput:
            response.value = options.defaultValue;
            response.accepted = !options.required || !options.defaultValue.isEmpty();
            break;

        default:
            response.accepted = !options.required;
            break;
    }

    return response;
}
