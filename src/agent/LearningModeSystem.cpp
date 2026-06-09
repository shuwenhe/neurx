#include "LearningModeSystem.h"
#include <QUuid>
#include <QDateTime>
#include <QRegularExpression>
#include <QDebug>
#include <algorithm>

LearningModeSystem::LearningModeSystem(QObject *parent)
    : QObject(parent)
{
}

LearningModeSystem::~LearningModeSystem() {}

LearningModeSystem::LearningSession LearningModeSystem::startLearningSession()
{
    LearningSession session;
    session.sessionId = QUuid::createUuid().toString();
    session.isActive = true;
    session.totalContributions = 0;
    session.userContributions = 0;
    session.autoImplementations = 0;

    m_currentSession = session;
    m_sessions[session.sessionId] = session;

    emit sessionStarted(session.sessionId);
    return session;
}

void LearningModeSystem::endLearningSession(const QString &sessionId)
{
    if (m_sessions.contains(sessionId)) {
        m_sessions[sessionId].isActive = false;
        emit sessionEnded(sessionId);
    }
}

LearningModeSystem::LearningSession LearningModeSystem::getCurrentSession() const
{
    return m_currentSession;
}

QList<LearningModeSystem::ContributionPoint> LearningModeSystem::identifyContributionPoints(const QString &codeContext)
{
    QList<ContributionPoint> points;

    // 分析代码上下文
    QStringList lines = codeContext.split("\n");
    
    for (int i = 0; i < lines.size(); ++i) {
        const auto &line = lines[i];
        
        // 识别错误处理部分
        if (line.contains("if") && line.contains("error")) {
            ContributionPoint point;
            point.lineNumber = i + 1;
            point.type = ErrorHandling;
            point.context = line;
            point.description = "Error handling strategy";
            point.hint = "Consider what error cases need handling and appropriate responses";
            points.append(point);
        }
        
        // 识别算法部分
        if (line.contains("for") || line.contains("while") || line.contains("sort")) {
            ContributionPoint point;
            point.lineNumber = i + 1;
            point.type = AlgorithmChoice;
            point.context = line;
            point.description = "Algorithm implementation";
            point.hint = "What algorithm would be most efficient here?";
            points.append(point);
        }
        
        // 识别数据结构选择
        if (line.contains("map") || line.contains("list") || line.contains("set") || 
            line.contains("vector") || line.contains("queue")) {
            ContributionPoint point;
            point.lineNumber = i + 1;
            point.type = DataStructureDecision;
            point.context = line;
            point.description = "Data structure choice";
            point.hint = "Is this the optimal data structure for the use case?";
            points.append(point);
        }
        
        // 识别设计模式
        if (line.contains("class") && (line.contains("Manager") || line.contains("Factory") || line.contains("Builder"))) {
            ContributionPoint point;
            point.lineNumber = i + 1;
            point.type = DesignPattern;
            point.context = line;
            point.description = "Design pattern implementation";
            point.hint = "What design pattern best fits this requirement?";
            points.append(point);
        }
    }

    return points;
}

bool LearningModeSystem::shouldRequestUserContribution(const ContributionType &type)
{
    // 根据交互级别决定是否请求用户参与
    switch (type) {
        case BusinessLogic:
            return m_interactivityLevel >= 6;
        case ErrorHandling:
            return m_interactivityLevel >= 7;
        case AlgorithmChoice:
            return m_interactivityLevel >= 5;
        case DataStructureDecision:
            return m_interactivityLevel >= 6;
        case UXDecision:
            return m_interactivityLevel >= 7;
        case DesignPattern:
            return m_interactivityLevel >= 5;
        case ArchitectureChoice:
            return m_interactivityLevel >= 4;
        default:
            return false;
    }
}

