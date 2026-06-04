#include <QTest>
#include <QObject>
#include "../src/editor/MultiCursor.h"

class TestMultiCursor : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        multiCursor = new MultiCursor();
        QVERIFY(multiCursor != nullptr);
    }

    void cleanupTestCase() {
        delete multiCursor;
    }

    // Test: Add cursor
    void testAddCursor() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        
        auto cursors = multiCursor->getAllCursors();
        QCOMPARE(cursors.size(), 1);
    }

    // Test: Add multiple cursors
    void testAddMultipleCursors() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 10});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 15});
        
        auto cursors = multiCursor->getAllCursors();
        QCOMPARE(cursors.size(), 3);
    }

    // Test: Remove cursor
    void testRemoveCursor() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 10});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 15});
        
        multiCursor->removeCursor(MultiCursor::CursorPos{0, 10});
        
        auto cursors = multiCursor->getAllCursors();
        QCOMPARE(cursors.size(), 2);
    }

    // Test: Clear secondary cursors
    void testClearSecondaryCursors() {
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 10});
        
        multiCursor->clearSecondaryCursors();
        
        auto cursors = multiCursor->getAllCursors();
        QCOMPARE(cursors.size(), 1);
    }

    // Test: Get all cursors
    void testGetAllCursors() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 10});
        
        auto cursors = multiCursor->getAllCursors();
        
        QCOMPARE(cursors.size(), 2);
    }

    // Test: Get primary cursor
    void testGetPrimaryCursor() {
        multiCursor->clearSecondaryCursors();
        
        auto primary = multiCursor->getMainCursor();
        
        QVERIFY(primary.line >= 0);
    }

    // Test: Cursor deduplication
    void testCursorDeduplication() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5}); // Duplicate
        
        auto cursors = multiCursor->getAllCursors();
        
        QCOMPARE(cursors.size(), 1); // Should be deduplicated
    }

    // Test: Sorting cursors
    void testSortingCursors() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 15});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{0, 10});
        
        auto cursors = multiCursor->getAllCursors();
        
        for (int i = 1; i < cursors.size(); ++i) {
            QVERIFY(cursors[i].column >= cursors[i-1].column);
        }
    }

    // Test: Cursor on multiple lines
    void testMultiLineInsert() {
        multiCursor->clearSecondaryCursors();
        
        multiCursor->addCursor(MultiCursor::CursorPos{0, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{1, 5});
        multiCursor->addCursor(MultiCursor::CursorPos{2, 5});
        
        auto cursors = multiCursor->getAllCursors();
        QCOMPARE(cursors.size(), 3);
    }

private:
    MultiCursor* multiCursor;
};

QTEST_MAIN(TestMultiCursor)
#include "tst_multi_cursor.moc"

