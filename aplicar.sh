#!/usr/bin/env bash
# AEGIS - aplica el tema. Uso:
#   aplicar.sh [todo|colores|fuentes|fuentes_ui|terminal|animado|hud|panel|bloqueo]
#   aplicar.sh acento N      0 cian, 1 ambar, 2 carmesi, 3 verde (fondo, HUD y bloqueo)
#   aplicar.sh demo on|off   oculta tu IP/red real en el HUD (para capturas)
# Reversible: ./revertir.sh (copia de tus ajustes en backup/original/)
set -euo pipefail
R="$HOME/.local/share/aegis"; T="$R/tema"; D="$HOME/.local/share"
WP=com.escaitech.aegis.wallpaper; HUD=com.escaitech.aegis.hud
paso="${1:-todo}"
js() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" >/dev/null; }

respaldo() { mkdir -p "$R/backup/original"
  for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc konsolerc kscreenlockerrc alacritty/alacritty.toml; do
    [ -e "$HOME/.config/$f" ] && [ ! -e "$R/backup/original/$f" ] && { mkdir -p "$R/backup/original/$(dirname "$f")"; cp "$HOME/.config/$f" "$R/backup/original/$f"; }
  done; true; }
fuentes()    { mkdir -p "$D/fonts/aegis"; cp "$R"/fuentes/* "$D/fonts/aegis/"; fc-cache -f "$D/fonts" >/dev/null 2>&1 || true; }
colores()    { mkdir -p "$D/color-schemes"; cp "$T/colores/AEGIS.colors" "$D/color-schemes/"
               plasma-apply-desktoptheme default >/dev/null 2>&1 || true   # Breeze sigue al esquema de color
               plasma-apply-colorscheme AEGIS; }
fuentes_ui() { kwriteconfig6 --file kdeglobals --group General --key font "Rajdhani,11,-1,5,500,0,0,0,0,0,0,0,0,0,0,1"
               kwriteconfig6 --file kdeglobals --group General --key menuFont "Rajdhani,11,-1,5,500,0,0,0,0,0,0,0,0,0,0,1"
               kwriteconfig6 --file kdeglobals --group General --key toolBarFont "Rajdhani,10,-1,5,500,0,0,0,0,0,0,0,0,0,0,1"
               kwriteconfig6 --file kdeglobals --group General --key fixed "Share Tech Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
               kwriteconfig6 --file kdeglobals --group WM --key activeFont "Rajdhani,11,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"
               qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }
terminal()   { mkdir -p "$D/konsole"; cp "$T"/konsole/* "$D/konsole/"
               kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile AEGIS.profile
               if command -v alacritty >/dev/null; then mkdir -p "$HOME/.config/alacritty"; cp "$T/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"; fi; }
animado()    { mkdir -p "$D/plasma/wallpapers"; ln -sfn "$R/fondo-animado/$WP" "$D/plasma/wallpapers/$WP"
               js "var ds = desktops(); for (var i = 0; i < ds.length; i++) { ds[i].wallpaperPlugin = '$WP';
                   ds[i].currentConfigGroup = ['Wallpaper', '$WP', 'General']; ds[i].writeConfig('Animar', true); }"; }
hud()        { mkdir -p "$D/plasma/plasmoids"; ln -sfn "$R/hud/$HUD" "$D/plasma/plasmoids/$HUD"
               js "var ds = desktops(); for (var i = 0; i < ds.length; i++) { var ids = ds[i].widgetIds;
                   for (var j = 0; j < ids.length; j++) { var w = ds[i].widgetById(ids[j]); if (w.type == '$HUD') w.remove(); } }"
               sleep 2   # que Plasma libere el hueco antes de colocarlo; se escala con la altura de la pantalla
               js "var g = screenGeometry(0); var k = Math.max(0.6, Math.min(2, (g.height - 68) / 954));
                   var w = Math.round(360 * k), h = Math.round(954 * k); desktops()[0].addWidget('$HUD', Math.max(0, g.width - w - 20), 48, w, h);"; }
panel()      { L=$(grep -m1 '^launchers=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | cut -d= -f2- || true)
               L="${L:-applications:systemsettings.desktop,preferred://filemanager,preferred://browser,applications:org.kde.konsole.desktop}"
               js "$(sed "s|__LANZADORES__|$L|" "$R/src/panel.js")"; }
bloqueo()    { kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin $WP
               kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group $WP --group General --key Animar true; }
acento()     { n="${1:-0}"; case "$n" in 0|1|2|3) ;; *) echo "acento: usa 0 (cian), 1 (ambar), 2 (carmesi) o 3 (verde)"; exit 1;; esac
               js "var ds = desktops(); for (var i = 0; i < ds.length; i++) {
                     ds[i].currentConfigGroup = ['Wallpaper', '$WP', 'General']; ds[i].writeConfig('Acento', $n);
                     var ids = ds[i].widgetIds; for (var j = 0; j < ids.length; j++) { var w = ds[i].widgetById(ids[j]);
                       if (w.type == '$HUD') { w.currentConfigGroup = ['General']; w.writeConfig('Acento', $n); } } }"
               kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group $WP --group General --key Acento "$n"; }
demo()       { mkdir -p "$HOME/.config/aegis"; if [ "${1:-on}" = off ]; then rm -f "$HOME/.config/aegis/demo"; else touch "$HOME/.config/aegis/demo"; fi; }

case "$paso" in
  todo) respaldo; fuentes; colores; fuentes_ui; terminal; animado; hud; panel; bloqueo ;;
  acento|demo) "$paso" "${2:-}" ;;
  colores|fuentes|fuentes_ui|terminal|animado|hud|panel|bloqueo) respaldo; "$paso" ;;
  *) sed -n 2,7p "$0"; exit 1 ;;
esac
echo "AEGIS: '$paso' aplicado. Para volver atras: $R/revertir.sh"
