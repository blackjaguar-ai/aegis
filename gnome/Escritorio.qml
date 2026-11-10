import QtQuick
import "../fondo-animado/com.escaitech.aegis.wallpaper/contents/ui" as F
import "../hud/com.escaitech.aegis.hud/contents/ui" as H
import "../fondo-animado/com.escaitech.aegis.wallpaper/contents/ui/telemetria.js" as T

// AEGIS para GNOME: el mismo fondo y el mismo HUD que en Plasma, alimentados por 'motor' (Python).
// motor.modo decide el gasto: "completo", "eco" (con bateria) o "pausa" (una ventana tapa el escritorio).
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
    property int n: 0
    property var ahora: new Date()

    function push(a, v, k) { var b = a.slice(); b.push(v); if (b.length > k) b.shift(); return b }
    function eventos(lista) { for (var i = 0; lista && i < lista.length; i++) esc.agregar(lista[i].tag, lista[i].f, lista[i].w) }
    Connections {
        target: motor
        function onRapido(js) {
            try {
                var x = JSON.parse(js)
                r.d = x
                r.cpuH = r.push(r.cpuH, x.cpu, 60); r.rxH = r.push(r.rxH, x.net.rx || 0, 60); r.txH = r.push(r.txH, x.net.tx || 0, 60)
                r.eventos(x.eventos)
                if (r.n % 3 === 0) { var l = T.linea(x, r.n / 3); esc.agregar(l.tag, l.f, false) }
                r.n++
            } catch (e) {}
        }
        function onLento(js) { try { var x = JSON.parse(js); r.s = x; r.eventos(x.eventos) } catch (e) {} }
    }
    Timer { interval: 1000; running: motor.modo !== "pausa"; repeat: true; triggeredOnStart: true; onTriggered: r.ahora = new Date() }

    F.Escena {
        id: esc
        anchors.fill: parent
        modo: motor.modo
        acento: r.p.a; acento2: r.p.b; fondo: r.p.f
        carga: (r.d.cpu || 0) / 100
        nucleos: r.d.nucleos || []
        conexiones: (r.d.conex || {}).l || []
        nConex: (r.d.conex || {}).n || 0
        energia: T.energia(r.d)
        enlace: T.enlace(r.d)
        sincroT: "CARGA"; sincroV: T.carga(r.d)
        estadoNucleo: T.nucleo(r.d)
    }

    H.Panel {
        readonly property real k: Math.max(0.6, Math.min(2, (r.height - motor.margenSup - 32) / 954))
        visible: motor.hudVisible
        width: 360 * k; height: 954 * k
        x: r.width - width - 20; y: motor.margenSup + 14
        d: r.d; s: r.s; cpuH: r.cpuH; rxH: r.rxH; txH: r.txH; ahora: r.ahora
        acento: r.p.a; acento2: r.p.b
        vivo: motor.modo !== "pausa"
        fluido: false   // medidores sin transicion: cada animacion iria a la frecuencia de la pantalla
        onAccion: function (id, arg) { motor.accion(id, arg) }
    }
}
