#include "RalphIterationEngine.h"
#include <QUuid>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>
#include <algorithm>

RalphIterationEngine::RalphIterationEngine(QObject *parent)
    : QObject(parent)
{
    m_statistics.totalLoops = 0;
    m_statistics.completedLoops = 0;
    m_statistics.failedLoops = 0;
}

RalphIterationEngine::~RalphIterationEngine() {}

RalphIterationEngine::RalphLoop RalphIterationEngine::startRalphLoop(const QString &prompt,
                                                                    const QString &completionPromise,
                                                                    const QString &workspaceRoot,
                                                                    int maxIterations)
{
    RalphLoop loop;
    loop.loopId = generateLoopId();
    loop.originalPrompt = prompt;
    loop.completionPromise = completionPromise;
    loop.maxIterations = (maxIterations > 0) ? maxIterations : m_maxIterationsGlobal;
    loop.currentIteration = 0;
    loop.status = Running;
    loop.workspaceRoot = workspaceRoot;
    loop.startTime = QDateTime::currentDateTime();
    loop.lastIterationTime = loop.startTime;

    m_loops[loop.loopId] = loop;
    m_statistics.totalLoops++;

    emit loopStarted(loop.loopId, prompt);

    return loop;
}

void RalphIterationEngine::stopRalphLoop(const QString &loopId)
{
    if (!m_loops.contains(loopId)) return;

    m_loops[loopId].status = Completed;
    m_statistics.completedLoops++;
    
    emit loopCompleted(loopId);
}

void RalphIterationEngine::pauseRalphLoop(const QString &loopId)
{
    if (!m_loops.contains(loopId)) return;
    
    m_loops[loopId].status = Paused;
    emit statusChanged(loopId, Paused);
}

void RalphIterationEngine::resumeRalphLoop(const QString &loopId)
{
    if (!m_loops.contains(loopId)) return;
    
    m_loops[loopId].status = Running;
    emit statusChanged(loopId, Running);
}

void RalphIterationEngine::cancelRalphLoop(const QString &loopId)
{
    if (!m_loops.contains(loopId)) return;
    
    m_loops[loopId].status = Cancelled;
    emit loopCancelled(loopId);
}

bool RalphIterationEngine::performIteration(const QString &loopId)
{
    if (!validateLoop(loopId)) {
        return false;
    }

    RalphLoop &loop = m_loops[loopId];

    if (!canContinueLoop(loop)) {
        if (loop.currentIteration >= loop.maxIterations) {
            loop.status = Failed;
            emit maxIterationsReached(loopId);
        }
        return false;
    }

    loop.currentIteration++;
    emit iterationStarted(loopId, loop.currentIteration);

    // 创建迭代上下文
    IterationContext context;
    context.iterationNumber = loop.currentIteration;
    context.prompt = injectPrompt(loopId);
    context.filestateSnapshot = getFileSnapshot(loop.workspaceRoot);
    context.gitHistorySnapshot = getGitSnapshot(loop.workspaceRoot);

    // 检查完成承诺
    QString proof;
    if (checkCompletionPromise(loopId, proof)) {
        context.completionPromiseFound = true;
        context.completionProof = proof;
        loop.status = Completed;
        m_statistics.completedLoops++;
        emit completionPromiseFound(loopId);
        emit loopCompleted(loopId);
        recordIteration(loopId, context);
        return true;
    }

    // 记录迭代
    recordIteration(loopId, context);
    loop.lastIterationTime = QDateTime::currentDateTime();

    // 检查无限循环
    if (checkForInfiniteLoop(loopId)) {
        emit infiniteLoopDetected(loopId);
    }

    // 检查进度
    if (detectProgress(loopId)) {
        QString progress = identifyProgressDirection(loopId);
        emit progressDetected(loopId, progress);
    }

    emit iterationCompleted(loopId, loop.currentIteration);
    
    m_statistics.totalIterations++;
    m_statistics.maxIterationsSingleLoop = qMax(m_statistics.maxIterationsSingleLoop, loop.currentIteration);
    
    return true;
}

bool RalphIterationEngine::checkCompletionPromise(const QString &loopId, QString &proof)
{
    if (!m_loops.contains(loopId)) {
        return false;
    }

    RalphLoop &loop = m_loops[loopId];
    QString searchPhrase = loop.completionPromise;

    proof = scanCompletionProof(loop.workspaceRoot, searchPhrase);
    return !proof.isEmpty();
}

QString RalphIterationEngine::injectPrompt(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return "";
    }

    const auto &loop = m_loops[loopId];
    
    // 构造带有迭代信息的提示
    QString injected = loop.originalPrompt;
    injected += QString("\n\n[Ralph Iteration %1/%2]\n")
                   .arg(loop.currentIteration)
                   .arg(loop.maxIterations > 0 ? QString::number(loop.maxIterations) : "unlimited");
    
    injected += "Current state:\n";
    
    // 添加修改的文件列表
    auto modified = getModifiedFiles(loopId);
    if (!modified.isEmpty()) {
        injected += "Modified files:\n";
        for (const auto &file : modified) {
            injected += QString("  - %1\n").arg(file);
        }
    }
    
    injected += "\nContinue improving until completion promise is found: " + loop.completionPromise;
    
    return injected;
}

