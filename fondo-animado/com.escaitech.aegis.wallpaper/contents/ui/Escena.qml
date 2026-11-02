import QtQuick
import QtQuick.Shapes
import "geo.js" as G

// AEGIS - escena del centro de mando. QtQuick puro (sin dependencias de Plasma) para poder probarla fuera.
// Se dibuja en un lienzo virtual de 1920x1080 y se escala para cubrir cualquier pantalla.
Item {
    id: esc
    property bool animar: true
    property color acento: "#3fe0ff"
    property color acento2: "#ffb347"
    property color fondo: "#02060c"
    property var ahora: new Date()
    readonly property real u: Math.max(width / 1920, height / 1080)
    readonly property real cx: 860
    readonly property real cy: 540
    clip: true

    Timer { interval: 1000; running: true; repeat: true; onTriggered: esc.ahora = new Date() }
    function p2(n) { return (n < 10 ? "0" : "") + n }
    function hhmmss(d) { return p2(d.getHours()) + ":" + p2(d.getMinutes()) + ":" + p2(d.getSeconds()) }

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
                    GradientStop { position: 0.0; color: G.alfa(esc.acento, 0.20) }
                    GradientStop { position: 0.35; color: G.alfa(esc.acento, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: 1920; y: 0 } PathLine { x: 1920; y: 1080 } PathLine { x: 0; y: 1080 } PathLine { x: 0; y: 0 }
            }
        }

        // ---------------------------------------------------------- reticula hexagonal (estatica)
        Canvas {
            id: hex
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                var c = getContext("2d"), r = 30, w = r * 1.5, h = r * Math.sqrt(3)
                c.reset()
                c.lineWidth = 1
                var col = esc.acento, k = 0
                for (var i = 0; i * w < 1920 + w; i++) {
                    for (var j = 0; j * h < 1080 + h; j++) {
                        var x = i * w, y = j * h + (i % 2 ? h / 2 : 0)
                        var dist = Math.hypot(x - esc.cx, y - esc.cy) / 1100
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

        // hexagonos que laten
        Repeater {
            model: 14
            Shape {
                id: hp
                required property int index
                readonly property real r: 26
                x: 60 + G.rnd(index * 7 + 3) * 1400; y: 80 + G.rnd(index * 11 + 5) * 900
                width: 2 * r + 2; height: 2 * r + 2
                preferredRendererType: Shape.CurveRenderer
                opacity: 0
                ShapePath {
                    strokeColor: G.alfa(esc.acento, 0.7); strokeWidth: 1.5
                    fillColor: G.alfa(esc.acento, 0.12)
                    PathSvg { path: G.hexagono(hp.r + 1, hp.r + 1, hp.r) }
                }
                SequentialAnimation on opacity {
                    running: esc.animar; loops: Animation.Infinite
                    PauseAnimation { duration: 600 + G.rnd(hp.index * 3) * 6000 }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 2000 + G.rnd(hp.index * 5) * 5000 }
                }
            }
        }

        // ---------------------------------------------------------- particulas ascendentes
        Repeater {
            model: 40
            Rectangle {
                id: pa
                required property int index
                width: 2 + G.rnd(index) * 2; height: width; radius: width / 2
                color: G.rnd(index * 9) < 0.15 ? esc.acento2 : esc.acento
                x: G.rnd(index * 3 + 1) * 1920
                opacity: 0.15 + G.rnd(index * 5) * 0.5
                NumberAnimation on y {
                    running: esc.animar; loops: Animation.Infinite
                    from: 1100; to: -20
                    duration: 14000 + G.rnd(pa.index * 13) * 22000
                }
                Component.onCompleted: y = G.rnd(index * 17) * 1080
            }
        }

        // ---------------------------------------------------------- NUCLEO
        Shape {   // resplandor del nucleo
            id: brillo
            x: esc.cx - 140; y: esc.cy - 140; width: 280; height: 280
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
            SequentialAnimation on opacity {
                running: esc.animar; loops: Animation.Infinite
                NumberAnimation { from: 0.7; to: 1; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.7; duration: 1800; easing.type: Easing.InOutSine }
            }
        }
        // anillos (radio del item = radio del trazo + margen)
        Anillo { cx: esc.cx; cy: esc.cy; radio: 372; animar: false; grosor: 1; color: G.alfa(esc.acento, 0.18); trazo: G.circulo(372, 372, 368) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 360; animar: esc.animar; periodo: 180000; grosor: 1.5; color: G.alfa(esc.acento, 0.45); trazo: G.marcas(360, 360, 342, 352, 120, 10, 330) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 322; animar: esc.animar; periodo: -90000; grosor: 2; color: G.alfa(esc.acento, 0.5); trazo: G.segs(322, 322, 315, 90, 0.5, 0) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 292; animar: esc.animar; periodo: 26000; grosor: 12; color: G.alfa(esc.acento, 0.55); trazo: G.segs(292, 292, 280, 3, 0.28, 10) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 292; animar: esc.animar; periodo: 26000; grosor: 2; color: G.alfa(esc.acento, 0.9); trazo: G.segs(292, 292, 266, 3, 0.28, 10) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 252; animar: esc.animar; periodo: -16000; grosor: 4; color: esc.acento2; trazo: G.segs(252, 252, 245, 4, 0.1, 30) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 222; animar: esc.animar; periodo: 60000; grosor: 18; color: G.alfa(esc.acento, 0.16); trazo: G.segs(222, 222, 210, 48, 0.72, 0) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 222; animar: esc.animar; periodo: 60000; grosor: 18; color: G.alfa(esc.acento, 0.5); trazo: G.segs(222, 222, 210, 6, 0.06, 0) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 166; animar: false; grosor: 2; color: G.alfa(esc.acento, 0.85); trazo: G.circulo(166, 166, 162) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 160; animar: esc.animar; periodo: -30000; grosor: 1.2; color: G.alfa(esc.acento, 0.6); trazo: G.marcas(160, 160, 146, 154, 60, 5, 140) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 136; animar: esc.animar; periodo: 8000; grosor: 6; color: G.alfa(esc.acento, 0.95); trazo: G.segs(136, 136, 130, 2, 0.35, 0) }
        Anillo { cx: esc.cx; cy: esc.cy; radio: 60; animar: esc.animar; periodo: -5000; grosor: 2; color: Qt.rgba(1, 1, 1, 0.7); trazo: G.segs(60, 60, 54, 3, 0.22, 0) }

        Column {
            anchors.horizontalCenter: brillo.horizontalCenter
            y: esc.cy + 180
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "AEGIS"; font.family: "Orbitron"; font.pixelSize: 30; font.weight: Font.Bold; font.letterSpacing: 12; color: "#eaffff" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "NÚCLEO · ESTABLE"; font.family: "Share Tech Mono"; font.pixelSize: 15; font.letterSpacing: 4; color: esc.acento }
        }

        // etiquetas con lineas guia
        Repeater {
            model: [
                { a: -40, t: "ENERGÍA", v: "100%" },
                { a: 40, t: "SINCRONÍA", v: "0.998" },
                { a: 140, t: "ENLACE", v: "ESTABLE" },
                { a: 200, t: "HORA LOCAL", v: "reloj" }
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
                    Text { text: et.modelData.t; font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.75); anchors.right: et.der ? undefined : parent.right }
                    Text { text: et.modelData.v === "reloj" ? esc.hhmmss(esc.ahora) : et.modelData.v; font.family: "Orbitron"; font.pixelSize: 20; color: "#eaffff"; anchors.right: et.der ? undefined : parent.right }
                }
            }
        }

        // ---------------------------------------------------------- RADAR (abajo izquierda)
        Item {
            id: radar
            readonly property real rr: 130
            x: 90; y: 770; width: 2 * rr; height: 2 * rr
            property real barrido: 0
            NumberAnimation on barrido { from: 0; to: 360; duration: 4200; loops: Animation.Infinite; running: esc.animar }
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
            Item {   // haz
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
            Repeater {   // ecos: se encienden cuando el haz pasa por encima
                model: 7
                Rectangle {
                    id: eco
                    required property int index
                    readonly property real ang: G.rnd(index * 19 + 2) * 360
                    readonly property real dist: 25 + G.rnd(index * 23 + 4) * (radar.rr - 40)
                    width: 7; height: 7; radius: 4
                    color: index % 3 === 0 ? esc.acento2 : esc.acento
                    x: radar.rr + dist * Math.cos(ang * Math.PI / 180) - 3.5
                    y: radar.rr + dist * Math.sin(ang * Math.PI / 180) - 3.5
                    opacity: Math.max(0, 1 - ((radar.barrido - ang + 360) % 360) / 260)
                }
            }
            Text { x: 0; y: -30; text: "RADAR · PERÍMETRO"; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Text { anchors.right: parent.right; y: -30; text: "R 2.4 KM"; font.family: "Share Tech Mono"; font.pixelSize: 14; color: esc.acento2 }
        }

        // ---------------------------------------------------------- REGISTRO (arriba izquierda)
        Item {
            id: registro
            x: 70; y: 80; width: 460; height: 240
            readonly property var frases: ["SYNC NÚCLEO", "HANDSHAKE TLS 1.3", "PAQUETE ACK", "ESCANEO PERÍMETRO", "CACHÉ L2 PURGADA", "KERNEL TICK",
                "DAEMON OK", "ENLACE ESTABLE", "TRAZA DE RUTA", "INTEGRIDAD 100%", "CIFRADO AES-256", "COLA VACÍA", "HEARTBEAT", "TELEMETRÍA RX"]
            property int n: 0
            ListModel { id: lineas }
            function nueva() {
                n++
                var hx = Math.floor(G.rnd(n * 1.7) * 0xFFFFFF).toString(16).toUpperCase()
                while (hx.length < 6) hx = "0" + hx
                var aviso = G.rnd(n * 3.1) < 0.1
                lineas.insert(0, { t: esc.hhmmss(new Date()), h: "0x" + hx, f: frases[Math.floor(G.rnd(n * 2.3) * frases.length)], w: aviso })
                if (lineas.count > 10) lineas.remove(10)
            }
            Timer { interval: 1300; running: esc.animar; repeat: true; onTriggered: registro.nueva() }
            Component.onCompleted: { for (var i = 0; i < 10; i++) nueva() }
            Text { y: 0; text: "REGISTRO DE EVENTOS"; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Rectangle { y: 22; width: 460; height: 1; color: G.alfa(esc.acento, 0.35) }
            Column {
                y: 30; spacing: 4
                Repeater {
                    model: lineas
                    Row {
                        required property int index
                        required property string t
                        required property string h
                        required property string f
                        required property bool w
                        spacing: 12
                        opacity: 1 - index / 11
                        Text { text: t; font.family: "Share Tech Mono"; font.pixelSize: 14; color: G.alfa(esc.acento, 0.55) }
                        Text { text: h; font.family: "Share Tech Mono"; font.pixelSize: 14; color: G.alfa(esc.acento, 0.4) }
                        Text { text: f; font.family: "Share Tech Mono"; font.pixelSize: 14; color: "#cfefff"; width: 210 }
                        Text { text: w ? "[AVISO]" : "[OK]"; font.family: "Share Tech Mono"; font.pixelSize: 14; color: w ? esc.acento2 : esc.acento }
                    }
                }
            }
        }

        // ---------------------------------------------------------- ESPECTRO (entre nucleo y HUD)
        Item {
            id: espectro
            x: 1330; y: 300; width: 150; height: 480
            property var v: []
            function nuevo() { var a = []; for (var i = 0; i < 24; i++) a.push(0.15 + Math.random() * 0.85); v = a }
            Timer { interval: 900; running: esc.animar; repeat: true; triggeredOnStart: true; onTriggered: espectro.nuevo() }
            Text { y: -30; text: "ESPECTRO"; font.family: "Share Tech Mono"; font.pixelSize: 14; font.letterSpacing: 3; color: G.alfa(esc.acento, 0.8) }
            Column {
                spacing: 6
                Repeater {
                    model: 24
                    Item {
                        id: bf
                        required property int index
                        width: 150; height: 14
                        Rectangle { width: 150; height: 14; color: G.alfa(esc.acento, 0.05) }
                        Rectangle {
                            height: 14
                            width: 150 * (espectro.v.length ? espectro.v[bf.index] : 0.3)
                            color: G.alfa(width > 125 ? esc.acento2 : esc.acento, 0.25 + 0.5 * width / 150)
                            Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
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
            ShapePath {   // escuadras de las esquinas
                strokeColor: G.alfa(esc.acento, 0.7); strokeWidth: 2; fillColor: "transparent"
                PathSvg { path: "M 30 110 L 30 60 L 80 60 M 1890 110 L 1890 60 L 1840 60 M 30 970 L 30 1050 L 80 1050 M 1890 970 L 1890 1050 L 1840 1050" }
            }
        }
        Rectangle {   // marcador que recorre la regla
            y: 1013; width: 10; height: 10; rotation: 45; color: esc.acento2
            NumberAnimation on x { from: 495; to: 1215; duration: 30000; loops: Animation.Infinite; running: esc.animar }
        }
        Text { x: 500; y: 1022; text: "SECTOR 07 · VECTOR 312°"; font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 2; color: G.alfa(esc.acento, 0.6) }
        Text { x: 1220 - width; y: 1022; text: "AEGIS TOE v1.0"; font.family: "Share Tech Mono"; font.pixelSize: 13; font.letterSpacing: 2; color: G.alfa(esc.acento, 0.6) }
    }

    // ---------------------------------------------------------- linea de escaneo y viñeta (pantalla completa)
    Rectangle {
        width: parent.width; height: 140 * esc.u
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.85; color: G.alfa(esc.acento, 0.05) }
            GradientStop { position: 1.0; color: G.alfa(esc.acento, 0.14) }
        }
        NumberAnimation on y { from: -140 * esc.u; to: esc.height; duration: 9000; loops: Animation.Infinite; running: esc.animar }
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
