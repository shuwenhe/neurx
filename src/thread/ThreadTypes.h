#pragma once

#include "ThreadId.h"
#include <QVariantMap>
#include <QDateTime>
#include <QVector>

/**
 * @enum ThreadInitializationMode
 * @brief How a thread was initialized or resumed
 */
enum class ThreadInitializationMode {
    Fresh,      ///< New thread created from scratch
    Resumed,    ///< Resumed from checkpoint
    Forked      ///< Forked from parent thread
};

/**
 * @struct ThreadPersistenceMetadata
 * @brief Metadata for thread persistence and lifecycle
 */
struct ThreadPersistenceMetadata {
    ThreadId threadId;
    ThreadId parentThreadId;            ///< Set if forked from another thread
    ThreadInitializationMode mode{ThreadInitializationMode::Fresh};
    
    QDateTime createdAt;
    QDateTime lastModified;
    QDateTime lastCheckpointAt;
    
    int checkpointCount{0};
    int forkCount{0};
    
    /// Custom metadata stored by application
    QVariantMap customMetadata;
};

/**
 * @struct CreateThreadParams
 * @brief Parameters for creating a new thread
 */
struct CreateThreadParams {
    ThreadInitializationMode mode{ThreadInitializationMode::Fresh};
    
    /// Parent thread ID if forking
    ThreadId parentThreadId;
    
    /// Custom initial metadata
    QVariantMap metadata;
};

/**
 * @struct ResumeThreadParams
 * @brief Parameters for resuming a thread from checkpoint
 */
struct ResumeThreadParams {
    ThreadId threadId;
    
    /// Specific checkpoint version (if null, use latest)
    QString checkpointVersion;
    
    /// Additional context to merge with resumed state
    QVariantMap contextOverrides;
};

/**
 * @struct StoredThread
 * @brief Represents a stored thread with its metadata and state
 */
struct StoredThread {
    ThreadId id;
    ThreadPersistenceMetadata metadata;
    
    /// Last known state (JSON serializable)
    QVariantMap lastState;
    
    /// Checkpoints available for this thread
    QVector<QString> availableCheckpoints;
    
    /// Whether thread is currently active
    bool isActive{false};
    
    /// Last execution timestamp
    QDateTime lastExecuted;
};

/**
 * @enum ThreadStoreError
 * @brief Error types for thread store operations
 */
enum class ThreadStoreError {
    Success = 0,
    NotFound,
    AlreadyExists,
    Corrupted,
    PermissionDenied,
    StorageError,
    CheckpointNotFound,
    InvalidOperation,
    Unknown
};
