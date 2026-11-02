#!/usr/bin/env bash
# AEGIS para GNOME (sesion X11). Solo toca tu usuario, sin sudo. Uso:
#   ./instalar-gnome.sh            instala, activa el arranque automatico y lo lanza
#   ./instalar-gnome.sh --acento=N 0 cian, 1 ambar, 2 carmesi, 3 verde
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"; DEST="$HOME/.local/share/aegis"; ACENTO=0
for a in "$@"; do case "$a" in --acento=*) ACENTO="${a#--acento=}";; -h|--help) sed -n 2,4p "$0"; exit 0;; esac; done
PY=/usr/bin/python3   # el python del sistema, no el de conda

[ "${XDG_SESSION_TYPE:-}" = x11 ] || { echo "AEGIS necesita una sesion X11 (elige 'Ubuntu en Xorg' al iniciar sesion)."; exit 1; }
falta=()
$PY -c 'import venv, ensurepip' 2>/dev/null || falta+=(python3-venv)
ldconfig -p | grep -q libxcb-cursor.so.0 || falta+=(libxcb-cursor0)
command -v xprop >/dev/null || falta+=(x11-utils)
if [ ${#falta[@]} -gt 0 ]; then echo "Falta: ${falta[*]}"; echo "Instala con:  sudo apt install ${falta[*]}"; echo "y vuelve a ejecutar ./instalar-gnome.sh"; exit 1; fi

echo "==> Copiando a $DEST"; mkdir -p "$DEST"
for x in gnome hud fondo-animado fuentes licencias tema instalar-gnome.sh desinstalar-gnome.sh README.md; do rm -rf "${DEST:?}/$x"; cp -a "$AQUI/$x" "$DEST/$x"; done
chmod +x "$DEST"/*.sh "$DEST"/gnome/*.py "$DEST"/hud/*/contents/code/*

if [ ! -x "$DEST/venv/bin/python" ]; then echo "==> Creando entorno Python propio (descarga PySide6, ~1-2 min)"; $PY -m venv "$DEST/venv"; fi
"$DEST/venv/bin/pip" install -q --upgrade pip
"$DEST/venv/bin/pip" install -q "PySide6-Essentials>=6.6"

echo "==> Fuentes"; mkdir -p "$HOME/.local/share/fonts/aegis"; cp "$DEST"/fuentes/* "$HOME/.local/share/fonts/aegis/"; fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
mkdir -p "$HOME/.config/aegis"; printf '{"acento": %s, "animar": true}\n' "$ACENTO" > "$HOME/.config/aegis/gnome.json"

echo "==> Arranque automatico"; mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/aegis.desktop" <<EOD
[Desktop Entry]
Type=Application
Name=AEGIS
Comment=Centro de mando holografico
Exec=$DEST/venv/bin/python $DEST/gnome/aegis-escritorio.py
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
EOD

pkill -f aegis-escritorio.py 2>/dev/null || true
nohup "$DEST/venv/bin/python" "$DEST/gnome/aegis-escritorio.py" >"$HOME/.config/aegis/gnome.log" 2>&1 &
sleep 4
if pgrep -f aegis-escritorio.py >/dev/null; then echo "AEGIS en linea. Quitarlo: $DEST/desinstalar-gnome.sh"
else echo "No arranco. Ultimas lineas del registro:"; tail -n 15 "$HOME/.config/aegis/gnome.log"; exit 1; fi
