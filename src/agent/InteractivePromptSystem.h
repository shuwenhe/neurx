#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>

/**
 * @class InteractivePromptSystem
 * @brief 交互式提示系统 - 用户交互接口
 * 
 * 提供用户交互的核心功能：
 * - 确认对话框
 * - 选择提示
 * - 文本输入
 * - 多选
 * - 进度指示
 * - 反馈收集
 */
class InteractivePromptSystem : public QObject {
    Q_OBJECT

public:
    enum PromptType {
        Confirmation,      // 是/否确认
        Choice,            // 单选
        MultipleChoice,    // 多选
        TextInput,         // 文本输入
        NumberInput,       // 数字输入
        PasswordInput,     // 密码输入
        FileSelection,     // 文件选择
        ProgressIndicator, // 进度指示
        Menu,              // 菜单
        Rating             // 评分
    };
    Q_ENUM(PromptType)

    struct PromptOptions {
        QString title;
        QString message;
        PromptType type;
        QStringList choices;
        QString defaultValue;
        bool required = false;
        int minLength = 0;
        int maxLength = -1;
        QString helpText;
        bool showInUI = true;
    };

    struct PromptResponse {
        bool accepted = false;
        QString value;
        QStringList selectedValues;
        int selectedIndex = -1;
        double rating = 0.0;
        QString timestamp;
    };

    explicit InteractivePromptSystem(QObject *parent = nullptr);
    ~InteractivePromptSystem();

    // 核心交互方法
    PromptResponse promptConfirmation(const QString &message, const QString &title = "Confirm");
    PromptResponse promptChoice(const QString &message, 
                                const QStringList &choices,
                                const QString &title = "Choose");
    PromptResponse promptMultipleChoice(const QString &message,
                                       const QStringList &choices,
                                       const QString &title = "Select");
    PromptResponse promptText(const QString &message,
                             const QString &title = "Input",
                             const QString &defaultValue = "");
    PromptResponse promptNumber(const QString &message,
                               const QString &title = "Enter Number",
                               double defaultValue = 0.0);
    PromptResponse promptPassword(const QString &message,
                                 const QString &title = "Password");
    PromptResponse promptFileSelection(const QString &title = "Select File",
                                      const QString &directory = "");

    // 进度显示
    void showProgress(const QString &message, int current, int total);
    void hideProgress();
    void updateProgressMessage(const QString &message);

    // 菜单系统
    int showMenu(const QString &title, const QStringList &options);
    
    // 反馈收集
    PromptResponse collectRating(const QString &message,
                                 int minRating = 1,
                                 int maxRating = 5);
    PromptResponse collectFeedback(const QString &prompt);

    // 通知
    void showInfo(const QString &message, const QString &title = "Information");
    void showWarning(const QString &message, const QString &title = "Warning");
    void showError(const QString &message, const QString &title = "Error");
    void showSuccess(const QString &message, const QString &title = "Success");

    // 表格显示
    void displayTable(const QString &title,
                     const QStringList &headers,
                     const QList<QStringList> &rows);

    // 配置
    void setDefaultTimeout(int milliseconds);
    int getDefaultTimeout() const;
    void setInteractiveMode(bool interactive);
    bool isInteractiveMode() const;

    // 历史记录
    QList<PromptResponse> getResponseHistory();
    void clearResponseHistory();

signals:
    void promptDisplayed(const PromptOptions &options);
    void responseReceived(const PromptResponse &response);
    void promptCancelled();
    void progressUpdated(int current, int total);

protected:
    virtual PromptResponse getResponseFromUser(const PromptOptions &options);

private:
    QList<PromptResponse> m_responseHistory;
    int m_defaultTimeout = 30000;  // 30 seconds
    bool m_interactiveMode = true;

    // 辅助方法
    bool validateInput(const QString &input, const PromptOptions &options);
    QString formatPromptMessage(const PromptOptions &options);
    PromptResponse createDefaultResponse(const PromptOptions &options);
};
