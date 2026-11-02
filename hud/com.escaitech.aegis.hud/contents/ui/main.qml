import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

// AEGIS HUD - envoltorio de Plasma: lee la telemetria con datos.py y se la pasa a Panel.qml
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property string codigo: Qt.resolvedUrl("../code/").toString().replace("file://", "")
    readonly property var paletas: [["#3fe0ff", "#ffb347"], ["#ffb347", "#3fe0ff"], ["#ff4d5e", "#ffd166"], ["#4dffa6", "#3fe0ff"]]
    readonly property var pal: paletas[Math.max(0, Math.min(3, Plasmoid.configuration.Acento || 0))]

    property var d: ({})
    property var s: ({})
    property var cpuH: []
    property var rxH: []
    property var txH: []
    property var ahora: new Date()

    function push(a, v, n) { var b = a.slice(); b.push(v); if (b.length > n) b.shift(); return b }
    function onRapido(out) {
        try {
            var x = JSON.parse(out); d = x
            cpuH = push(cpuH, x.cpu, 60); rxH = push(rxH, x.net.rx || 0, 60); txH = push(txH, x.net.tx || 0, 60)
        } catch (e) {}
    }
    function onLento(out) { try { s = JSON.parse(out) } catch (e) {} }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        connectedSources: []
        onNewData: function (fuente, datos) {
            disconnectSource(fuente)
            if (fuente.indexOf("datos.py' rapido") >= 0) root.onRapido(datos["stdout"])
            else if (fuente.indexOf("datos.py' lento") >= 0) root.onLento(datos["stdout"])
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sh.connectSource("python3 -I '" + root.codigo + "datos.py' rapido") }
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sh.connectSource("python3 -I '" + root.codigo + "datos.py' lento") }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.ahora = new Date() }

    fullRepresentation: Item {
        implicitWidth: 360
        implicitHeight: 954
        Layout.minimumWidth: 180; Layout.minimumHeight: 477
        Layout.preferredWidth: 360; Layout.preferredHeight: 954
        Panel {
            anchors.fill: parent
            d: root.d; s: root.s
            cpuH: root.cpuH; rxH: root.rxH; txH: root.txH
            ahora: root.ahora
            acento: root.pal[0]; acento2: root.pal[1]
            onAccion: function (id, arg) {
                var a = String(arg || "").replace(/'/g, "'\\''")   // comillas simples escapadas para el shell
                sh.connectSource("sh '" + root.codigo + "accion.sh' " + id + " '" + a + "' #" + Date.now())
            }
        }
    }
}
