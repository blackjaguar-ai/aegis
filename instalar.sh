#!/usr/bin/env bash
# AEGIS - instalador. Solo toca tu usuario (sin sudo). Uso:
#   ./instalar.sh                 instala y aplica el tema completo (KDE Plasma 6)
#   ./instalar.sh --grafico       lo mismo con ventanas de KDE (lo que hace el doble clic)
#   ./instalar.sh --sin-aplicar   solo copia los archivos
#   ./instalar.sh --acento=N      0 cian (defecto), 1 ambar, 2 carmesi, 3 verde
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"; DEST="$HOME/.local/share/aegis"; APLICAR=1; GRAFICO=0; ACENTO=""
for a in "$@"; do case "$a" in
  --sin-aplicar) APLICAR=0;; --grafico) GRAFICO=1;; --acento=*) ACENTO="${a#--acento=}";;
  -h|--help) sed -n 2,7p "$0"; exit 0;; esac; done
[ "$GRAFICO" = 1 ] && ! command -v kdialog >/dev/null && GRAFICO=0

dialogo() { if [ "$GRAFICO" = 1 ]; then case "$1" in
    msg) kdialog --title AEGIS --msgbox "$2";; error) kdialog --title AEGIS --error "$2";;
    yesno) kdialog --title AEGIS --yes-label Instalar --no-label Cancelar --yesno "$2";; esac
  else echo "$2"; fi; }
fallo() { dialogo error "$1"; exit 1; }
plasma6() { local v; v="$(plasmashell --version 2>/dev/null | awk '{print $2}')"; [ "${v%%.*}" -ge 6 ] 2>/dev/null; }

if [ "$APLICAR" = 1 ]; then
  falta=(); for c in python3 qdbus6 kwriteconfig6 plasmashell plasma-apply-colorscheme fc-cache; do command -v "$c" >/dev/null || falta+=("$c"); done
  [ ${#falta[@]} -gt 0 ] && fallo "Faltan: ${falta[*]}. Instalalos con el gestor de paquetes de tu distribucion y vuelve a probar."
  plasma6 || fallo "AEGIS necesita KDE Plasma 6 y no lo detecto en este equipo, asi que no he tocado nada."
fi
if [ "$GRAFICO" = 1 ]; then
  dialogo yesno "Se instalara AEGIS: fondo animado, HUD de telemetria, barra, colores, fuentes y terminal.

Antes guarda una copia de tus ajustes y se puede deshacer. No usa sudo. El escritorio se recargara." || exit 0
fi

principal() {
  echo "==> Copiando a $DEST"; mkdir -p "$DEST"
  for x in src hud fondo-animado tema fuentes licencias aplicar.sh revertir.sh desinstalar.sh README.md; do rm -rf "${DEST:?}/$x"; cp -a "$AQUI/$x" "$DEST/$x"; done
  chmod +x "$DEST"/*.sh "$DEST"/hud/*/contents/code/* 2>/dev/null || true
  if [ "$APLICAR" = 1 ]; then
    echo "==> Aplicando el tema"; "$DEST/aplicar.sh" todo
    [ -n "$ACENTO" ] && "$DEST/aplicar.sh" acento "$ACENTO"
    echo "==> Reiniciando el shell de Plasma"; systemctl --user restart plasma-plasmashell.service 2>/dev/null || true
  else echo "Copiado. Aplica cuando quieras con: $DEST/aplicar.sh todo"; fi
}

if [ "$GRAFICO" = 1 ]; then
  LOG="$(mktemp /tmp/aegis-instalar.XXXXXX)"
  kdialog --title AEGIS --passivepopup "Instalando AEGIS..." 8 2>/dev/null &
  set +e; ( set -e; principal ) >"$LOG" 2>&1; rc=$?; set -e
  [ $rc -eq 0 ] || fallo "No se ha podido instalar. Tus ajustes originales no se han perdido.

$(tail -n 6 "$LOG")

Registro completo: $LOG"
  dialogo msg "AEGIS en linea. Para volver atras: $DEST/revertir.sh"
else
  principal
  [ "$APLICAR" = 1 ] && echo "AEGIS en linea. Volver atras: $DEST/revertir.sh  |  desinstalar: $DEST/desinstalar.sh"
fi
