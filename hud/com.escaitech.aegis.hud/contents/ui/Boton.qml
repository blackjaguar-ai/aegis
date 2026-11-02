import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// Boton achaflanado
Item {
    id: b
    property string texto: ""
    property string sub: ""
    property color acento: "#3fe0ff"
    signal pulsado
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: ma.pressed ? G.alfa(b.acento, 0.45) : ma.containsMouse ? G.alfa(b.acento, 0.2) : G.alfa(b.acento, 0.06)
            strokeColor: ma.containsMouse ? b.acento : G.alfa(b.acento, 0.45); strokeWidth: 1
            PathSvg { path: G.chaflan(b.width, b.height, 7) }
        }
    }
    Column {
        anchors.centerIn: parent
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: b.texto; font.family: Pal.ui; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 2; color: Pal.text }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: b.sub; font.family: Pal.mono; font.pixelSize: 9; color: Pal.dim; visible: text !== "" }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.pulsado() }
}
