#!/usr/bin/env python3
"""AEGIS para GNOME (X11): fondo animado + HUD como capa de escritorio, detras de tus ventanas.

Ahorro de energia (modo "auto"):
  pausa     una ventana maximizada o a pantalla completa tapa el escritorio: no se redibuja nada
  eco       sin cargador: 12 cuadros por segundo, sin particulas ni destellos
  completo  con cargador y escritorio visible

Uso:  aegis-escritorio.py [--acento N] [--modo auto|completo|eco] [--sin-animar]
Mostrar u ocultar el HUD:  gnome/alternar-hud.sh   (el instalador lo asigna a Super+Alt+A)
Ajustes persistentes en ~/.config/aegis/gnome.json  ({"acento": 0, "modo": "auto", "animar": true})"""
import glob, json, os, shutil, signal, subprocess, sys

from PySide6.QtCore import QObject, QProcess, Property, QTimer, QUrl, Signal, Slot, Qt
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQuick import QQuickView

try:
    from Xlib import X, display as xdisplay
    from Xlib.error import XError
except Exception:   # sin python-xlib no hay pausa automatica, todo lo demas funciona
    xdisplay = None

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
CODIGO = os.path.join(RAIZ, 'hud', 'com.escaitech.aegis.hud', 'contents', 'code')
CONF = os.path.expanduser('~/.config/aegis/gnome.json')
PIDF = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), 'aegis-escritorio.pid')


def ajustes():
    c = {'acento': 0, 'modo': 'auto', 'animar': True}
    try:
        with open(CONF) as f:
            c.update(json.load(f))
    except Exception:
        pass
    a = sys.argv[1:]
    for clave in ('--acento', '--modo'):
        if clave in a and a.index(clave) + 1 < len(a):
            v = a[a.index(clave) + 1]
            c[clave[2:]] = int(v) if clave == '--acento' else v
    if '--sin-animar' in a:
        c['animar'] = False
    return c


def corriente_ac():
    hay = False
    for p in glob.glob('/sys/class/power_supply/*'):
        try:
            if open(p + '/type').read().strip() == 'Mains':
                hay = True
                if open(p + '/online').read().strip() == '1':
                    return True
        except Exception:
            pass
    return not hay or not glob.glob('/sys/class/power_supply/BAT*')


class Vigia:
    """Detecta si alguna ventana maximizada o a pantalla completa tapa nuestra pantalla (EWMH, X11)."""

    def __init__(self, propia, rect):
        self.ok = False
        if xdisplay is None:
            return
        try:
            self.d = xdisplay.Display()
            self.root = self.d.screen().root
            self.at = {n: self.d.intern_atom(n) for n in (
                '_NET_CLIENT_LIST_STACKING', '_NET_WM_STATE', '_NET_WM_STATE_FULLSCREEN', '_NET_WM_STATE_MAXIMIZED_VERT',
                '_NET_WM_STATE_MAXIMIZED_HORZ', '_NET_WM_STATE_HIDDEN', '_NET_CURRENT_DESKTOP', '_NET_WM_DESKTOP')}
            self.propia, self.rect, self.ok = propia, rect, True
        except Exception:
            self.ok = False

    def _prop(self, w, nombre):
        p = w.get_full_property(self.at[nombre], X.AnyPropertyType)
        return list(p.value) if p else []

    def cubierto(self):
        if not self.ok:
            return False
        try:
            lista = self._prop(self.root, '_NET_CLIENT_LIST_STACKING')
            actual = (self._prop(self.root, '_NET_CURRENT_DESKTOP') or [0])[0]
            rx, ry, rw, rh = self.rect
            for wid in lista:
                if wid == self.propia:
                    continue
                w = self.d.create_resource_object('window', wid)
                try:
                    est = set(self._prop(w, '_NET_WM_STATE'))
                    if self.at['_NET_WM_STATE_HIDDEN'] in est:
                        continue
                    tapa = self.at['_NET_WM_STATE_FULLSCREEN'] in est or (
                        self.at['_NET_WM_STATE_MAXIMIZED_VERT'] in est and self.at['_NET_WM_STATE_MAXIMIZED_HORZ'] in est)
                    if not tapa:
                        continue
                    esc = self._prop(w, '_NET_WM_DESKTOP')
                    if esc and esc[0] not in (actual, 0xFFFFFFFF):
                        continue
                    g = w.get_geometry()
                    t = w.translate_coords(self.root, 0, 0)
                    x, y = -t.x, -t.y
                    cx, cy = x + g.width // 2, y + g.height // 2      # su centro cae en nuestra pantalla
                    if rx <= cx < rx + rw and ry <= cy < ry + rh:
                        return True
                except XError:
                    continue
            return False
        except Exception as e:
            if os.environ.get('AEGIS_DEBUG'):
                print('vigia error:', repr(e), flush=True)
            return False


