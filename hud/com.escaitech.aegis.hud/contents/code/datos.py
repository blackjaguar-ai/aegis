#!/usr/bin/env python3
"""AEGIS - motor de telemetria. Solo lectura, sin sudo.
  datos.py rapido [etiqueta]  CPU por nucleo, RAM, temperatura, GPU (solo si ya esta despierta), bateria,
                              red, conexiones, procesos y eventos del sistema (cada ~2 s)
  datos.py lento  [etiqueta]  puertos, servicios caidos, perfil de energia, docker, proyectos git,
                              clima (cache de 30 min) y accesos directos (cada ~20 s)
Configuracion: ~/.config/aegis/config.json (se crea con valores por defecto la primera vez).
La unica llamada de red es el clima (Open-Meteo, sin clave). Para desactivarla: "clima": null.
Modo demo (capturas sin tus datos de red): touch ~/.config/aegis/demo
Salida: JSON por stdout."""
import glob, hashlib, ipaddress, json, os, platform, re, shutil, socket, subprocess, sys, time, urllib.request

MODO = sys.argv[1] if len(sys.argv) > 1 else 'rapido'
ETQ = re.sub(r'[^a-z0-9_-]', '', (sys.argv[2] if len(sys.argv) > 2 else 'hud').lower()) or 'hud'
RUN = os.environ.get('XDG_RUNTIME_DIR', '/tmp')
ESTADO = os.path.join(RUN, f'aegis-{ETQ}-{MODO}.json')
CONF_DIR = os.path.expanduser('~/.config/aegis')
CONF = os.path.join(CONF_DIR, 'config.json')
CACHE = os.path.expanduser('~/.cache/aegis')
DEMO = os.path.exists(os.path.join(CONF_DIR, 'demo'))


def sh(cmd, t=2):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def leer(p, d=''):
    try:
        with open(p) as f:
            return f.read().strip()
    except Exception:
        return d


def jcarga(p, d=None):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return d


def jguarda(p, x):
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        tmp = p + '.tmp'
        with open(tmp, 'w') as f:
            json.dump(x, f)
        os.replace(tmp, p)
    except Exception:
        pass


def ev(tag, texto, aviso=False):
    return dict(tag=tag, f=texto, w=aviso)


# ------------------------------------------------------------------ configuracion
ZONAS = {  # zona horaria -> (lat, lon, ciudad) para el clima por defecto
    'America/Lima': (-12.05, -77.04, 'LIMA'), 'America/Bogota': (4.71, -74.07, 'BOGOTÁ'),
    'America/Mexico_City': (19.43, -99.13, 'CDMX'), 'America/Santiago': (-33.45, -70.67, 'SANTIAGO'),
    'America/Argentina/Buenos_Aires': (-34.6, -58.38, 'BUENOS AIRES'), 'America/Caracas': (10.48, -66.9, 'CARACAS'),
    'America/Guayaquil': (-2.17, -79.92, 'GUAYAQUIL'), 'America/La_Paz': (-16.5, -68.15, 'LA PAZ'),
    'America/Montevideo': (-34.9, -56.16, 'MONTEVIDEO'), 'Europe/Madrid': (40.42, -3.7, 'MADRID'),
}
ACCESOS = [
    dict(t='TERMINAL', s='shell', cmd='@terminal'),
    dict(t='MONITOR', s='btop/htop', cmd='@monitor'),
    dict(t='VS CODE', s='editor', cmd='code'),
    dict(t='CHROME', s='web', cmd='google-chrome'),
    dict(t='CLAUDE', s='ia', cmd='claude-desktop'),
    dict(t='JUPYTER', s='conda', cmd="@term:bash -ic 'jupyter lab'"),
    dict(t='RED', s='ss · ip', cmd='@red'),
    dict(t='ARCHIVOS', s='~', cmd='xdg-open ~'),
]


