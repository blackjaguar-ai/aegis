#!/usr/bin/env bash
# AEGIS - revierte tus ajustes y borra lo instalado.
#   ./desinstalar.sh          revierte y borra plugins, esquema, perfiles y fuentes
#   ./desinstalar.sh --todo   ademas borra ~/.local/share/aegis y ~/.config/aegis (guarda copia del backup en /tmp)
set -uo pipefail
R="$HOME/.local/share/aegis"; D="$HOME/.local/share"
"$R/revertir.sh"
rm -rf "$D/plasma/wallpapers/com.escaitech.aegis.wallpaper" "$D/plasma/plasmoids/com.escaitech.aegis.hud" \
       "$D/color-schemes/AEGIS.colors" "$D/konsole/AEGIS.colorscheme" "$D/konsole/AEGIS.profile" "$D/fonts/aegis"
fc-cache -f "$D/fonts" >/dev/null 2>&1
if [ "${1:-}" = "--todo" ]; then cp -r "$R/backup" /tmp/aegis-backup-final 2>/dev/null; rm -rf "$HOME/.config/aegis" "$R"
  echo "Borrado todo. Copia de tus ajustes originales en /tmp/aegis-backup-final"; fi
echo "AEGIS desinstalado."
