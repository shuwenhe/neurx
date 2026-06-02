#pragma once

#include <QString>
#include <QVector>
#include <QVariantMap>
#include <memory>

/**
 * @brief TIER2IntegrationTests - TIER 2集成测试框架
 * 
 * 测试覆盖：
 * 1. ToolBridge初始化
 * 2. CodeMagic工具执行
 * 3. Memory存储和检索
 * 4. Approval权限检查
 * 5. Plugin工具发现
 * 6. LLM推荐
 * 7. 复合工具执行
 * 8. 性能指标
 */
class TIER2IntegrationTests {
public:
    /**
     * @brief 运行所有集成测试
     */
    static bool runAllTests();

    /**
     * @brief 测试ToolBridge初始化
     */
    static bool testToolBridgeInitialization();

    /**
     * @brief 测试CodeMagic工具
     */
    static bool testCodeMagicTools();

    /**
     * @brief 测试工具执行和缓存
     */
    static bool testToolExecution();

    /**
     * @brief 测试权限和审批
     */
    static bool testPermissionsAndApprovals();

    /**
     * @brief 测试工具推荐
     */
    static bool testToolRecommendations();

    /**
     * @brief 测试复合工具
     */
    static bool testCompositeTools();

    /**
     * @brief 测试统计和监控
     */
    static bool testStatisticsAndMonitoring();

    /**
     * @brief 打印测试报告
     */
    static QString generateTestReport();

private:
    static int m_testsRun;
    static int m_testsPassed;
    static int m_testsFailed;
    static QVector<QString> m_testResults;

    static void logTestResult(const QString &testName, bool passed);
};