class Motor(QObject):
    rapido = Signal(str)
    lento = Signal(str)
    modoChanged = Signal()
    hudChanged = Signal()

    def __init__(self, c):
        super().__init__()
        self._acento = int(c.get('acento', 0))
        self._preferido = c.get('modo', 'auto') if c.get('animar', True) else 'pausa'
        self._modo = 'completo'
        self._hud = True
        self._procs = {}
        self.vigia = None
        self._ac = corriente_ac()
        self.t_rapido = QTimer(self); self.t_rapido.setInterval(2000); self.t_rapido.timeout.connect(lambda: self._lanzar('rapido'))
        self.t_lento = QTimer(self); self.t_lento.setInterval(20000); self.t_lento.timeout.connect(lambda: self._lanzar('lento'))
        self.t_vigia = QTimer(self); self.t_vigia.setInterval(1500); self.t_vigia.timeout.connect(self.revisar)
        self.t_ac = QTimer(self); self.t_ac.setInterval(5000); self.t_ac.timeout.connect(self._leer_ac)
        for t in (self.t_rapido, self.t_lento, self.t_vigia, self.t_ac):
            t.start()
        QTimer.singleShot(50, lambda: self._lanzar('rapido'))
        QTimer.singleShot(80, lambda: self._lanzar('lento'))

    # ---- datos
    def _lanzar(self, modo):
        if modo in self._procs:
            return
        p = QProcess(self)
        p.finished.connect(lambda *_: self._fin(modo, p))
        self._procs[modo] = p
        p.start(sys.executable, ['-I', os.path.join(CODIGO, 'datos.py'), modo, 'gnome'])

    def _fin(self, modo, p):
        out = bytes(p.readAllStandardOutput()).decode(errors='replace')
        self._procs.pop(modo, None)
        p.deleteLater()
        (self.rapido if modo == 'rapido' else self.lento).emit(out)

    # ---- energia
    def _leer_ac(self):
        ac = corriente_ac()
        if ac != self._ac:
            self._ac = ac
            self.revisar()

    def revisar(self):
        if self._preferido == 'pausa':
            nuevo = 'pausa'
        elif self.vigia and self.vigia.cubierto():
            nuevo = 'pausa'
        elif self._preferido in ('completo', 'eco'):
            nuevo = self._preferido
        else:
            nuevo = 'completo' if self._ac else 'eco'
        if nuevo != self._modo:
            self._modo = nuevo
            if os.environ.get('AEGIS_DEBUG'):
                print('AEGIS modo ->', nuevo, flush=True)
            # tapado: no hace falta leer cada 2 s (al destaparse se retoma en el acto)
            if nuevo == 'pausa':
                self.t_rapido.setInterval(10000)
            else:
                self.t_rapido.setInterval(2000)
                self._lanzar('rapido')
            self.modoChanged.emit()

    def alternar_hud(self):
        self._hud = not self._hud
        self.hudChanged.emit()

    @Slot(str, str)
    def accion(self, ident, arg):
        QProcess.startDetached('sh', [os.path.join(CODIGO, 'accion.sh'), ident, arg])

    acento = Property(int, lambda self: self._acento, constant=True)
    margenSup = Property(int, lambda self: 32, constant=True)   # alto de la barra superior de GNOME
    modo = Property(str, lambda self: self._modo, notify=modoChanged)
    hudVisible = Property(bool, lambda self: self._hud, notify=hudChanged)


def marcar_como_escritorio(wid):
    """X11: tipo de ventana DESKTOP -> va detras de todo, sin barra de tareas ni Alt+Tab."""
    if not shutil.which('xprop'):
        return False
    r = subprocess.run(['xprop', '-id', str(wid), '-f', '_NET_WM_WINDOW_TYPE', '32a',
                        '-set', '_NET_WM_WINDOW_TYPE', '_NET_WM_WINDOW_TYPE_DESKTOP'], capture_output=True)
    return r.returncode == 0


def main():
    os.environ.setdefault('QT_QPA_PLATFORM', 'xcb')
    app = QGuiApplication(sys.argv)
    app.setApplicationName('aegis-escritorio')
    for f in glob.glob(os.path.join(RAIZ, 'fuentes', '*')):
        QFontDatabase.addApplicationFont(f)

    motor = Motor(ajustes())
    v = QQuickView()
    v.setColor(Qt.black)
    v.setFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint | Qt.WindowDoesNotAcceptFocus)
    v.setResizeMode(QQuickView.SizeRootObjectToView)
    v.rootContext().setContextProperty('motor', motor)
    v.setSource(QUrl.fromLocalFile(os.path.join(AQUI, 'Escritorio.qml')))
    if v.status() == QQuickView.Error:
        for e in v.errors():
            print('AEGIS QML:', e.toString(), file=sys.stderr)
        return 1

    g = app.primaryScreen().geometry()
    v.setGeometry(g)
    wid = int(v.winId())
    if app.platformName() == 'xcb':
        marcar_como_escritorio(wid)   # antes de mostrarla, para que el gestor de ventanas lo respete
        motor.vigia = Vigia(wid, (g.x(), g.y(), g.width(), g.height()))
    v.show()
    app.primaryScreen().geometryChanged.connect(v.setGeometry)

    # Super+Alt+A envia SIGUSR1; SIGTERM cierra limpio. El latido deja que Python atienda las senales.
    signal.signal(signal.SIGUSR1, lambda *_: QTimer.singleShot(0, motor.alternar_hud))
    signal.signal(signal.SIGTERM, lambda *_: app.quit())
    latido = QTimer()
    latido.start(300)
    latido.timeout.connect(lambda: None)
    motor.revisar()
    try:   # el atajo de teclado y el desinstalador apuntan a este PID exacto, nunca a otros procesos
        with open(PIDF, 'w') as f:
            f.write(str(os.getpid()))
    except Exception:
        pass
    rc = app.exec()
    try:
        if open(PIDF).read().strip() == str(os.getpid()):
            os.remove(PIDF)
    except Exception:
        pass
    return rc


if __name__ == '__main__':
    sys.exit(main())
