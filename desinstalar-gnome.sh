#!/usr/bin/env bash
# AEGIS para GNOME - lo detiene y lo borra (arranque automatico, entorno Python, fuentes y archivos).
#   ./desinstalar-gnome.sh          lo apaga y quita el arranque automatico (conserva archivos para reactivarlo)
#   ./desinstalar-gnome.sh --todo   ademas borra ~/.local/share/aegis, ~/.config/aegis y las fuentes
set -uo pipefail
pkill -f aegis-escritorio.py 2>/dev/null
rm -f "$HOME/.config/autostart/aegis.desktop"
if [ "${1:-}" = "--todo" ]; then
  rm -rf "$HOME/.local/share/aegis" "$HOME/.config/aegis" "$HOME/.local/share/fonts/aegis"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
  echo "AEGIS borrado por completo."
else echo "AEGIS apagado y fuera del arranque. Borrar todo: ./desinstalar-gnome.sh --todo"; fi
