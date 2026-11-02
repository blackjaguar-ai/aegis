import QtQuick
import "../fondo-animado/com.escaitech.aegis.wallpaper/contents/ui" as F
import "../hud/com.escaitech.aegis.hud/contents/ui" as H

// AEGIS para GNOME: el mismo fondo y el mismo HUD que en Plasma, alimentados por 'motor' (Python).
Item {
    id: r
    readonly property var paletas: [
        { a: "#3fe0ff", b: "#ffb347", f: "#02060c" }, { a: "#ffb347", b: "#3fe0ff", f: "#0a0602" },
        { a: "#ff4d5e", b: "#ffd166", f: "#0c0204" }, { a: "#4dffa6", b: "#3fe0ff", f: "#020a06" }]
    readonly property var p: paletas[Math.max(0, Math.min(3, motor.acento))]
    property var d: ({})
    property var s: ({})
    property var cpuH: []
    property var rxH: []
    property var txH: []
    property var ahora: new Date()

    function push(a, v, n) { var b = a.slice(); b.push(v); if (b.length > n) b.shift(); return b }
    Connections {
        target: motor
        function onRapido(js) {
            try { var x = JSON.parse(js); r.d = x; r.cpuH = r.push(r.cpuH, x.cpu, 60)
                  r.rxH = r.push(r.rxH, x.net.rx || 0, 60); r.txH = r.push(r.txH, x.net.tx || 0, 60) } catch (e) {}
        }
        function onLento(js) { try { r.s = JSON.parse(js) } catch (e) {} }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: r.ahora = new Date() }

    F.Escena { anchors.fill: parent; animar: motor.animar; acento: r.p.a; acento2: r.p.b; fondo: r.p.f }

    H.Panel {
        readonly property real k: Math.max(0.6, Math.min(2, (r.height - motor.margenSup - 32) / 954))
        width: 360 * k; height: 954 * k
        x: r.width - width - 20; y: motor.margenSup + 14
        d: r.d; s: r.s; cpuH: r.cpuH; rxH: r.rxH; txH: r.txH; ahora: r.ahora
        acento: r.p.a; acento2: r.p.b
        onAccion: function (id) { motor.accion(id) }
    }
}
