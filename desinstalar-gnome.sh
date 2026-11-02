#!/usr/bin/env bash
# AEGIS para GNOME - lo detiene y lo borra (arranque automatico, entorno Python, fuentes y archivos).
#   ./desinstalar-gnome.sh          lo apaga y quita el arranque automatico (conserva archivos para reactivarlo)
#   ./desinstalar-gnome.sh --todo   ademas borra ~/.local/share/aegis, ~/.config/aegis y las fuentes
set -uo pipefail
parar() {   # detiene AEGIS por su PID exacto (no por nombre: no toca editores con el archivo abierto)
  f="${XDG_RUNTIME_DIR:-/tmp}/aegis-escritorio.pid"
  if [ -f "$f" ]; then kill "$(cat "$f")" 2>/dev/null || true; fi
  pkill -f "$HOME/.local/share/aegis/gnome/aegis-escritorio.py" 2>/dev/null || true
  sleep 1
}
parar
rm -f "$HOME/.config/autostart/aegis.desktop"
if command -v gsettings >/dev/null; then   # quita el atajo Super+Alt+A
  BASE=org.gnome.settings-daemon.plugins.media-keys; KB=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/aegis/
  lista="$(gsettings get $BASE custom-keybindings 2>/dev/null || echo '@as []')"
  nueva="$(python3 -I -c 'import ast,sys
s=sys.argv[1].replace("@as ","")
l=[x for x in (ast.literal_eval(s) if s.strip() else []) if x != sys.argv[2]]
print(str(l))' "$lista" "$KB")"
  gsettings set $BASE custom-keybindings "$nueva" 2>/dev/null
  gsettings reset-recursively $BASE.custom-keybinding:$KB 2>/dev/null
fi
if [ "${1:-}" = "--todo" ]; then
  rm -rf "$HOME/.local/share/aegis" "$HOME/.config/aegis" "$HOME/.cache/aegis" "$HOME/.local/share/fonts/aegis"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
  echo "AEGIS borrado por completo."
else echo "AEGIS apagado y fuera del arranque. Borrar todo: ./desinstalar-gnome.sh --todo"; fi
