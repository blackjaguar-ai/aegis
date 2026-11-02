# AEGIS

> Tema de escritorio para **KDE Plasma 6** con estética de centro de mando holográfico: núcleo de anillos animado, radar, registro de eventos y un HUD con telemetría real de tu equipo.

![AEGIS en cian](capturas/escritorio-cian.png)

![Animación](capturas/animacion.gif)

| Ámbar | Carmesí |
|---|---|
| ![Ámbar](capturas/escritorio-ambar.png) | ![Carmesí](capturas/escritorio-carmesi.png) |

## Qué incluye

| Pieza | Qué es |
|---|---|
| Fondo animado | Plugin de Plasma vectorial (QML). Tiene un núcleo de 12 anillos que giran a distinta velocidad, un radar con barrido y ecos, un registro de eventos en vivo, un espectro, una retícula hexagonal con celdas que laten, partículas y una línea de escaneo. Se escala a cualquier resolución sin perder nitidez y también se usa en la pantalla de bloqueo. |
| HUD | Widget con reloj, **sistemas** (CPU, RAM y temperatura en medidores, gráfica de CPU, carga, disco y batería), **enlace** (IP, gateway, SSID, VPN y tráfico ↓↑ con gráfica), **procesos** (los que más CPU usan), **perímetro** (puertos en escucha; los expuestos a la red salen en ámbar, y avisa de servicios caídos) y **operaciones** (terminal, monitor, red y archivos). |
| Barra | Panel superior: inicio, apps, reloj centrado y bandeja reducida. |
| Colores | Esquema `AEGIS` para todas las ventanas y para Plasma (Breeze lo sigue). |
| Terminal | Perfil y paleta para Konsole, y paleta para Alacritty si la tienes. |
| Tipografía | Orbitron (titulares), Rajdhani (interfaz) y Share Tech Mono (datos y terminal). Todas con licencia OFL. |

El motor de datos (`hud/.../code/datos.py`) **solo lee** `/proc`, `/sys`, `ip`, `ss` y `ps`. No usa la red ni `sudo`.

## Instalar

**Con doble clic:** descomprime el paquete y abre **«Instalar AEGIS»**.

**Desde la terminal:**

```bash
tar xzf aegis-1.0.tar.gz && cd aegis-1.0
./instalar.sh                 # acento cian
./instalar.sh --acento=1      # 0 cian, 1 ámbar, 2 carmesí, 3 verde
```

Necesita KDE Plasma 6, `python3`, `qdbus6` y `kwriteconfig6`. Solo toca tu usuario y, antes de cambiar nada, guarda una copia de tus ajustes en `~/.local/share/aegis/backup/original/`.

## Uso

```bash
~/.local/share/aegis/aplicar.sh acento 2     # cambia el acento del fondo, el HUD y el bloqueo
~/.local/share/aegis/aplicar.sh demo on      # el HUD oculta tu IP y tu red real (para capturas)
~/.local/share/aegis/aplicar.sh hud          # recoloca el HUD si cambias de resolución
~/.local/share/aegis/revertir.sh             # vuelve a tus ajustes anteriores
~/.local/share/aegis/desinstalar.sh --todo   # lo borra todo
```

El acento y la animación también se cambian desde *Configurar escritorio y fondo de pantalla* y desde la configuración del widget.

## Estructura

```
fondo-animado/   plugin de fondo (Escena.qml es QtQuick puro: se puede probar sin Plasma)
hud/             widget HUD (Panel.qml es QtQuick puro; main.qml lo conecta con datos.py)
tema/            esquema de color, Konsole y Alacritty
src/panel.js     disposición de la barra superior
```

## Créditos y licencia

La arquitectura sigue a [PixelZen](https://github.com/mosqui1988/pixelzen): plugins QML, un motor de datos de solo lectura y scripts reversibles. El código y el arte de AEGIS son originales.
El código está bajo licencia GPL-3.0-or-later, y las fuentes tienen licencia SIL OFL 1.1 (ver `licencias/`).
