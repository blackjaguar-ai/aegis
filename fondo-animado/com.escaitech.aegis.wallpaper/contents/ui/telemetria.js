.pragma library
// AEGIS - traduce una lectura de datos.py ("rapido") a lo que muestra la escena.

function tasa(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/S" : b >= 1024 ? Math.round(b / 1024) + " KB/S" : b + " B/S" }

// linea de telemetria real para el registro; rota entre metricas
function linea(d, n) {
    var op = []
    var load = (d.load || [0])[0] || 0
    op.push({ tag: "CPU", f: "CPU " + Math.round(d.cpu || 0) + "%" + (d.ghz ? " · " + d.ghz.toFixed(1) + " GHZ" : "") + " · CARGA " + load.toFixed(2) })
    if (d.ram) op.push({ tag: "MEM", f: "RAM " + d.ram.usado + "/" + d.ram.total + " GB · DISCO " + Math.round(d.disco || 0) + "%" })
    var g = d.gpu
    var gtxt = !g ? "" : g.estado === "dormida" ? " · GPU EN REPOSO" : (g.temp !== undefined && g.temp !== null) ? " · GPU " + Math.round(g.temp) + "°C " + Math.round(g.uso || 0) + "%" : " · GPU ACTIVA"
    if (d.temp !== null && d.temp !== undefined) op.push({ tag: "TMP", f: "TEMP " + Math.round(d.temp) + "°C" + gtxt })
    if (d.net) op.push({ tag: "NET", f: "RX " + tasa(d.net.rx || 0) + " · TX " + tasa(d.net.tx || 0) + " · " + ((d.conex || {}).n || 0) + " CONEX" })
    if (d.bat) op.push({ tag: "PWR", f: "BATERÍA " + d.bat.pct + "%" + (d.bat.w > 0 ? " · " + d.bat.w.toFixed(1) + " W" : "") + (d.ac ? " · CARGANDO" : "") })
    return op[n % op.length]
}

function energia(d) {
    if (!d.bat) return "AC"
    return d.bat.pct + "%" + (d.ac ? " ⚡" : "")
}

function enlace(d) {
    var n = d.net || {}
    if (!n.iface) return "SIN ENLACE"
    return (n.vpn ? "VPN · " : "") + (n.ssid || "CABLEADA").toUpperCase().substring(0, 14)
}

function carga(d) { return ((d.load || [0])[0] || 0).toFixed(2) }

function nucleo(d) {
    var c = Math.round(d.cpu || 0)
    return c >= 90 ? "CARGA MÁXIMA" : "CPU " + c + "%"
}
