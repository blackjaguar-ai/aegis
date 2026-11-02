import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// Medidor circular de 270 grados
Item {
    id: g
    property real valor: 0
    property real maximo: 100
    property string etiqueta: ""
    property string texto: ""
    property string unidad: ""
    property color color: "#3fe0ff"
    property bool animado: true
    width: 96; height: 100
    readonly property real f: Math.max(0, Math.min(1, valor / maximo))
    property real fa: f
    Behavior on fa { enabled: g.animado; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    Shape {
        width: 96; height: 96
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: G.alfa(g.color, 0.14); strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.FlatCap
            PathSvg { path: G.arco(48, 48, 39, 135, 270) }
        }
        ShapePath {
            strokeColor: g.color; strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.FlatCap
            PathSvg { path: g.fa > 0.004 ? G.arco(48, 48, 39, 135, 270 * g.fa) : "M 0 0" }
        }
        ShapePath {
            strokeColor: G.alfa(g.color, 0.45); strokeWidth: 1; fillColor: "transparent"
            PathSvg { path: G.marcasArco(48, 48, 46, 48, 135, 270, 27) }
        }
    }
    Column {
        x: 0; width: 96; y: 28
        Text { width: 96; horizontalAlignment: Text.AlignHCenter; text: g.texto; font.family: Pal.tit; font.pixelSize: 20; font.weight: Font.Medium; color: Pal.text }
        Text { width: 96; horizontalAlignment: Text.AlignHCenter; text: g.unidad; font.family: Pal.mono; font.pixelSize: 10; color: Pal.dim }
    }
    Text { y: 80; width: 96; horizontalAlignment: Text.AlignHCenter; text: g.etiqueta; font.family: Pal.ui; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 3; color: g.color }
}
