import QtQuick
import QtQuick.Shapes

// Un anillo vectorial. Su giro sale del reloj comun de la escena ('fase', en segundos), asi todo
// se acelera, se ralentiza o se congela a la vez segun el modo de energia y la carga de CPU.
Item {
    id: a
    property real radio: 100          // medio lado del item (el trazo debe caber dentro)
    property string trazo: ""
    property color color: "#3fe0ff"
    property real grosor: 2
    property int periodo: 0           // ms por vuelta; negativo = antihorario; 0 = fijo
    property real fase: 0
    property real cx: 0
    property real cy: 0
    x: cx - radio; y: cy - radio
    width: 2 * radio; height: 2 * radio
    rotation: periodo === 0 ? 0 : (fase * 360000 / periodo) % 360

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: a.color
            strokeWidth: a.grosor
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathSvg { path: a.trazo }
        }
    }
}
