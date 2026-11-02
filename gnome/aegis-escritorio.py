#!/usr/bin/env python3
"""AEGIS para GNOME (X11): muestra el fondo animado y el HUD como capa de escritorio, detras de tus ventanas.
Uso:  aegis-escritorio.py [--acento N] [--sin-animar]
Ajustes persistentes en ~/.config/aegis/gnome.json  ({"acento": 0, "animar": true})"""
import glob, json, os, shutil, subprocess, sys

from PySide6.QtCore import QObject, QProcess, Property, QTimer, QUrl, Signal, Slot, Qt
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQuick import QQuickView

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
CODIGO = os.path.join(RAIZ, 'hud', 'com.escaitech.aegis.hud', 'contents', 'code')
CONF = os.path.expanduser('~/.config/aegis/gnome.json')


def ajustes():
    c = {'acento': 0, 'animar': True}
    try:
        with open(CONF) as f:
            c.update(json.load(f))
    except Exception:
        pass
    a = sys.argv[1:]
    if '--acento' in a:
        c['acento'] = int(a[a.index('--acento') + 1])
    if '--sin-animar' in a:
        c['animar'] = False
    return c


class Motor(QObject):
    """Ejecuta datos.py (rapido cada 2 s, lento cada 20 s) sin bloquear la interfaz y lanza las acciones del HUD."""
    rapido = Signal(str)
    lento = Signal(str)

    def __init__(self, c):
        super().__init__()
        self._acento, self._animar = int(c['acento']), bool(c['animar'])
        self._procs = {}
        for modo, ms in (('rapido', 2000), ('lento', 20000)):
            t = QTimer(self); t.setInterval(ms); t.timeout.connect(lambda m=modo: self._lanzar(m)); t.start()
            QTimer.singleShot(50, lambda m=modo: self._lanzar(m))

    def _lanzar(self, modo):
        if modo in self._procs:   # el anterior aun no ha terminado
            return
        p = QProcess(self)
        p.finished.connect(lambda *_: self._fin(modo, p))
        self._procs[modo] = p
        p.start(sys.executable, ['-I', os.path.join(CODIGO, 'datos.py'), modo])

    def _fin(self, modo, p):
        out = bytes(p.readAllStandardOutput()).decode(errors='replace')
        self._procs.pop(modo, None); p.deleteLater()
        (self.rapido if modo == 'rapido' else self.lento).emit(out)

    @Slot(str)
    def accion(self, ident):
        QProcess.startDetached('sh', [os.path.join(CODIGO, 'accion.sh'), ident])

    def _get_acento(self): return self._acento
    def _get_animar(self): return self._animar
    def _get_margen(self): return 32   # alto de la barra superior de GNOME
    acento = Property(int, _get_acento, constant=True)
    animar = Property(bool, _get_animar, constant=True)
    margenSup = Property(int, _get_margen, constant=True)


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

    pantalla = app.primaryScreen().geometry()
    v.setGeometry(pantalla)
    if app.platformName() == 'xcb':
        marcar_como_escritorio(int(v.winId()))   # antes de mostrarla, para que el gestor de ventanas lo respete
    v.show()
    app.primaryScreen().geometryChanged.connect(v.setGeometry)
    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
