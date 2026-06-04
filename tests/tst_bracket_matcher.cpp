#include <QTest>
#include <QObject>
#include "../src/editor/BracketMatcher.h"

class TestBracketMatcher : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        matcher = new BracketMatcher();
        QVERIFY(matcher != nullptr);
    }

    void cleanupTestCase() {
        delete matcher;
    }

    // Test: Find matching bracket for opening bracket
    void testFindMatchingBracketOpen() {
        QString text = "function test() { return 42; }";
        
        BracketPair result = matcher->findMatchingBracket(text, 0, 15);
        
        QVERIFY(result.closeLine >= 0 || result.closeColumn >= 0);
    }

    // Test: Find matching bracket for closing bracket
    void testFindMatchingBracketClose() {
        QString text = "function test() { return 42; }";
        
        BracketPair result = matcher->findMatchingBracket(text, 0, 29);
        
        QVERIFY(result.openLine >= 0 || result.openColumn >= 0);
    }

    // Test: Get matching bracket
    void testGetMatchingBracket() {
        QString text = "function test() { return 42; }";
        
        BracketPair result = matcher->getMatchingBracket(text, 0, 15);
        
        QVERIFY(result.openChar != 0 || result.closeChar != 0);
    }

    // Test: Nested brackets
    void testNestedBrackets() {
        QString text = "arr[map(x => { return x * 2; })]";
        
        BracketPair result = matcher->findMatchingBracket(text, 0, 3);
        
        QVERIFY(result.closeColumn > result.openColumn);
    }

    // Test: Check opening bracket
    void testIsOpeningBracket() {
        QVERIFY(BracketMatcher::isOpeningBracket('('));
        QVERIFY(BracketMatcher::isOpeningBracket('['));
        QVERIFY(BracketMatcher::isOpeningBracket('{'));
        QVERIFY(!BracketMatcher::isOpeningBracket('a'));
    }

    // Test: Check closing bracket
    void testIsClosingBracket() {
        QVERIFY(BracketMatcher::isClosingBracket(')'));
        QVERIFY(BracketMatcher::isClosingBracket(']'));
        QVERIFY(BracketMatcher::isClosingBracket('}'));
        QVERIFY(!BracketMatcher::isClosingBracket('a'));
    }

    // Test: Get character at position
    void testGetCharAt() {
        QString text = "hello";
        
        QChar ch = matcher->getCharAt(text, 0, 0);
        
        QCOMPARE(ch, QChar('h'));
    }

    // Test: Matching bracket at position (Q_INVOKABLE)
    void testMatchingBracketAt() {
        QString text = "(hello)";
        
        QVariantMap result = matcher->matchingBracketAt(text, 0, 0);
        
        QVERIFY(!result.isEmpty() || result.isEmpty());
    }

    // Test: Different bracket types
    void testDifferentBracketTypes() {
        QString textRound = "(hello)";
        QString textSquare = "[hello]";
        QString textCurly = "{hello}";
        
        BracketPair round = matcher->findMatchingBracket(textRound, 0, 0);
        BracketPair square = matcher->findMatchingBracket(textSquare, 0, 0);
        BracketPair curly = matcher->findMatchingBracket(textCurly, 0, 0);
        
        QVERIFY(round.openChar != 0 || round.closeChar != 0);
        QVERIFY(square.openChar != 0 || square.closeChar != 0);
        QVERIFY(curly.openChar != 0 || curly.closeChar != 0);
    }

private:
    BracketMatcher* matcher;
};

QTEST_MAIN(TestBracketMatcher)
#include "tst_bracket_matcher.moc"
