import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// Grafica de linea con relleno; los datos entran por la derecha
Item {
    id: t
    property var datos: []
    property real maximo: 100
    property int capacidad: 60
    property color color: "#3fe0ff"
    property bool relleno: true
    function puntos() {
        var n = datos.length; if (n < 2) return []
        var m = Math.max(maximo, 1e-9), paso = width / (capacidad - 1), a = []
        for (var i = 0; i < n; i++) a.push([width - (n - 1 - i) * paso, height - 1 - (height - 2) * Math.min(1, datos[i] / m)])
        return a
    }
    readonly property var pts: puntos()
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: t.height
                GradientStop { position: 0; color: G.alfa(t.color, t.relleno ? 0.35 : 0) }
                GradientStop { position: 1; color: G.alfa(t.color, 0) }
            }
            PathSvg {
                path: {
                    var p = t.pts; if (p.length < 2) return "M 0 0"
                    var s = "M " + p[0][0].toFixed(1) + " " + t.height
                    for (var i = 0; i < p.length; i++) s += " L " + p[i][0].toFixed(1) + " " + p[i][1].toFixed(1)
                    return s + " L " + p[p.length - 1][0].toFixed(1) + " " + t.height + " Z"
                }
            }
        }
        ShapePath {
            strokeColor: t.color; strokeWidth: 1.5; fillColor: "transparent"
            PathSvg {
                path: {
                    var p = t.pts; if (p.length < 2) return "M 0 0"
                    var s = "M " + p[0][0].toFixed(1) + " " + p[0][1].toFixed(1)
                    for (var i = 1; i < p.length; i++) s += " L " + p[i][0].toFixed(1) + " " + p[i][1].toFixed(1)
                    return s
                }
            }
        }
    }
}
