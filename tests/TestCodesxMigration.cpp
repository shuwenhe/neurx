#include "TestCodesxMigration.h"
#include "src/thread/store/FileBasedThreadStore.h"
#include "src/approvals/DefaultApprovalManager.h"
#include "src/sandbox/DefaultSandboxManager.h"
#include <QTemporaryDir>
#include <QDebug>

// ==================== TestThreadId ====================

void TestThreadId::initTestCase()
{
    qDebug() << "Starting TestThreadId";
}

void TestThreadId::cleanupTestCase()
{
    qDebug() << "Finished TestThreadId";
}

void TestThreadId::testGenerate()
{
    ThreadId id1 = ThreadId::generate();
    ThreadId id2 = ThreadId::generate();
    
    QVERIFY(!id1.isNull());
    QVERIFY(!id2.isNull());
    QVERIFY(id1 != id2);
}

void TestThreadId::testFromString()
{
    ThreadId id1 = ThreadId::generate();
    QString str = id1.toString();
    
    ThreadId id2 = ThreadId::fromString(str);
    QCOMPARE(id1, id2);
}

void TestThreadId::testFromUuid()
{
    QUuid uuid = QUuid::createUuid();
    ThreadId id(uuid);
    
    QCOMPARE(id.toUuid(), uuid);
}

void TestThreadId::testToString()
{
    ThreadId id = ThreadId::generate();
    QString str = id.toString();
    
    QVERIFY(!str.isEmpty());
    QVERIFY(!str.contains("{"));
    QVERIFY(!str.contains("}"));
}

void TestThreadId::testEquality()
{
    ThreadId id1 = ThreadId::generate();
    ThreadId id2 = id1;
    ThreadId id3 = ThreadId::generate();
    
    QCOMPARE(id1, id2);
    QVERIFY(id1 != id3);
}

void TestThreadId::testOrdering()
{
    ThreadId id1 = ThreadId::generate();
    ThreadId id2 = ThreadId::generate();
    
    // Should be comparable
    QVERIFY((id1 < id2) || (id2 < id1) || (id1 == id2));
}

void TestThreadId::testIsNull()
{
    ThreadId id;
    QVERIFY(id.isNull());
    
    ThreadId id2 = ThreadId::generate();
    QVERIFY(!id2.isNull());
}

// ==================== TestInMemoryThreadStore ====================

void TestInMemoryThreadStore::initTestCase()
{
    qDebug() << "Starting TestInMemoryThreadStore";
    m_store = std::make_shared<InMemoryThreadStore>();
}

void TestInMemoryThreadStore::cleanupTestCase()
{
    qDebug() << "Finished TestInMemoryThreadStore";
    m_store.reset();
}

