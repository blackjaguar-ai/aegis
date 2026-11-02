import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// Tarjeta con esquinas achaflanadas, cabecera y acentos en las esquinas
Item {
    id: m
    property string titulo: ""
    property string meta: ""
    property color metaColor: Pal.dim
    property color acento: "#3fe0ff"
    property real ch: 12
    default property alias contenido: cuerpo.data

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Pal.panel; strokeColor: G.alfa(m.acento, 0.32); strokeWidth: 1
            PathSvg { path: G.chaflan(m.width, m.height, m.ch) }
        }
        ShapePath {
            fillColor: "transparent"; strokeColor: m.acento; strokeWidth: 2; capStyle: ShapePath.FlatCap
            PathSvg {
                path: "M 0 " + (m.ch + 20) + " L 0 " + m.ch + " L " + m.ch + " 0 L " + (m.ch + 34) + " 0 "
                    + "M " + m.width + " " + (m.height - m.ch - 20) + " L " + m.width + " " + (m.height - m.ch) + " L " + (m.width - m.ch) + " " + m.height + " L " + (m.width - m.ch - 34) + " " + m.height
            }
        }
    }
    Rectangle { x: 14; y: 14; width: 6; height: 6; color: m.acento }
    Text { x: 28; y: 9; text: m.titulo; font.family: Pal.tit; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 3; color: Pal.text }
    Text { anchors.right: parent.right; anchors.rightMargin: 14; y: 9; text: m.meta; font.family: Pal.mono; font.pixelSize: 12; color: m.metaColor }
    Rectangle {
        x: 14; y: 31; width: m.width - 28; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: G.alfa(m.acento, 0.6) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Item { id: cuerpo; x: 14; y: 40; width: m.width - 28; height: m.height - 40 - 12 }
}
