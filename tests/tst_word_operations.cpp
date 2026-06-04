#include <QTest>
#include <QObject>
#include "../src/editor/WordOperations.h"

class TestWordOperations : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        wordOps = new WordOperations();
        QVERIFY(wordOps != nullptr);
    }

    void cleanupTestCase() {
        delete wordOps;
    }

    // Test: Get word bounds at cursor position
    void testGetWordBounds() {
        QString text = "const message = 'hello world';";
        
        auto bounds = wordOps->getWordBounds(text, 0, 10);
        
        QVERIFY(bounds.startColumn >= 0);
        QVERIFY(!bounds.word.isEmpty());
    }

    // Test: Word bounds at beginning
    void testWordBoundsAtBeginning() {
        QString text = "function testFunction() { }";
        
        auto bounds = wordOps->getWordBounds(text, 0, 0);
        
        QVERIFY(bounds.startColumn >= 0);
    }

    // Test: Word bounds at end
    void testWordBoundsAtEnd() {
        QString text = "const x = 1;";
        int len = text.length();
        
        auto bounds = wordOps->getWordBounds(text, 0, len - 1);
        
        QVERIFY(bounds.startColumn >= 0);
    }

    // Test: Find next word
    void testFindNextWord() {
        QString text = "hello world foo bar";
        int line = 0, column = 0;
        
        wordOps->findNextWord(text, line, column);
        
        QVERIFY(column > 0);
    }

    // Test: Multiple words in sequence
    void testMultipleWords() {
        QString text = "hello world foo bar";
        
        auto bounds1 = wordOps->getWordBounds(text, 0, 2);
        auto bounds2 = wordOps->getWordBounds(text, 0, 8);
        
        QVERIFY(!bounds1.word.isEmpty());
        QVERIFY(!bounds2.word.isEmpty());
    }

    // Test: Word with underscores
    void testWordWithUnderscores() {
        QString text = "my_variable_name = 42;";
        
        auto bounds = wordOps->getWordBounds(text, 0, 5);
        
        QVERIFY(!bounds.word.isEmpty());
    }

    // Test: Word with numbers
    void testWordWithNumbers() {
        QString text = "const var123 = value;";
        
        auto bounds = wordOps->getWordBounds(text, 0, 10);
        
        QVERIFY(!bounds.word.isEmpty());
    }

    // Test: Word bounds at whitespace
    void testWordBoundsAtWhitespace() {
        QString text = "hello   world";
        
        auto bounds = wordOps->getWordBounds(text, 0, 5);
        
        // At whitespace, should return empty or nearby word
        QVERIFY(bounds.startColumn >= 0);
    }

private:
    WordOperations* wordOps;
};

QTEST_MAIN(TestWordOperations)
#include "tst_word_operations.moc"
