# Neurx State Management System

The State Management System maintains consistent agent context and state across conversation turns, goals, and execution threads.

## Overview

The state management system provides:
- Thread-safe variable management
- Complete change history and audit trail
- Transaction support with rollback
- Snapshot and recovery capabilities
- Conversation turn tracking
- Conflict detection and resolution

## Core Components

### StateScope
Variables can be scoped to:
- **Global** - Agent-wide state
- **Thread** - Thread-specific context
- **Conversation** - Turn-specific state
- **Task** - Task execution state
- **Local** - Local execution scope

### ContextState
Represents a snapshot of state:
```cpp
ContextState state;
state.variables["user_name"] = "Alice";
state.variables["context"] = QVariantMap(...);
state.threadId = "thread-123";
```

### StateChange
Records every modification:
```cpp
StateChange change;
change.type = StateChangeType::Set;
change.key = "counter";
change.oldValue = 5;
change.newValue = 6;
change.timestamp = QDateTime::currentDateTime();
```

## Usage Examples

### Variable Management

```cpp
// Set a variable
manager->setVariable("user_count", 42, "Updated from API");

// Get a variable
int count = manager->getVariable("user_count", 0).toInt();

// Check existence
if (manager->hasVariable("user_name")) {
    qDebug() << "User name set";
}

// Set multiple variables
QVariantMap vars;
vars["name"] = "Alice";
vars["age"] = 30;
manager->setVariables(vars, "User profile update");

// Get variables matching pattern
auto userVars = manager->getVariables("user_*");
```

### Numeric Operations

```cpp
// Increment a counter
manager->setVariable("visits", 0);
manager->incrementVariable("visits");  // visits = 1
manager->incrementVariable("visits", 5);  // visits = 6

// Append to lists
manager->appendToList("tags", "important");
manager->appendToList("tags", "urgent");
```

### Object Merging

```cpp
// Merge with existing object
QVariantMap config;
config["timeout"] = 30000;
config["retries"] = 3;

manager->mergeVariable("settings", config);

// Existing "settings" will be merged with new config
```

### Transactions

```cpp
// Begin transaction
QString txId = manager->beginTransaction("Update user profile");

// Make changes
manager->setVariable("user_name", "Bob");
manager->setVariable("user_email", "bob@example.com");
manager->incrementVariable("profile_updates");

// Commit transaction
manager->commitTransaction(txId, [](bool success) {
    qDebug() << "Transaction committed:" << success;
});

// Or rollback
manager->rollbackTransaction(txId, [](bool success) {
    qDebug() << "Transaction rolled back";
});
```

### History Tracking

```cpp
// Get all changes (last 100)
auto history = manager->getChangeHistory(100);
for (const auto &change : history) {
    qDebug() << "Changed:" << change.key
             << "from" << change.oldValue
             << "to" << change.newValue;
}

// Get variable-specific history
auto userHistory = manager->getVariableHistory("user_name");

// Get changes since a time
auto recentChanges = manager->getChangesSince(QDateTime::currentDateTime().addHours(-1));

// Get last change
auto lastChange = manager->getLastChange("user_name");
```

### Snapshots

```cpp
// Create snapshot
auto snapshot = manager->createSnapshot("checkpoint-1", "After user login");

// List all snapshots
auto snapshots = manager->listSnapshots();
for (const auto &snap : snapshots) {
    qDebug() << "Snapshot:" << snap.label << "at" << snap.capturedAt;
}

// Restore from snapshot
manager->restoreSnapshot(snapshot.snapshotId, [](bool success) {
    qDebug() << "State restored from snapshot";
});

// Delete snapshot
manager->deleteSnapshot(snapshot.snapshotId, [](bool success) {
    qDebug() << "Snapshot deleted";
});
```

### Conversation Turns

```cpp
// Start a turn
QString turnId = manager->startTurn(1, "What's the weather?");

// Make changes during turn
manager->setVariable("last_question", "What's the weather?");
manager->incrementVariable("turn_count");

// Complete turn
manager->completeTurn(turnId, "It's sunny and 72°F", [](bool success) {
    qDebug() << "Turn completed";
});

// Get turn history
auto turns = manager->getTurnHistory(50);
for (const auto &turn : turns) {
    qDebug() << "Turn" << turn.turnNumber
             << "User:" << turn.userMessage
             << "Agent:" << turn.agentResponse;
}

// Get specific turn state
auto turn = manager->getTurnState(turnId);
```

