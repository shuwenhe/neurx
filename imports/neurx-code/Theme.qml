pragma Singleton
import QtQuick 6.2

QtObject {
    property string currentTheme: "dark"

    // ── Palette ────────────────────────────────────────────────────────────
    property color bg:         currentTheme === "dark" ? "#0d0d0d" : "#ffffff"
    property color surface:    currentTheme === "dark" ? "#161616" : "#f3f3f3"
    property color surfaceAlt: currentTheme === "dark" ? "#1e1e1e" : "#e8e8e8"
    property color border:     currentTheme === "dark" ? "#2a2a2a" : "#d1d1d1"
    property color accent:     currentTheme === "dark" ? "#7c6af5" : "#005fb8"
    property color accentHover:currentTheme === "dark" ? "#9080ff" : "#0078d4"
    property color textPrimary:currentTheme === "dark" ? "#e8e8e8" : "#242424"
    property color textMuted:  currentTheme === "dark" ? "#888888" : "#616161"
    property color error:      "#e05252"
    property color success:    "#52c07c"
    property color warning:    "#e0a250"

    // ── Typography ─────────────────────────────────────────────────────────
    property int fontBase: Qt.application.font.pixelSize > 0
                                    ? Qt.application.font.pixelSize : 13
    property int fontXs:   Math.round(fontBase * 0.77)  // ~10 @ 13px
    property int fontSm:   Math.round(fontBase * 0.85)  // ~11 @ 13px
    property int fontMd:   fontBase                     // 13 @ 13px
    property int fontLg:   Math.round(fontBase * 1.23)  // ~16 @ 13px

    property font  monoFont: Qt.font({ family: "JetBrains Mono, Consolas, monospace", pixelSize: fontMd })
    property font  uiFont:   Qt.font({ family: "Inter, Segoe UI, sans-serif",          pixelSize: fontMd })
    property int   radius:   6

    function toggleTheme() {
        currentTheme = (currentTheme === "dark" ? "light" : "dark")
    }
}
