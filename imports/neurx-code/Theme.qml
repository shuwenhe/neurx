pragma Singleton
import QtQuick 6.2

QtObject {
    // ── Palette ────────────────────────────────────────────────────────────
    readonly property color bg:         "#0d0d0d"
    readonly property color surface:    "#161616"
    readonly property color surfaceAlt: "#1e1e1e"
    readonly property color border:     "#2a2a2a"
    readonly property color accent:     "#7c6af5"
    readonly property color accentHover:"#9080ff"
    readonly property color textPrimary:"#e8e8e8"
    readonly property color textMuted:  "#888888"
    readonly property color error:      "#e05252"
    readonly property color success:    "#52c07c"
    readonly property color warning:    "#e0a250"

    // ── Typography ─────────────────────────────────────────────────────────
    // fontBase follows Qt.application.font, which is set in main.cpp based on
    // the screen's logical DPI so the UI scales correctly on all displays.
    readonly property int fontBase: Qt.application.font.pixelSize > 0
                                    ? Qt.application.font.pixelSize : 13
    readonly property int fontXs:   Math.round(fontBase * 0.77)  // ~10 @ 13px
    readonly property int fontSm:   Math.round(fontBase * 0.85)  // ~11 @ 13px
    readonly property int fontMd:   fontBase                     // 13 @ 13px
    readonly property int fontLg:   Math.round(fontBase * 1.23)  // ~16 @ 13px

    readonly property font  monoFont: Qt.font({ family: "JetBrains Mono, Consolas, monospace", pixelSize: fontMd })
    readonly property font  uiFont:   Qt.font({ family: "Inter, Segoe UI, sans-serif",          pixelSize: fontMd })
    readonly property int   radius:   6
}