RalphIterationEngine::RalphLoop RalphIterationEngine::getLoopStatus(const QString &loopId)
{
    if (m_loops.contains(loopId)) {
        return m_loops[loopId];
    }
    return RalphLoop();
}

RalphIterationEngine::LoopStatus RalphIterationEngine::getCurrentStatus(const QString &loopId)
{
    if (m_loops.contains(loopId)) {
        return m_loops[loopId].status;
    }
    return Idle;
}

int RalphIterationEngine::getCurrentIteration(const QString &loopId)
{
    if (m_loops.contains(loopId)) {
        return m_loops[loopId].currentIteration;
    }
    return 0;
}

QJsonArray RalphIterationEngine::getIterationHistory(const QString &loopId)
{
    if (m_loops.contains(loopId)) {
        return m_loops[loopId].iterationHistory;
    }
    return QJsonArray();
}

QStringList RalphIterationEngine::getModifiedFiles(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return QStringList();
    }

    return m_loops[loopId].modifiedFiles;
}

QJsonObject RalphIterationEngine::getFileSnapshot(const QString &workspaceRoot)
{
    QJsonObject snapshot;
    QJsonArray files;

    QDir dir(workspaceRoot);
    dir.setFilter(QDir::Files | QDir::NoDotAndDotDot);
    dir.setNameFilters({"*.cpp", "*.h", "*.ts", "*.js", "*.py"});

    for (const auto &fileInfo : dir.entryInfoList()) {
        QJsonObject fileObj;
        fileObj["path"] = fileInfo.filePath();
        fileObj["size"] = static_cast<int>(fileInfo.size());
        fileObj["modified"] = fileInfo.lastModified().toString(Qt::ISODate);
        files.append(fileObj);
    }

    snapshot["files"] = files;
    snapshot["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    return snapshot;
}

bool RalphIterationEngine::hasFilesChanged(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return false;
    }

    auto currentFiles = getModifiedFiles(loopId);
    return !currentFiles.isEmpty();
}

QJsonObject RalphIterationEngine::getGitSnapshot(const QString &workspaceRoot)
{
    QJsonObject snapshot;
    
    QProcess process;
    process.setWorkingDirectory(workspaceRoot);

    // 获取最近5次提交
    process.start("git", QStringList() << "log" << "-5" << "--pretty=format:%H|%s");
    process.waitForFinished();

    QJsonArray commits;
    QString output = QString::fromUtf8(process.readAllStandardOutput());
    for (const auto &line : output.split("\n")) {
        if (line.isEmpty()) continue;
        auto parts = line.split("|");
        if (parts.size() == 2) {
            QJsonObject commit;
            commit["hash"] = parts[0];
            commit["message"] = parts[1];
            commits.append(commit);
        }
    }

    snapshot["commits"] = commits;
    snapshot["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    return snapshot;
}

QString RalphIterationEngine::getGitDiff(const QString &loopId, int iteration)
{
    if (!m_loops.contains(loopId)) {
        return "";
    }

    // 此处可以实现获取特定迭代的git diff
    return "";
}

RalphIterationEngine::IterationContext RalphIterationEngine::analyzeIteration(const QString &loopId, int iteration)
{
    IterationContext context;
    context.iterationNumber = iteration;
    
    if (m_loops.contains(loopId)) {
        const auto &loop = m_loops[loopId];
        if (iteration <= loop.iterationHistory.size()) {
            auto iterObj = loop.iterationHistory[iteration - 1].toObject();
            context.prompt = iterObj["prompt"].toString();
            context.filestateSnapshot = iterObj["fileSnapshot"].toObject();
            context.completionPromiseFound = iterObj["completionFound"].toBool();
        }
    }
    
    return context;
}

QString RalphIterationEngine::identifyProgressDirection(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return "";
    }

    const auto &loop = m_loops[loopId];
    
    if (loop.modifiedFiles.isEmpty()) {
        return "No file modifications";
    }

    return QString("Modified %1 files in iteration %2")
               .arg(loop.modifiedFiles.size())
               .arg(loop.currentIteration);
}

bool RalphIterationEngine::detectInfiniteLoop(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return false;
    }

    const auto &loop = m_loops[loopId];
    
    // 检查最后5次迭代是否修改了相同的文件
    if (loop.iterationHistory.size() >= 5) {
        QSet<QString> lastModified;
        
        for (int i = qMax(0, loop.iterationHistory.size() - 5); i < loop.iterationHistory.size(); ++i) {
            auto iterObj = loop.iterationHistory[i].toObject();
            auto files = iterObj["modifiedFiles"].toArray();
            
            for (const auto &file : files) {
                lastModified.insert(file.toString());
            }
        }
        
        // 如果最后5次迭代修改的文件完全相同，可能是无限循环
        return lastModified.size() <= 2;
    }
    
    return false;
}

