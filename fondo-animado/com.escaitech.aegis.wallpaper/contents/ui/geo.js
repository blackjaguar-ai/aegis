.pragma library
// AEGIS - geometria vectorial: genera trazos SVG (para PathSvg) de arcos, anillos y marcas.

function pt(cx, cy, r, a) {
    var t = a * Math.PI / 180
    return (cx + r * Math.cos(t)).toFixed(2) + " " + (cy + r * Math.sin(t)).toFixed(2)
}
// un arco de 'sw' grados empezando en 'a0' (grados, 0 = derecha, sentido horario)
function arco(cx, cy, r, a0, sw) {
    return "M " + pt(cx, cy, r, a0) + " A " + r + " " + r + " 0 " + (sw > 180 ? 1 : 0) + " 1 " + pt(cx, cy, r, a0 + sw) + " "
}
function circulo(cx, cy, r) {
    return "M " + pt(cx, cy, r, 0) + " A " + r + " " + r + " 0 1 1 " + pt(cx, cy, r, 180) + " A " + r + " " + r + " 0 1 1 " + pt(cx, cy, r, 360) + " "
}
// n segmentos repartidos en la circunferencia; frac = parte llena de cada hueco
function segs(cx, cy, r, n, frac, off) {
    var s = "", paso = 360 / n
    for (var i = 0; i < n; i++) s += arco(cx, cy, r, (off || 0) + i * paso, paso * frac)
    return s
}
// marcas radiales; cada 'cada' una es larga (de r0l a r1)
function marcas(cx, cy, r0, r1, n, cada, r0l) {
    var s = ""
    for (var i = 0; i < n; i++) {
        var a = i * 360 / n, ri = (cada && i % cada === 0) ? r0l : r0
        s += "M " + pt(cx, cy, ri, a) + " L " + pt(cx, cy, r1, a) + " "
    }
    return s
}
function hexagono(cx, cy, r) {
    var s = ""
    for (var i = 0; i < 6; i++) s += (i ? "L " : "M ") + pt(cx, cy, r, i * 60) + " "
    return s + "Z "
}
// marco con esquinas achaflanadas (para tarjetas)
function chaflan(w, h, c) {
    return "M " + c + " 0 L " + w + " 0 L " + w + " " + (h - c) + " L " + (w - c) + " " + h + " L 0 " + h + " L 0 " + c + " Z"
}
// pseudoaleatorio determinista: misma escena en cada arranque
function rnd(seed) { var x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x) }
function alfa(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
