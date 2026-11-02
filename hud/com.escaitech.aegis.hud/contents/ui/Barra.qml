import QtQuick

// Barra segmentada
Item {
    id: b
    property real f: 0
    property color color: "#3fe0ff"
    height: 8
    readonly property int n: Math.max(1, Math.floor((width + 2) / 6))
    Row {
        spacing: 2
        Repeater {
            model: b.n
            Rectangle {
                required property int index
                width: 4; height: b.height
                color: b.color
                opacity: index < Math.round(b.f * b.n) ? 0.95 : 0.13
            }
        }
    }
}
