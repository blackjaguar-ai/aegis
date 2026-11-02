import QtQuick
import QtQuick.Shapes

// Un anillo vectorial que gira sobre su centro. 'trazo' es un path SVG dibujado alrededor de (radio, radio).
Item {
    id: a
    property real radio: 100          // medio lado del item (el trazo debe caber dentro)
    property string trazo: ""
    property color color: "#3fe0ff"
    property real grosor: 2
    property int periodo: 0           // ms por vuelta; negativo = antihorario; 0 = fijo
    property bool animar: true
    property real cx: 0
    property real cy: 0
    x: cx - radio; y: cy - radio
    width: 2 * radio; height: 2 * radio

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
    RotationAnimator on rotation {
        from: 0; to: a.periodo < 0 ? -360 : 360
        duration: Math.max(1, Math.abs(a.periodo))
        loops: Animation.Infinite
        running: a.animar && a.periodo !== 0
    }
}