QString LearningModeSystem::generateContributionPrompt(const ContributionPoint &point)
{
    QString prompt;
    
    switch (point.type) {
        case BusinessLogic:
            prompt = QString("Business Logic Contribution Point:\n\n"
                           "Location: %1\n"
                           "Context: %2\n\n"
                           "Hint: %3\n\n"
                           "Please implement the business logic for this section.")
                       .arg(QString::number(point.lineNumber))
                       .arg(point.context)
                       .arg(point.hint);
            break;
            
        case ErrorHandling:
            prompt = QString("Error Handling Strategy:\n\n"
                           "Location: %1\n"
                           "Context: %2\n\n"
                           "Hint: %3\n\n"
                           "What error cases should be handled? How should they be handled?")
                       .arg(QString::number(point.lineNumber))
                       .arg(point.context)
                       .arg(point.hint);
            break;
            
        case AlgorithmChoice:
            prompt = QString("Algorithm Implementation:\n\n"
                           "Location: %1\n"
                           "Context: %2\n\n"
                           "Hint: %3\n\n"
                           "Choose and implement the most efficient algorithm for this task.")
                       .arg(QString::number(point.lineNumber))
                       .arg(point.context)
                       .arg(point.hint);
            break;
            
        case DesignPattern:
            prompt = QString("Design Pattern:\n\n"
                           "Location: %1\n"
                           "Context: %2\n\n"
                           "Hint: %3\n\n"
                           "What design pattern would best serve this requirement?")
                       .arg(QString::number(point.lineNumber))
                       .arg(point.context)
                       .arg(point.hint);
            break;
            
        default:
            prompt = QString("Code Contribution:\n\nLocation: %1\nContext: %2")
                       .arg(QString::number(point.lineNumber))
                       .arg(point.context);
            break;
    }
    
    return prompt;
}

bool LearningModeSystem::acceptUserContribution(const QString &sessionId,
                                                const ContributionPoint &point,
                                                const QString &userCode)
{
    if (!m_sessions.contains(sessionId)) {
        return false;
    }

    m_sessions[sessionId].userContributions++;
    m_sessions[sessionId].totalContributions++;

    // 在概念学习中添加
    QString concept;
    switch (point.type) {
        case ErrorHandling:
            concept = "Error Handling";
            break;
        case AlgorithmChoice:
            concept = "Algorithm Design";
            break;
        case DesignPattern:
            concept = "Design Patterns";
            break;
        case DataStructureDecision:
            concept = "Data Structures";
            break;
        default:
            concept = "Software Engineering";
            break;
    }
    
    if (!m_sessions[sessionId].concepts.contains(concept)) {
        m_sessions[sessionId].concepts.append(concept);
        emit conceptLearned(concept);
    }

    return true;
}

void LearningModeSystem::provideEducationalInsight(const ContributionPoint &point, const QString &concept)
{
    QString insight;
    
    if (concept.contains("Error", Qt::CaseInsensitive)) {
        insight = "Error handling is crucial for robust software. Consider all failure paths "
                 "and handle each appropriately.";
    } else if (concept.contains("Algorithm", Qt::CaseInsensitive)) {
        insight = "Algorithm choice significantly impacts performance. Consider time and space "
                 "complexity trade-offs.";
    } else if (concept.contains("Pattern", Qt::CaseInsensitive)) {
        insight = "Design patterns provide proven solutions to common problems. They make code "
                 "more maintainable and scalable.";
    } else if (concept.contains("Data", Qt::CaseInsensitive)) {
        insight = "Selecting the right data structure is key. Different structures have different "
                 "trade-offs for insertion, deletion, and search operations.";
    } else {
        insight = "This is an important design decision. Consider the requirements and constraints "
                 "carefully.";
    }
    
    emit educationalInsightProvided(concept, insight);
}

QString LearningModeSystem::analyzeCodeContext(const QString &code, int lineStart, int lineEnd)
{
    QString analysis;
    
    QStringList lines = code.split("\n");
    if (lineStart >= 0 && lineEnd < lines.size()) {
        for (int i = lineStart; i <= lineEnd && i < lines.size(); ++i) {
            analysis += lines[i] + "\n";
        }
    }
    
    // 分析代码特征
    if (analysis.contains("error") || analysis.contains("exception")) {
        analysis += "\n[Contains error handling]";
    }
    if (analysis.contains("for") || analysis.contains("while")) {
        analysis += "\n[Contains loops]";
    }
    if (analysis.contains("if") && analysis.contains("else")) {
        analysis += "\n[Contains conditional logic]";
    }
    
    return analysis;
}

QStringList LearningModeSystem::extractDesignPatterns(const QString &code)
{
    QStringList patterns;
    
    if (code.contains("Factory")) patterns.append("Factory Pattern");
    if (code.contains("Singleton")) patterns.append("Singleton Pattern");
    if (code.contains("Builder")) patterns.append("Builder Pattern");
    if (code.contains("Observer") || code.contains("signal") || code.contains("slot")) 
        patterns.append("Observer Pattern");
    if (code.contains("Strategy")) patterns.append("Strategy Pattern");
    if (code.contains("Decorator")) patterns.append("Decorator Pattern");
    if (code.contains("Adapter")) patterns.append("Adapter Pattern");
    if (code.contains("Template")) patterns.append("Template Method Pattern");
    
    return patterns;
}

