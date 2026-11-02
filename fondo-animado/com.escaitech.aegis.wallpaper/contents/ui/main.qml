import QtQuick
import org.kde.plasma.plasmoid

// AEGIS - plugin de fondo. Toda la escena vive en Escena.qml (QtQuick puro).
WallpaperItem {
    id: root
    readonly property var paletas: [
        { a: "#3fe0ff", b: "#ffb347", f: "#02060c" },   // cian
        { a: "#ffb347", b: "#3fe0ff", f: "#0a0602" },   // ambar
        { a: "#ff4d5e", b: "#ffd166", f: "#0c0204" },   // carmesi
        { a: "#4dffa6", b: "#3fe0ff", f: "#020a06" }    // verde
    ]
    readonly property var p: paletas[Math.max(0, Math.min(3, root.configuration.Acento || 0))]
    Escena {
        anchors.fill: parent
        animar: root.configuration.Animar !== false
        acento: root.p.a
        acento2: root.p.b
        fondo: root.p.f
    }
}
