pragma Singleton
import QtQuick

// AEGIS - paleta y tipografia comunes del HUD
QtObject {
    readonly property color panel: Qt.rgba(0.01, 0.05, 0.09, 0.74)
    readonly property color text: "#dff8ff"
    readonly property color dim: "#7fb2c4"
    readonly property color faint: "#3a6070"
    readonly property color ok: "#4dffa6"
    readonly property color warn: "#ffb347"
    readonly property color hot: "#ff4d5e"
    readonly property string tit: "Orbitron"
    readonly property string ui: "Rajdhani"
    readonly property string mono: "Share Tech Mono"
}
