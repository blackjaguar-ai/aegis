import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// AEGIS HUD - interfaz pura (sin Plasma). Recibe los datos y emite 'accion' al pulsar un boton.
// Diseno de 360x954; se escala entero para caber en el espacio que le den.
Item {
    id: p
    property var d: ({})
    property var s: ({})
    property var cpuH: []
    property var rxH: []
    property var txH: []
    property var ahora: new Date()
    property color acento: "#3fe0ff"
    property color acento2: "#ffb347"
    signal accion(string id)

    implicitWidth: 360; implicitHeight: 954
    readonly property real k: Math.max(0.4, Math.min(width / 360, height / 954))

    // ------------------------------------------------------------ utilidades
    function v(o, ruta, def) { var x = o; var c = ruta.split("."); for (var i = 0; i < c.length; i++) { if (x === null || x === undefined) return def; x = x[c[i]] } return (x === null || x === undefined) ? def : x }
    function p2(n) { return (n < 10 ? "0" : "") + n }
    // si el acento ya es rojo, la alerta critica pasa a blanco para no confundirse
    readonly property color critico: (acento.r > 0.85 && acento.g < 0.5) ? "#ffffff" : Pal.hot
    function nivel(x, a, b) { return x >= b ? p.critico : x >= a ? Pal.warn : p.acento }
    function tasa(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : b + " B/s" }
    function durac(x) { var dd = Math.floor(x / 86400), hh = Math.floor(x % 86400 / 3600), mm = Math.floor(x % 3600 / 60); return dd > 0 ? dd + "d " + p2(hh) + "h" : p2(hh) + "h " + p2(mm) + "m" }
    readonly property var dias: ["DOMINGO", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO"]
    readonly property var meses: ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    readonly property real maxRed: Math.max(65536, Math.max.apply(null, rxH.concat(txH).concat([0])))

    component Etq: Text { font.family: Pal.mono; font.pixelSize: 12; color: Pal.dim }
    component Val: Text { font.family: Pal.mono; font.pixelSize: 13; color: Pal.text; elide: Text.ElideRight }

    Item {
        id: lienzo
        width: 360; height: 954
        scale: p.k
        transformOrigin: Item.TopLeft
        x: (p.width - 360 * p.k) / 2

        // ======================================================== CABECERA
        Marco {
            id: cab
            x: 0; y: 0; width: 360; height: 150
            acento: p.acento
            titulo: "AEGIS  //  NODO DE MANDO"
            meta: "● EN LÍNEA"
            metaColor: Pal.ok
            Row {
                y: -4
                Text { id: hm; text: p.p2(p.ahora.getHours()) + ":" + p.p2(p.ahora.getMinutes()); font.family: Pal.tit; font.pixelSize: 50; font.weight: Font.Medium; color: Pal.text }
                Text { anchors.baseline: hm.baseline; text: ":" + p.p2(p.ahora.getSeconds()); font.family: Pal.tit; font.pixelSize: 22; color: p.acento2 }
            }
            Text {
                anchors.right: parent.right; y: 6
                horizontalAlignment: Text.AlignRight
                text: p.dias[p.ahora.getDay()] + "\n" + p.p2(p.ahora.getDate()) + " " + p.meses[p.ahora.getMonth()] + " " + p.ahora.getFullYear()
                font.family: Pal.ui; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 2; lineHeight: 0.95; color: p.acento
            }
            Row {
                y: 66; spacing: 14
                Etq { text: "ACTIVO " + p.durac(p.v(p.d, "up", 0)) }
                Etq { text: p.v(p.s, "host", "—") + " · " + p.v(p.s, "kernel", "") }
            }
            Etq { y: 84; width: parent.width; elide: Text.ElideRight; text: p.v(p.s, "so", "Linux").toUpperCase(); color: Pal.faint }
        }

        // ======================================================== SISTEMAS
        Marco {
            id: sis
            x: 0; y: cab.y + cab.height + 8; width: 360; height: 284
            acento: p.acento
            titulo: "SISTEMAS"
            meta: p.v(p.d, "nuc", 0) + " NÚCLEOS · " + p.v(p.d, "ram.total", 0) + " GB"
            Medidor {
                x: 0; y: 0
                valor: p.v(p.d, "cpu", 0); etiqueta: "CPU"; texto: Math.round(p.v(p.d, "cpu", 0)); unidad: "%"
                color: p.nivel(valor, 70, 90)
            }
            Medidor {
                x: 104; y: 0
                valor: p.v(p.d, "ram.pct", 0); etiqueta: "RAM"; texto: Math.round(p.v(p.d, "ram.pct", 0)); unidad: p.v(p.d, "ram.usado", 0) + " GB"
                color: p.nivel(valor, 75, 90)
            }
            Medidor {
                x: 208; y: 0
                readonly property var t: p.v(p.d, "temp", null)
                valor: t === null ? 0 : t; maximo: 100; etiqueta: "TEMP"; texto: t === null ? "--" : Math.round(t); unidad: "°C"
                color: t === null ? Pal.faint : p.nivel(t, 70, 85)
            }
            Etq { y: 106; text: "CPU · 2 MIN"; font.pixelSize: 10; color: Pal.faint }
            Traza { y: 104; width: parent.width; height: 48; datos: p.cpuH; capacidad: 60; color: p.acento }
            Rectangle { y: 152; width: parent.width; height: 1; color: G.alfa(p.acento, 0.2) }

            Column {
                y: 162; width: parent.width; spacing: 9
                Item {
                    width: parent.width; height: 16
                    Etq { text: "CARGA" }
                    Val { anchors.right: parent.right; text: p.v(p.d, "load", [0, 0, 0]).map(function (x) { return x.toFixed(2) }).join("  ") }
                }
                Item {
                    width: parent.width; height: 16
                    Etq { text: "DISCO" }
                    Barra { x: 70; y: 4; width: 150; f: p.v(p.d, "disco", 0) / 100; color: p.nivel(p.v(p.d, "disco", 0), 80, 92) }
                    Val { anchors.right: parent.right; text: Math.round(p.v(p.d, "disco", 0)) + "% · " + p.v(p.d, "libre", 0) + "G" }
                }
                Item {
                    width: parent.width; height: 16
                    readonly property var bat: p.v(p.d, "bat", null)
                    Etq { text: "ENERGÍA" }
                    Barra { x: 70; y: 4; width: 150; visible: parent.bat !== null; f: parent.bat ? parent.bat.pct / 100 : 0; color: parent.bat && parent.bat.pct < 20 ? Pal.hot : Pal.ok }
                    Val {
                        anchors.right: parent.right
                        text: parent.bat === null ? "RED ELÉCTRICA" : parent.bat.pct + "%" + (parent.bat.estado === "Charging" ? " ⚡" : "")
                        color: parent.bat === null ? Pal.ok : Pal.text
                    }
                }
            }
        }

        // ======================================================== RED
        Marco {
            id: red
            x: 0; y: sis.y + sis.height + 8; width: 360; height: 160
            acento: p.acento
            readonly property var n: p.v(p.d, "net", {})
            titulo: "ENLACE"
            meta: red.n.iface ? red.n.iface.toUpperCase() : "SIN ENLACE"
            metaColor: red.n.iface ? Pal.dim : Pal.hot
            Grid {
                columns: 2; columnSpacing: 10; rowSpacing: 3
                Etq { text: "IP" } Val { width: 120; text: red.n.ip || "—" }
                Etq { text: "GW" } Val { width: 120; text: red.n.gw || "—" }
                Etq { text: "SSID" } Val { width: 120; text: red.n.ssid || "cableada" }
                Etq { text: "VPN" } Val { width: 120; text: red.n.vpn ? "ACTIVA · " + red.n.vpn : "INACTIVA"; color: red.n.vpn ? Pal.ok : Pal.warn }
            }
            Column {
                anchors.right: parent.right; spacing: 2
                Text { anchors.right: parent.right; text: "↓ " + p.tasa(red.n.rx || 0); font.family: Pal.tit; font.pixelSize: 15; color: p.acento }
                Text { anchors.right: parent.right; text: "↑ " + p.tasa(red.n.tx || 0); font.family: Pal.tit; font.pixelSize: 15; color: p.acento2 }
            }
            Traza { y: 76; width: parent.width; height: 32; datos: p.rxH; maximo: p.maxRed; color: p.acento }
            Traza { y: 76; width: parent.width; height: 32; datos: p.txH; maximo: p.maxRed; color: p.acento2; relleno: false }
        }

        // ======================================================== PROCESOS
        Marco {
            id: proc
            x: 0; y: red.y + red.height + 8; width: 360; height: 128
            acento: p.acento
            titulo: "PROCESOS"
            meta: "TOP CPU"
            Column {
                width: parent.width; spacing: 4
                Repeater {
                    model: p.v(p.d, "top", [])
                    Item {
                        required property var modelData
                        width: parent.width; height: 16
                        Text { width: 120; elide: Text.ElideRight; text: modelData.n; font.family: Pal.ui; font.pixelSize: 15; font.weight: Font.DemiBold; color: Pal.text }
                        Barra { x: 128; y: 4; width: 120; f: Math.min(1, modelData.c / 100); color: p.nivel(modelData.c, 50, 85) }
                        Val { anchors.right: parent.right; text: modelData.c.toFixed(1) + "%" }
                    }
                }
            }
        }

        // ======================================================== PERIMETRO
        Marco {
            id: per
            x: 0; y: proc.y + proc.height + 8; width: 360; height: 100
            acento: p.acento
            readonly property var lista: p.v(p.s, "puertos", [])
            readonly property int expuestos: lista.filter(function (x) { return !x.local }).length
            readonly property int fallos: p.v(p.s, "fallos", 0)
            titulo: "PERÍMETRO"
            meta: fallos > 0 ? fallos + " SERVICIO" + (fallos > 1 ? "S" : "") + " CAÍDO" + (fallos > 1 ? "S" : "") : expuestos > 0 ? expuestos + " EXPUESTO" + (expuestos > 1 ? "S" : "") : "SELLADO"
            metaColor: fallos > 0 ? Pal.hot : expuestos > 0 ? Pal.warn : Pal.ok
            Flow {
                width: parent.width; spacing: 5
                Repeater {
                    model: per.lista.slice(0, 8)
                    Rectangle {
                        required property var modelData
                        width: chip.implicitWidth + 12; height: 20
                        color: G.alfa(modelData.local ? p.acento : Pal.warn, 0.08)
                        border.width: 1; border.color: G.alfa(modelData.local ? p.acento : Pal.warn, 0.6)
                        Text { id: chip; anchors.centerIn: parent; text: ":" + modelData.p + (modelData.n ? " " + modelData.n : ""); font.family: Pal.mono; font.pixelSize: 11; color: modelData.local ? Pal.text : Pal.warn }
                    }
                }
                Etq { visible: per.lista.length === 0; text: "SIN PUERTOS EN ESCUCHA" }
            }
        }

        // ======================================================== OPERACIONES
        Marco {
            id: ops
            x: 0; y: per.y + per.height + 8; width: 360; height: 92
            acento: p.acento
            titulo: "OPERACIONES"
            Row {
                spacing: 6
                Repeater {
                    model: [
                        { id: "terminal", t: "TERMINAL", s: "shell" },
                        { id: "monitor", t: "MONITOR", s: "btop/htop" },
                        { id: "red", t: "RED", s: "ss · ip" },
                        { id: "archivos", t: "ARCHIVOS", s: "~" }
                    ]
                    Boton {
                        required property var modelData
                        width: (332 - 18) / 4; height: 40
                        acento: p.acento
                        texto: modelData.t; sub: modelData.s
                        onPulsado: p.accion(modelData.id)
                    }
                }
            }
        }
    }
}
