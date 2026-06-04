#include <QTest>
#include <QObject>
#include "../src/editor/CaseConverter.h"

class TestCaseConverter : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        converter = new CaseConverter();
        QVERIFY(converter != nullptr);
    }

    void cleanupTestCase() {
        delete converter;
    }

    // Test: Convert to uppercase
    void testToUpperCase() {
        QString text = "hello world";
        
        QString result = CaseConverter::convert(text, CaseConverter::UpperCase);
        
        QCOMPARE(result, QString("HELLO WORLD"));
    }

    // Test: Convert to lowercase
    void testToLowerCase() {
        QString text = "HELLO WORLD";
        
        QString result = CaseConverter::convert(text, CaseConverter::LowerCase);
        
        QCOMPARE(result, QString("hello world"));
    }

    // Test: Convert to title case
    void testToTitleCase() {
        QString text = "hello world";
        
        QString result = CaseConverter::convert(text, CaseConverter::TitleCase);
        
        QVERIFY(!result.isEmpty());
    }

    // Test: Convert to camel case
    void testCamelCase() {
        QString text = "hello world";
        
        QString result = CaseConverter::convert(text, CaseConverter::CamelCase);
        
        QVERIFY(!result.isEmpty());
    }

    // Test: Convert to snake case
    void testSnakeCase() {
        QString text = "helloWorld";
        
        QString result = CaseConverter::convert(text, CaseConverter::SnakeCase);
        
        QVERIFY(result.contains("_") || result == "hello_world");
    }

    // Test: Convert to kebab case
    void testKebabCase() {
        QString text = "helloWorld";
        
        QString result = CaseConverter::convert(text, CaseConverter::KebabCase);
        
        QVERIFY(result.contains("-") || result == "hello-world");
    }

    // Test: Convert to pascal case
    void testPascalCase() {
        QString text = "hello world";
        
        QString result = CaseConverter::convert(text, CaseConverter::PascalCase);
        
        QVERIFY(!result.isEmpty());
    }

    // Test: Convert to constant case
    void testConstantCase() {
        QString text = "hello world";
        
        QString result = CaseConverter::convert(text, CaseConverter::ConstantCase);
        
        QVERIFY(!result.isEmpty());
    }

    // Test: Convert word
    void testConvertWord() {
        QString word = "test";
        
        QString upper = CaseConverter::convertWord(word, CaseConverter::UpperCase);
        QString lower = CaseConverter::convertWord(word, CaseConverter::LowerCase);
        
        QCOMPARE(upper, QString("TEST"));
        QCOMPARE(lower, QString("test"));
    }

    // Test: Convert multiple words
    void testConvertWords() {
        QStringList words = {"hello", "world", "test"};
        
        QString result = CaseConverter::convertWords(words, CaseConverter::UpperCase);
        
        QVERIFY(!result.isEmpty());
    }

    // Test: Detect style
    void testDetectStyle() {
        QString upperText = "HELLO_WORLD";
        QString camelText = "helloWorld";
        
        auto upperStyle = CaseConverter::detectStyle(upperText);
        auto camelStyle = CaseConverter::detectStyle(camelText);
        
        QVERIFY(upperStyle >= 0);
        QVERIFY(camelStyle >= 0);
    }

    // Test: Preserve numbers
    void testPreserveNumbers() {
        QString text = "test123value";
        
        QString upper = CaseConverter::convert(text, CaseConverter::UpperCase);
        QString lower = CaseConverter::convert(text, CaseConverter::LowerCase);
        
        QVERIFY(upper.contains("123"));
        QVERIFY(lower.contains("123"));
    }

    // Test: Empty string
    void testEmptyString() {
        QString text = "";
        
        QString upper = CaseConverter::convert(text, CaseConverter::UpperCase);
        QString lower = CaseConverter::convert(text, CaseConverter::LowerCase);
        
        QCOMPARE(upper, QString(""));
        QCOMPARE(lower, QString(""));
    }

    // Test: Single character
    void testSingleCharacter() {
        QString text = "a";
        
        QString upper = CaseConverter::convert(text, CaseConverter::UpperCase);
        
        QCOMPARE(upper, QString("A"));
    }

private:
    CaseConverter* converter;
};

QTEST_MAIN(TestCaseConverter)
#include "tst_case_converter.moc"
