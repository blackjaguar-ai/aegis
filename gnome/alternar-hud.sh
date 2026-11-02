#!/bin/sh
# AEGIS - muestra u oculta el HUD (lo usa el atajo Super+Alt+A). Apunta al PID exacto de AEGIS.
f="${XDG_RUNTIME_DIR:-/tmp}/aegis-escritorio.pid"
[ -f "$f" ] && kill -USR1 "$(cat "$f")" 2>/dev/null
