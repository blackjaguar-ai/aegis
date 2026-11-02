import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "telemetria.js" as T

// AEGIS - plugin de fondo para Plasma. La escena vive en Escena.qml (QtQuick puro).
// Lee la telemetria con el motor del HUD; sin cargador pasa a modo eco.
WallpaperItem {
    id: root
    readonly property var paletas: [
        { a: "#3fe0ff", b: "#ffb347", f: "#02060c" },   // cian
        { a: "#ffb347", b: "#3fe0ff", f: "#0a0602" },   // ambar
        { a: "#ff4d5e", b: "#ffd166", f: "#0c0204" },   // carmesi
        { a: "#4dffa6", b: "#3fe0ff", f: "#020a06" }    // verde
    ]
    readonly property var p: paletas[Math.max(0, Math.min(3, root.configuration.Acento || 0))]
    property var d: ({})
    property int n: 0

    P5Support.DataSource {
        id: sh
        engine: "executable"
        connectedSources: []
        onNewData: function (fuente, datos) {
            disconnectSource(fuente)
            try {
                var x = JSON.parse(datos["stdout"])
                root.d = x
                for (var i = 0; x.eventos && i < x.eventos.length; i++) esc.agregar(x.eventos[i].tag, x.eventos[i].f, x.eventos[i].w)
                if (root.n % 3 === 0) { var l = T.linea(x, root.n / 3); esc.agregar(l.tag, l.f, false) }
                root.n++
            } catch (e) {}
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: sh.connectSource("python3 -I \"$HOME/.local/share/aegis/hud/com.escaitech.aegis.hud/contents/code/datos.py\" rapido fondo")
    }

    Escena {
        id: esc
        anchors.fill: parent
        modo: root.configuration.Animar === false ? "pausa" : (root.d.ac === false ? "eco" : "completo")
        acento: root.p.a; acento2: root.p.b; fondo: root.p.f
        carga: (root.d.cpu || 0) / 100
        nucleos: root.d.nucleos || []
        conexiones: (root.d.conex || {}).l || []
        nConex: (root.d.conex || {}).n || 0
        energia: T.energia(root.d)
        enlace: T.enlace(root.d)
        sincroT: "CARGA"; sincroV: T.carga(root.d)
        estadoNucleo: T.nucleo(root.d)
    }
}
