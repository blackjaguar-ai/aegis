#!/bin/sh
# AEGIS HUD - botones de OPERACIONES. Abre la primera terminal disponible.
term() {
  for t in konsole alacritty kitty foot xterm; do command -v "$t" >/dev/null 2>&1 && break; t=""; done
  case "$t" in
    konsole)   setsid -f konsole --hold -e sh -c "$1" ;;
    alacritty) setsid -f alacritty --hold -e sh -c "$1" ;;
    kitty)     setsid -f kitty --hold sh -c "$1" ;;
    foot)      setsid -f foot --hold sh -c "$1" ;;
    xterm)     setsid -f xterm -hold -e sh -c "$1" ;;
  esac
}
case "$1" in
  terminal) for t in konsole alacritty kitty foot xterm; do command -v "$t" >/dev/null 2>&1 && { setsid -f "$t"; exit 0; }; done ;;
  monitor)  for m in btop htop top; do command -v "$m" >/dev/null 2>&1 && { term "$m"; exit 0; }; done ;;
  red)      term "echo '== INTERFACES =='; ip -br addr; echo; echo '== RUTAS =='; ip route; echo; echo '== PUERTOS EN ESCUCHA =='; ss -tulpn 2>/dev/null" ;;
  archivos) setsid -f xdg-open "$HOME" ;;
esac