### Querying State

```cpp
// Query variables by pattern
StateQuery query;
query.pattern = "user_*";
query.scope = StateScope::Global;

auto userVars = manager->queryVariables(query);

// Search state
auto results = manager->searchState("Alice");
for (const auto &result : results) {
    qDebug() << "Found:" << result.first << "=" << result.second;
}

// Get state diff
StateDiff diff = manager->getStateDiff(oldState, newState);
qDebug() << "Added:" << diff.added.size() << "variables";
qDebug() << "Modified:" << diff.modified.size() << "variables";
qDebug() << "Removed:" << diff.removed.size() << "variables";
```

### Conflict Resolution

```cpp
// Handle conflicts
StateConflict conflict;
conflict.stateKey = "user_role";
conflict.version1 = "admin";
conflict.version2 = "user";

manager->resolveConflict(conflict, [](const StateConflict &resolved) {
    qDebug() << "Conflict resolved to:" << resolved.resolved;
});

// Check for unresolved conflicts
auto conflicts = manager->getUnresolvedConflicts();
```

### Persistence

```cpp
// Save state to storage
manager->saveState("backup-1", [](bool success) {
    qDebug() << "State saved:" << success;
});

// Load state from storage
manager->loadState("backup-1", [](const ContextState &state) {
    qDebug() << "State loaded, variables:" << state.variables.size();
});
```

### Cleanup

```cpp
// Clear all state
manager->clearAllState([](bool success) {
    qDebug() << "All state cleared";
});

// Remove old state
QDateTime oneWeekAgo = QDateTime::currentDateTime().addDays(-7);
manager->clearOldState(oneWeekAgo, [](int removedCount) {
    qDebug() << "Removed" << removedCount << "old state entries";
});
```

### Statistics

```cpp
// Get state statistics
auto stats = manager->getStateStats();
qDebug() << "Total variables:" << stats["totalVariables"];
qDebug() << "Total changes:" << stats["totalChanges"];
qDebug() << "Total snapshots:" << stats["totalSnapshots"];
qDebug() << "Total turns:" << stats["totalTurns"];
```

### Validation

```cpp
// Validate state consistency
QString error;
if (!manager->validateStateConsistency(error)) {
    qDebug() << "Consistency error:" << error;
}

// Check integrity
if (!manager->checkStateIntegrity(error)) {
    qDebug() << "Integrity error:" << error;
}
```

## Signals and Events

Connect to state events:

```cpp
connect(manager.get(), &StateManager::variableChanged,
    [](const StateChange &change) {
        qDebug() << "Variable changed:" << change.key;
    });

connect(manager.get(), &StateManager::stateChanged,
    [](const ContextState &newState) {
        qDebug() << "State changed";
    });

connect(manager.get(), &StateManager::transactionCommitted,
    [](const QString &txId) {
        qDebug() << "Transaction committed:" << txId;
    });

connect(manager.get(), &StateManager::turnCompleted,
    [](const TurnState &turn) {
        qDebug() << "Turn" << turn.turnNumber << "completed";
    });
```

## Best Practices

1. **Use transactions for related changes** - Group related modifications
2. **Create snapshots before risky operations** - Enable easy recovery
3. **Check variable existence** - Avoid relying on defaults
4. **Use patterns for variable names** - Makes querying easier (e.g., `user_*`, `config_*`)
5. **Track scope appropriately** - Use correct scope for each variable
6. **Monitor history** - Review changes for debugging
7. **Clean up old state** - Prevent unbounded growth
8. **Validate before operations** - Check consistency regularly

## Architecture

The state management uses:
- **Scoped storage** - Variables organized by scope
- **Change history** - Complete audit trail
- **Transaction support** - ACID-like guarantees
- **Snapshots** - Point-in-time recovery
- **Turn tracking** - Conversation state per turn
- **Mutex protection** - Thread-safe operations
- **Signal/slot events** - Observer pattern for changes
