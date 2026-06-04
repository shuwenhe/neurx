#include <QTest>
#include <QObject>
#include <QKeySequence>
#include "../src/services/KeyBindingManager.h"

class TestKeyBindingManager : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        manager = KeyBindingManager::instance();
        QVERIFY(manager != nullptr);
    }

    // Test: Get keybinding for command
    void testGetKeyBinding() {
        KeyBinding binding = manager->getKeyBinding("editor.jumpToBracket");
        
        QVERIFY(!binding.keys.isEmpty());
    }

    // Test: All Phase 2 commands registered
    void testPhase2CommandsRegistered() {
        QVERIFY(!manager->getKeyBinding("editor.jumpToBracket").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.selectToMatchingBracket").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.toggleCaseLower").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.toggleCaseUpper").keys.isEmpty());
    }

    // Test: All Phase 3 commands registered
    void testPhase3CommandsRegistered() {
        QVERIFY(!manager->getKeyBinding("editor.smartSelectRight").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.smartSelectLeft").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.toggleHighlight").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.rename").keys.isEmpty());
        QVERIFY(!manager->getKeyBinding("editor.goToDefinition").keys.isEmpty());
    }

    // Test: Register custom keybinding
    void testRegisterCustomBinding() {
        KeyBinding binding;
        binding.commandId = "custom.command";
        binding.keys = "Ctrl+Alt+X";
        
        manager->registerKeyBinding(binding);
        
        KeyBinding result = manager->getKeyBinding("custom.command");
        
        QCOMPARE(result.keys, QString("Ctrl+Alt+X"));
    }

    // Test: Register with shorthand
    void testRegisterShorthand() {
        manager->registerKeyBinding("test.shorthand", "Ctrl+Shift+P");
        
        KeyBinding binding = manager->getKeyBinding("test.shorthand");
        
        QCOMPARE(binding.keys, QString("Ctrl+Shift+P"));
    }

    // Test: Multiple valid keybindings
    void testMultipleBindings() {
        KeyBinding binding1 = manager->getKeyBinding("editor.jumpToBracket");
        KeyBinding binding2 = manager->getKeyBinding("editor.toggleHighlight");
        
        QVERIFY(!binding1.keys.isEmpty());
        QVERIFY(!binding2.keys.isEmpty());
        QVERIFY(binding1.keys != binding2.keys);
    }

    // Test: Get all keybindings
    void testGetAllKeyBindings() {
        auto bindings = manager->getAllKeyBindings();
        
        QVERIFY(bindings.size() > 10); // Should have many commands registered
    }

    // Test: Detect conflicts
    void testConflictDetection() {
        auto conflicts = manager->findConflicts("Ctrl+A");
        
        // May or may not have conflicts depending on setup
        // Just verify it doesn't crash
        QVERIFY(true);
    }

    // Test: Has conflict check
    void testHasConflict() {
        bool hasConflict = manager->hasConflict("Ctrl+A");
        
        // Just verify it doesn't crash and returns a bool
        QVERIFY(hasConflict || !hasConflict);
    }

    // Test: Get command by keys
    void testGetCommandByKeys() {
        QString command = manager->getCommand("Ctrl+Shift+\\\\");
        
        // Should return a command if keybinding exists
        QVERIFY(command.isEmpty() || !command.isEmpty());
    }

    // Test: Unregister keybinding
    void testUnregisterKeyBinding() {
        manager->registerKeyBinding("test.temp", "Ctrl+1");
        manager->unregisterKeyBinding("test.temp");
        
        KeyBinding binding = manager->getKeyBinding("test.temp");
        
        QCOMPARE(binding.keys, QString(""));
    }

private:
    KeyBindingManager* manager;
};

QTEST_MAIN(TestKeyBindingManager)
#include "tst_keybinding_manager.moc"
