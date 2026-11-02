import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// AEGIS - escena del centro de mando. QtQuick puro (sin Plasma) para poder probarla fuera.
// Se dibuja en un lienzo virtual de 1920x1080 y se escala para cubrir cualquier pantalla.
//
// Energia: todo el movimiento sale de un unico reloj ('fase'):
//   modo "completo"  avanza en cada cuadro (FrameAnimation): animacion fluida con particulas y destellos
//   modo "eco"       avanza 12 veces por segundo y apaga particulas, destellos y linea de escaneo
//   modo "pausa"     no avanza: la escena queda quieta y la GPU no redibuja nada
// Datos: quien la use le pasa carga, nucleos, conexiones y etiquetas, y llama a agregar() con eventos reales.
Item {
    id: esc
    property string modo: "completo"
    property color acento: "#3fe0ff"
    property color acento2: "#ffb347"
    property color fondo: "#02060c"

    property real carga: 0.1              // 0..1, uso total de CPU
    property var nucleos: []              // % de uso por nucleo
    property var conexiones: []           // [{a: grados, d: 0..1, x: externa}]
    property int nConex: 0
    property string energia: "--"
    property string enlace: "--"
    property string sincroT: "CARGA"
    property string sincroV: "--"
    property string estadoNucleo: "EN LÍNEA"

    readonly property bool fluido: modo === "completo"
    readonly property bool vivo: modo !== "pausa"
    readonly property real u: Math.max(width / 1920, height / 1080)
    readonly property real cx: 860
    readonly property real cy: 540
    property var ahora: new Date()
    clip: true

    // ---------------------------------------------------------- reloj comun
    property real fase: 0
    property real cargaS: carga
    Behavior on cargaS { enabled: esc.fluido; NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }
    readonly property real vel: 0.7 + 1.8 * Math.max(0, Math.min(1, cargaS))   // el nucleo se acelera con la CPU
    FrameAnimation { running: esc.modo === "completo"; onTriggered: esc.fase += Math.min(frameTime, 0.1) * esc.vel }
    Timer { interval: 83; repeat: true; running: esc.modo === "eco"; onTriggered: esc.fase += 0.083 * esc.vel }
    Timer { interval: 1000; repeat: true; running: esc.vivo; triggeredOnStart: true; onTriggered: esc.ahora = new Date() }

    function p2(n) { return (n < 10 ? "0" : "") + n }
    function hhmmss(d) { return p2(d.getHours()) + ":" + p2(d.getMinutes()) + ":" + p2(d.getSeconds()) }
    function ciclo(periodo, desfase) { var x = (fase / periodo + (desfase || 0)) % 1; return x < 0 ? x + 1 : x }

    // registro de eventos: lo alimenta quien use la escena
    ListModel { id: lineas }
    function agregar(tag, texto, aviso) {
        lineas.insert(0, { t: hhmmss(new Date()), tag: (tag || "SYS").substring(0, 3), f: texto, w: !!aviso })
        if (lineas.count > 10) lineas.remove(10)
    }

    Rectangle { anchors.fill: parent; color: esc.fondo }

    Item {
        id: lienzo
        width: 1920; height: 1080
        anchors.centerIn: parent
        scale: esc.u

        // ---------------------------------------------------------- resplandor de fondo
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: esc.cx; centerY: esc.cy; centerRadius: 900
                    focalX: esc.cx; focalY: esc.cy
                    GradientStop { position: 0.0; color: G.alfa(esc.acento, 0.14 + 0.1 * esc.cargaS) }
                    GradientStop { position: 0.35; color: G.alfa(esc.acento, 0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: 1920; y: 0 } PathLine { x: 1920; y: 1080 } PathLine { x: 0; y: 1080 } PathLine { x: 0; y: 0 }
            }
        }

        // ---------------------------------------------------------- reticula hexagonal (se pinta una vez)
        Canvas {
            id: hex
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                var c = getContext("2d"), r = 30, w = r * 1.5, h = r * Math.sqrt(3), col = esc.acento, k = 0
                c.reset(); c.lineWidth = 1
                for (var i = 0; i * w < 1920 + w; i++) {
                    for (var j = 0; j * h < 1080 + h; j++) {
                        var x = i * w, y = j * h + (i % 2 ? h / 2 : 0), dist = Math.hypot(x - esc.cx, y - esc.cy) / 1100
                        k++
                        c.beginPath()
                        for (var s = 0; s < 6; s++) {
                            var t = s * Math.PI / 3, px = x + (r - 2) * Math.cos(t), py = y + (r - 2) * Math.sin(t)
                            if (s === 0) c.moveTo(px, py); else c.lineTo(px, py)
                        }
                        c.closePath()
                        c.strokeStyle = Qt.rgba(col.r, col.g, col.b, Math.max(0.025, 0.09 - dist * 0.06))
                        c.stroke()
                        if (G.rnd(k) < 0.05) { c.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.05); c.fill() }
                    }
                }
            }
            Connections { target: esc; function onAcentoChanged() { hex.requestPaint() } }
        }

        // hexagonos que laten (solo en modo completo)
        Repeater {
            model: 14
            Shape {
                id: hp
                required property int index
                readonly property real r: 26
                readonly property real per: 5 + G.rnd(index * 3) * 9
                readonly property real c: esc.ciclo(per, G.rnd(index * 13))
                visible: esc.fluido
                x: 60 + G.rnd(index * 7 + 3) * 1400; y: 80 + G.rnd(index * 11 + 5) * 900
                width: 2 * r + 2; height: 2 * r + 2
                preferredRendererType: Shape.CurveRenderer
                opacity: c < 0.08 ? c / 0.08 : c < 0.35 ? 1 - (c - 0.08) / 0.27 : 0
                ShapePath {
                    strokeColor: G.alfa(esc.acento, 0.7); strokeWidth: 1.5
                    fillColor: G.alfa(esc.acento, 0.12)
                    PathSvg { path: G.hexagono(hp.r + 1, hp.r + 1, hp.r) }
                }
            }
        }

        // ---------------------------------------------------------- particulas ascendentes (solo modo completo)
        Repeater {
            model: 40
            Rectangle {
                id: pa
                required property int index
                readonly property real vy: 35 + G.rnd(index * 13) * 50
                visible: esc.fluido
                width: 2 + G.rnd(index) * 2; height: width; radius: width / 2
                color: G.rnd(index * 9) < 0.15 ? esc.acento2 : esc.acento
                x: G.rnd(index * 3 + 1) * 1920
                y: 1100 - ((esc.fase * vy + G.rnd(index * 17) * 1120) % 1120)
                opacity: 0.15 + G.rnd(index * 5) * 0.5
            }
        }

        // ---------------------------------------------------------- NUCLEO
        Shape {   // resplandor: mas intenso cuanto mayor es la carga
            id: brillo
            x: esc.cx - 140; y: esc.cy - 140; width: 280; height: 280
            opacity: 0.55 + 0.3 * esc.cargaS + 0.15 * Math.sin(esc.fase * 2 * Math.PI / 3.6)
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 140; centerY: 140; centerRadius: 140; focalX: 140; focalY: 140
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.95) }
                    GradientStop { position: 0.18; color: G.alfa(esc.acento, 0.85) }
                    GradientStop { position: 0.5; color: G.alfa(esc.acento, 0.22) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathSvg { path: G.circulo(140, 140, 140) }
            }
        }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 372; grosor: 1; color: G.alfa(esc.acento, 0.18); trazo: G.circulo(372, 372, 368) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 360; periodo: 180000; grosor: 1.5; color: G.alfa(esc.acento, 0.45); trazo: G.marcas(360, 360, 342, 352, 120, 10, 330) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 322; periodo: -90000; grosor: 2; color: G.alfa(esc.acento, 0.5); trazo: G.segs(322, 322, 315, 90, 0.5, 0) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 292; periodo: 26000; grosor: 12; color: G.alfa(esc.acento, 0.55); trazo: G.segs(292, 292, 280, 3, 0.28, 10) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 292; periodo: 26000; grosor: 2; color: G.alfa(esc.acento, 0.9); trazo: G.segs(292, 292, 266, 3, 0.28, 10) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 252; periodo: -16000; grosor: 4; color: esc.acento2; trazo: G.segs(252, 252, 245, 4, 0.1, 30) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 222; periodo: 60000; grosor: 18; color: G.alfa(esc.acento, 0.16); trazo: G.segs(222, 222, 210, 48, 0.72, 0) }
        Anillo {   // segmentos encendidos = carga de CPU (de 2 a 48)
            fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 222; periodo: 60000; grosor: 18
            color: G.alfa(esc.cargaS > 0.85 ? esc.acento2 : esc.acento, 0.55)
            readonly property int encendidos: Math.max(2, Math.round(48 * Math.max(0, Math.min(1, esc.cargaS))))
            trazo: { var s = ""; for (var i = 0; i < encendidos; i++) s += G.arco(222, 222, 210, i * 7.5, 7.5 * 0.72); return s }
        }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 166; grosor: 2; color: G.alfa(esc.acento, 0.85); trazo: G.circulo(166, 166, 162) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 160; periodo: -30000; grosor: 1.2; color: G.alfa(esc.acento, 0.6); trazo: G.marcas(160, 160, 146, 154, 60, 5, 140) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 136; periodo: 8000; grosor: 6; color: G.alfa(esc.acento, 0.95); trazo: G.segs(136, 136, 130, 2, 0.35, 0) }
        Anillo { fase: esc.fase; cx: esc.cx; cy: esc.cy; radio: 60; periodo: -5000; grosor: 2; color: Qt.rgba(1, 1, 1, 0.7); trazo: G.segs(60, 60, 54, 3, 0.22, 0) }

        Column {
            anchors.horizontalCenter: brillo.horizontalCenter
            y: esc.cy + 180
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "AEGIS"; font.family: "Orbitron"; font.pixelSize: 30; font.weight: Font.Bold; font.letterSpacing: 12; color: "#eaffff" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "NÚCLEO · " + esc.estadoNucleo; font.family: "Share Tech Mono"; font.pixelSize: 15; font.letterSpacing: 4; color: esc.cargaS > 0.85 ? esc.acento2 : esc.acento }
        }

        // etiquetas con lineas guia (datos reales)
        Repeater {
            model: [
                { a: -40, t: "ENERGÍA", k: "energia" },
                { a: 40, t: "sincro", k: "sincro" },
                { a: 140, t: "ENLACE", k: "enlace" },
                { a: 200, t: "HORA LOCAL", k: "reloj" }
            ]
            Item {
                id: et
                required property var modelData
                readonly property bool der: Math.cos(modelData.a * Math.PI / 180) > 0
                readonly property real x0: esc.cx + 372 * Math.cos(modelData.a * Math.PI / 180)
                readonly property real y0: esc.cy + 372 * Math.sin(modelData.a * Math.PI / 180)
                readonly property real x1: x0 + (der ? 40 : -40)
                readonly property real y1: y0 + (modelData.a > 0 && modelData.a < 180 ? 40 : -40)
                readonly property real x2: x1 + (der ? 85 : -85)
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: G.alfa(esc.acento, 0.7); strokeWidth: 1.2; fillColor: "transparent"
                        startX: et.x0; startY: et.y0
                        PathLine { x: et.x1; y: et.y1 }
                        PathLine { x: et.x2; y: et.y1 }
                    }
                }
                Rectangle { x: et.x0 - 3; y: et.y0 - 3; width: 6; height: 6; color: esc.acento2 }
                Column {
                    x: et.der ? et.x1 + 4 : et.x2 - 4 - width
                    y: et.y1 - height - 3
                    Text {
                        anchors.right: et.der ? undefined : parent.right
                        text: et.modelData.k === "sincro" ? esc.sincroT : et.modelData.t
                        font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.75)
                    }
                    Text {
                        anchors.right: et.der ? undefined : parent.right
                        text: et.modelData.k === "reloj" ? esc.hhmmss(esc.ahora) : et.modelData.k === "energia" ? esc.energia
                            : et.modelData.k === "enlace" ? esc.enlace : esc.sincroV
                        font.family: "Orbitron"; font.pixelSize: 20; color: "#eaffff"
                    }
                }
            }
        }

        // ---------------------------------------------------------- RADAR: un eco por conexion de red real
        Item {
            id: radar
            readonly property real rr: 130
            x: 90; y: 770; width: 2 * rr; height: 2 * rr
            readonly property real barrido: (esc.fase * 360 / 4.2) % 360
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: G.alfa(esc.acento, 0.35); strokeWidth: 1; fillColor: G.alfa(esc.acento, 0.03)
                    PathSvg { path: G.circulo(radar.rr, radar.rr, radar.rr - 1) + G.circulo(radar.rr, radar.rr, radar.rr * 0.66) + G.circulo(radar.rr, radar.rr, radar.rr * 0.33)
                                    + "M 0 " + radar.rr + " L " + 2 * radar.rr + " " + radar.rr + " M " + radar.rr + " 0 L " + radar.rr + " " + 2 * radar.rr }
                }
                ShapePath {
                    strokeColor: G.alfa(esc.acento, 0.6); strokeWidth: 1; fillColor: "transparent"
                    PathSvg { path: G.marcas(radar.rr, radar.rr, radar.rr - 8, radar.rr - 1, 72, 6, radar.rr - 14) }
                }
            }
            Item {
                anchors.fill: parent
                rotation: radar.barrido
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: ConicalGradient {
                            centerX: radar.rr; centerY: radar.rr; angle: 0
                            GradientStop { position: 0.0; color: G.alfa(esc.acento, 0.55) }
                            GradientStop { position: 0.16; color: G.alfa(esc.acento, 0.0) }
                            GradientStop { position: 1.0; color: G.alfa(esc.acento, 0.0) }
                        }
                        PathSvg { path: G.circulo(radar.rr, radar.rr, radar.rr - 2) }
                    }
                    ShapePath {
                        strokeColor: esc.acento; strokeWidth: 2
                        startX: radar.rr; startY: radar.rr
                        PathLine { x: 2 * radar.rr - 2; y: radar.rr }
                    }
                }
            }
            Repeater {
                model: esc.conexiones
                Rectangle {
                    required property var modelData
                    readonly property real dd: 10 + modelData.d * (radar.rr - 20)
                    width: 7; height: 7; radius: 4
                    color: modelData.x ? esc.acento2 : esc.acento
                    x: radar.rr + dd * Math.cos(modelData.a * Math.PI / 180) - 3.5
                    y: radar.rr + dd * Math.sin(modelData.a * Math.PI / 180) - 3.5
                    opacity: esc.vivo ? Math.max(0.15, 1 - ((radar.barrido - modelData.a + 360) % 360) / 260) : 0.8
                }
            }
            Text { x: 0; y: -30; text: "RADAR · RED"; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Text { anchors.right: parent.right; y: -30; text: esc.nConex + " CONEX"; font.family: "Share Tech Mono"; font.pixelSize: 14; color: esc.acento2 }
        }

        // ---------------------------------------------------------- REGISTRO DE EVENTOS (reales)
        Item {
            x: 70; y: 80; width: 460; height: 240
            Text { y: 0; text: "REGISTRO DE EVENTOS"; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Rectangle { y: 22; width: 460; height: 1; color: G.alfa(esc.acento, 0.35) }
            Column {
                y: 30; spacing: 4
                Repeater {
                    model: lineas
                    Row {
                        required property int index
                        required property string t
                        required property string tag
                        required property string f
                        required property bool w
                        spacing: 12
                        opacity: 1 - index / 11
                        Text { text: t; font.family: "Share Tech Mono"; font.pixelSize: 14; color: G.alfa(esc.acento, 0.55) }
                        Text { text: tag; width: 30; font.family: "Share Tech Mono"; font.pixelSize: 14; color: G.alfa(esc.acento2, 0.75) }
                        Text { text: f; width: 270; elide: Text.ElideRight; font.family: "Share Tech Mono"; font.pixelSize: 14; color: "#cfefff" }
                        Text { text: w ? "[AVISO]" : "[OK]"; font.family: "Share Tech Mono"; font.pixelSize: 14; color: w ? esc.acento2 : esc.acento }
                    }
                }
            }
        }

        // ---------------------------------------------------------- NUCLEOS: uso real de cada nucleo de CPU
        Item {
            id: espectro
            x: 1330; y: 300; width: 150; height: 480
            readonly property int n: Math.max(1, esc.nucleos.length)
            readonly property real hb: Math.max(3, Math.min(14, (480 - (n - 1) * 4) / n))
            Text { y: -30; text: "NÚCLEOS · " + esc.nucleos.length; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Column {
                spacing: 4
                Repeater {
                    model: espectro.n
                    Item {
                        id: bf
                        required property int index
                        readonly property real v: esc.nucleos.length > index ? esc.nucleos[index] / 100 : 0
                        width: 150; height: espectro.hb
                        Rectangle { anchors.fill: parent; color: G.alfa(esc.acento, 0.05) }
                        Rectangle {
                            height: parent.height
                            width: Math.max(2, 150 * Math.min(1, bf.v))
                            color: G.alfa(bf.v > 0.8 ? esc.acento2 : esc.acento, 0.3 + 0.6 * bf.v)
                            Behavior on width { enabled: esc.fluido; NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------- regla inferior y marco
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: G.alfa(esc.acento, 0.4); strokeWidth: 1; fillColor: "transparent"
                PathSvg {
                    path: {
                        var s = "M 500 1010 L 1220 1010 "
                        for (var i = 0; i <= 72; i++) { var x = 500 + i * 10; s += "M " + x + " 1010 L " + x + " " + (i % 10 ? 1004 : 996) + " " }
                        return s
                    }
                }
            }
            ShapePath {
                strokeColor: G.alfa(esc.acento, 0.7); strokeWidth: 2; fillColor: "transparent"
                PathSvg { path: "M 30 110 L 30 60 L 80 60 M 1890 110 L 1890 60 L 1840 60 M 30 970 L 30 1050 L 80 1050 M 1890 970 L 1890 1050 L 1840 1050" }
            }
        }
        Rectangle { y: 1013; width: 10; height: 10; rotation: 45; color: esc.acento2; x: 495 + esc.ciclo(30) * 720 }
        Text { x: 500; y: 1022; text: "MODO " + esc.modo.toUpperCase(); font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 2; color: G.alfa(esc.acento, 0.6) }
        Text { x: 1220 - width; y: 1022; text: "AEGIS TOE v2.0"; font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 2; color: G.alfa(esc.acento, 0.6) }
    }

    // ---------------------------------------------------------- linea de escaneo (solo modo completo) y viñeta
    Rectangle {
        visible: esc.fluido
        width: parent.width; height: 140 * esc.u
        y: esc.ciclo(9) * (esc.height + 140 * esc.u) - 140 * esc.u
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.85; color: G.alfa(esc.acento, 0.05) }
            GradientStop { position: 1.0; color: G.alfa(esc.acento, 0.14) }
        }
    }
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: esc.width / 2; centerY: esc.height / 2; centerRadius: Math.max(esc.width, esc.height) * 0.75
                focalX: esc.width / 2; focalY: esc.height / 2
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
            }
            startX: 0; startY: 0
            PathLine { x: esc.width; y: 0 } PathLine { x: esc.width; y: esc.height } PathLine { x: 0; y: esc.height } PathLine { x: 0; y: 0 }
        }
    }
}