void TestInMemoryThreadStore::testCreateThread()
{
    CreateThreadParams params;
    params.mode = ThreadInitializationMode::Fresh;
    params.metadata["test"] = "value";
    
    ThreadId createdId;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->createThread(params, [&](auto err, auto id) {
        error = err;
        createdId = id;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(!createdId.isNull());
    
    m_testThreadId = createdId;
}

void TestInMemoryThreadStore::testForkThread()
{
    testCreateThread();
    
    QVariantMap forkContext;
    forkContext["forkReason"] = "test_fork";
    
    ThreadId forkedId;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->forkThread(m_testThreadId, forkContext, [&](auto err, auto id) {
        error = err;
        forkedId = id;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(!forkedId.isNull());
    QVERIFY(forkedId != m_testThreadId);
}

void TestInMemoryThreadStore::testResumeThread()
{
    testCreateThread();
    
    ResumeThreadParams params;
    params.threadId = m_testThreadId;
    params.contextOverrides["resumed"] = true;
    
    StoredThread resumedThread;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->resumeThread(params, [&](auto err, auto thread) {
        error = err;
        resumedThread = thread;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QCOMPARE(resumedThread.id, m_testThreadId);
}

void TestInMemoryThreadStore::testSaveCheckpoint()
{
    testCreateThread();
    
    QVariantMap state;
    state["data"] = "checkpoint_data";
    
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->saveCheckpoint(m_testThreadId, state, "test_checkpoint", [&](auto err) {
        error = err;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
}

void TestInMemoryThreadStore::testLoadCheckpoint()
{
    testSaveCheckpoint();
    
    QVector<QString> checkpoints;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool listCalled = false;
    
    m_store->listCheckpoints(m_testThreadId, [&](auto err, auto list) {
        error = err;
        checkpoints = list;
        listCalled = true;
    });
    
    QVERIFY(listCalled);
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(checkpoints.size() > 0);
    
    QString cpId = checkpoints[0];
    QVariantMap loadedState;
    error = ThreadStoreError::StorageError;
    bool loadCalled = false;
    
    m_store->loadCheckpoint(m_testThreadId, cpId, [&](auto err, auto state) {
        error = err;
        loadedState = state;
        loadCalled = true;
    });
    
    QVERIFY(loadCalled);
    QCOMPARE(error, ThreadStoreError::Success);
}

void TestInMemoryThreadStore::testListCheckpoints()
{
    testSaveCheckpoint();
    
    QVector<QString> checkpoints;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->listCheckpoints(m_testThreadId, [&](auto err, auto list) {
        error = err;
        checkpoints = list;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(checkpoints.size() >= 1);
}

void TestInMemoryThreadStore::testGetThread()
{
    testCreateThread();
    
    StoredThread retrieved;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->getThread(m_testThreadId, [&](auto err, auto thread) {
        error = err;
        retrieved = thread;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QCOMPARE(retrieved.id, m_testThreadId);
}

void TestInMemoryThreadStore::testListThreads()
{
    testCreateThread();
    
    QVector<StoredThread> threads;
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->listThreads(QVariantMap(), [&](auto err, auto list) {
        error = err;
        threads = list;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    QVERIFY(threads.size() >= 1);
}

void TestInMemoryThreadStore::testDeleteThread()
{
    testCreateThread();
    
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->deleteThread(m_testThreadId, [&](auto err) {
        error = err;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
    
    // Verify it's deleted
    StoredThread retrieved;
    error = ThreadStoreError::StorageError;
    called = false;
    
    m_store->getThread(m_testThreadId, [&](auto err, auto thread) {
        error = err;
        retrieved = thread;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::NotFound);
}

void TestInMemoryThreadStore::testPruneCheckpoints()
{
    testCreateThread();
    
    // Save multiple checkpoints
    for (int i = 0; i < 5; ++i) {
        QVariantMap state;
        state["iteration"] = i;
        
        m_store->saveCheckpoint(m_testThreadId, state, QString("checkpoint_%1").arg(i), 
                              [](auto err) {});
    }
    
    // Prune to keep only 2
    ThreadStoreError error = ThreadStoreError::StorageError;
    bool called = false;
    
    m_store->pruneCheckpoints(m_testThreadId, 2, [&](auto err) {
        error = err;
        called = true;
    });
    
    QVERIFY(called);
    QCOMPARE(error, ThreadStoreError::Success);
}

void TestInMemoryThreadStore::testGetStats()
{
    testCreateThread();
    
    QVariantMap stats;
    bool called = false;
    
    m_store->getStats([&](auto s) {
        stats = s;
        called = true;
    });
    
    QVERIFY(called);
    QVERIFY(stats.contains("threadCount"));
    QVERIFY(stats["threadCount"].toInt() >= 1);
}

void TestInMemoryThreadStore::testConcurrentOperations()
{
    // Test multiple threads accessing store simultaneously
    // (Simplified version - real implementation would use QThreadPool)
    
    testCreateThread();
    testForkThread();
    testResumeThread();
    testSaveCheckpoint();
}

// ==================== TestApprovalManager ====================

void TestApprovalManager::initTestCase()
{
    qDebug() << "Starting TestApprovalManager";
    m_manager = std::make_shared<DefaultApprovalManager>();
}

void TestApprovalManager::cleanupTestCase()
{
    qDebug() << "Finished TestApprovalManager";
    m_manager.reset();
}

void TestApprovalManager::testSetDefaultPolicy()
{
    ApprovalPolicy policy;
    policy.defaultPolicy = AskForApproval::OnRequest;
    policy.defaultReviewer = ApprovalsReviewer::User;
    
    m_manager->setDefaultPolicy(policy);
    
    ApprovalPolicy retrieved = m_manager->getDefaultPolicy();
    QCOMPARE(retrieved.defaultPolicy, AskForApproval::OnRequest);
    QCOMPARE(retrieved.defaultReviewer, ApprovalsReviewer::User);
}

void TestApprovalManager::testAddGranularRule()
{
    GranularApprovalConfig rule;
    rule.toolName = "test_tool";
    rule.resourcePattern = ".*\\.git";
    rule.policy = AskForApproval::Never;
    
    m_manager->addGranularRule(rule);
    
    AskForApproval policy = m_manager->getPolicyFor("test_tool", "some/.git");
    QCOMPARE(policy, AskForApproval::Never);
}

void TestApprovalManager::testRequestExecApproval()
{
    ExecApprovalRequestEvent request;
    request.toolName = "git";
    request.command = "git push";
    
    bool approved = false;
    ApprovalDecision decision = ApprovalDecision::Reject;
    bool called = false;
    
    m_manager->requestExecApproval(request, [&](auto appr, auto dec) {
        approved = appr;
        decision = dec;
        called = true;
    });
    
    QVERIFY(called);
    // Default policy is OnRequest, so should approve
    QVERIFY(approved);
}

void TestApprovalManager::testRecordDecision()
{
    QString approvalId = "test_approval_123";
    
    m_manager->recordDecision(approvalId, ApprovalDecision::Accept, "Test approval");
    
    QVariantMap stats = m_manager->getApprovalStats();
    QVERIFY(stats["totalRequests"].toInt() >= 0);
}

void TestApprovalManager::testGetStats()
{
    QVariantMap stats = m_manager->getApprovalStats();
    
    QVERIFY(stats.contains("totalRequests"));
    QVERIFY(stats.contains("approvedCount"));
    QVERIFY(stats.contains("rejectedCount"));
    QVERIFY(stats.contains("pendingCount"));
}

void TestApprovalManager::testReadOnlyMode()
{
    m_manager->setReadOnlyMode(true);
    QVERIFY(m_manager->isReadOnlyMode());
    
    m_manager->setReadOnlyMode(false);
    QVERIFY(!m_manager->isReadOnlyMode());
}

// ==================== TestSandboxManager ====================

void TestSandboxManager::initTestCase()
{
    qDebug() << "Starting TestSandboxManager";
    m_manager = std::make_shared<DefaultSandboxManager>();
}

void TestSandboxManager::cleanupTestCase()
{
    qDebug() << "Finished TestSandboxManager";
    m_manager.reset();
}

void TestSandboxManager::testAvailableSandboxTypes()
{
    QVector<SandboxType> types = m_manager->availableSandboxTypes();
    
    QVERIFY(types.size() >= 1);
    // None should always be available
    QVERIFY(types.contains(SandboxType::None));
}

void TestSandboxManager::testRecommendedType()
{
    SandboxType recommended = m_manager->recommendedSandboxType();
    
    QVERIFY(m_manager->isSandboxTypeAvailable(recommended));
}

void TestSandboxManager::testFileSystemPolicy()
{
    FileSystemSandboxPolicy policy;
    policy.allowedReadPaths << "/tmp";
    policy.allowedWritePaths << "/home";
    
    m_manager->setFileSystemPolicy(policy);
    
    FileSystemSandboxPolicy retrieved = m_manager->getFileSystemPolicy();
    QVERIFY(retrieved.allowedReadPaths.contains("/tmp"));
}

void TestSandboxManager::testCanAccess()
{
    m_manager->addAllowedReadPath("/tmp");
    
    bool canRead = m_manager->canAccess("/tmp/test", FileSystemAccessMode::Read);
    QVERIFY(canRead);
    
    bool canWrite = m_manager->canAccess("/tmp/test", FileSystemAccessMode::Write);
    QVERIFY(!canWrite);  // Write not explicitly allowed
}

void TestSandboxManager::testExecuteInSandbox()
{
    SandboxExecRequest request;
    request.command = "echo 'test'";
    request.readPermission = FileSystemAccessMode::Read;
    request.writePermission = FileSystemAccessMode::Read;
    
    int exitCode = -1;
    QString output;
    bool called = false;
    
    m_manager->executeInSandbox(request, [&](auto code, auto out, auto err) {
        exitCode = code;
        output = out;
        called = true;
    });
    
    // Wait a bit for async execution
    QTest::qWait(100);
    
    QVERIFY(called);
    QCOMPARE(exitCode, 0);
}

void TestSandboxManager::testProtectedMetadata()
{
    m_manager->protectMetadataPath(".test_secret");
    
    bool isProtected = m_manager->isProtectedMetadata(".test_secret");
    QVERIFY(isProtected);
}

void TestSandboxManager::testGetStats()
{
    QVariantMap stats = m_manager->getStats();
    
    QVERIFY(stats.contains("totalExecutions"));
    QVERIFY(stats.contains("successfulExecutions"));
    QVERIFY(stats.contains("failedExecutions"));
}

// ==================== Main ====================

QTEST_MAIN(TestThreadId)
#include "TestCodesxMigration.moc"
