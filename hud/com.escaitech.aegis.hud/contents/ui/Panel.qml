import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// AEGIS HUD v2 - interfaz pura (sin Plasma). Recibe los datos y emite accion(id, arg) al pulsar.
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
    property bool vivo: true                 // false = pausa (nadie lo ve): sin rotar pestanas
    property bool fluido: true               // false = modo eco/pausa: sin transiciones animadas
    signal accion(string id, string arg)
    function verTab(k) { mod.tab = k; mod.fijadoHasta = Date.now() + 3600000 }

    implicitWidth: 360; implicitHeight: 954
    readonly property real k: Math.max(0.4, Math.min(width / 360, height / 954))

    // ------------------------------------------------------------ utilidades
    function v(o, ruta, def) { var x = o; var c = ruta.split("."); for (var i = 0; i < c.length; i++) { if (x === null || x === undefined) return def; x = x[c[i]] } return (x === null || x === undefined) ? def : x }
    function p2(n) { return (n < 10 ? "0" : "") + n }
    readonly property color critico: (acento.r > 0.85 && acento.g < 0.5) ? "#ffffff" : Pal.hot
    function nivel(x, a, b) { return x >= b ? p.critico : x >= a ? Pal.warn : p.acento }
    function tasa(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : b + " B/s" }
    function durac(x) { var dd = Math.floor(x / 86400), hh = Math.floor(x % 86400 / 3600), mm = Math.floor(x % 3600 / 60); return dd > 0 ? dd + "d " + p2(hh) + "h" : p2(hh) + "h " + p2(mm) + "m" }
    function hm(m) { return m > 0 ? Math.floor(m / 60) + "h" + p2(m % 60) : "" }
    readonly property var dias: ["DOMINGO", "LUNES", "MARTES", "MIÉRCOLES", "JUEVES", "VIERNES", "SÁBADO"]
    readonly property var meses: ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    readonly property var perfiles: ({ "performance": "RENDIMIENTO", "balanced": "EQUILIBRADO", "power-saver": "AHORRO", "low-power": "AHORRO", "quiet": "SILENCIO" })
    readonly property real maxRed: Math.max(65536, Math.max.apply(null, rxH.concat(txH).concat([0])))
    readonly property var accesosDef: [{ t: "TERMINAL", s: "shell" }, { t: "MONITOR", s: "btop/htop" }, { t: "VS CODE", s: "editor" }, { t: "CHROME", s: "web" },
                                       { t: "CLAUDE", s: "ia" }, { t: "JUPYTER", s: "conda" }, { t: "RED", s: "ss · ip" }, { t: "ARCHIVOS", s: "~" }]

    component Etq: Text { font.family: Pal.mono; font.pixelSize: 12; color: Pal.dim }
    component Val: Text { font.family: Pal.mono; font.pixelSize: 13; color: Pal.text; elide: Text.ElideRight }

    Item {
        id: lienzo
        width: 360; height: 954
        scale: p.k
        transformOrigin: Item.TopLeft
        x: (p.width - 360 * p.k) / 2

        // ======================================================== CABECERA: hora, fecha, clima
        Marco {
            id: cab
            x: 0; y: 0; width: 360; height: 150
            acento: p.acento
            titulo: "AEGIS  //  NODO DE MANDO"
            meta: "● EN LÍNEA"
            metaColor: Pal.ok
            Row {
                y: -4
                Text { id: hmT; text: p.p2(p.ahora.getHours()) + ":" + p.p2(p.ahora.getMinutes()); font.family: Pal.tit; font.pixelSize: 50; font.weight: Font.Medium; color: Pal.text }
                Text { anchors.baseline: hmT.baseline; text: ":" + p.p2(p.ahora.getSeconds()); font.family: Pal.tit; font.pixelSize: 22; color: p.acento2 }
            }
            Column {   // clima (Open-Meteo, cada 30 min)
                readonly property var c: p.v(p.s, "clima", null)
                anchors.right: parent.right; y: 0; spacing: 0
                visible: c !== null
                Text { anchors.right: parent.right; text: parent.c ? parent.c.temp + "°" : ""; font.family: Pal.tit; font.pixelSize: 26; color: p.acento2 }
                Text { anchors.right: parent.right; text: parent.c ? parent.c.cond : ""; font.family: Pal.mono; font.pixelSize: 10; color: Pal.dim }
                Text { anchors.right: parent.right; text: parent.c ? parent.c.ciudad + (parent.c.hum ? " · " + parent.c.hum + "%" : "") : ""; font.family: Pal.mono; font.pixelSize: 10; color: Pal.faint }
            }
            Item {
                y: 64; width: parent.width; height: 16
                Text {
                    text: p.dias[p.ahora.getDay()] + " · " + p.p2(p.ahora.getDate()) + " " + p.meses[p.ahora.getMonth()] + " " + p.ahora.getFullYear()
                    font.family: Pal.ui; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 2; color: p.acento
                }
                Etq { anchors.right: parent.right; y: 1; text: "ACTIVO " + p.durac(p.v(p.d, "up", 0)) }
            }
            Etq {
                y: 84; width: parent.width; elide: Text.ElideRight; color: Pal.faint
                text: p.v(p.s, "host", "—") + " · " + p.v(p.s, "kernel", "") + " · " + p.v(p.s, "so", "Linux").toUpperCase() + (p.v(p.s, "perfil", null) ? " · " + (p.perfiles[p.s.perfil] || p.s.perfil.toUpperCase()) : "")
            }
        }

        // ======================================================== SISTEMAS: CPU, RAM, TEMP, GPU
        Marco {
            id: sis
            x: 0; y: cab.y + cab.height + 8; width: 360; height: 284
            acento: p.acento
            titulo: "SISTEMAS"
            meta: p.v(p.d, "nuc", 0) + " NÚCLEOS" + (p.v(p.d, "ghz", null) ? " · " + p.d.ghz.toFixed(1) + " GHZ" : "") + " · " + p.v(p.d, "ram.total", 0) + " GB"
            Medidor {
                x: 0; scale: 0.78; transformOrigin: Item.TopLeft; animado: p.fluido
                valor: p.v(p.d, "cpu", 0); etiqueta: "CPU"; texto: Math.round(p.v(p.d, "cpu", 0)); unidad: "%"
                color: p.nivel(valor, 70, 90)
            }
            Medidor {
                x: 77; scale: 0.78; transformOrigin: Item.TopLeft; animado: p.fluido
                valor: p.v(p.d, "ram.pct", 0); etiqueta: "RAM"; texto: Math.round(p.v(p.d, "ram.pct", 0)); unidad: p.v(p.d, "ram.usado", 0) + " GB"
                color: p.nivel(valor, 75, 90)
            }
            Medidor {
                x: 154; scale: 0.78; transformOrigin: Item.TopLeft; animado: p.fluido
                readonly property var t: p.v(p.d, "temp", null)
                valor: t === null ? 0 : t; etiqueta: "TEMP"; texto: t === null ? "--" : Math.round(t); unidad: "°C"
                color: t === null ? Pal.faint : p.nivel(t, 70, 85)
            }
            Medidor {   // la GPU solo se consulta si ya estaba despierta (no gasta bateria)
                x: 231; scale: 0.78; transformOrigin: Item.TopLeft; animado: p.fluido
                readonly property var g: p.v(p.d, "gpu", null)
                readonly property bool on: g !== null && g.estado === "activa" && g.uso !== undefined && g.uso !== null
                valor: on ? g.uso : 0; etiqueta: "GPU"
                texto: g === null ? "--" : on ? Math.round(g.uso) : g.estado === "dormida" ? "Zz" : "ON"
                unidad: g === null ? "SIN GPU" : on ? Math.round(g.temp) + "°C · " + (g.vram / 1024).toFixed(1) + "G" : g.estado === "dormida" ? "REPOSO" : "ACTIVA"
                color: g === null || !on ? Pal.faint : p.nivel(Math.max(g.uso, g.temp - 10), 70, 85)
            }
            Etq { y: 84; text: "CPU · 2 MIN"; font.pixelSize: 10; color: Pal.faint }
            Traza { y: 84; width: parent.width; height: 40; datos: p.cpuH; capacidad: 60; color: p.acento }
            Rectangle { y: 128; width: parent.width; height: 1; color: G.alfa(p.acento, 0.2) }
            Column {
                y: 138; width: parent.width; spacing: 9
                Item {
                    width: parent.width; height: 16
                    Etq { text: "CARGA" }
                    Val { anchors.right: parent.right; text: p.v(p.d, "load", [0, 0, 0]).map(function (x) { return x.toFixed(2) }).join("  ") }
                }
                Item {
                    width: parent.width; height: 16
                    Etq { text: "DISCO" }
                    Barra { x: 70; y: 4; width: 130; f: p.v(p.d, "disco", 0) / 100; color: p.nivel(p.v(p.d, "disco", 0), 80, 92) }
                    Val { anchors.right: parent.right; text: Math.round(p.v(p.d, "disco", 0)) + "% · " + p.v(p.d, "libre", 0) + "G" }
                }
                Item {
                    width: parent.width; height: 16
                    readonly property var bat: p.v(p.d, "bat", null)
                    readonly property bool ac: p.v(p.d, "ac", true)
                    Etq { text: "ENERGÍA" }
                    Barra { x: 70; y: 4; width: 130; visible: parent.bat !== null; f: parent.bat ? parent.bat.pct / 100 : 0; color: parent.bat && parent.bat.pct < 20 ? p.critico : Pal.ok }
                    Val {
                        anchors.right: parent.right
                        readonly property var b: parent.bat
                        text: b === null ? "RED ELÉCTRICA"
                            : b.pct + "%" + (b.w > 0 ? " · " + b.w.toFixed(0) + "W" : "") + (p.hm(b.min) ? " · " + p.hm(b.min) : "") + (parent.ac ? " ⚡" : "")
                        color: b === null ? Pal.ok : Pal.text
                    }
                }
            }
        }

        // ======================================================== ENLACE
        Marco {
            id: red
            x: 0; y: sis.y + sis.height + 8; width: 360; height: 160
            acento: p.acento
            readonly property var n: p.v(p.d, "net", {})
            titulo: "ENLACE"
            meta: red.n.iface ? red.n.iface.toUpperCase() + " · " + p.v(p.d, "conex.n", 0) + " CONEX" : "SIN ENLACE"
            metaColor: red.n.iface ? Pal.dim : p.critico
            Grid {
                columns: 2; columnSpacing: 10; rowSpacing: 3
                Etq { text: "IP" } Val { width: 120; text: red.n.ip || "—" }
                Etq { text: "GW" } Val { width: 120; text: red.n.gw || "—" }
                Etq { text: "SSID" } Val { width: 120; text: red.n.ssid || (red.n.iface ? "cableada" : "—") }
                Etq { text: "VPN" } Val { width: 120; text: red.n.vpn ? "ACTIVA · " + red.n.vpn : "INACTIVA"; color: red.n.vpn ? Pal.ok : Pal.dim }
            }
            Column {
                anchors.right: parent.right; spacing: 2
                Text { anchors.right: parent.right; text: "↓ " + p.tasa(red.n.rx || 0); font.family: Pal.tit; font.pixelSize: 15; color: p.acento }
                Text { anchors.right: parent.right; text: "↑ " + p.tasa(red.n.tx || 0); font.family: Pal.tit; font.pixelSize: 15; color: p.acento2 }
                Text { anchors.right: parent.right; text: p.v(p.d, "conex.ext", 0) + " EXTERNAS"; font.family: Pal.mono; font.pixelSize: 10; color: Pal.dim }
            }
            Traza { y: 76; width: parent.width; height: 32; datos: p.rxH; maximo: p.maxRed; color: p.acento }
            Traza { y: 76; width: parent.width; height: 32; datos: p.txH; maximo: p.maxRed; color: p.acento2; relleno: false }
        }

        // ======================================================== MODULOS: procesos / docker / proyectos / perimetro
        Marco {
            id: mod
            x: 0; y: red.y + red.height + 8; width: 360; height: 172
            acento: p.acento
            readonly property var tabs: ["PROCESOS", "DOCKER", "PROYECTOS", "PERÍMETRO"]
            property int tab: 0
            property real fijadoHasta: 0      // al pulsar una pestana, deja de rotar durante un minuto
            readonly property var dk: p.v(p.s, "docker", { ok: false, msg: "SIN DATOS", c: [] })
            readonly property var repos: p.v(p.s, "proyectos", [])
            readonly property var pts: p.v(p.s, "puertos", [])
            readonly property int expuestos: pts.filter(function (x) { return !x.local }).length
            readonly property int fallos: p.v(p.s, "fallos", 0)
            titulo: "MÓDULOS"
            meta: tab === 0 ? "TOP CPU"
                : tab === 1 ? (dk.ok ? dk.on + "/" + dk.total + " ACTIVOS" : "NO DISPONIBLE")
                : tab === 2 ? repos.length + " REPOS"
                : (fallos > 0 ? fallos + " CAÍDO" + (fallos > 1 ? "S" : "") : expuestos > 0 ? expuestos + " EXPUESTO" + (expuestos > 1 ? "S" : "") : "SELLADO")
            metaColor: tab === 3 ? (fallos > 0 ? p.critico : expuestos > 0 ? Pal.warn : Pal.ok) : Pal.dim
            Timer { interval: 12000; repeat: true; running: p.vivo; onTriggered: if (Date.now() > mod.fijadoHasta) mod.tab = (mod.tab + 1) % 4 }

            Row {   // pestanas
                y: -4; spacing: 4
                Repeater {
                    model: mod.tabs
                    Rectangle {
                        required property int index
                        required property string modelData
                        width: (332 - 12) / 4; height: 20
                        color: mod.tab === index ? G.alfa(p.acento, 0.22) : maT.containsMouse ? G.alfa(p.acento, 0.1) : "transparent"
                        border.width: 1; border.color: G.alfa(p.acento, mod.tab === index ? 0.8 : 0.3)
                        Text { anchors.centerIn: parent; text: modelData; font.family: Pal.mono; font.pixelSize: 10; color: mod.tab === index ? Pal.text : Pal.dim }
                        MouseArea { id: maT; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { mod.tab = index; mod.fijadoHasta = Date.now() + 60000 } }
                    }
                }
            }
            Item {
                y: 24; width: parent.width; height: 96

                // ---- PROCESOS
                Column {
                    visible: mod.tab === 0; width: parent.width; spacing: 6
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
                // ---- DOCKER
                Column {
                    visible: mod.tab === 1; width: parent.width; spacing: 4
                    Etq { visible: !mod.dk.ok; text: mod.dk.msg || ""; color: Pal.warn }
                    Etq { visible: mod.dk.ok && mod.dk.c.length === 0; text: "SIN CONTENEDORES" }
                    Repeater {
                        model: mod.dk.ok ? mod.dk.c.slice(0, 4) : []
                        Item {
                            required property var modelData
                            width: parent.width; height: 20
                            Rectangle { y: 6; width: 8; height: 8; radius: 4; color: modelData.on ? Pal.ok : Pal.faint }
                            Text { x: 14; width: 120; elide: Text.ElideRight; text: modelData.n; font.family: Pal.ui; font.pixelSize: 15; font.weight: Font.DemiBold; color: modelData.on ? Pal.text : Pal.dim }
                            Text { x: 138; y: 2; width: 140; elide: Text.ElideRight; text: modelData.img; font.family: Pal.mono; font.pixelSize: 10; color: Pal.faint }
                            Boton {
                                anchors.right: parent.right; width: 46; height: 19
                                acento: modelData.on ? p.acento2 : p.acento
                                texto: modelData.on ? "■ STOP" : "▶ RUN"; tam: 11
                                onPulsado: p.accion(modelData.on ? "docker-stop" : "docker-start", modelData.n)
                            }
                        }
                    }
                }
                // ---- PROYECTOS
                Column {
                    visible: mod.tab === 2; width: parent.width; spacing: 4
                    Etq { visible: mod.repos.length === 0; text: "SIN REPOS GIT (edita \"proyectos\" en config.json)" }
                    Repeater {
                        model: mod.repos.slice(0, 4)
                        Rectangle {
                            required property var modelData
                            width: parent.width; height: 20
                            color: maP.containsMouse ? G.alfa(p.acento, 0.12) : "transparent"
                            Text { x: 2; width: 120; elide: Text.ElideRight; text: modelData.n; font.family: Pal.ui; font.pixelSize: 15; font.weight: Font.DemiBold; color: Pal.text }
                            Text { x: 126; y: 2; width: 90; elide: Text.ElideRight; text: modelData.b; font.family: Pal.mono; font.pixelSize: 11; color: p.acento }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 2; y: 2
                                text: (modelData.sucio ? "●" + modelData.sucio + " " : "✓ ") + (modelData.adelante ? "↑" + modelData.adelante + " " : "") + (modelData.atras ? "↓" + modelData.atras : "")
                                font.family: Pal.mono; font.pixelSize: 11; color: modelData.sucio ? Pal.warn : Pal.ok
                            }
                            MouseArea { id: maP; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.accion("proyecto", modelData.ruta) }
                        }
                    }
                }
                // ---- PERIMETRO
                Flow {
                    visible: mod.tab === 3; width: parent.width; spacing: 5
                    Repeater {
                        model: mod.pts.slice(0, 10)
                        Rectangle {
                            required property var modelData
                            width: chip.implicitWidth + 12; height: 20
                            color: G.alfa(modelData.local ? p.acento : Pal.warn, 0.08)
                            border.width: 1; border.color: G.alfa(modelData.local ? p.acento : Pal.warn, 0.6)
                            Text { id: chip; anchors.centerIn: parent; text: ":" + modelData.p + (modelData.n ? " " + modelData.n : ""); font.family: Pal.mono; font.pixelSize: 11; color: modelData.local ? Pal.text : Pal.warn }
                        }
                    }
                    Etq { visible: mod.pts.length === 0; text: "SIN PUERTOS EN ESCUCHA" }
                }
            }
        }

        // ======================================================== ACCESOS (configurables en ~/.config/aegis/config.json)
        Marco {
            id: acc
            x: 0; y: mod.y + mod.height + 8; width: 360; height: 138
            acento: p.acento
            titulo: "ACCESOS"
            meta: "SUPER+ALT+A OCULTA"
            readonly property var lista: { var a = p.v(p.s, "accesos", []); return a.length ? a : p.accesosDef }
            Grid {
                columns: 4; spacing: 6
                Repeater {
                    model: acc.lista.slice(0, 8)
                    Boton {
                        required property int index
                        required property var modelData
                        width: (332 - 18) / 4; height: 40
                        acento: p.acento
                        texto: modelData.t; sub: modelData.s
                        onPulsado: p.accion("acceso", String(index))
                    }
                }
            }
        }
    }
}
