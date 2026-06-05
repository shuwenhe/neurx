#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QJsonObject>
#include <optional>

/**
 * @class PeekView
 * @brief Show inline preview of definitions, references, or search results
 * 
 * Ported from VS Code: /src/vs/editor/contrib/peekView/
 * 
 * Features:
 * - Inline previews of definitions
 * - Reference list with previews
 * - Search results inline
 * - Navigation within preview
 */

class PeekView : public QObject {
    Q_OBJECT

public:
    explicit PeekView(QObject* parent = nullptr);
    ~PeekView() override = default;

    // Peek view modes
    enum class PeekMode {
        Definition,      // Show definition
        References,      // Show all references
        Implementations, // Show implementations
        TypeDefinition,  // Show type definition
        Search           // Show search results
    };
    Q_ENUM(PeekMode)

    // Location entry
    struct Location {
        QString file;
        int line{0};
        int column{0};
        int endLine{0};
        int endColumn{0};
        QString name;           // Symbol name
        QString kind;           // "class", "function", "variable", etc.
        QString containerName;  // Parent container (class, namespace, etc.)
    };

    // Peek result with preview
    struct PeekResult {
        PeekMode mode;
        QList<Location> locations;
        int currentIndex{0};
        QString symbol;         // The symbol being peeked
        int startLine{-1};      // Preview start line
        int endLine{-1};        // Preview end line
        QString previewContent; // Content to show
    };

    /**
     * @brief Open definition peek view
     * @param filePath Current file
     * @param line Current line
     * @param column Current column
     * @param symbol Symbol name (optional, auto-detect if empty)
     * @return Peek result
     */
    PeekResult peekDefinition(const QString& filePath, int line, int column, const QString& symbol = "");

    /**
     * @brief Open references peek view
     * @param filePath Current file
     * @param line Current line
     * @param column Current column
     * @param symbol Symbol name
     * @return Peek result
     */
    PeekResult peekReferences(const QString& filePath, int line, int column, const QString& symbol = "");

    /**
     * @brief Open implementations peek view
     * @param filePath Current file
     * @param line Current line
     * @param column Current column
     * @param symbol Symbol name
     * @return Peek result
     */
    PeekResult peekImplementations(const QString& filePath, int line, int column, const QString& symbol = "");

    /**
     * @brief Open type definition peek view
     * @param filePath Current file
     * @param line Current line
     * @param column Current column
     * @param symbol Symbol name
     * @return Peek result
     */
    PeekResult peekTypeDefinition(const QString& filePath, int line, int column, const QString& symbol = "");

    /**
     * @brief Navigate to next location in peek view
     * @return Updated peek result
     */
    PeekResult nextPeekLocation();

    /**
     * @brief Navigate to previous location in peek view
     * @return Updated peek result
     */
    PeekResult previousPeekLocation();

    /**
     * @brief Navigate to specific location in peek view
     * @param index Index in locations list
     * @return Updated peek result
     */
    PeekResult gotoLocationIndex(int index);

    /**
     * @brief Close current peek view
     */
    void closePeek();

    /**
     * @brief Check if peek view is open
     * @return True if peek view is active
     */
    bool isPeekOpen() const { return m_activePeek.has_value(); }

    /**
     * @brief Get current peek result
     * @return Current peek result (if open)
     */
    std::optional<PeekResult> getCurrentPeekResult() const { return m_activePeek; }

    /**
     * @brief Add custom location to peek view
     * @param location Location to add
     */
    void addPeekLocation(const Location& location);

    /**
     * @brief Get file context (lines around location)
     * @param filePath File path
     * @param line Line number (center line)
     * @param contextLines Lines of context before and after
     * @return Text content
     */
    QString getFileContext(const QString& filePath, int line, int contextLines = 5);

    /**
     * @brief Get line of code
     * @param filePath File path
     * @param line Line number
     * @return Line content
     */
    QString getLineContent(const QString& filePath, int line);

signals:
    /**
     * @brief Emitted when peek view opened
     */
    void peekOpened(const PeekResult& result);

    /**
     * @brief Emitted when peek location changed
     */
    void peekLocationChanged(const PeekResult& result);

    /**
     * @brief Emitted when peek view closed
     */
    void peekClosed();

    /**
     * @brief Emitted when user selects a location
     */
    void locationSelected(const Location& location);

    /**
     * @brief Emitted when preview content ready
     */
    void previewReady(const QString& content);

private:
    struct PeekState {
        PeekResult result;
        QString currentFile;
        int currentLine{-1};
        int currentColumn{-1};
    };

    // Load preview content for location
    QString loadPreviewContent(const Location& location);

    // Format location for display
    QString formatLocation(const Location& location) const;

    std::optional<PeekResult> m_activePeek;
    std::optional<PeekState> m_peekState;

    // Cache for preview content
    QHash<QString, QString> m_previewCache;
};

Q_DECLARE_METATYPE(PeekView::PeekMode)
Q_DECLARE_METATYPE(PeekView::Location)
Q_DECLARE_METATYPE(PeekView::PeekResult)