bool RalphIterationEngine::detectProgress(const QString &loopId)
{
    if (!m_loops.contains(loopId)) {
        return false;
    }

    const auto &loop = m_loops[loopId];
    
    // 检查是否有新的文件被修改
    if (loop.currentIteration == 1) {
        return !loop.modifiedFiles.isEmpty();
    }
    
    // 检查是否有完成承诺的增加证据
    if (loop.currentIteration > 1 && loop.iterationHistory.size() >= 2) {
        auto currentIter = loop.iterationHistory[loop.iterationHistory.size() - 1].toObject();
        auto previousIter = loop.iterationHistory[loop.iterationHistory.size() - 2].toObject();
        
        // 如果错误减少，表示有进展
        int currentErrors = currentIter["errors"].toInt(0);
        int previousErrors = previousIter["errors"].toInt(0);
        
        return currentErrors < previousErrors;
    }
    
    return false;
}

void RalphIterationEngine::setMaxIterationsGlobal(int max)
{
    m_maxIterationsGlobal = qMax(1, max);
}

int RalphIterationEngine::getMaxIterationsGlobal() const
{
    return m_maxIterationsGlobal;
}

void RalphIterationEngine::setIterationTimeout(int milliseconds)
{
    m_iterationTimeout = qMax(1000, milliseconds);
}

int RalphIterationEngine::getIterationTimeout() const
{
    return m_iterationTimeout;
}

RalphIterationEngine::RalphStatistics RalphIterationEngine::getStatistics() const
{
    return m_statistics;
}

QString RalphIterationEngine::generateLoopId()
{
    return QUuid::createUuid().toString();
}

bool RalphIterationEngine::validateLoop(const QString &loopId)
{
    return m_loops.contains(loopId) && m_loops[loopId].status == Running;
}

bool RalphIterationEngine::canContinueLoop(const RalphLoop &loop)
{
    if (loop.status != Running) {
        return false;
    }

    if (loop.maxIterations > 0 && loop.currentIteration >= loop.maxIterations) {
        return false;
    }

    return true;
}

void RalphIterationEngine::recordIteration(const QString &loopId, const IterationContext &context)
{
    if (!m_loops.contains(loopId)) {
        return;
    }

    RalphLoop &loop = m_loops[loopId];
    
    QJsonObject iterObj;
    iterObj["iteration"] = context.iterationNumber;
    iterObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    iterObj["prompt"] = context.prompt;
    iterObj["fileSnapshot"] = context.filestateSnapshot;
    iterObj["gitSnapshot"] = context.gitHistorySnapshot;
    iterObj["completionFound"] = context.completionPromiseFound;
    iterObj["completionProof"] = context.completionProof;
    iterObj["errors"] = context.errorLog.size();
    
    QJsonArray errorArray;
    for (const auto &error : context.errorLog) {
        errorArray.append(error);
    }
    iterObj["errorLog"] = errorArray;

    loop.iterationHistory.append(iterObj);
}

void RalphIterationEngine::updateLoopStatus(const QString &loopId, LoopStatus status)
{
    if (m_loops.contains(loopId)) {
        m_loops[loopId].status = status;
        emit statusChanged(loopId, status);
    }
}

bool RalphIterationEngine::checkForInfiniteLoop(const QString &loopId)
{
    return detectInfiniteLoop(loopId);
}

QStringList RalphIterationEngine::detectModifiedFiles(const QString &workspaceRoot)
{
    QStringList modified;
    
    QProcess process;
    process.setWorkingDirectory(workspaceRoot);
    process.start("git", QStringList() << "status" << "--porcelain");
    process.waitForFinished();

    QString output = QString::fromUtf8(process.readAllStandardOutput());
    for (const auto &line : output.split("\n")) {
        if (!line.isEmpty()) {
            modified.append(line.mid(3));
        }
    }

    return modified;
}

QString RalphIterationEngine::scanCompletionProof(const QString &workspaceRoot, const QString &searchPhrase)
{
    // 在所有文件中搜索completion promise
    QDir dir(workspaceRoot);
    dir.setFilter(QDir::Files | QDir::NoDotAndDotDot);
    dir.setNameFilters({"*.cpp", "*.h", "*.ts", "*.js", "*.py", "*.md", "*.txt"});

    for (const auto &fileInfo : dir.entryInfoList(QDir::AllDirs | QDir::NoDotAndDotDot)) {
        // 递归搜索
    }

    // 检查git log
    QProcess process;
    process.setWorkingDirectory(workspaceRoot);
    process.start("git", QStringList() << "log" << "-p" << "--grep=" + searchPhrase);
    process.waitForFinished();

    if (process.exitCode() == 0) {
        return QString::fromUtf8(process.readAllStandardOutput());
    }

    return "";
}
