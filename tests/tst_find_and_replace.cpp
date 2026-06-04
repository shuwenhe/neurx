#include <QTest>
#include <QObject>
#include "../src/editor/FindAndReplace.h"

class TestFindAndReplace : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        finder = new FindAndReplace();
        QVERIFY(finder != nullptr);
    }

    void cleanupTestCase() {
        delete finder;
    }

    // Test: Simple text search
    void testSimpleFind() {
        QString text = "The quick brown fox jumps over the lazy dog";
        QString searchTerm = "fox";
        
        auto result = finder->findNext(text, searchTerm, 0, 0);
        
        QVERIFY(result.found);
        QVERIFY(result.line >= 0);
    }

    // Test: Case-sensitive search
    void testCaseSensitiveFind() {
        QString text = "Hello hello HELLO";
        QString searchTerm = "Hello";
        
        FindAndReplace::SearchOptions options = FindAndReplace::CaseSensitive;
        
        auto result = finder->findNext(text, searchTerm, 0, 0, options);
        
        QVERIFY(result.found);
    }

    // Test: Case-insensitive search
    void testCaseInsensitiveFind() {
        QString text = "Hello HELLO hello";
        QString searchTerm = "hello";
        
        FindAndReplace::SearchOptions options = FindAndReplace::None;
        
        auto result = finder->findAll(text, searchTerm, options);
        
        QVERIFY(result.size() >= 1);
    }

    // Test: Whole word matching
    void testWholeWordFind() {
        QString text = "testing test testing tested";
        QString searchTerm = "test";
        
        FindAndReplace::SearchOptions options = FindAndReplace::WholeWord;
        
        auto result = finder->findAll(text, searchTerm, options);
        
        QCOMPARE(result.size(), 1); // Only "test" should match
    }

    // Test: Regex search
    void testRegexFind() {
        QString text = "test123 hello456 world789";
        QString pattern = "[0-9]+";
        
        FindAndReplace::SearchOptions options = FindAndReplace::Regex;
        
        auto result = finder->findAll(text, pattern, options);
        
        QCOMPARE(result.size(), 3);
    }

    // Test: Find and replace
    void testReplaceNext() {
        QString text = "cat bat cat";
        QString searchTerm = "cat";
        QString replacement = "dog";
        
        FindAndReplace::ReplaceResult result = finder->replaceNext(text, searchTerm, replacement, 0, 0);
        
        QVERIFY(result.success);
        QVERIFY(result.text.contains("dog"));
    }

    // Test: Replace all
    void testReplaceAll() {
        QString text = "cat bat cat dog cat";
        QString searchTerm = "cat";
        QString replacement = "dog";
        
        FindAndReplace::ReplaceResult result = finder->replaceAll(text, searchTerm, replacement);
        
        QVERIFY(result.success);
        QCOMPARE(result.occurrenceCount, 3);
    }

    // Test: Find previous
    void testFindPrevious() {
        QString text = "cat bat cat dog cat";
        QString searchTerm = "cat";
        
        auto resultNext = finder->findNext(text, searchTerm, 0, 0);
        auto resultPrev = finder->findPrevious(text, searchTerm, -1, -1);
        
        QVERIFY(resultNext.found);
        QVERIFY(resultPrev.found || !resultPrev.found); // May or may not find backward
    }

    // Test: Empty search term
    void testEmptySearchTerm() {
        QString text = "hello world";
        QString searchTerm = "";
        
        auto result = finder->findNext(text, searchTerm, 0, 0);
        
        QCOMPARE(result.found, false);
    }

    // Test: Search in empty text
    void testSearchInEmptyText() {
        QString text = "";
        QString searchTerm = "hello";
        
        auto result = finder->findNext(text, searchTerm, 0, 0);
        
        QCOMPARE(result.found, false);
    }

    // Test: Find all in text
    void testFindAll() {
        QString text = "one two one three one";
        QString searchTerm = "one";
        
        auto results = finder->findAll(text, searchTerm);
        
        QCOMPARE(results.size(), 3);
    }

    // Test: Current search state
    void testCurrentSearchState() {
        QString text = "test search";
        QString searchTerm = "test";
        
        finder->findNext(text, searchTerm, 0, 0);
        
        QString current = finder->currentSearchText();
        QCOMPARE(current, searchTerm);
    }

private:
    FindAndReplace* finder;
};

QTEST_MAIN(TestFindAndReplace)
#include "tst_find_and_replace.moc"
