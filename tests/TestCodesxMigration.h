#pragma once

#include <QObject>
#include <QTest>
#include "src/thread/ThreadId.h"
#include "src/thread/ThreadTypes.h"
#include "src/thread/store/ThreadStore.h"
#include "src/thread/store/InMemoryThreadStore.h"

/**
 * @class TestThreadId
 * @brief Unit tests for ThreadId
 */
class TestThreadId : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    
    void testGenerate();
    void testFromString();
    void testFromUuid();
    void testToString();
    void testEquality();
    void testOrdering();
    void testIsNull();
};

/**
 * @class TestInMemoryThreadStore
 * @brief Unit tests for InMemoryThreadStore
 */
class TestInMemoryThreadStore : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    
    void testCreateThread();
    void testForkThread();
    void testResumeThread();
    void testSaveCheckpoint();
    void testLoadCheckpoint();
    void testListCheckpoints();
    void testGetThread();
    void testListThreads();
    void testDeleteThread();
    void testPruneCheckpoints();
    void testGetStats();
    void testConcurrentOperations();

private:
    std::shared_ptr<InMemoryThreadStore> m_store;
    ThreadId m_testThreadId;
};

/**
 * @class TestFileBasedThreadStore
 * @brief Unit tests for FileBasedThreadStore
 */
class TestFileBasedThreadStore : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    
    void testInitialize();
    void testCreateThread();
    void testForkThread();
    void testResumeThread();
    void testSaveCheckpoint();
    void testLoadCheckpoint();
    void testPersistence();
    void testConcurrentAccess();

private:
    QString m_tempDir;
};

/**
 * @class TestApprovalManager
 * @brief Unit tests for ApprovalManager
 */
class TestApprovalManager : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    
    void testSetDefaultPolicy();
    void testAddGranularRule();
    void testRequestExecApproval();
    void testRecordDecision();
    void testGetStats();
    void testReadOnlyMode();

private:
    std::shared_ptr<ApprovalManager> m_manager;
};

/**
 * @class TestSandboxManager
 * @brief Unit tests for SandboxManager
 */
class TestSandboxManager : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    
    void testAvailableSandboxTypes();
    void testRecommendedType();
    void testFileSystemPolicy();
    void testCanAccess();
    void testExecuteInSandbox();
    void testProtectedMetadata();
    void testGetStats();

private:
    std::shared_ptr<SandboxManager> m_manager;
};
