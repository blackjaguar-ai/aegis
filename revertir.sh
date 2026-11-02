#!/usr/bin/env bash
# AEGIS - vuelve a tus ajustes anteriores (backup/original). No borra los archivos del tema.
set -uo pipefail
R="$HOME/.local/share/aegis"; B="$R/backup/original"; C="$HOME/.config"
for f in kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc konsolerc kscreenlockerrc alacritty/alacritty.toml; do
  [ -e "$B/$f" ] && cp "$B/$f" "$C/$f"
done
[ -e "$B/kscreenlockerrc" ] || kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin --delete 2>/dev/null
esq=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme); [ -n "$esq" ] && plasma-apply-colorscheme "$esq" >/dev/null 2>&1
tema=$(kreadconfig6 --file plasmarc --group Theme --key name); plasma-apply-desktoptheme "${tema:-default}" >/dev/null 2>&1
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
systemctl --user restart plasma-plasmashell.service 2>/dev/null || (kquitapp6 plasmashell; sleep 1; kstart plasmashell >/dev/null 2>&1 &)
echo "AEGIS revertido. Si algo se ve a medias, cierra sesion y vuelve a entrar."
