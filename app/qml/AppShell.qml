import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import QtQuick.Pdf

Item {
    id: shell

    readonly property color bg: "#111111"
    readonly property color surface: "#1a1a1a"
    readonly property color border: "#2b2b2b"
    readonly property color accent: "#19a974"
    readonly property color textPrimary: "#f3f3f3"
    readonly property color textMuted: "#a0a0a0"
    readonly property color panelAlt: "#151515"
    readonly property color panelHover: "#202020"
    readonly property color editorBg: "#0f1115"
    readonly property color selectionBg: "#173f31"
    readonly property color userBubble: "#123d2f"
    readonly property color agentBubble: "#171b22"
    readonly property color lineNumberBg: "#14181d"
    readonly property color lineNumberBorder: "#20262d"
    readonly property color highlightKeyword: "#6cb6ff"
    readonly property color highlightString: "#f69d50"
    readonly property color highlightComment: "#7f8c98"
    readonly property color highlightDirective: "#d2a8ff"
    readonly property int paneHandleWidth: 10
    readonly property int paneMinExplorerWidth: 220
    readonly property int paneMinEditorWidth: 340
    readonly property int paneMinAgentWidth: 380
    readonly property real userBubbleWidthRatio: 0.58
    readonly property real assistantBubbleWidthRatio: 0.86

    readonly property int workspaceMargin: 20

    property int selectedFileIndex: -1
    property string selectedFilePath: ""
    property string explorerCurrentPath: ""
    property string explorerRootLabel: ""
    property bool explorerRootExpanded: true
    property var explorerExpandedPaths: ({})
    property int explorerPaneWidth: 280
    property int agentPaneWidth: 540
    property int runSteps: 4
    property bool agentRunning: false
    property int runClickSeq: 0
    property real runStartMs: 0
    property string lastPromptText: ""
    property string lastResponseLabel: qsTr("NeurX")
    property string lastRunDurationText: ""
    property string runtimeStatusText: Runtime.ping()
    property string editorPlainText: ""
    property string editorKind: "Text"
    property int activeEditorTabIndex: -1
    property var diagnosticsSkillRecords: []
    property string selectedSkillName: ""
    property string skillStatusFilter: ""
    property bool skillActiveOnly: false
    property bool skillHighFailOnly: false
    property bool selectedSkillFailedOnly: false
    property string selectedSkillToolFilter: ""
    property string selectedSkillSearchText: ""
    property bool agentDetailsExpanded: false
    property int activeAssistantMessageIndex: -1
    property string activeAssistantStreamText: ""
    property string copyNoticeText: ""
    property string loginButtonText: qsTr("登录")
    property string loginPhoneText: ""
    property string loginCodeText: ""
    property string loginStatusText: ""
    property string generatedLoginCode: ""
    property bool loginLoggedIn: false
    property int agentRunTimeoutMs: 120000
    property bool restoringSession: false
    property real uiZoom: 1.0
    readonly property real minUiZoom: 0.5
    readonly property real maxUiZoom: 2.0
    readonly property real uiZoomStep: 0.1

    function roundedUiZoom(value) {
        return Math.round(value * 10) / 10
    }

    function setUiZoom(value) {
        var next = Math.max(minUiZoom, Math.min(maxUiZoom, roundedUiZoom(value)))
        if (Math.abs(next - uiZoom) < 0.001) {
            return
        }
        uiZoom = next
    }

    function zoomIn() {
        setUiZoom(uiZoom + uiZoomStep)
    }

    function zoomOut() {
        setUiZoom(uiZoom - uiZoomStep)
    }

    function resetZoom() {
        setUiZoom(1.0)
    }

    function imageKinds() {
        return ["PNG", "JPG", "JPEG", "GIF", "BMP", "WEBP", "SVG"]
    }

    function videoKinds() {
        return ["MP4", "MOV", "M4V", "WEBM", "MKV", "AVI"]
    }

    function officeDocumentKinds() {
        return ["DOC", "DOCX", "XLS", "XLSX", "PPT", "PPTX", "ODT", "ODS", "ODP", "RTF"]
    }

    function inlineDocumentKinds() {
        return ["DOCX"]
    }

    function imageKindForPath(path) {
        var value = normalizedPath(path)
        if (!value.length) {
            return ""
        }
        var slash = value.lastIndexOf("/")
        var dot = value.lastIndexOf(".")
        if (dot <= slash) {
            return ""
        }
        return value.slice(dot + 1).toUpperCase()
    }

    function effectiveEditorKind(path, fallbackKind) {
        var imageKind = imageKindForPath(path)
        if (imageKinds().indexOf(imageKind) >= 0) {
            return imageKind
        }
        if (videoKinds().indexOf(imageKind) >= 0) {
            return imageKind
        }
        if (officeDocumentKinds().indexOf(imageKind) >= 0) {
            return imageKind
        }
        if (imageKind === "PDF") {
            return imageKind
        }
        return fallbackKind || "Text"
    }

    function isImageKind(kind, path) {
        var nextKind = effectiveEditorKind(path, kind)
        return imageKinds().indexOf((nextKind || "").toUpperCase()) >= 0
    }

    function isPdfKind(kind) {
        return (kind || "").toUpperCase() === "PDF"
    }

    function isVideoKind(kind, path) {
        var nextKind = effectiveEditorKind(path, kind)
        return videoKinds().indexOf((nextKind || "").toUpperCase()) >= 0
    }

    function isOfficeDocumentKind(kind, path) {
        var nextKind = effectiveEditorKind(path, kind)
        return officeDocumentKinds().indexOf((nextKind || "").toUpperCase()) >= 0
    }

    function isInlineDocumentKind(kind, path) {
        var nextKind = effectiveEditorKind(path, kind)
        return inlineDocumentKinds().indexOf((nextKind || "").toUpperCase()) >= 0
    }

    function readEditorPreviewText(path, kind) {
        if (isInlineDocumentKind(kind, path)) {
            return Runtime.read_docx_text_file(path)
        }
        return Runtime.read_text_file(path)
    }

    function editorImageSource(path) {
        var value = normalizedPath(path)
        if (!value.length) {
            return ""
        }
        value = value.replace(/\\/g, "/")
        if (value.charAt(0) !== "/") {
            value = "/" + value
        }
        // encodeURI preserves /:@!$&'()*+,;=# but encodes spaces and Unicode
        return encodeURI("file://" + value)
    }

    function explorerLeafName(path) {
        var value = (path || "").trim()
        if (!value.length) {
            return qsTr("COMPUTER")
        }
        while (value.length > 1 && value.charAt(value.length - 1) === "/") {
            value = value.slice(0, value.length - 1)
        }
        var slash = value.lastIndexOf("/")
        if (slash < 0) {
            return value.toUpperCase()
        }
        var leaf = value.slice(slash + 1)
        if (!leaf.length) {
            leaf = value
        }
        return leaf.toUpperCase()
    }

    function editorTabLabel(path, fallbackLabel) {
        var fallback = (fallbackLabel || "").trim()
        if (fallback.length) {
            return fallback
        }
        var value = normalizedPath(path)
        if (!value.length) {
            return qsTr("Preview")
        }
        var slash = value.lastIndexOf("/")
        return slash >= 0 ? value.slice(slash + 1) : value
    }

    function directoryForFilePath(path) {
        var value = (path || "").trim()
        if (!value.length) {
            return ""
        }
        while (value.length > 1 && value.charAt(value.length - 1) === "/") {
            value = value.slice(0, value.length - 1)
        }
        var slash = value.lastIndexOf("/")
        if (slash <= 0) {
            return ""
        }
        return value.slice(0, slash)
    }

    function normalizedPath(path) {
        var value = (path || "").trim()
        while (value.length > 1 && value.charAt(value.length - 1) === "/") {
            value = value.slice(0, value.length - 1)
        }
        return value
    }

    function indexOfEntryPath(path) {
        var target = normalizedPath(path)
        for (var i = 0; i < fileModel.count; ++i) {
            if (normalizedPath(fileModel.get(i).path) === target) {
                return i
            }
        }
        return -1
    }

    function indexOfEditorTab(path) {
        var target = normalizedPath(path)
        if (!target.length) {
            return -1
        }
        for (var i = 0; i < editorTabsModel.count; ++i) {
            if (normalizedPath(editorTabsModel.get(i).path) === target) {
                return i
            }
        }
        return -1
    }

    function syncEditorStateFromActiveTab() {
        if (activeEditorTabIndex < 0 || activeEditorTabIndex >= editorTabsModel.count) {
            selectedFilePath = ""
            editorKind = "Text"
            editorPlainText = ""
            selectedFileIndex = -1
            persistSessionState()
            return
        }

        var tab = editorTabsModel.get(activeEditorTabIndex)
        selectedFilePath = tab.path
        editorKind = tab.kind
        editorPlainText = tab.text

        var entryIndex = indexOfEntryPath(tab.path)
        selectedFileIndex = entryIndex

        // Auto-reveal: expand explorer to the file and scroll to it
        if (tab.path.length > 0) {
            expandToFilePath(tab.path)
            var revealedIndex = indexOfEntryPath(tab.path)
            if (revealedIndex >= 0) {
                selectedFileIndex = revealedIndex
                fileView.positionViewAtIndex(revealedIndex, ListView.Contain)
            }
        }

        persistSessionState()
    }

    function activateEditorTab(index) {
        if (index < 0 || index >= editorTabsModel.count) {
            activeEditorTabIndex = -1
            syncEditorStateFromActiveTab()
            return
        }
        activeEditorTabIndex = index
        syncEditorStateFromActiveTab()
    }

    function openEditorTab(path, kind, text, fallbackLabel, preferExisting, isPreview) {
        if (isPreview === undefined) {
            isPreview = true
        }
        var normalizedFilePath = normalizedPath(path)
        var resolvedKind = effectiveEditorKind(normalizedFilePath, kind)
        var shouldReuse = preferExisting !== false && normalizedFilePath.length > 0
        var existingIndex = shouldReuse ? indexOfEditorTab(normalizedFilePath) : -1

        if (existingIndex >= 0) {
            editorTabsModel.setProperty(existingIndex, "kind", resolvedKind)
            editorTabsModel.setProperty(existingIndex, "text", (isImageKind(resolvedKind, normalizedFilePath) || isVideoKind(resolvedKind, normalizedFilePath) || isPdfKind(resolvedKind) || (isOfficeDocumentKind(resolvedKind, normalizedFilePath) && !isInlineDocumentKind(resolvedKind, normalizedFilePath))) ? "" : (text || ""))
            editorTabsModel.setProperty(existingIndex, "label", editorTabLabel(normalizedFilePath, fallbackLabel))
            if (!isPreview) {
                editorTabsModel.setProperty(existingIndex, "preview", false)
            }
            activateEditorTab(existingIndex)
            return
        }

        // If there's an existing preview tab, replace it instead of appending
        var previewIndex = -1
        for (var i = 0; i < editorTabsModel.count; ++i) {
            if (editorTabsModel.get(i).preview) {
                previewIndex = i
                break
            }
        }

        if (previewIndex >= 0) {
            editorTabsModel.setProperty(previewIndex, "path", normalizedFilePath)
            editorTabsModel.setProperty(previewIndex, "kind", resolvedKind)
            editorTabsModel.setProperty(previewIndex, "text", (isImageKind(resolvedKind, normalizedFilePath) || isVideoKind(resolvedKind, normalizedFilePath) || isPdfKind(resolvedKind) || (isOfficeDocumentKind(resolvedKind, normalizedFilePath) && !isInlineDocumentKind(resolvedKind, normalizedFilePath))) ? "" : (text || ""))
            editorTabsModel.setProperty(previewIndex, "label", editorTabLabel(normalizedFilePath, fallbackLabel))
            editorTabsModel.setProperty(previewIndex, "preview", isPreview)
            activateEditorTab(previewIndex)
            return
        }

        editorTabsModel.append({
            path: normalizedFilePath,
            kind: resolvedKind,
            text: (isImageKind(resolvedKind, normalizedFilePath) || isVideoKind(resolvedKind, normalizedFilePath) || isPdfKind(resolvedKind) || (isOfficeDocumentKind(resolvedKind, normalizedFilePath) && !isInlineDocumentKind(resolvedKind, normalizedFilePath))) ? "" : (text || ""),
            label: editorTabLabel(normalizedFilePath, fallbackLabel),
            preview: isPreview
        })
        activateEditorTab(editorTabsModel.count - 1)
    }

    function closeEditorTab(index) {
        if (index < 0 || index >= editorTabsModel.count) {
            return
        }

        var wasActive = index === activeEditorTabIndex
        editorTabsModel.remove(index, 1)

        if (editorTabsModel.count === 0) {
            activeEditorTabIndex = -1
            syncEditorStateFromActiveTab()
            return
        }

        if (wasActive) {
            activateEditorTab(Math.min(index, editorTabsModel.count - 1))
            return
        }

        if (index < activeEditorTabIndex) {
            activeEditorTabIndex -= 1
        }
        syncEditorStateFromActiveTab()
    }

    function closeActiveEditorTab() {
        if (activeEditorTabIndex >= 0) {
            closeEditorTab(activeEditorTabIndex)
        }
    }

    function activateAdjacentEditorTab(step) {
        if (editorTabsModel.count <= 1) {
            return
        }
        if (activeEditorTabIndex < 0) {
            activateEditorTab(0)
            return
        }
        var offset = step < 0 ? -1 : 1
        var nextIndex = (activeEditorTabIndex + offset + editorTabsModel.count) % editorTabsModel.count
        activateEditorTab(nextIndex)
    }

    function editorTabsSnapshot() {
        var tabs = []
        for (var i = 0; i < editorTabsModel.count; ++i) {
            var tab = editorTabsModel.get(i)
            tabs.push({
                path: tab.path || "",
                kind: tab.kind || "Text",
                label: tab.label || "",
                preview: !!tab.preview,
                text: (tab.path || "").length > 0 ? "" : (tab.text || "")
            })
        }
        return tabs
    }

    function restoreEditorTabs(tabEntries, activeIndex) {
        editorTabsModel.clear()

        for (var i = 0; i < tabEntries.length; ++i) {
            var entry = tabEntries[i]
            var path = normalizedPath(entry.path || "")
            var text = ""
            var kind = effectiveEditorKind(path, entry.kind || "Text")

            if (path.length > 0) {
                if (!isImageKind(kind, path) && !isVideoKind(kind, path) && !isPdfKind(kind) && !(isOfficeDocumentKind(kind, path) && !isInlineDocumentKind(kind, path))) {
                    text = readEditorPreviewText(path, kind)
                    if (text.indexOf("read_text_file_failed:") === 0 || text.indexOf("read_docx_text_file_failed:") === 0) {
                        continue
                    }
                }
            } else {
                text = entry.text || ""
            }

            editorTabsModel.append({
                path: path,
                kind: kind,
                text: text,
                label: editorTabLabel(path, entry.label || ""),
                preview: !!entry.preview
            })
        }

        if (editorTabsModel.count === 0) {
            activeEditorTabIndex = -1
            syncEditorStateFromActiveTab()
            return
        }

        var targetIndex = activeIndex
        if (targetIndex < 0 || targetIndex >= editorTabsModel.count) {
            targetIndex = 0
        }
        activateEditorTab(targetIndex)
    }

    function expandToFilePath(filePath) {
        var targetFilePath = normalizedPath(filePath)
        var targetDirPath = normalizedPath(directoryForFilePath(targetFilePath))
        var rootPath = normalizedPath(explorerCurrentPath)
        if (!targetFilePath.length || !targetDirPath.length) {
            return
        }

        if (!rootPath.length) {
            if (targetDirPath === "/") {
                var rootIndex = indexOfEntryPath("/")
                if (rootIndex >= 0) {
                    var rootEntry = fileModel.get(rootIndex)
                    if (rootEntry.isDir && !rootEntry.expanded) {
                        expandDirectory(rootIndex)
                    }
                }
                return
            }

            var topRootIndex = indexOfEntryPath("/")
            if (topRootIndex < 0) {
                return
            }
            var topRootEntry = fileModel.get(topRootIndex)
            if (topRootEntry.isDir && !topRootEntry.expanded) {
                expandDirectory(topRootIndex)
            }

            var topParts = targetDirPath.slice(1).split("/")
            var topCurrentPath = "/"
            for (var topPartIndex = 0; topPartIndex < topParts.length; ++topPartIndex) {
                if (!topParts[topPartIndex].length) {
                    continue
                }
                topCurrentPath = topCurrentPath === "/"
                    ? "/" + topParts[topPartIndex]
                    : topCurrentPath + "/" + topParts[topPartIndex]
                var topIndex = indexOfEntryPath(topCurrentPath)
                if (topIndex >= 0) {
                    var topEntry = fileModel.get(topIndex)
                    if (topEntry.isDir && !topEntry.expanded) {
                        expandDirectory(topIndex)
                    }
                }
            }
            return
        }

        if (targetDirPath === rootPath) {
            return
        }
        if (targetDirPath.indexOf(rootPath + "/") !== 0) {
            return
        }

        var relativeDir = targetDirPath.slice(rootPath.length + 1)
        var parts = relativeDir.split("/")
        var currentPath = rootPath
        for (var i = 0; i < parts.length; ++i) {
            if (!parts[i].length) {
                continue
            }
            currentPath += "/" + parts[i]
            var index = indexOfEntryPath(currentPath)
            if (index >= 0) {
                var entry = fileModel.get(index)
                if (entry.isDir && !entry.expanded) {
                    expandDirectory(index)
                }
            }
        }
    }

    function persistSessionState() {
        if (restoringSession) {
            return
        }
        Runtime.save_ui_session(
            explorerCurrentPath || "",
            selectedFilePath || "",
            explorerPaneWidth,
            agentPaneWidth,
            uiZoom,
            editorTabsSnapshot(),
            activeEditorTabIndex)
    }

    function restoreEditorSession() {
        restoringSession = true

        var session = Runtime.load_ui_session()

        if ((session.explorerPaneWidth || 0) > 0) {
            explorerPaneWidth = session.explorerPaneWidth
        }
        if ((session.agentPaneWidth || 0) > 0) {
            agentPaneWidth = session.agentPaneWidth
        }
        if ((session.uiZoom || 0) > 0) {
            uiZoom = session.uiZoom
        }

        var savedFilePath = (session.selectedFilePath || "").trim()
        var savedExplorerPath = (session.explorerCurrentPath || "").trim()
        var savedEditorTabs = session.editorTabs || []
        var savedActiveEditorTabIndex = session.activeEditorTabIndex
        if (savedActiveEditorTabIndex === undefined || savedActiveEditorTabIndex === null) {
            savedActiveEditorTabIndex = -1
        }
        var targetExplorerPath = savedExplorerPath.length ? savedExplorerPath : Runtime.explorer_default_path()
        var normalizedTargetExplorerPath = normalizedPath(targetExplorerPath)

        if (savedFilePath.length && savedExplorerPath.length) {
            var inferredDir = normalizedPath(directoryForFilePath(savedFilePath))
            var fileUnderExplorerRoot = inferredDir === normalizedTargetExplorerPath
                || inferredDir.indexOf(normalizedTargetExplorerPath + "/") === 0
            if (inferredDir.length && (!normalizedTargetExplorerPath.length || !fileUnderExplorerRoot)) {
                targetExplorerPath = inferredDir
            }
        }

        refreshExplorer(targetExplorerPath)

        if (savedEditorTabs.length > 0) {
            restoreEditorTabs(savedEditorTabs, savedActiveEditorTabIndex)
        } else if (savedFilePath.length) {
            expandToFilePath(savedFilePath)
            for (var i = 0; i < fileModel.count; ++i) {
                var entry = fileModel.get(i)
                if (!entry.isDir && normalizedPath(entry.path) === normalizedPath(savedFilePath)) {
                    selectFile(i, false)
                    break
                }
            }
        }

        if (selectedFilePath.length) {
            expandToFilePath(selectedFilePath)
            selectedFileIndex = indexOfEntryPath(selectedFilePath)
            if (selectedFileIndex >= 0) {
                fileView.positionViewAtIndex(selectedFileIndex, ListView.Contain)
            }
        }

        restoringSession = false
        persistSessionState()
    }

    function escapeHtml(text) {
        return (text || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/\"/g, "&quot;")
    }

    function syntaxKeywords(kind) {
        if (kind === "DOCX") {
            return []
        }
        if (kind === "QML") {
            return ["import", "property", "readonly", "required", "signal", "function", "if", "else", "return", "true", "false", "var", "let", "const", "id", "onClicked", "anchors", "parent"]
        }
        if (kind === "C++") {
            return ["class", "const", "constexpr", "enum", "explicit", "false", "for", "if", "include", "int", "namespace", "nullptr", "override", "private", "protected", "public", "return", "signals", "slots", "static", "struct", "switch", "template", "true", "void", "while"]
        }
        return ["if", "else", "for", "while", "return", "function", "const", "let", "var", "true", "false"]
    }

    function codeFontCss() {
        // Avoid generic CSS font families here because Qt on Windows may
        // resolve them through legacy GDI aliases like "Modern" and log warnings.
        return "'Consolas','Cascadia Mono','Courier New'"
    }

    function lineNumberHtml(text) {
        var lineCount = Math.max(1, (text || "").split("\n").length)
        var numbers = []
        for (var index = 1; index <= lineCount; ++index) {
            numbers.push(index)
        }

        return "<pre style=\"margin:0;font-family:" + codeFontCss() + ";font-size:14px;line-height:1.35;color:" + shell.textMuted + ";text-align:right;\">"
            + numbers.join("\n")
            + "</pre>"
    }

    function highlightCode(text, kind) {
        var source = text || ""
        if (!source.length) {
            return "<pre style=\"margin:0;font-family:" + codeFontCss() + ";font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\"></pre>"
        }
        if (kind === "DOCX") {
            return "<pre style=\"margin:0;font-family:" + codeFontCss() + ";font-size:14px;line-height:1.45;color:" + shell.textPrimary + ";white-space:pre-wrap;\">"
                + escapeHtml(source)
                + "</pre>"
        }

        var keywords = syntaxKeywords(kind)
        var keywordPattern = keywords.length > 0 ? "\\b(?:" + keywords.join("|") + ")\\b" : "$^"
        var tokenPattern = new RegExp("(//[^\\n]*|/\\*[\\s\\S]*?\\*/|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|#[A-Za-z_][A-Za-z0-9_]*|" + keywordPattern + ")", "g")
        var highlighted = ""
        var lastIndex = 0
        var match

        while ((match = tokenPattern.exec(source)) !== null) {
            highlighted += escapeHtml(source.slice(lastIndex, match.index))
            var token = match[0]
            var color = shell.highlightKeyword

            if (token.indexOf("//") === 0 || token.indexOf("/*") === 0) {
                color = shell.highlightComment
            } else if (token.indexOf("#") === 0) {
                color = shell.highlightDirective
            } else if (token.indexOf("\"") === 0 || token.indexOf("'") === 0) {
                color = shell.highlightString
            }

            highlighted += "<span style=\"color:" + color + ";\">" + escapeHtml(token) + "</span>"
            lastIndex = match.index + token.length
        }

        highlighted += escapeHtml(source.slice(lastIndex))
        return "<pre style=\"margin:0;font-family:" + codeFontCss() + ";font-size:14px;line-height:1.35;color:" + shell.textPrimary + ";\">"
            + highlighted.replace(/\t/g, "    ")
            + "</pre>"
    }

    function appendConversationMessage(kind, label, text, pending) {
        var parsed = shell.parseConversationPayload(text || "")
        conversationModel.append({
            kind: kind,
            label: label,
            text: text,
            bodyText: parsed.bodyText,
            modeText: parsed.modeText,
            planText: parsed.planText,
            pending: pending,
            durationText: pending ? qsTr("Working...") : "",
            copied: false
        })
        conversationList.positionViewAtEnd()
    }

    function copyConversationText(text) {
        if (!text || !text.length) {
            return
        }
        Runtime.copy_to_clipboard(text)
        shell.copyNoticeText = qsTr("Copied")
        copyNoticeTimer.restart()
    }

    function beginConversation(prompt, responseLabel, pendingText) {
        lastPromptText = prompt
        lastResponseLabel = responseLabel
        activeAssistantStreamText = ""
        resultOutput.text = pendingText
        lastRunDurationText = qsTr("Working...")
        runStartMs = Date.now()
        appendConversationMessage("user", qsTr("You"), prompt, false)
        activeAssistantMessageIndex = conversationModel.count
        appendConversationMessage("assistant", responseLabel, pendingText, true)
    }

    function updateStreamingConversation(chunk) {
        if (!chunk || !chunk.length) {
            return
        }
        activeAssistantStreamText += chunk
        resultOutput.text = activeAssistantStreamText
        var parsed = shell.parseConversationPayload(activeAssistantStreamText)
        if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
            conversationModel.setProperty(activeAssistantMessageIndex, "text", activeAssistantStreamText)
            conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", parsed.bodyText)
            conversationModel.setProperty(activeAssistantMessageIndex, "modeText", parsed.modeText)
            conversationModel.setProperty(activeAssistantMessageIndex, "planText", parsed.planText)
            conversationModel.setProperty(activeAssistantMessageIndex, "pending", true)
            conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("Streaming..."))
        }
        conversationList.positionViewAtEnd()
    }

    function finishConversation(result, durationText) {
        activeAssistantStreamText = ""
        resultOutput.text = result
        var parsed = shell.parseConversationPayload(result)
        diagnosticsSkillRecords = parseSkillRecords(result)
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
            conversationModel.setProperty(activeAssistantMessageIndex, "text", result)
            conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", parsed.bodyText)
            conversationModel.setProperty(activeAssistantMessageIndex, "modeText", parsed.modeText)
            conversationModel.setProperty(activeAssistantMessageIndex, "planText", parsed.planText)
            conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
            conversationModel.setProperty(activeAssistantMessageIndex, "durationText", durationText || "")
        }
        conversationList.positionViewAtEnd()
        activeAssistantMessageIndex = -1
    }

    function parseConversationPayload(text) {
        var source = text || ""
        var lines = source.split("\n")
        var modeText = ""
        var planText = ""
        var bodyLines = []
        var inHeader = true

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i]
            if (inHeader && line.indexOf("[mode] ") === 0) {
                modeText = line.substring(7).trim()
                continue
            }
            if (inHeader && line.indexOf("[plan] ") === 0) {
                planText = line.substring(7).trim()
                continue
            }
            if (inHeader && line.trim().length === 0 && (modeText.length > 0 || planText.length > 0)) {
                continue
            }
            inHeader = false
            bodyLines.push(line)
        }

        return {
            modeText: modeText,
            planText: planText,
            bodyText: bodyLines.join("\n").trim()
        }
    }

    function elapsedDurationText() {
        var startMs = Number(shell.runStartMs)
        var nowMs = Date.now()
        if (!isFinite(startMs) || startMs <= 0 || startMs > nowMs) {
            return qsTr("Worked just now")
        }
        var elapsedSeconds = Math.max(1, Math.round((nowMs - startMs) / 1000))
        return qsTr("Worked for %1s").arg(elapsedSeconds)
    }

    function refreshLoginButtonText() {
        shell.loginButtonText = shell.loginLoggedIn ? qsTr("已登录") : qsTr("登录")
    }

    function generateFourDigitCode() {
        return String(1000 + Math.floor(Math.random() * 9000))
    }

    function requireLoginForAgentAction(actionLabel) {
        if (shell.loginLoggedIn) {
            return false
        }
        shell.runtimeStatusText = qsTr("login_required")
        shell.loginStatusText = qsTr("请先登录后再进行%1").arg(actionLabel)
        loginPopup.open()
        return true
    }

    function sendAgentPrompt() {
        if (requireLoginForAgentAction(qsTr("Agent 请求"))) {
            return
        }
        if (shell.agentRunning) {
            return
        }

        var prompt = promptEditor.text.trim()
        if (!prompt) {
            prompt = "hello"
        }
        promptEditor.text = ""

        shell.runClickSeq += 1
        shell.agentRunning = true
        shell.runtimeStatusText = qsTr("routing #") + shell.runClickSeq
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Working on your request..."))
        agentRunTimeoutTimer.restart()
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            Runtime.run_agent_auto_async(prompt, shell.selectedFilePath || "", shell.runSteps)
        } catch (e) {
            resultOutput.text = qsTr("run_agent_failed: ") + e
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "modeText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "planText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
                activeAssistantMessageIndex = -1
            }
            shell.runtimeStatusText = qsTr("failed #") + shell.runClickSeq
            shell.agentRunning = false
            agentRunTimeoutTimer.stop()
        } finally {
            // Completion comes from Runtime.agentRunFinished.
        }
    }

    function sendCodeSuggestion() {
        if (requireLoginForAgentAction(qsTr("代码请求"))) {
            return
        }
        var prompt = promptEditor.text.trim()
        var filePath = shell.selectedFilePath || ""
        promptEditor.text = ""
        shell.runtimeStatusText = qsTr("suggesting")
        shell.beginConversation(prompt, qsTr("NeurX"), qsTr("Preparing code suggestion..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.run_code_assistant(prompt, filePath)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("suggestion_done")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", shell.lastRunDurationText)
            }
            activeAssistantMessageIndex = -1
        } catch (e) {
            resultOutput.text = qsTr("suggest_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.lastRunDurationText = qsTr("Working...")
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", resultOutput.text)
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
            }
            activeAssistantMessageIndex = -1
        }
    }

    function resolvedAgentPrompt() {
        var prompt = promptEditor.text.trim()
        if (!prompt && shell.lastPromptText.length > 0) {
            prompt = shell.lastPromptText
        }
        if (!prompt) {
            prompt = "hello"
        }
        return prompt
    }

    function sendSkillSnapshot() {
        if (requireLoginForAgentAction(qsTr("技能导出"))) {
            return
        }
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("snapshot")
        shell.beginConversation(prompt, qsTr("Snapshot"), qsTr("Exporting skill snapshot..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_skill_snapshot(prompt, shell.runSteps)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("snapshot_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("snapshot_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    function sendTrajectoryExport() {
        if (requireLoginForAgentAction(qsTr("轨迹导出"))) {
            return
        }
        var prompt = resolvedAgentPrompt()
        shell.runtimeStatusText = qsTr("trajectory")
        shell.beginConversation(prompt, qsTr("Trajectory"), qsTr("Exporting agent trajectory..."))
        diagnosticsSkillRecords = []
        selectedSkillName = ""
        skillStatusFilter = ""
        skillActiveOnly = false
        skillHighFailOnly = false
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        shell.agentDetailsExpanded = false

        try {
            resultOutput.text = Runtime.export_agent_trajectory(prompt, shell.runSteps)
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.runtimeStatusText = qsTr("trajectory_done")
            shell.finishConversation(resultOutput.text, shell.lastRunDurationText)
        } catch (e) {
            resultOutput.text = qsTr("trajectory_failed: ") + e
            shell.runtimeStatusText = qsTr("failed")
            shell.finishConversation(resultOutput.text, qsTr("failed"))
        }
    }

    ListModel {
        id: conversationModel
    }

    ListModel {
        id: fileModel
    }

    ListModel {
        id: editorTabsModel
    }

    function explorerChildEntries(path, depth) {
        var entries = Runtime.explorer_entries(path || "")
        var dirs = []
        var files = []
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            var isExpanded = !!explorerExpandedPaths[entry.path]
            var item = {
                label: entry.label,
                path: entry.path,
                kind: entry.kind,
                isDir: entry.isDir,
                depth: depth,
                expanded: entry.isDir ? isExpanded : false,
                isRoot: false
            }
            if (entry.isDir) {
                dirs.push(item)
            } else {
                files.push(item)
            }
        }
        // Always render directories before files at every tree level.
        return dirs.concat(files)
    }

    function insertExpandedChildren(index) {
        if (index < 0 || index >= fileModel.count) {
            return 0
        }
        var entry = fileModel.get(index)
        if (!entry.isDir || !entry.expanded) {
            return 0
        }
        var children = explorerChildEntries(entry.path, entry.depth + 1)
        for (var i = 0; i < children.length; ++i) {
            fileModel.insert(index + 1 + i, children[i])
        }
        var inserted = children.length
        var cursor = index + 1
        for (var j = 0; j < children.length; ++j) {
            if (children[j].isDir && children[j].expanded) {
                var nested = insertExpandedChildren(cursor)
                inserted += nested
                cursor += nested
            }
            cursor += 1
        }
        return inserted
    }

    function populateExplorerRoot() {
        fileModel.clear()
        if (!explorerRootExpanded) {
            selectedFileIndex = -1
            return
        }

        var children = explorerChildEntries(explorerCurrentPath, 0)
        if (!explorerCurrentPath.length && children.length === 1
                && children[0].isDir && children[0].path === "/") {
            children[0].expanded = true
            explorerExpandedPaths["/"] = true
        }

        for (var i = 0; i < children.length; ++i) {
            fileModel.append(children[i])
        }
        for (var j = 0; j < fileModel.count; ++j) {
            if (fileModel.get(j).isDir && fileModel.get(j).expanded) {
                insertExpandedChildren(j)
            }
        }
        var activeEntryIndex = indexOfEntryPath(selectedFilePath)
        selectedFileIndex = activeEntryIndex >= 0 ? activeEntryIndex : (fileModel.count > 0 ? 0 : -1)
        if (selectedFileIndex >= 0) {
            fileView.positionViewAtIndex(selectedFileIndex, ListView.Contain)
        } else {
            fileView.positionViewAtBeginning()
        }
    }

    function refreshExplorer(path) {
        fileModel.clear()
        explorerCurrentPath = path || ""
        explorerRootLabel = shell.explorerLeafName(explorerCurrentPath)
        explorerRootExpanded = true
        populateExplorerRoot()
        persistSessionState()
    }

    function collapseDirectory(index) {
        if (index < 0 || index >= fileModel.count) {
            return
        }
        var entry = fileModel.get(index)
        var depth = entry.depth
        var removeCount = 0
        for (var i = index + 1; i < fileModel.count; ++i) {
            if (fileModel.get(i).depth <= depth) {
                break
            }
            removeCount += 1
        }
        if (removeCount > 0) {
            fileModel.remove(index + 1, removeCount)
        }
        fileModel.setProperty(index, "expanded", false)
        explorerExpandedPaths[entry.path] = false
    }

    function expandDirectory(index) {
        if (index < 0 || index >= fileModel.count) {
            return
        }
        var entry = fileModel.get(index)
        var children = explorerChildEntries(entry.path, entry.depth + 1)
        for (var i = 0; i < children.length; ++i) {
            fileModel.insert(index + 1 + i, children[i])
        }
        fileModel.setProperty(index, "expanded", true)
        explorerExpandedPaths[entry.path] = true
    }

    function toggleDirectory(index) {
        if (index < 0 || index >= fileModel.count) {
            return
        }
        var entry = fileModel.get(index)
        if (!entry.isDir) {
            return
        }
        if (entry.expanded) {
            collapseDirectory(index)
        } else {
            expandDirectory(index)
        }
    }

    function selectFile(index, isPreview) {
        if (index < 0 || index >= fileModel.count) {
            return
        }

        var entry = fileModel.get(index)
        selectedFileIndex = index
        if (entry.isDir) {
            // directories are handled in toggleDirectory
            toggleDirectory(index)
            return
        }
        if (isImageKind(entry.kind, entry.path)) {
            openEditorTab(entry.path, entry.kind, "", entry.label, true, isPreview)
            return
        }
        if (isVideoKind(entry.kind, entry.path)) {
            openEditorTab(entry.path, entry.kind, "", entry.label, true, isPreview)
            return
        }
        if (isPdfKind(entry.kind)) {
            openEditorTab(entry.path, entry.kind, "", entry.label, true, isPreview)
            return
        }
        if (isInlineDocumentKind(entry.kind, entry.path)) {
            var docxText = Runtime.read_docx_text_file(entry.path)
            if (docxText.indexOf("read_docx_text_file_failed:") === 0) {
                shell.copyNoticeText = qsTr("Open failed")
                copyNoticeTimer.restart()
                return
            }
            openEditorTab(entry.path, entry.kind, docxText, entry.label, true, isPreview)
            return
        }
        if (isOfficeDocumentKind(entry.kind, entry.path)) {
            openEditorTab(entry.path, entry.kind, "", entry.label, true, isPreview)
            return
        }
        openEditorTab(entry.path, entry.kind, Runtime.read_text_file(entry.path), entry.label, true, isPreview)
    }

    function goExplorerUp() {
        if (!explorerCurrentPath || explorerCurrentPath === "/") {
            refreshExplorer("")
            return
        }
        var normalized = explorerCurrentPath
        while (normalized.length > 1 && normalized.charAt(normalized.length - 1) === "/") {
            normalized = normalized.slice(0, normalized.length - 1)
        }
        var slash = normalized.lastIndexOf("/")
        if (slash <= 0) {
            refreshExplorer("")
            return
        }
        refreshExplorer(normalized.slice(0, slash))
    }

    function clamp(value, minValue, maxValue) {
        if (maxValue < minValue) {
            return maxValue
        }
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function clampPaneWidths() {
        var available = Math.max(0, shell.width - (workspaceMargin * 2) - (paneHandleWidth * 2))
        var minEditor = Math.min(paneMinEditorWidth, available)
        var maxLeft = Math.max(paneMinExplorerWidth, available - paneMinAgentWidth - minEditor)
        explorerPaneWidth = clamp(explorerPaneWidth, paneMinExplorerWidth, maxLeft)

        var maxRight = Math.max(paneMinAgentWidth, available - explorerPaneWidth - minEditor)
        agentPaneWidth = clamp(agentPaneWidth, paneMinAgentWidth, maxRight)

        var editorWidth = available - explorerPaneWidth - agentPaneWidth
        if (editorWidth < paneMinEditorWidth) {
            var deficit = paneMinEditorWidth - editorWidth
            var reduceRight = Math.min(deficit, agentPaneWidth - paneMinAgentWidth)
            agentPaneWidth -= reduceRight
            deficit -= reduceRight

            if (deficit > 0) {
                var reduceLeft = Math.min(deficit, explorerPaneWidth - paneMinExplorerWidth)
                explorerPaneWidth -= reduceLeft
            }
        }
    }

    function parseResultField(text, key) {
        var lines = (text || "").split("\n")
        var prefix = key + "="
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0) {
                return lines[i].slice(prefix.length)
            }
        }
        return ""
    }

    function exportSavedPath(text) {
        return parseResultField(text, "saved_path")
    }

    function exportActiveSkill(text) {
        return parseResultField(text, "active_skill")
    }

    function exportSkillExecutionStatus(text) {
        return parseResultField(text, "skill_execution_status")
    }

    function exportTraceCount(text) {
        return parseResultField(text, "trace_count")
    }

    function exportRegistryVersion(text) {
        return parseResultField(text, "registry_version")
    }

    function exportPromoteCount(text) {
        return parseResultField(text, "promote_count")
    }

    function exportRetireCount(text) {
        return parseResultField(text, "retire_count")
    }

    function exportLastAction(text) {
        return parseResultField(text, "last_action")
    }

    function exportLastObservation(text) {
        return parseResultField(text, "last_observation")
    }

    function parseSkillRecords(text) {
        var lines = (text || "").split("\n")
        var records = []
        for (var i = 0; i < lines.length; ++i) {
            var match = /^skill\[(\d+)\]\.([a-z_]+)=(.*)$/.exec(lines[i])
            if (!match) {
                continue
            }
            var index = parseInt(match[1], 10)
            var field = match[2]
            var value = match[3]
            if (!records[index]) {
                records[index] = {
                    skill_index: index,
                    name: "",
                    version: "",
                    intent: "",
                    status: "",
                    created_step: "",
                    updated_step: "",
                    promote_count: "",
                    fail_count: "",
                    success_rate: "",
                    avg_steps: "",
                    tool_cost: "",
                    stability: ""
                }
            }
            records[index][field] = value
        }

        var compact = []
        for (var j = 0; j < records.length; ++j) {
            if (records[j]) {
                compact.push(records[j])
            }
        }
        return compact
    }

    function selectedSkillRecord() {
        var records = filteredDiagnosticsSkillRecords()
        for (var i = 0; i < records.length; ++i) {
            if ((records[i].name || "") === selectedSkillName) {
                return records[i]
            }
        }
        for (var j = 0; j < diagnosticsSkillRecords.length; ++j) {
            if ((diagnosticsSkillRecords[j].name || "") === selectedSkillName) {
                return diagnosticsSkillRecords[j]
            }
        }
        return null
    }

    function skillStatusOptions() {
        var seen = { "": true }
        var options = [""]
        for (var i = 0; i < diagnosticsSkillRecords.length; ++i) {
            var status = (diagnosticsSkillRecords[i].status || "").trim()
            if (!status.length || seen[status]) {
                continue
            }
            seen[status] = true
            options.push(status)
        }
        return options
    }

    function filteredDiagnosticsSkillRecords() {
        var filtered = []
        for (var i = 0; i < diagnosticsSkillRecords.length; ++i) {
            var item = diagnosticsSkillRecords[i]
            if (skillStatusFilter.length > 0 && (item.status || "") !== skillStatusFilter) {
                continue
            }
            if (skillActiveOnly && (item.name || "") !== exportActiveSkill(resultOutput.text)) {
                continue
            }
            if (skillHighFailOnly && parseInt(item.fail_count || "0", 10) < 2) {
                continue
            }
            filtered.push(item)
        }
        return filtered
    }

    function clearSelectedSkillIfFilteredOut() {
        if (!selectedSkillName.length) {
            return
        }
        var records = filteredDiagnosticsSkillRecords()
        for (var i = 0; i < records.length; ++i) {
            if ((records[i].name || "") === selectedSkillName) {
                return diagnosticsSkillRecords[i]
            }
        }
        selectedSkillName = ""
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
    }

    function skillRecordPreview(text, skillRecord) {
        if (!skillRecord) {
            return ""
        }
        var lines = (text || "").split("\n")
        var prefix = "skill[" + skillRecord.skill_index + "]."
        var preview = []
        var active = exportActiveSkill(text)
        var execution = exportSkillExecutionStatus(text)
        var savedPath = exportSavedPath(text)
        if (skillRecord.name) {
            preview.push("selected_skill=" + skillRecord.name)
        }
        if (active.length > 0) {
            preview.push("active_skill=" + active)
        }
        if (execution.length > 0) {
            preview.push("skill_execution_status=" + execution)
        }
        if (savedPath.length > 0) {
            preview.push("saved_path=" + savedPath)
        }
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(prefix) === 0) {
                preview.push(lines[i])
            }
        }
        return preview.join("\n")
    }

    function trajectoryPreviewForSkill(text, skillRecord) {
        if (!skillRecord) {
            return ""
        }

        var lines = (text || "").split("\n")
        var skillName = skillRecord.name || ""
        var headers = []
        var stepMap = {}
        var activePrefix = /^active_skill\[(\d+)\]=(.*)$/
        var fieldPrefix = /^(step|task|input|action|observation|ok|active_skill|tool|tool_timeout_ms|tool_retries)\[(\d+)\]=(.*)$/

        for (var i = 0; i < lines.length; ++i) {
            var headerMatch = /^([^\[]+)=/.exec(lines[i])
            var stepMatch = fieldPrefix.exec(lines[i])
            if (stepMatch) {
                var index = stepMatch[2]
                if (!stepMap[index]) {
                    stepMap[index] = []
                }
                stepMap[index].push(lines[i])
                continue
            }
            if (headerMatch && headerMatch[1].indexOf("skill") !== 0) {
                headers.push(lines[i])
            }
        }

        var filtered = []
        for (var j = 0; j < lines.length; ++j) {
            var activeMatch = activePrefix.exec(lines[j])
            if (!activeMatch) {
                continue
            }
            if ((activeMatch[2] || "") !== skillName) {
                continue
            }
            var stepLines = stepMap[activeMatch[1]]
            if (!stepLines) {
                continue
            }
            filtered.push(stepLines.join("\n"))
        }

        var preview = []
        preview.push("selected_skill=" + skillName)
        preview.push("filtered_trace_steps=" + filtered.length)
        if (headers.length > 0) {
            preview.push(headers.join("\n"))
        }
        if (filtered.length > 0) {
            preview.push(filtered.join("\n\n"))
        } else {
            preview.push("no_trace_steps_for_skill=true")
            preview.push(skillRecordPreview(text, skillRecord))
        }
        return preview.join("\n")
    }

    function traceStepsForSkill(text, skillRecord) {
        if (!skillRecord) {
            return []
        }

        var lines = (text || "").split("\n")
        var skillName = skillRecord.name || ""
        var stepMap = {}
        var orderedIndexes = []
        var activePrefix = /^active_skill\[(\d+)\]=(.*)$/
        var fieldPrefix = /^(step|task|input|action|observation|ok|active_skill|tool|tool_timeout_ms|tool_retries)\[(\d+)\]=(.*)$/

        for (var i = 0; i < lines.length; ++i) {
            var stepMatch = fieldPrefix.exec(lines[i])
            if (!stepMatch) {
                continue
            }
            var field = stepMatch[1]
            var index = stepMatch[2]
            var value = stepMatch[3]
            if (!stepMap[index]) {
                stepMap[index] = {
                    step: "",
                    task: "",
                    input: "",
                    action: "",
                    observation: "",
                    ok: "false",
                    active_skill: "",
                    tool: "",
                    tool_timeout_ms: "0",
                    tool_retries: "0"
                }
                orderedIndexes.push(index)
            }
            stepMap[index][field] = value
        }

        var filtered = []
        for (var j = 0; j < orderedIndexes.length; ++j) {
            var item = stepMap[orderedIndexes[j]]
            if ((item.active_skill || "") === skillName) {
                filtered.push(item)
            }
        }
        return filtered
    }

    function selectedSkillTraceSteps() {
        return traceStepsForSkill(resultOutput.text, selectedSkillRecord())
    }

    function selectedSkillTraceToolOptions() {
        var steps = selectedSkillTraceSteps()
        var seen = { "": true }
        var options = [""]
        for (var i = 0; i < steps.length; ++i) {
            var toolName = (steps[i].tool || "").trim()
            if (!toolName.length || seen[toolName]) {
                continue
            }
            seen[toolName] = true
            options.push(toolName)
        }
        return options
    }

    function filteredSelectedSkillTraceSteps() {
        var steps = selectedSkillTraceSteps()
        var filtered = []
        var searchText = (selectedSkillSearchText || "").trim().toLowerCase()
        for (var i = 0; i < steps.length; ++i) {
            var item = steps[i]
            if (selectedSkillFailedOnly && (item.ok || "false") === "true") {
                continue
            }
            if (selectedSkillToolFilter.length > 0 && (item.tool || "") !== selectedSkillToolFilter) {
                continue
            }
            if (searchText.length > 0) {
                var actionText = (item.action || "").toLowerCase()
                var observationText = (item.observation || "").toLowerCase()
                if (actionText.indexOf(searchText) < 0 && observationText.indexOf(searchText) < 0) {
                    continue
                }
            }
            filtered.push(item)
        }
        return filtered
    }

    function traceStepPreview(stepRecord) {
        if (!stepRecord) {
            return ""
        }

        var lines = []
        lines.push("step=" + (stepRecord.step || ""))
        lines.push("task=" + (stepRecord.task || ""))
        lines.push("input=" + (stepRecord.input || ""))
        lines.push("action=" + (stepRecord.action || ""))
        lines.push("observation=" + (stepRecord.observation || ""))
        lines.push("active_skill=" + (stepRecord.active_skill || ""))
        lines.push("tool=" + (stepRecord.tool || ""))
        lines.push("tool_timeout_ms=" + (stepRecord.tool_timeout_ms || "0"))
        lines.push("tool_retries=" + (stepRecord.tool_retries || "0"))
        lines.push("ok=" + (stepRecord.ok || "false"))
        return lines.join("\n")
    }

    function filteredSkillContextPreview() {
        var skillRecord = selectedSkillRecord()
        if (!skillRecord) {
            return ""
        }

        var preview = []
        var steps = filteredSelectedSkillTraceSteps()
        preview.push("selected_skill=" + (skillRecord.name || ""))
        preview.push("failed_only=" + (selectedSkillFailedOnly ? "true" : "false"))
        preview.push("tool_filter=" + (selectedSkillToolFilter || ""))
        preview.push("search_text=" + (selectedSkillSearchText || ""))
        preview.push("filtered_trace_steps=" + steps.length)
        preview.push(skillRecordPreview(resultOutput.text, skillRecord))
        if (steps.length > 0) {
            var blocks = []
            for (var i = 0; i < steps.length; ++i) {
                blocks.push(traceStepPreview(steps[i]))
            }
            preview.push(blocks.join("\n\n"))
        } else {
            preview.push("no_trace_steps_for_current_filters=true")
        }
        return preview.join("\n")
    }

    function openFilteredSkillContext() {
        var text = filteredSkillContextPreview()
        if (!text.length) {
            return
        }
        selectedFileIndex = -1
        openEditorTab("", "Text", text, qsTr("Skill Context"), false)
        shell.copyNoticeText = qsTr("Opened context")
        copyNoticeTimer.restart()
    }

    function openTraceStep(stepRecord) {
        if (!stepRecord) {
            return
        }
        selectedFileIndex = -1
        openEditorTab("", "Text", traceStepPreview(stepRecord), qsTr("Trace Step"), false)
        shell.copyNoticeText = qsTr("Opened step")
        copyNoticeTimer.restart()
    }

    function openSavedExport(path) {
        var next = (path || "").trim()
        if (!next.length) {
            return
        }
        if (isImageKind("", next)) {
            selectedFileIndex = -1
            openEditorTab(next, imageKindForPath(next), "", "", true)
            shell.copyNoticeText = qsTr("Opened export")
            copyNoticeTimer.restart()
            return
        }
        if (isVideoKind("", next)) {
            selectedFileIndex = -1
            openEditorTab(next, imageKindForPath(next), "", "", true)
            shell.copyNoticeText = qsTr("Opened export")
            copyNoticeTimer.restart()
            return
        }
        if (isInlineDocumentKind("", next)) {
            var docxText = Runtime.read_docx_text_file(next)
            if (docxText.indexOf("read_docx_text_file_failed:") === 0) {
                shell.copyNoticeText = qsTr("Open failed")
                copyNoticeTimer.restart()
                return
            }
            selectedFileIndex = -1
            openEditorTab(next, imageKindForPath(next), docxText, "", true)
            shell.copyNoticeText = qsTr("Opened export")
            copyNoticeTimer.restart()
            return
        }
        if (isOfficeDocumentKind("", next)) {
            selectedFileIndex = -1
            openEditorTab(next, imageKindForPath(next), "", "", true)
            shell.copyNoticeText = qsTr("Opened export")
            copyNoticeTimer.restart()
            return
        }
        var text = Runtime.read_text_file(next)
        if (text.indexOf("read_text_file_failed:") === 0) {
            shell.copyNoticeText = qsTr("Open failed")
            copyNoticeTimer.restart()
            return
        }
        selectedFileIndex = -1
        openEditorTab(next, "Text", text, "", true)
        shell.copyNoticeText = qsTr("Opened export")
        copyNoticeTimer.restart()
    }

    function activateSkillRecord(skillRecord) {
        if (!skillRecord) {
            return
        }
        selectedSkillName = skillRecord.name || ""
        selectedSkillFailedOnly = false
        selectedSkillToolFilter = ""
        selectedSkillSearchText = ""
        var skillName = (skillRecord.name || "").trim()
        if (skillName.length > 0) {
            promptEditor.text = qsTr("Inspect skill %1").arg(skillName)
            promptEditor.forceActiveFocus()
            promptEditor.cursorPosition = promptEditor.text.length
        }
        selectedFileIndex = -1
        openEditorTab("", "Text", trajectoryPreviewForSkill(resultOutput.text, skillRecord), skillName.length ? skillName : qsTr("Skill"), false)
    }

    function openSelectedSkillExport() {
        var savedPath = exportSavedPath(resultOutput.text)
        if (savedPath.length > 0) {
            openSavedExport(savedPath)
            return
        }
        var skillRecord = selectedSkillRecord()
        if (skillRecord) {
            selectedFileIndex = -1
            openEditorTab("", "Text", trajectoryPreviewForSkill(resultOutput.text, skillRecord), qsTr("Skill Preview"), false)
        }
    }

    function inspectSelectedSkill() {
        var skillRecord = selectedSkillRecord()
        if (!skillRecord) {
            return
        }
        var skillName = (skillRecord.name || "").trim()
        if (!skillName.length) {
            return
        }
        promptEditor.text = qsTr("Inspect skill %1").arg(skillName)
        promptEditor.forceActiveFocus()
        promptEditor.cursorPosition = promptEditor.text.length
    }

    function hasStructuredExport(text) {
        return exportSavedPath(text).length > 0
            || exportActiveSkill(text).length > 0
            || exportTraceCount(text).length > 0
            || exportRegistryVersion(text).length > 0
    }

    function isFailureResult(text) {
        return text.indexOf("runtime_") === 0
            || text.indexOf("local_model_") === 0
            || text.indexOf("repo_not_found") === 0
    }

    Connections {
        target: Runtime

        function onAgentRunFinished(result) {
            agentRunTimeoutTimer.stop()
            shell.lastRunDurationText = shell.elapsedDurationText()
            shell.finishConversation(result, shell.lastRunDurationText)
            shell.runtimeStatusText = isFailureResult(result) ? qsTr("failed #") + shell.runClickSeq : qsTr("done #") + shell.runClickSeq
            shell.agentRunning = false
        }

        function onAgentRunChunk(chunk) {
            shell.updateStreamingConversation(chunk)
        }
    }

    Timer {
        id: agentRunTimeoutTimer
        interval: shell.agentRunTimeoutMs
        repeat: false
        onTriggered: {
            if (!shell.agentRunning) {
                return
            }
            var timeoutText = qsTr("runtime_timeout: agent request exceeded %1s").arg(Math.round(shell.agentRunTimeoutMs / 1000))
            resultOutput.text = timeoutText
            if (activeAssistantMessageIndex >= 0 && activeAssistantMessageIndex < conversationModel.count) {
                conversationModel.setProperty(activeAssistantMessageIndex, "text", timeoutText)
                conversationModel.setProperty(activeAssistantMessageIndex, "bodyText", timeoutText)
                conversationModel.setProperty(activeAssistantMessageIndex, "modeText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "planText", "")
                conversationModel.setProperty(activeAssistantMessageIndex, "pending", false)
                conversationModel.setProperty(activeAssistantMessageIndex, "durationText", qsTr("failed"))
                activeAssistantMessageIndex = -1
            }
            shell.activeAssistantStreamText = ""
            shell.runtimeStatusText = qsTr("failed #") + shell.runClickSeq
            shell.agentRunning = false
        }
    }

    Component.onCompleted: {
        var loginSession = Runtime.load_login_session()
        shell.loginLoggedIn = !!loginSession.loggedIn
        shell.loginPhoneText = loginSession.phone || ""
        refreshLoginButtonText()
        restoreEditorSession()
        // Only apply the checkpoint model selection when using the s-backend.
        // When the backend points to Ollama, the model is already set
        // from the environment (e.g. "neurx-qwen2.5vl-local:latest") and must
        // not be overridden with a checkpoint file path.
        var baseUrl = Runtime.localModelBaseUrl
        var backend = Runtime.localModelBackend || ""
        var isOllama = backend === "ollama" || baseUrl.toLowerCase().indexOf("ollama") !== -1
        if (Runtime.checkpointModelChoices.length > 0 && !isOllama) {
            Runtime.localModelName = Runtime.checkpointModelChoices[0].value
        }
        clampPaneWidths()
    }
    onWidthChanged: clampPaneWidths()
    onExplorerPaneWidthChanged: persistSessionState()
    onAgentPaneWidthChanged: persistSessionState()
    onUiZoomChanged: persistSessionState()

    Shortcut {
        sequences: ["Ctrl+W", "Ctrl+F4"]
        onActivated: shell.closeActiveEditorTab()
    }

    Shortcut {
        sequences: ["Ctrl+Tab"]
        onActivated: shell.activateAdjacentEditorTab(1)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Tab"]
        onActivated: shell.activateAdjacentEditorTab(-1)
    }

    Rectangle {
        anchors.fill: parent
        color: shell.bg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: shell.explorerPaneWidth
                Layout.fillHeight: true
                radius: 10
                color: "#181818"
                border.color: "#252526"

                Item {
                    anchors.fill: parent

                    RowLayout {
                        id: explorerHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 38
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("EXPLORER")
                                color: "#cccccc"
                                font.pixelSize: 12
                                font.letterSpacing: 1.2
                                font.bold: true
                            }
                        }

                        ToolButton {
                            icon.source: "qrc:/neurx/app/icons/refresh.svg"
                            display: AbstractButton.IconOnly
                            icon.width: 14
                            icon.height: 14
                            width: 28
                            height: 28
                            onClicked: shell.refreshExplorer(shell.explorerCurrentPath)
                        }

                        ToolButton {
                            icon.source: "qrc:/neurx/app/icons/disks.svg"
                            display: AbstractButton.IconOnly
                            icon.width: 14
                            icon.height: 14
                            width: 28
                            height: 28
                            onClicked: shell.refreshExplorer("")
                        }

                        ToolButton {
                            icon.source: "qrc:/neurx/app/icons/up.svg"
                            display: AbstractButton.IconOnly
                            icon.width: 14
                            icon.height: 14
                            width: 28
                            height: 28
                            enabled: shell.explorerCurrentPath.length > 0
                            onClicked: shell.goExplorerUp()
                        }

                        Item { Layout.preferredWidth: 8 }
                    }

                    Rectangle {
                        id: explorerDivider
                        anchors.top: explorerHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#252526"
                    }

                    Rectangle {
                        id: explorerRootRow
                        anchors.top: explorerDivider.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32
                        color: "transparent"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                shell.explorerRootExpanded = !shell.explorerRootExpanded
                                shell.populateExplorerRoot()
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 6

                            Text {
                                visible: false
                            }

                            Image {
                                source: shell.explorerRootExpanded
                                    ? "qrc:/neurx/app/icons/chevron-down.svg"
                                    : "qrc:/neurx/app/icons/chevron-right.svg"
                                sourceSize.width: 12
                                sourceSize.height: 12
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                            }

                            Image {
                                source: "qrc:/neurx/app/icons/folder.svg"
                                sourceSize.width: 14
                                sourceSize.height: 14
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                            }

                            Text {
                                text: shell.explorerRootLabel.length > 0 ? shell.explorerRootLabel : qsTr("FOLDERS")
                                color: "#c5c5c5"
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    Rectangle {
                        id: explorerTreePanel
                        anchors.top: explorerRootRow.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        color: "#181818"

                        ListView {
                            id: fileView
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 6
                            model: fileModel
                            spacing: 0
                            clip: true
                            currentIndex: shell.selectedFileIndex
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AlwaysOn
                                width: 10
                                contentItem: Rectangle {
                                    implicitWidth: 10
                                    radius: 5
                                    color: "#4b4b4b"
                                }
                                background: Rectangle {
                                    radius: 5
                                    color: "#232323"
                                }
                            }

                            delegate: Rectangle {
                                required property int index
                                required property string label
                                required property string path
                                required property string kind
                                required property bool isDir
                                required property int depth
                                required property bool expanded

                                width: ListView.view.width
                                height: 24
                                radius: 4
                                color: mouseArea.containsMouse
                                    ? "#2a2d2e"
                                    : ListView.isCurrentItem
                                        ? "#37373d"
                                        : "transparent"
                                border.width: 0

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: shell.selectFile(index, true)
                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            shell.selectFile(index, true)
                                            fileContextMenu.popup()
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (!isDir) {
                                            shell.selectFile(index, false)
                                        }
                                    }
                                }

                                Menu {
                                    id: fileContextMenu

                                    MenuItem {
                                        text: qsTr("Copy Path")
                                        enabled: path.length > 0
                                        onTriggered: {
                                            Runtime.copy_to_clipboard(path)
                                            shell.copyNoticeText = qsTr("Path copied")
                                            copyNoticeTimer.restart()
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 + (depth * 14)
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Text {
                                        Layout.preferredWidth: 10
                                        visible: false
                                    }

                                    Image {
                                        source: isDir
                                            ? (expanded
                                                ? "qrc:/neurx/app/icons/chevron-down.svg"
                                                : "qrc:/neurx/app/icons/chevron-right.svg")
                                            : ""
                                        visible: isDir
                                        sourceSize.width: 12
                                        sourceSize.height: 12
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                    }

                                    Image {
                                        source: isDir
                                            ? "qrc:/neurx/app/icons/folder.svg"
                                            : "qrc:/neurx/app/icons/file.svg"
                                        sourceSize.width: 14
                                        sourceSize.height: 14
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                    }

                                    Text {
                                        text: label
                                        color: ListView.isCurrentItem ? "#ffffff" : "#cccccc"
                                        font.pixelSize: 13
                                        font.bold: false
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        text: kind
                                        color: "#8c8c8c"
                                        font.pixelSize: 10
                                        visible: !isDir
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.explorerPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxLeft = Math.max(shell.paneMinExplorerWidth, available - shell.paneMinAgentWidth - shell.paneMinEditorWidth)
                        shell.explorerPaneWidth = shell.clamp(dragStartWidth + delta, shell.paneMinExplorerWidth, maxLeft)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(0, shell.width - (shell.workspaceMargin * 2) - shell.explorerPaneWidth - shell.agentPaneWidth - (shell.paneHandleWidth * 2))
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Editor")
                            color: shell.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: selectedFilePath.length
                                ? selectedFilePath
                                : (activeEditorTabIndex >= 0 && activeEditorTabIndex < editorTabsModel.count
                                    ? editorTabsModel.get(activeEditorTabIndex).label
                                    : "")
                            color: shell.textMuted
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 28
                            radius: 10
                            color: shell.panelAlt
                            border.color: shell.border

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Read only")
                                color: shell.textMuted
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 12
                        color: shell.panelAlt
                        border.color: shell.border
                        clip: true

                        ListView {
                            id: editorTabsView
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 5
                            anchors.bottomMargin: 5
                            model: editorTabsModel
                            orientation: ListView.Horizontal
                            spacing: 6
                            clip: true

                            delegate: Rectangle {
                                required property int index
                                required property string label
                                required property string path
                                required property bool preview
                                property bool isPreview: preview

                                width: Math.min(220, Math.max(120, tabLabel.implicitWidth + 42))
                                height: 28
                                radius: 8
                                color: index === shell.activeEditorTabIndex ? "#2c313a" : "#1a1d22"
                                border.color: index === shell.activeEditorTabIndex ? "#4b5563" : "#2a2f36"

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onClicked: shell.activateEditorTab(index)
                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.MiddleButton) {
                                            mouse.accepted = true
                                            shell.closeEditorTab(index)
                                        }
                                    }
                                    onDoubleClicked: {
                                        if (isPreview) {
                                            editorTabsModel.setProperty(index, "preview", false)
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        id: tabLabel
                                        Layout.fillWidth: true
                                        text: label
                                        font.italic: isPreview
                                        color: index === shell.activeEditorTabIndex ? shell.textPrimary : "#c3c8cf"
                                        font.pixelSize: 12
                                        elide: Text.ElideMiddle
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        radius: 8
                                        color: closeTabMouse.containsMouse ? "#3b414a" : "transparent"
                                        visible: editorTabsModel.count > 0

                                        Text {
                                            anchors.centerIn: parent
                                            text: "x"
                                            color: "#9da3ae"
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: closeTabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: function(mouse) {
                                                mouse.accepted = true
                                                shell.closeEditorTab(index)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Open files from Explorer to create editor tabs.")
                                color: shell.textMuted
                                visible: editorTabsModel.count === 0
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: shell.editorBg
                        border.color: shell.border
                        clip: true

                        Rectangle {
                            id: editorGutter
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 60
                            color: shell.lineNumberBg
                            border.color: shell.lineNumberBorder
                            visible: !shell.isImageKind(shell.editorKind, shell.selectedFilePath)
                                && !shell.isVideoKind(shell.editorKind, shell.selectedFilePath)
                                && !shell.isPdfKind(shell.editorKind)
                                && !(shell.isOfficeDocumentKind(shell.editorKind, shell.selectedFilePath)
                                    && !shell.isInlineDocumentKind(shell.editorKind, shell.selectedFilePath))

                            Text {
                                id: editorLineNumbers
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 12 - editorFlick.contentY
                                textFormat: Text.RichText
                                text: shell.lineNumberHtml(shell.editorPlainText)
                            }
                        }

                        Flickable {
                            id: editorFlick
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.left: editorGutter.right
                            anchors.margins: 1
                            contentWidth: Math.max(width, editorText.paintedWidth + 32)
                            contentHeight: editorText.paintedHeight + 24
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: !shell.isImageKind(shell.editorKind, shell.selectedFilePath)
                                && !shell.isVideoKind(shell.editorKind, shell.selectedFilePath)
                                && !shell.isPdfKind(shell.editorKind)
                                && !(shell.isOfficeDocumentKind(shell.editorKind, shell.selectedFilePath)
                                    && !shell.isInlineDocumentKind(shell.editorKind, shell.selectedFilePath))
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                            ScrollBar.horizontal: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            TextEdit {
                                id: editorText
                                width: Math.max(editorFlick.width - 32, paintedWidth + 4)
                                height: paintedHeight + 2
                                x: 16
                                y: 12
                                text: shell.highlightCode(shell.editorPlainText, shell.editorKind)
                                textFormat: TextEdit.RichText
                                readOnly: true
                                wrapMode: TextEdit.NoWrap
                                selectByMouse: true
                                color: shell.textPrimary
                                selectionColor: shell.accent
                                selectedTextColor: shell.bg
                                font.family: "Consolas"
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Select a file from Explorer to open it in the editor.")
                                color: shell.textMuted
                                visible: shell.editorPlainText.length === 0 && shell.selectedFilePath.length === 0
                            }
                        }

                        Flickable {
                            id: imagePreviewFlick
                            anchors.fill: parent
                            anchors.margins: 1
                            contentWidth: Math.max(width, previewImage.paintedWidth + 32)
                            contentHeight: Math.max(height, previewImage.paintedHeight + 32)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: shell.isImageKind(shell.editorKind, shell.selectedFilePath)
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                            ScrollBar.horizontal: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            Image {
                                id: previewImage
                                x: 16
                                y: 16
                                source: shell.isImageKind(shell.editorKind, shell.selectedFilePath)
                                    ? shell.editorImageSource(shell.selectedFilePath)
                                    : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                sourceSize.width: Math.max(1, imagePreviewFlick.width)
                                sourceSize.height: Math.max(1, imagePreviewFlick.height)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Image preview unavailable")
                            color: shell.textMuted
                            visible: shell.isImageKind(shell.editorKind, shell.selectedFilePath)
                                && previewImage.status === Image.Error
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#090b0f"
                            visible: shell.isVideoKind(shell.editorKind, shell.selectedFilePath)

                            MediaPlayer {
                                id: previewPlayer
                                source: shell.isVideoKind(shell.editorKind, shell.selectedFilePath)
                                    ? shell.editorImageSource(shell.selectedFilePath)
                                    : ""
                                audioOutput: AudioOutput {
                                    volume: 1.0
                                }
                                videoOutput: previewVideoOutput
                                onSourceChanged: {
                                    if (source.toString().length > 0) {
                                        play()
                                    } else {
                                        stop()
                                    }
                                }
                            }

                            VideoOutput {
                                id: previewVideoOutput
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.bottom: videoControls.top
                                anchors.margins: 16
                                fillMode: VideoOutput.PreserveAspectFit
                            }

                            Rectangle {
                                id: videoControls
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 16
                                height: 56
                                radius: 12
                                color: "#161b22"
                                border.color: shell.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 96
                                        Layout.preferredHeight: 32
                                        radius: 8
                                        color: playPauseMouseArea.pressed ? "#157f58" : shell.accent
                                        border.color: Qt.lighter(shell.accent, 1.15)

                                        Text {
                                            anchors.centerIn: parent
                                            text: previewPlayer.playbackState === MediaPlayer.PlayingState
                                                ? qsTr("Pause")
                                                : qsTr("Play")
                                            color: shell.bg
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: playPauseMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (previewPlayer.playbackState === MediaPlayer.PlayingState) {
                                                    previewPlayer.pause()
                                                } else {
                                                    previewPlayer.play()
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: shell.selectedFilePath.length
                                            ? qsTr("Playing %1").arg(shell.editorTabLabel(shell.selectedFilePath, ""))
                                            : qsTr("No video selected.")
                                        color: shell.textMuted
                                        elide: Text.ElideMiddle
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 124
                                        Layout.preferredHeight: 32
                                        radius: 8
                                        color: openVideoMouseArea.pressed ? "#222a34" : "#1b222c"
                                        border.color: shell.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Open Externally")
                                            color: shell.textPrimary
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: openVideoMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Qt.openUrlExternally(shell.editorImageSource(shell.selectedFilePath))
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#0d1015"
                            visible: shell.isPdfKind(shell.editorKind)

                            PdfDocument {
                                id: previewPdfDocument
                                source: shell.isPdfKind(shell.editorKind) && shell.selectedFilePath.length > 0
                                    ? shell.editorImageSource(shell.selectedFilePath)
                                    : ""
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    radius: 12
                                    color: "#161b22"
                                    border.color: shell.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 96
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: pdfFitWidthMouseArea.pressed ? "#157f58" : shell.accent
                                            border.color: Qt.lighter(shell.accent, 1.15)

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Fit Width")
                                                color: shell.bg
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: pdfFitWidthMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pdfPreview.scaleToWidth(pdfPreview.width, pdfPreview.height)
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 92
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: pdfFitPageMouseArea.pressed ? "#222a34" : "#1b222c"
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Fit Page")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: pdfFitPageMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pdfPreview.scaleToPage(pdfPreview.width, pdfPreview.height)
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 84
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: pdfZoomOutMouseArea.pressed ? "#222a34" : "#1b222c"
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Zoom -")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: pdfZoomOutMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pdfPreview.renderScale = Math.max(0.25, pdfPreview.renderScale / 1.2)
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 84
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: pdfZoomInMouseArea.pressed ? "#222a34" : "#1b222c"
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Zoom +")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: pdfZoomInMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pdfPreview.renderScale = Math.min(5.0, pdfPreview.renderScale * 1.2)
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: previewPdfDocument.status === PdfDocument.Ready
                                                ? qsTr("Page %1 / %2  |  %3%")
                                                    .arg(pdfPreview.currentPage + 1)
                                                    .arg(Math.max(1, previewPdfDocument.pageCount))
                                                    .arg(Math.round(pdfPreview.renderScale * 100))
                                                : (previewPdfDocument.status === PdfDocument.Loading
                                                    ? qsTr("Loading PDF...")
                                                    : shell.editorTabLabel(shell.selectedFilePath, qsTr("PDF")))
                                            color: shell.textMuted
                                            elide: Text.ElideMiddle
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 124
                                            Layout.preferredHeight: 32
                                            radius: 8
                                            color: openPdfMouseArea.pressed ? "#222a34" : "#1b222c"
                                            border.color: shell.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Open Externally")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: openPdfMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.openUrlExternally(shell.editorImageSource(shell.selectedFilePath))
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 12
                                    color: "#0f1115"
                                    border.color: shell.border
                                    clip: true

                                    PdfMultiPageView {
                                        id: pdfPreview
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        visible: previewPdfDocument.status === PdfDocument.Ready
                                        document: previewPdfDocument
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 12
                                        visible: previewPdfDocument.status !== PdfDocument.Ready

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: previewPdfDocument.status === PdfDocument.Loading
                                                ? qsTr("Loading PDF...")
                                                : (previewPdfDocument.error.length > 0
                                                    ? qsTr("PDF preview unavailable")
                                                    : qsTr("No PDF file selected."))
                                            color: shell.textPrimary
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: previewPdfDocument.error.length > 0
                                                ? previewPdfDocument.error
                                                : qsTr("Please wait while the document is prepared.")
                                            color: shell.textMuted
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                            onWidthChanged: {
                                if (previewPdfDocument.status === PdfDocument.Ready) {
                                    pdfPreview.scaleToWidth(width - 32, height - 32)
                                }
                            }
                        }

                        Connections {
                            target: previewPdfDocument
                            function onStatusChanged(status) {
                                if (status === PdfDocument.Ready) {
                                    pdfPreview.scaleToWidth(pdfPreview.width, pdfPreview.height)
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 14
                            visible: shell.isOfficeDocumentKind(shell.editorKind, shell.selectedFilePath)
                                && !shell.isInlineDocumentKind(shell.editorKind, shell.selectedFilePath)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Document preview is not available in this build")
                                color: shell.textPrimary
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: shell.selectedFilePath.length
                                    ? qsTr("Open this document in your system office app.")
                                    : qsTr("No document selected.")
                                color: shell.textMuted
                                font.pixelSize: 12
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 184
                                height: 38
                                radius: 10
                                color: openDocumentMouseArea.pressed ? "#157f58" : shell.accent
                                border.color: Qt.lighter(shell.accent, 1.15)
                                visible: shell.selectedFilePath.length > 0

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Open Document")
                                    color: shell.bg
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: openDocumentMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(shell.editorImageSource(shell.selectedFilePath))
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: qsTr("Status")
                            color: shell.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: selectedFilePath.length
                                ? qsTr("Editing %1").arg(selectedFilePath)
                                : (activeEditorTabIndex >= 0 && activeEditorTabIndex < editorTabsModel.count
                                    ? qsTr("Previewing %1").arg(editorTabsModel.get(activeEditorTabIndex).label)
                                    : qsTr("No file open"))
                            color: shell.textPrimary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.paneHandleWidth
                Layout.fillHeight: true
                color: shell.bg

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    radius: 5
                    color: shell.panelAlt
                    border.color: shell.border
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SplitHCursor
                    property real dragStartX: 0
                    property int dragStartWidth: 0

                    onPressed: function(mouse) {
                        dragStartX = mouse.x
                        dragStartWidth = shell.agentPaneWidth
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed) {
                            return
                        }
                        var delta = mouse.x - dragStartX
                        var available = Math.max(0, shell.width - (shell.workspaceMargin * 2) - (shell.paneHandleWidth * 2))
                        var maxRight = Math.max(shell.paneMinAgentWidth, available - shell.explorerPaneWidth - shell.paneMinEditorWidth)
                        shell.agentPaneWidth = shell.clamp(dragStartWidth - delta, shell.paneMinAgentWidth, maxRight)
                        shell.clampPaneWidths()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: shell.agentPaneWidth
                Layout.fillHeight: true
                radius: 18
                color: shell.surface
                border.color: shell.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 8
                    anchors.bottomMargin: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("Conversation")
                            color: shell.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 36
                            radius: 18
                            color: agentLoginMouseArea.pressed ? "#157f58" : shell.accent
                            border.color: Qt.lighter(shell.accent, 1.15)

                            Text {
                                anchors.centerIn: parent
                                text: shell.loginButtonText
                                color: shell.bg
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: agentLoginMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    shell.runtimeStatusText = qsTr("login_clicked")
                                    shell.loginStatusText = ""
                                    if (shell.loginLoggedIn) {
                                        shell.loginStatusText = qsTr("当前已登录手机号：") + shell.loginPhoneText
                                    }
                                    loginPopup.open()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 440
                        Layout.minimumHeight: 320
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        Timer {
                            id: copyNoticeTimer
                            interval: 1200
                            repeat: false
                            onTriggered: shell.copyNoticeText = ""
                        }

                        ListView {
                            id: conversationList
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            spacing: 12
                            model: conversationModel
                            boundsBehavior: Flickable.StopAtBounds
                            onContentHeightChanged: positionViewAtEnd()
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Item {
                                width: conversationList.width
                                height: bubbleRect.height

                                Timer {
                                    id: copyResetTimer
                                    interval: 3000
                                    repeat: false
                                    onTriggered: conversationModel.setProperty(index, "copied", false)
                                }

                                Rectangle {
                                    id: bubbleRect
                                    width: model.kind === "user"
                                        ? Math.max(180, parent.width * shell.userBubbleWidthRatio)
                                        : Math.max(260, parent.width * shell.assistantBubbleWidthRatio)
                                    height: bubbleColumn.implicitHeight + 20
                                    x: model.kind === "user" ? parent.width - width : 0
                                    radius: 12
                                    color: model.kind === "user" ? shell.userBubble : shell.agentBubble
                                    border.color: model.kind === "user" ? Qt.rgba(1, 1, 1, 0.06) : shell.border

                                    HoverHandler {
                                        id: bubbleHover
                                        target: bubbleRect
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    }

                                    Column {
                                        id: bubbleColumn
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            spacing: 8
                                            Layout.fillWidth: true

                                            Rectangle {
                                                visible: model.kind !== "user"
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: shell.accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: qsTr("C")
                                                    color: shell.bg
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                text: model.label
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                visible: model.kind !== "user"
                                                text: model.durationText
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            ToolButton {
                                                enabled: !model.pending && model.text.length > 0
                                                visible: bubbleHover.hovered || model.copied
                                                opacity: enabled ? 1.0 : 0.45
                                                Layout.alignment: Qt.AlignTop
                                                width: 24
                                                height: 24
                                                padding: 0
                                                text: ""
                                                background: Rectangle {
                                                    radius: 6
                                                    color: model.copied ? Qt.rgba(0.10, 0.66, 0.45, 0.16) : Qt.rgba(1, 1, 1, 0.04)
                                                    border.color: model.copied ? Qt.rgba(0.10, 0.66, 0.45, 0.48) : Qt.rgba(255, 255, 255, 0.06)
                                                }
                                                contentItem: Image {
                                                    anchors.centerIn: parent
                                                    width: 14
                                                    height: 14
                                                    source: model.copied ? "qrc:/neurx/app/icons/check.svg" : "qrc:/neurx/app/icons/copy.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    sourceSize.width: 14
                                                    sourceSize.height: 14
                                                    opacity: enabled ? 1.0 : 0.45
                                                    smooth: true
                                                    mipmap: true
                                                }
                                                onClicked: {
                                                    shell.copyConversationText(model.bodyText && model.bodyText.length > 0 ? model.bodyText : model.text)
                                                    conversationModel.setProperty(index, "copied", true)
                                                    copyResetTimer.restart()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: model.modeText && model.modeText.length > 0
                                            radius: 999
                                            color: Qt.rgba(0.10, 0.66, 0.45, 0.14)
                                            border.color: Qt.rgba(0.10, 0.66, 0.45, 0.42)
                                            height: 22
                                            width: modeLabel.implicitWidth + 14

                                            Text {
                                                id: modeLabel
                                                anchors.centerIn: parent
                                                text: model.modeText
                                                color: shell.accent
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            visible: model.planText && model.planText.length > 0
                                            width: Math.max(120, bubbleRect.width - 26)
                                            text: model.planText
                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                            color: shell.textMuted
                                            font.pixelSize: 11
                                        }

                                        TextEdit {
                                            width: Math.max(120, bubbleRect.width - 26)
                                            text: model.bodyText && model.bodyText.length > 0 ? model.bodyText : model.text
                                            readOnly: true
                                            selectByMouse: true
                                            selectByKeyboard: true
                                            activeFocusOnPress: true
                                            persistentSelection: true
                                            cursorVisible: false
                                            mouseSelectionMode: TextEdit.SelectCharacters
                                            textFormat: TextEdit.PlainText
                                            wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                            color: shell.textPrimary
                                            selectionColor: shell.selectionBg
                                            selectedTextColor: shell.textPrimary
                                            font.pixelSize: 13
                                        }
                                    }

                                }
                            }
                        }

                        Rectangle {
                            visible: shell.copyNoticeText.length > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            radius: 999
                            color: Qt.rgba(0.09, 0.12, 0.11, 0.92)
                            border.color: Qt.rgba(0.39, 0.67, 0.54, 0.55)
                            z: 10

                            Text {
                                anchors.margins: 6
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: shell.textPrimary
                                font.pixelSize: 10
                                text: shell.copyNoticeText
                            }
                        }

                        TextEdit {
                            id: resultOutput
                            visible: false
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            text: qsTr("Run the agent to see output here.")
                            font.pixelSize: 12
                        }
                    }

                    Text {
                        text: qsTr("Send")
                        color: shell.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Rectangle {
                        id: promptInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        Layout.maximumHeight: 88
                        radius: 12
                        color: shell.editorBg
                        border.color: shell.border

                        TextEdit {
                            id: promptEditor
                            anchors.fill: parent
                            anchors.margins: 10
                            text: ""
                            wrapMode: TextEdit.Wrap
                            color: shell.textPrimary
                            selectionColor: shell.accent
                            selectedTextColor: shell.bg
                            font.pixelSize: 13
                            focus: true
                            Keys.priority: Keys.BeforeItem

                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    shell.sendAgentPrompt()
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: qsTr("Ask the agent to inspect files or summarize state")
                            color: shell.textMuted
                            visible: promptEditor.text.length === 0 && !promptEditor.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 116
                            Layout.preferredHeight: 34
                            radius: 10
                            color: shell.agentRunning ? shell.panelHover : shell.accent

                            Text {
                                anchors.centerIn: parent
                                text: shell.agentRunning ? qsTr("Running...") : qsTr("Run")
                                color: shell.bg
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !shell.agentRunning
                                onClicked: shell.sendAgentPrompt()
                            }
                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: hasStructuredExport(resultOutput.text)
                        implicitHeight: exportDetailsColumn.implicitHeight + 20
                        radius: 12
                        color: shell.panelAlt
                        border.color: shell.border

                        ColumnLayout {
                            id: exportDetailsColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: qsTr("Diagnostics")
                                    color: shell.textPrimary
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                ToolButton {
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                    enabled: visible
                                    padding: 0
                                    width: 24
                                    height: 24
                                    text: ""
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Copy saved path")
                                    contentItem: Text {
                                        text: "⧉"
                                        color: shell.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 14
                                    }
                                    onClicked: shell.copyConversationText(exportSavedPath(resultOutput.text))
                                }

                                ToolButton {
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                    enabled: visible
                                    padding: 0
                                    width: 24
                                    height: 24
                                    text: ""
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Open export")
                                    contentItem: Text {
                                        text: "↗"
                                        color: shell.textPrimary
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 14
                                    }
                                    onClicked: shell.openSavedExport(exportSavedPath(resultOutput.text))
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6

                                Text {
                                    text: qsTr("Saved Path")
                                    color: shell.textMuted
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportSavedPath(resultOutput.text)
                                    color: shell.textPrimary
                                    elide: Text.ElideMiddle
                                    visible: exportSavedPath(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Active Skill")
                                    color: shell.textMuted
                                    visible: exportActiveSkill(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportActiveSkill(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportActiveSkill(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Execution")
                                    color: shell.textMuted
                                    visible: exportSkillExecutionStatus(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportSkillExecutionStatus(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportSkillExecutionStatus(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Trace Count")
                                    color: shell.textMuted
                                    visible: exportTraceCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportTraceCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportTraceCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Registry Version")
                                    color: shell.textMuted
                                    visible: exportRegistryVersion(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportRegistryVersion(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportRegistryVersion(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Promotions")
                                    color: shell.textMuted
                                    visible: exportPromoteCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportPromoteCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportPromoteCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Retirements")
                                    color: shell.textMuted
                                    visible: exportRetireCount(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportRetireCount(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportRetireCount(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Last Action")
                                    color: shell.textMuted
                                    visible: exportLastAction(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportLastAction(resultOutput.text)
                                    color: shell.textPrimary
                                    visible: exportLastAction(resultOutput.text).length > 0
                                }

                                Text {
                                    text: qsTr("Last Observation")
                                    color: shell.textMuted
                                    visible: exportLastObservation(resultOutput.text).length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: exportLastObservation(resultOutput.text)
                                    color: shell.textPrimary
                                    wrapMode: Text.WrapAnywhere
                                    visible: exportLastObservation(resultOutput.text).length > 0
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: diagnosticsSkillRecords.length > 0
                                spacing: 6

                                Text {
                                    text: qsTr("Skills")
                                    color: shell.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    ComboBox {
                                        id: skillStatusCombo
                                        Layout.preferredWidth: 170
                                        model: shell.skillStatusOptions()
                                        currentIndex: Math.max(0, model.indexOf(shell.skillStatusFilter))

                                        delegate: ItemDelegate {
                                            required property var modelData
                                            required property int index
                                            width: parent ? parent.width : 170
                                            text: modelData && modelData.length > 0 ? modelData : qsTr("All statuses")
                                        }

                                        contentItem: Text {
                                            leftPadding: 10
                                            rightPadding: 10
                                            verticalAlignment: Text.AlignVCenter
                                            text: skillStatusCombo.displayText
                                            color: shell.textPrimary
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        displayText: currentText && currentText.length > 0 ? currentText : qsTr("All statuses")
                                        onActivated: {
                                            shell.skillStatusFilter = currentValue || currentText || ""
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    Text {
                                        text: qsTr("%1 skills").arg(shell.filteredDiagnosticsSkillRecords().length)
                                        color: shell.textMuted
                                        font.pixelSize: 11
                                    }

                                    CheckBox {
                                        text: qsTr("Active only")
                                        checked: shell.skillActiveOnly
                                        onToggled: {
                                            shell.skillActiveOnly = checked
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    CheckBox {
                                        text: qsTr("High fail")
                                        checked: shell.skillHighFailOnly
                                        onToggled: {
                                            shell.skillHighFailOnly = checked
                                            shell.clearSelectedSkillIfFilteredOut()
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                Repeater {
                                    model: filteredDiagnosticsSkillRecords()

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: skillColumn.implicitHeight + 14
                                        radius: 10
                                        color: shell.editorBg
                                        border.color: shell.selectedSkillName === (modelData.name || "")
                                            ? shell.accent
                                            : skillMouse.containsMouse ? shell.accent : shell.border

                                        ColumnLayout {
                                            id: skillColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: modelData.name || qsTr("(unnamed)")
                                                    color: shell.textPrimary
                                                    font.bold: true
                                                }

                                                Text {
                                                    text: modelData.status || qsTr("unknown")
                                                    color: shell.textMuted
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: modelData.version || ""
                                                    color: shell.textMuted
                                                }

                                                ToolButton {
                                                    padding: 0
                                                    width: 22
                                                    height: 22
                                                    text: "⧉"
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: qsTr("Copy skill context")
                                                    onClicked: shell.copyConversationText(shell.skillRecordPreview(resultOutput.text, modelData))
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTr("success=%1 stability=%2 avg_steps=%3 fail=%4 promote=%5")
                                                    .arg(modelData.success_rate || "0")
                                                    .arg(modelData.stability || "0")
                                                    .arg(modelData.avg_steps || "0")
                                                    .arg(modelData.fail_count || "0")
                                                    .arg(modelData.promote_count || "0")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                wrapMode: Text.WrapAnywhere
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.intent || ""
                                                color: shell.textPrimary
                                                font.pixelSize: 11
                                                wrapMode: Text.WrapAnywhere
                                                visible: text.length > 0
                                            }
                                        }

                                        MouseArea {
                                            id: skillMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            z: -1
                                            onClicked: shell.activateSkillRecord(modelData)
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: shell.selectedSkillName.length > 0 && shell.selectedSkillRecord() !== null
                                    implicitHeight: selectedSkillColumn.implicitHeight + 16
                                    radius: 10
                                    color: Qt.rgba(0.10, 0.15, 0.13, 0.95)
                                    border.color: shell.accent

                                    ColumnLayout {
                                        id: selectedSkillColumn
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: qsTr("Selected Skill")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            Text {
                                                text: shell.selectedSkillRecord() ? shell.selectedSkillRecord().name || "" : ""
                                                color: shell.textPrimary
                                                font.bold: true
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Inspect")
                                                onClicked: shell.inspectSelectedSkill()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Copy")
                                                onClicked: shell.copyConversationText(shell.selectedSkillRecord().name || "")
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Open")
                                                onClicked: shell.openSelectedSkillExport()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Context")
                                                onClicked: shell.openFilteredSkillContext()
                                            }

                                            ToolButton {
                                                visible: shell.selectedSkillRecord() !== null
                                                text: qsTr("Copy all")
                                                onClicked: shell.copyConversationText(shell.filteredSkillContextPreview())
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: shell.selectedSkillRecord() ? shell.selectedSkillRecord().intent || "" : ""
                                            color: shell.textPrimary
                                            wrapMode: Text.WrapAnywhere
                                            visible: text.length > 0
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: shell.selectedSkillRecord()
                                                ? qsTr("status=%1 version=%2 success=%3 stability=%4 avg_steps=%5 fail=%6 promote=%7")
                                                    .arg(shell.selectedSkillRecord().status || "unknown")
                                                    .arg(shell.selectedSkillRecord().version || "")
                                                    .arg(shell.selectedSkillRecord().success_rate || "0")
                                                    .arg(shell.selectedSkillRecord().stability || "0")
                                                    .arg(shell.selectedSkillRecord().avg_steps || "0")
                                                    .arg(shell.selectedSkillRecord().fail_count || "0")
                                                    .arg(shell.selectedSkillRecord().promote_count || "0")
                                                : ""
                                            color: shell.textMuted
                                            font.pixelSize: 11
                                            wrapMode: Text.WrapAnywhere
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: shell.selectedSkillTraceSteps().length > 0
                                            spacing: 6

                                            Text {
                                                text: qsTr("Trace Steps")
                                                color: shell.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                CheckBox {
                                                    text: qsTr("Failed only")
                                                    checked: shell.selectedSkillFailedOnly
                                                    onToggled: shell.selectedSkillFailedOnly = checked
                                                }

                                                ComboBox {
                                                    id: selectedSkillToolCombo
                                                    Layout.preferredWidth: 160
                                                    model: shell.selectedSkillTraceToolOptions()
                                                    currentIndex: Math.max(0, model.indexOf(shell.selectedSkillToolFilter))

                                                    delegate: ItemDelegate {
                                                        required property var modelData
                                                        required property int index
                                                        width: parent ? parent.width : 160
                                                        text: modelData && modelData.length > 0 ? modelData : qsTr("All tools")
                                                    }

                                                    contentItem: Text {
                                                        leftPadding: 10
                                                        rightPadding: 10
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: selectedSkillToolCombo.displayText
                                                        color: shell.textPrimary
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    displayText: currentText && currentText.length > 0 ? currentText : qsTr("All tools")
                                                    onActivated: shell.selectedSkillToolFilter = currentValue || currentText || ""
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 180
                                                    Layout.preferredHeight: 30
                                                    radius: 8
                                                    color: shell.editorBg
                                                    border.color: shell.border

                                                    TextInput {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        text: shell.selectedSkillSearchText
                                                        color: shell.textPrimary
                                                        font.pixelSize: 12
                                                        verticalAlignment: Text.AlignVCenter
                                                        clip: true
                                                        selectByMouse: true
                                                        onTextChanged: shell.selectedSkillSearchText = text
                                                    }

                                                    Text {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: qsTr("Search action/observation")
                                                        color: shell.textMuted
                                                        font.pixelSize: 12
                                                        visible: shell.selectedSkillSearchText.length === 0
                                                    }
                                                }

                                                Text {
                                                    text: qsTr("%1 steps").arg(shell.filteredSelectedSkillTraceSteps().length)
                                                    color: shell.textMuted
                                                    font.pixelSize: 11
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            Text {
                                                visible: shell.filteredSelectedSkillTraceSteps().length === 0
                                                text: qsTr("No steps match the current filters")
                                                color: shell.textMuted
                                                font.pixelSize: 11
                                            }

                                            Repeater {
                                                model: shell.filteredSelectedSkillTraceSteps()

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    implicitHeight: stepColumn.implicitHeight + 14
                                                    radius: 8
                                                    color: shell.editorBg
                                                    border.color: shell.border

                                                    ColumnLayout {
                                                        id: stepColumn
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: 4

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 8

                                                            Text {
                                                                text: qsTr("Step %1").arg(modelData.step || "?")
                                                                color: shell.textPrimary
                                                                font.bold: true
                                                            }

                                                            Text {
                                                                text: modelData.task || qsTr("unknown")
                                                                color: shell.textMuted
                                                            }

                                                            Item {
                                                                Layout.fillWidth: true
                                                            }

                                                            ToolButton {
                                                                text: qsTr("Copy")
                                                                onClicked: shell.copyConversationText(shell.traceStepPreview(modelData))
                                                            }

                                                            ToolButton {
                                                                text: qsTr("Open")
                                                                onClicked: shell.openTraceStep(modelData)
                                                            }

                                                            Text {
                                                                text: (modelData.ok || "false") === "true" ? qsTr("ok") : qsTr("failed")
                                                                color: (modelData.ok || "false") === "true" ? shell.accent : "#e57373"
                                                                font.bold: true
                                                            }
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("tool=%1 timeout=%2 retries=%3")
                                                                .arg(modelData.tool || "-")
                                                                .arg(modelData.tool_timeout_ms || "0")
                                                                .arg(modelData.tool_retries || "0")
                                                            color: shell.textMuted
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("action: %1").arg(modelData.action || "")
                                                            color: shell.textPrimary
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 8
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("input: %1").arg(modelData.input || "")
                                                            color: shell.textMuted
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 7
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: qsTr("observation: %1").arg(modelData.observation || "")
                                                            color: shell.textPrimary
                                                            font.pixelSize: 11
                                                            wrapMode: Text.WrapAnywhere
                                                            visible: text.length > 13
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }

    Popup {
        id: loginPopup
        anchors.centerIn: Overlay.overlay
        width: 360
        height: 300
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            radius: 16
            color: shell.surface
            border.color: shell.border
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: qsTr("登录")
                    color: shell.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                ToolButton {
                    text: "✕"
                    onClicked: loginPopup.close()
                }
            }

                Text {
                    text: qsTr("输入手机号和验证码")
                    color: shell.textMuted
                font.pixelSize: 12
            }

            TextField {
                id: phoneField
                Layout.fillWidth: true
                placeholderText: qsTr("请输入手机号")
                text: shell.loginPhoneText
                color: shell.textPrimary
                selectByMouse: true
                onTextChanged: shell.loginPhoneText = text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                TextField {
                    id: codeField
                    Layout.fillWidth: true
                    placeholderText: qsTr("请输入验证码")
                    text: shell.loginCodeText
                    color: shell.textPrimary
                    selectByMouse: true
                    onTextChanged: shell.loginCodeText = text
                }

                Rectangle {
                    Layout.preferredWidth: 102
                    Layout.preferredHeight: 38
                    radius: 10
                    color: verifyMouseArea.pressed ? shell.panelHover : shell.panelAlt
                    border.color: shell.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("获取验证码")
                        color: shell.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        id: verifyMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (shell.loginPhoneText.trim().length === 0) {
                                shell.loginStatusText = qsTr("请先输入手机号")
                                return
                            }
                            shell.generatedLoginCode = shell.generateFourDigitCode()
                            shell.loginStatusText = qsTr("验证码已发送到手机，模拟验证码：") + shell.generatedLoginCode
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: shell.loginStatusText
                color: shell.textMuted
                visible: text.length > 0
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: cancelLoginMouseArea.pressed ? shell.panelHover : shell.panelAlt
                    border.color: shell.border

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("取消")
                        color: shell.textPrimary
                        font.bold: true
                    }

                    MouseArea {
                        id: cancelLoginMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: loginPopup.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: submitLoginMouseArea.pressed ? "#157f58" : shell.accent
                    border.color: Qt.lighter(shell.accent, 1.15)

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("登录")
                        color: shell.bg
                        font.bold: true
                    }

                    MouseArea {
                        id: submitLoginMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (shell.loginPhoneText.trim().length === 0) {
                                shell.loginStatusText = qsTr("请输入手机号")
                                return
                            }
                            if (shell.loginCodeText.trim().length === 0) {
                                shell.loginStatusText = qsTr("请输入验证码")
                                return
                            }
                            if (shell.generatedLoginCode.length !== 4) {
                                shell.loginStatusText = qsTr("请先获取验证码")
                                return
                            }
                            if (shell.loginCodeText.trim() !== shell.generatedLoginCode) {
                                shell.loginStatusText = qsTr("验证码错误，请输入 4 位正确验证码")
                                return
                            }
                            shell.loginLoggedIn = true
                            Runtime.save_login_session(true, shell.loginPhoneText)
                            shell.generatedLoginCode = ""
                            shell.loginCodeText = ""
                            shell.loginStatusText = qsTr("登录成功：") + shell.loginPhoneText
                            shell.refreshLoginButtonText()
                            shell.copyNoticeText = qsTr("已提交登录信息")
                            copyNoticeTimer.restart()
                            loginPopup.close()
                        }
                    }
                }
            }
        }
    }
}
