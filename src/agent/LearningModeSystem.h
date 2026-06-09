#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QMap>

/**
 * @class LearningModeSystem
 * @brief 学习模式系统 - 交互式代码学习功能
 * 
 * 提供交互式学习体验：
 * - 识别适合用户参与的代码点
 * - 请求有意义的代码贡献
 * - 提供教育性insights
 * - 合适时自动实现，不适合时请求参与
 */
class LearningModeSystem : public QObject {
    Q_OBJECT

public:
    enum ContributionType {
        BusinessLogic,
        ErrorHandling,
        AlgorithmChoice,
        DataStructureDecision,
        UXDecision,
        DesignPattern,
        ArchitectureChoice,
        Unknown
    };
    Q_ENUM(ContributionType)

    struct ContributionPoint {
        QString location;              // 代码位置
        ContributionType type;         // 贡献类型
        QString description;           // 描述
        QString context;               // 上下文
        QString hint;                  // 提示
        int lineNumber = 0;
        QString fileName;
    };

    struct LearningSession {
        QString sessionId;
        bool isActive = false;
        int totalContributions = 0;
        int userContributions = 0;
        int autoImplementations = 0;
        QStringList concepts;          // 学习的概念
        QStringList patterns;          // 学习的模式
    };

    explicit LearningModeSystem(QObject *parent = nullptr);
    ~LearningModeSystem();

    // 学习会话管理
    LearningSession startLearningSession();
    void endLearningSession(const QString &sessionId);
    LearningSession getCurrentSession() const;

    // 贡献点识别
    QList<ContributionPoint> identifyContributionPoints(const QString &codeContext);
    bool shouldRequestUserContribution(const ContributionType &type);

    // 用户交互
    QString generateContributionPrompt(const ContributionPoint &point);
    bool acceptUserContribution(const QString &sessionId, 
                                const ContributionPoint &point,
                                const QString &userCode);
    void provideEducationalInsight(const ContributionPoint &point, const QString &concept);

    // 代码分析
    QString analyzeCodeContext(const QString &code, int lineStart, int lineEnd);
    QStringList extractDesignPatterns(const QString &code);
    QStringList identifyTradeoffs(const QString &codeContext);

    // 学习路径
    QString suggestNextLearningTopic(const QString &sessionId);
    QStringList getLearningPath() const;

    // 配置
    void setInteractivityLevel(int level);  // 1-10, 10 = 最大交互
    int getInteractivityLevel() const;
    void setAutoImplementThreshold(double threshold);
    double getAutoImplementThreshold() const;

    // 反馈
    struct SessionFeedback {
        int totalTime = 0;              // 总时间(秒)
        int userContributions = 0;
        int conceptsLearned = 0;
        double satisfactionScore = 0.0;
        QString notes;
    };
    
    SessionFeedback collectSessionFeedback(const QString &sessionId);

signals:
    void sessionStarted(const QString &sessionId);
    void sessionEnded(const QString &sessionId);
    void contributionPointFound(const ContributionPoint &point);
    void userContributionRequested(const ContributionPoint &point);
    void educationalInsightProvided(const QString &concept, const QString &explanation);
    void autoImplementationExecuted(const ContributionPoint &point);
    void conceptLearned(const QString &concept);
    void sessionFeedbackReady(const SessionFeedback &feedback);

private:
    LearningSession m_currentSession;
    int m_interactivityLevel = 7;
    double m_autoImplementThreshold = 0.7;
    QMap<QString, LearningSession> m_sessions;

    // 辅助方法
    ContributionType classifyContributionType(const QString &codeContext);
    QString extractBusinessLogic(const QString &code);
    QString extractErrorHandling(const QString &code);
    QString extractAlgorithmArea(const QString &code);
    bool isComplexEnough(const QString &code) const;
    bool shouldAutoImplement(const QString &codeContext) const;
};