def config():
    c = jcarga(CONF)
    if isinstance(c, dict):
        return c
    tz = os.path.realpath('/etc/localtime').split('zoneinfo/')[-1]
    z = ZONAS.get(tz)
    c = dict(clima=dict(lat=z[0], lon=z[1], ciudad=z[2]) if z else None, accesos=ACCESOS,
             proyectos=['~/proyectos', '~/dev', '~/code', '~/src', '~/projects', '~/git', '~/Documentos', '~/Documents', '~'])
    jguarda(CONF, c)
    return c


# ------------------------------------------------------------------ rapido
def cpus(e):
    act = {}
    for l in open('/proc/stat'):
        if not l.startswith('cpu'):
            break
        p = l.split()
        v = [int(x) for x in p[1:9]]
        act[p[0]] = [v[3] + v[4], sum(v)]
    ant, e['cpus'] = e.get('cpus', {}), act

    def pct(k):
        a, b = ant.get(k), act[k]
        if not a or b[1] == a[1]:
            return 0.0
        return round(max(0.0, 100.0 * (1 - (b[0] - a[0]) / (b[1] - a[1]))), 1)
    nuc = sorted((k for k in act if k != 'cpu'), key=lambda k: int(k[3:]))
    return pct('cpu'), [pct(k) for k in nuc]


def ghz():
    f = [int(x) for x in (leer(p) for p in glob.glob('/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq')) if x.isdigit()]
    return round(sum(f) / len(f) / 1e6, 2) if f else None


def memoria():
    m = {}
    for l in open('/proc/meminfo'):
        k, v = l.split(':')
        m[k] = int(v.split()[0])
    tot, disp = m['MemTotal'], m['MemAvailable']
    return dict(pct=round(100.0 * (tot - disp) / tot, 1), usado=round((tot - disp) / 1048576, 1), total=round(tot / 1048576, 1))


def temperatura():
    for h in glob.glob('/sys/class/hwmon/hwmon*'):
        if leer(h + '/name') in ('k10temp', 'coretemp', 'zenpower', 'cpu_thermal'):
            t = leer(h + '/temp1_input')
            if t:
                return round(int(t) / 1000.0, 1)
    for t in sorted(glob.glob('/sys/class/thermal/thermal_zone*/temp')):
        v = leer(t)
        if v.lstrip('-').isdigit() and int(v) > 0:
            return round(int(v) / 1000.0, 1)
    return None


def gpu(e):
    """Solo consulta nvidia-smi si la GPU ya esta despierta: llamarlo con la GPU dormida la despierta y gasta bateria."""
    for dev in glob.glob('/sys/bus/pci/devices/*'):
        if leer(dev + '/vendor') != '0x10de' or not leer(dev + '/class').startswith('0x03'):
            continue
        if leer(dev + '/power/runtime_status', 'active') != 'active':
            return dict(estado='dormida')
        if not shutil.which('nvidia-smi'):
            return dict(estado='activa')
        n = e.get('gpu_n', 0)
        e['gpu_n'] = n + 1
        if n % 3 and e.get('gpu'):   # cada ~6 s basta
            return e['gpu']
        salida = sh(['nvidia-smi', '--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw',
                     '--format=csv,noheader,nounits'], 3).splitlines()
        o = [x.strip() for x in salida[0].split(',')] if salida else []

        def num(x):
            try:
                return float(x)
            except Exception:
                return None
        g = dict(estado='activa')
        if len(o) >= 6:
            g.update(nombre=o[0].replace('NVIDIA GeForce ', '').replace(' Laptop GPU', ''), uso=num(o[1]), temp=num(o[2]),
                     vram=num(o[3]), vram_t=num(o[4]), w=num(o[5]))
        e['gpu'] = g
        return g
    return None


def corriente_ac():
    hay = False
    for p in glob.glob('/sys/class/power_supply/*'):
        if leer(p + '/type') == 'Mains':
            hay = True
            if leer(p + '/online') == '1':
                return True
    return not hay or not glob.glob('/sys/class/power_supply/BAT*')