QStringList LearningModeSystem::identifyTradeoffs(const QString &codeContext)
{
    QStringList tradeoffs;
    
    if (codeContext.contains("vector") || codeContext.contains("list")) {
        tradeoffs.append("Vector: Fast random access, slow insertion");
        tradeoffs.append("List: Slow access, fast insertion/deletion");
    }
    
    if (codeContext.contains("recursion") || codeContext.contains("loop")) {
        tradeoffs.append("Recursion: Elegant, risk of stack overflow");
        tradeoffs.append("Loop: Iterative, more explicit control");
    }
    
    if (codeContext.contains("cache") || codeContext.contains("memory")) {
        tradeoffs.append("Space-time trade-off: More memory for faster access");
    }
    
    return tradeoffs;
}

QString LearningModeSystem::suggestNextLearningTopic(const QString &sessionId)
{
    if (!m_sessions.contains(sessionId)) {
        return "";
    }
    
    const auto &session = m_sessions[sessionId];
    
    if (!session.concepts.contains("Design Patterns")) {
        return "Design Patterns";
    } else if (!session.concepts.contains("Algorithm Design")) {
        return "Algorithm Design";
    } else if (!session.concepts.contains("Data Structures")) {
        return "Data Structures";
    } else if (!session.concepts.contains("Error Handling")) {
        return "Error Handling";
    }
    
    return "Advanced Architecture";
}

QStringList LearningModeSystem::getLearningPath() const
{
    return {
        "Basic Syntax",
        "Data Structures",
        "Algorithm Design",
        "Design Patterns",
        "Error Handling",
        "Advanced Architecture",
        "Performance Optimization"
    };
}

void LearningModeSystem::setInteractivityLevel(int level)
{
    m_interactivityLevel = qBound(1, level, 10);
}

int LearningModeSystem::getInteractivityLevel() const
{
    return m_interactivityLevel;
}

void LearningModeSystem::setAutoImplementThreshold(double threshold)
{
    m_autoImplementThreshold = qBound(0.0, threshold, 1.0);
}

double LearningModeSystem::getAutoImplementThreshold() const
{
    return m_autoImplementThreshold;
}

LearningModeSystem::SessionFeedback LearningModeSystem::collectSessionFeedback(const QString &sessionId)
{
    SessionFeedback feedback;
    
    if (m_sessions.contains(sessionId)) {
        const auto &session = m_sessions[sessionId];
        feedback.userContributions = session.userContributions;
        feedback.conceptsLearned = session.concepts.size();
        feedback.totalTime = 0;  // 应该在实际使用中计算
    }
    
    return feedback;
}

LearningModeSystem::ContributionType LearningModeSystem::classifyContributionType(const QString &codeContext)
{
    if (codeContext.contains("error") || codeContext.contains("exception")) {
        return ErrorHandling;
    }
    if (codeContext.contains("for") || codeContext.contains("while") || codeContext.contains("sort")) {
        return AlgorithmChoice;
    }
    if (codeContext.contains("class") && codeContext.contains("Manager")) {
        return DesignPattern;
    }
    
    return Unknown;
}

QString LearningModeSystem::extractBusinessLogic(const QString &code)
{
    return code;
}

QString LearningModeSystem::extractErrorHandling(const QString &code)
{
    if (code.contains("if") && code.contains("error")) {
        return code;
    }
    return "";
}

QString LearningModeSystem::extractAlgorithmArea(const QString &code)
{
    if (code.contains("for") || code.contains("while")) {
        return code;
    }
    return "";
}

bool LearningModeSystem::isComplexEnough(const QString &code) const
{
    return code.size() > 50;
}

bool LearningModeSystem::shouldAutoImplement(const QString &codeContext) const
{
    // 简单的启发式：如果代码相对简单且interactivityLevel较低，则自动实现
    double complexity = static_cast<double>(codeContext.size()) / 1000.0;
    double interactivityFactor = m_interactivityLevel / 10.0;
    
    double score = complexity * (1.0 - interactivityFactor);
    return score < m_autoImplementThreshold;
}
