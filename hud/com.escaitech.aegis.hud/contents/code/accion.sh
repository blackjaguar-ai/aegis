#!/bin/sh
# AEGIS - acciones del HUD.
#   accion.sh acceso N            lanza el acceso N de ~/.config/aegis/config.json
#   accion.sh terminal|monitor|red|archivos
#   accion.sh docker-start NOMBRE | docker-stop NOMBRE
#   accion.sh proyecto RUTA       abre el proyecto en VS Code (o en el gestor de archivos)
# En config.json, "cmd" admite: @terminal @monitor @red @archivos, "@term:ORDEN" (en una terminal) o cualquier orden.
AQUI="$(cd "$(dirname "$0")" && pwd)"
aviso() { command -v notify-send >/dev/null 2>&1 && notify-send -a AEGIS "AEGIS" "$1"; }

term() {
  for t in konsole gnome-terminal alacritty kitty foot xterm; do command -v "$t" >/dev/null 2>&1 && break; t=""; done
  case "$t" in
    konsole)        setsid -f konsole --hold -e sh -c "$1" ;;
    gnome-terminal) setsid -f gnome-terminal -- sh -c "$1; echo; echo '[Enter para cerrar]'; read x" ;;
    alacritty)      setsid -f alacritty --hold -e sh -c "$1" ;;
    kitty)          setsid -f kitty --hold sh -c "$1" ;;
    foot)           setsid -f foot --hold sh -c "$1" ;;
    xterm)          setsid -f xterm -hold -e sh -c "$1" ;;
    *)              aviso "No encontré ninguna terminal" ;;
  esac
}
terminal() { for t in konsole gnome-terminal alacritty kitty foot xterm; do command -v "$t" >/dev/null 2>&1 && { setsid -f "$t"; return; }; done; aviso "No encontré ninguna terminal"; }
monitor()  { for m in btop htop top; do command -v "$m" >/dev/null 2>&1 && { term "$m"; return; }; done; }
red()      { term "echo '== INTERFACES =='; ip -br addr; echo; echo '== RUTAS =='; ip route; echo; echo '== PUERTOS EN ESCUCHA =='; ss -tulpn 2>/dev/null"; }
archivos() { setsid -f xdg-open "$HOME"; }

ejecutar() {   # interpreta un "cmd" de config.json
  case "$1" in
    @terminal) terminal ;; @monitor) monitor ;; @red) red ;; @archivos) archivos ;;
    @term:*)   term "${1#@term:}" ;;
    *)         prog="$(printf '%s' "$1" | awk '{print $1}')"
               if command -v "$prog" >/dev/null 2>&1; then setsid -f sh -c "$1" >/dev/null 2>&1
               elif command -v gtk-launch >/dev/null 2>&1 && gtk-launch "$prog" >/dev/null 2>&1; then :
               else aviso "No encontré «$prog». Cambia este acceso en ~/.config/aegis/config.json"; fi ;;
  esac
}

case "$1" in
  terminal|monitor|red|archivos) "$1" ;;
  acceso)
    case "$2" in *[!0-9]*|'') exit 1 ;; esac
    cmd="$(python3 -I -c 'import json,os,sys
c=json.load(open(os.path.expanduser("~/.config/aegis/config.json")))
a=c.get("accesos") or []; i=int(sys.argv[1])
print(a[i].get("cmd","") if i < len(a) else "")' "$2" 2>/dev/null)"
    [ -n "$cmd" ] && ejecutar "$cmd" ;;
  docker-start|docker-stop)
    case "$2" in *[!A-Za-z0-9_.-]*|'') exit 1 ;; esac   # solo nombres de contenedor validos
    if docker "${1#docker-}" "$2" >/dev/null 2>&1; then aviso "Contenedor $2: ${1#docker-} OK"
    else aviso "No se pudo hacer ${1#docker-} en $2"; fi ;;
  proyecto)
    [ -d "$2" ] || exit 1
    if command -v code >/dev/null 2>&1; then setsid -f code "$2" >/dev/null 2>&1; else setsid -f xdg-open "$2"; fi ;;
esac