def bateria():
    for b in glob.glob('/sys/class/power_supply/BAT*'):
        cap, est = int(leer(b + '/capacity', '0') or 0), leer(b + '/status')

        def n(x):
            v = leer(b + '/' + x)
            return int(v) if v.lstrip('-').isdigit() else 0
        uv = n('voltage_now')
        pw = n('power_now') or (n('current_now') * uv // 1000000 if uv else 0)
        en = n('energy_now') or (n('charge_now') * uv // 1000000 if uv else 0)
        ef = n('energy_full') or (n('charge_full') * uv // 1000000 if uv else 0)
        mins = 0
        if pw > 0:
            if est == 'Discharging':
                mins = int(en / pw * 60)
            elif est == 'Charging':
                mins = int(max(0, ef - en) / pw * 60)
        return dict(pct=cap, estado=est, w=round(pw / 1e6, 1), min=mins)
    return None


def red(e):
    r = sh(['ip', '-o', 'route', 'show', 'default'])
    m = re.search(r'dev (\S+)', r)
    iface = m.group(1) if m else None
    gw = re.search(r'via (\S+)', r)
    out = dict(iface=iface, ip=None, gw=gw.group(1) if gw else None, ssid=None, rx=0, tx=0, vpn=None)
    ahora = time.time()
    if iface:
        m = re.search(r'inet (\S+?)/', sh(['ip', '-o', '-4', 'addr', 'show', iface]))
        out['ip'] = m.group(1) if m else None
        rx = int(leer(f'/sys/class/net/{iface}/statistics/rx_bytes', '0') or 0)
        tx = int(leer(f'/sys/class/net/{iface}/statistics/tx_bytes', '0') or 0)
        ant = e.get('net')
        if ant and ant[0] == iface and ahora > ant[3]:
            dt = ahora - ant[3]
            out['rx'], out['tx'] = max(0, int((rx - ant[1]) / dt)), max(0, int((tx - ant[2]) / dt))
        e['net'] = [iface, rx, tx, ahora]
        if os.path.exists(f'/sys/class/net/{iface}/wireless'):
            if shutil.which('iw'):
                m = re.search(r'SSID: (.+)', sh(['iw', 'dev', iface, 'link']))
                out['ssid'] = m.group(1).strip() if m else None
            if not out['ssid'] and shutil.which('nmcli'):
                for l in sh(['nmcli', '-t', '-f', 'ACTIVE,SSID', 'dev', 'wifi']).splitlines():
                    if l.startswith('yes:') or l.startswith('sí:'):
                        out['ssid'] = l.split(':', 1)[1]
                        break
    for v in sorted(os.listdir('/sys/class/net')):
        if re.match(r'(tailscale|tun|wg|proton|nordlynx|vpn)', v) and leer(f'/sys/class/net/{v}/operstate') != 'down':
            out['vpn'] = v
            break
    if DEMO:
        out.update(ip='10.0.7.42', gw='10.0.7.1', ssid='AEGIS-NET' if out['ssid'] else None)
    return out


def privada(ip):
    try:
        a = ipaddress.ip_address(ip)
        return a.is_private or a.is_link_local
    except Exception:
        return True


def conexiones():
    """Conexiones TCP establecidas -> ecos del radar. Angulo y distancia salen de un hash de la IP: estables entre lecturas."""
    vistos, lista = set(), []
    for l in sh(['ss', '-tnH', 'state', 'established']).splitlines():
        c = l.split()
        if len(c) < 4:
            continue
        peer = c[-1]
        ip = peer.rsplit(':', 1)[0].strip('[]')
        if ip.startswith('127.') or ip in ('::1',) or ip.startswith('::ffff:127.'):
            continue
        ip = ip.replace('::ffff:', '')
        if ip in vistos:
            continue
        vistos.add(ip)
        h = hashlib.md5(ip.encode()).digest()
        lista.append(dict(a=round(h[0] * 360 / 256, 1), d=round(0.2 + 0.75 * h[1] / 255, 3), x=not privada(ip)))
    return dict(n=len(vistos), ext=sum(1 for x in lista if x['x']), l=lista[:24])


def procesos():
    top = []
    for l in sh(['ps', '-eo', 'comm,%cpu,%mem', '--sort=-%cpu', '--no-headers']).splitlines()[:8]:
        p = l.split()
        if len(p) >= 3 and p[0] not in ('ps', 'python3') and len(top) < 4:
            top.append(dict(n=' '.join(p[:-2])[:18], c=float(p[-2]), m=float(p[-1])))
    return top


def usb():
    out = {}
    for d in glob.glob('/sys/bus/usb/devices/*'):
        b = os.path.basename(d)
        if b.startswith('usb') or ':' in b:
            continue
        n = leer(d + '/product')
        if n:
            out[b] = n[:28]
    return out


def eventos_rapido(e, d):
    """Compara con la lectura anterior y devuelve solo lo que cambio."""
    a = e.get('ev')
    usbs = usb()
    a0 = a or {}
    t = d['temp'] or 0
    # histeresis: el aviso salta al cruzar el umbral alto y solo se rearma al bajar del umbral bajo
    act = dict(ac=d['ac'], ssid=d['net']['ssid'], iface=d['net']['iface'], vpn=d['net']['vpn'], usb=usbs,
               bat=(d['bat'] or {}).get('pct'), tcal=t >= 85 or (bool(a0.get('tcal')) and t >= 78),
               ccal=d['cpu'] >= 90 or (bool(a0.get('ccal')) and d['cpu'] >= 70),
               gpu=(d['gpu'] or {}).get('estado'))
    e['ev'] = act
    if not a:
        return [ev('SYS', 'TELEMETRÍA EN LÍNEA')]
    out = []
    if act['ac'] != a.get('ac'):
        out.append(ev('PWR', 'CARGADOR CONECTADO' if act['ac'] else 'FUNCIONANDO CON BATERÍA', not act['ac']))
    if act['iface'] != a.get('iface') or act['ssid'] != a.get('ssid'):
        out.append(ev('NET', ('ENLACE ' + (act['ssid'] or act['iface'] or '')).strip() if act['iface'] else 'SIN ENLACE', not act['iface']))
    if act['vpn'] != a.get('vpn'):
        out.append(ev('NET', 'VPN ACTIVA · ' + act['vpn'] if act['vpn'] else 'VPN DESCONECTADA'))
    for k, n in usbs.items():
        if k not in a.get('usb', {}):
            out.append(ev('USB', 'CONECTADO · ' + n.upper()))
    for k, n in a.get('usb', {}).items():
        if k not in usbs:
            out.append(ev('USB', 'RETIRADO · ' + n.upper()))
    b0, b1 = a.get('bat'), act['bat']
    if b0 is not None and b1 is not None and not act['ac']:
        for u in (20, 10, 5):
            if b0 > u >= b1:
                out.append(ev('PWR', f'BATERÍA BAJA · {b1}%', True))
    if act['tcal'] and not a.get('tcal'):
        out.append(ev('TMP', f'TEMPERATURA ALTA · {d["temp"]:.0f}°C', True))
    if act['ccal'] and not a.get('ccal'):
        out.append(ev('CPU', f'CARGA ALTA · {d["cpu"]:.0f}%', True))
    if act['gpu'] != a.get('gpu') and act['gpu'] and a.get('gpu'):
        out.append(ev('GPU', 'GPU DESPIERTA' if act['gpu'] == 'activa' else 'GPU EN REPOSO'))
    return out


def rapido():
    e = jcarga(ESTADO, {})
    du = shutil.disk_usage('/')
    total, nuc = cpus(e)
    d = dict(t=int(time.time()), cpu=total, nucleos=nuc, ghz=ghz(), ram=memoria(), temp=temperatura(), gpu=gpu(e),
             ac=corriente_ac(), bat=bateria(), net=red(e), conex=conexiones(),
             load=[float(x) for x in leer('/proc/loadavg', '0 0 0').split()[:3]],
             up=int(float(leer('/proc/uptime', '0').split()[0])),
             disco=round(100.0 * du.used / du.total, 1), libre=round(du.free / 2 ** 30), top=procesos(), nuc=os.cpu_count())
    d['eventos'] = eventos_rapido(e, d)
    jguarda(ESTADO, e)
    return d


# ------------------------------------------------------------------ lento
NOMBRES = {22: 'ssh', 53: 'dns', 80: 'http', 443: 'https', 631: 'cups', 3000: 'dev', 3306: 'mysql', 5000: 'dev', 5173: 'vite',
           5432: 'pg', 6379: 'redis', 8000: 'dev', 8080: 'http', 8888: 'jupyter', 1716: 'kdeconn', 5900: 'vnc', 27017: 'mongo'}


def puertos():
    vistos = {}
    for l in sh(['ss', '-tlnpH']).splitlines():
        c = l.split()
        if len(c) < 5:
            continue
        m = re.search(r':(\d+)$', c[3])
        if not m:
            continue
        p, host = int(m.group(1)), c[3].rsplit(':', 1)[0]
        pr = re.search(r'\(\("([^"]+)"', l)
        local = host.startswith('127.') or host == '[::1]'
        if p not in vistos:
            vistos[p] = dict(p=p, n=(pr.group(1) if pr else NOMBRES.get(p, ''))[:8], local=local)
        elif not local:
            vistos[p]['local'] = False
    return sorted(vistos.values(), key=lambda x: (x['local'], x['p']))[:12]


def docker():
    if not shutil.which('docker'):
        return dict(ok=False, msg='DOCKER NO INSTALADO', c=[])
    try:
        r = subprocess.run(['docker', 'ps', '-a', '--format', '{{json .}}'], capture_output=True, text=True, timeout=4)
    except Exception:
        return dict(ok=False, msg='DOCKER NO RESPONDE', c=[])
    if r.returncode:
        msg = 'SIN PERMISO · AÑÁDETE AL GRUPO docker' if 'permission denied' in r.stderr.lower() else 'DAEMON APAGADO'
        return dict(ok=False, msg=msg, c=[])
    c = []
    for l in r.stdout.splitlines():
        try:
            j = json.loads(l)
        except Exception:
            continue
        c.append(dict(n=j.get('Names', '')[:22], img=j.get('Image', '').split('@')[0][-24:], on=j.get('State') == 'running',
                      st=j.get('Status', '')[:22]))
    c.sort(key=lambda x: (not x['on'], x['n']))
    return dict(ok=True, msg='', c=c[:8], on=sum(1 for x in c if x['on']), total=len(c))


def proyectos(e, conf):
    ahora = time.time()
    if e.get('repos_t', 0) < ahora - 600:
        encontrados = []
        for r in conf.get('proyectos') or []:
            r = os.path.expanduser(r)
            if not os.path.isdir(r):
                continue
            prof_max = 1 if r == os.path.expanduser('~') else 3
            for dp, dn, _ in os.walk(r):
                if '.git' in dn:
                    if dp not in encontrados:
                        encontrados.append(dp)
                    dn[:] = []
                    continue
                if dp[len(r):].count(os.sep) >= prof_max:
                    dn[:] = []
                    continue
                dn[:] = [x for x in dn if not x.startswith('.') and x not in ('node_modules', 'venv', 'anaconda3', 'miniconda3', 'snap', 'target', '__pycache__')]
            if len(encontrados) > 30:
                break
        e['repos_l'], e['repos_t'] = encontrados[:30], ahora
    out = []
    for r in e.get('repos_l', []):
        b = sh(['git', '-C', r, 'rev-parse', '--abbrev-ref', 'HEAD']).strip()
        if not b:
            continue
        st = sh(['git', '-C', r, 'status', '--porcelain']).splitlines()
        ab = sh(['git', '-C', r, 'rev-list', '--left-right', '--count', '@{u}...HEAD']).split()
        t = sh(['git', '-C', r, 'log', '-1', '--format=%ct']).strip()
        out.append(dict(n=os.path.basename(r)[:20], b=b[:16], ruta=r, sucio=len(st), atras=int(ab[0]) if len(ab) == 2 else 0,
                        adelante=int(ab[1]) if len(ab) == 2 else 0, t=int(t) if t.isdigit() else 0))
    out.sort(key=lambda x: -x['t'])
    return out[:6]


WMO = {0: 'DESPEJADO', 1: 'CASI DESPEJADO', 2: 'PARCIAL', 3: 'NUBLADO', 45: 'NIEBLA', 48: 'NIEBLA', 51: 'LLOVIZNA', 53: 'LLOVIZNA',
       55: 'LLOVIZNA', 61: 'LLUVIA', 63: 'LLUVIA', 65: 'LLUVIA FUERTE', 71: 'NIEVE', 73: 'NIEVE', 75: 'NIEVE', 80: 'CHUBASCOS',
       81: 'CHUBASCOS', 82: 'CHUBASCOS', 95: 'TORMENTA', 96: 'TORMENTA', 99: 'TORMENTA'}


def clima(conf):
    c = conf.get('clima')
    if not isinstance(c, dict) or 'lat' not in c:
        return None
    p = os.path.join(CACHE, 'clima.json')
    cache = jcarga(p)
    if cache and cache.get('t', 0) > time.time() - 1800 and cache.get('ciudad') == c.get('ciudad'):
        return cache
    url = ('https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s'
           '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto') % (c['lat'], c['lon'])
    try:
        with urllib.request.urlopen(url, timeout=4) as r:
            j = json.load(r)['current']
        out = dict(t=int(time.time()), ciudad=c.get('ciudad', ''), temp=round(j['temperature_2m']), hum=j.get('relative_humidity_2m'),
                   viento=round(j.get('wind_speed_10m', 0)), cond=WMO.get(int(j.get('weather_code', -1)), '—'))
        jguarda(p, out)
        return out
    except Exception:
        return cache   # sin red: el ultimo dato bueno


def perfil():
    if shutil.which('powerprofilesctl'):
        p = sh(['powerprofilesctl', 'get']).strip()
        if p:
            return p
    return leer('/sys/firmware/acpi/platform_profile') or None


def lento():
    e = jcarga(ESTADO, {})
    conf = config()
    fallos = len([l for l in sh(['systemctl', '--failed', '--no-legend', '--plain']).splitlines() if l.strip()])
    fallos += len([l for l in sh(['systemctl', '--user', '--failed', '--no-legend', '--plain']).splitlines() if l.strip()])
    so = re.search(r'^PRETTY_NAME="?([^"\n]+)', leer('/etc/os-release'), re.M)
    dk = docker()
    pts = puertos()
    eventos = []
    antes = e.get('dk')
    ahora = {x['n']: x['on'] for x in dk['c']}
    if antes is not None:
        for n, on in ahora.items():
            if antes.get(n) != on:
                eventos.append(ev('DCK', ('INICIADO · ' if on else 'DETENIDO · ') + n.upper(), not on))
    e['dk'] = ahora
    exp = sorted(x['p'] for x in pts if not x['local'])
    if e.get('exp') is not None:
        for p in exp:
            if p not in e['exp']:
                eventos.append(ev('NET', f'PUERTO EXPUESTO · :{p}', True))
    e['exp'] = exp
    accesos = [dict(t=str(a.get('t', '?'))[:10], s=str(a.get('s', ''))[:12]) for a in (conf.get('accesos') or ACCESOS)][:8]
    out = dict(puertos=pts, fallos=fallos, host='aegis-node' if DEMO else socket.gethostname(),
               kernel=platform.release().split('-')[0], so=so.group(1) if so else 'Linux', perfil=perfil(),
               docker=dk, proyectos=proyectos(e, conf), clima=clima(conf), accesos=accesos, eventos=eventos)
    jguarda(ESTADO, e)
    return out


if __name__ == '__main__':
    print(json.dumps(lento() if MODO == 'lento' else rapido(), ensure_ascii=False))
