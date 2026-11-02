#!/usr/bin/env python3
"""AEGIS HUD - motor de telemetria. Solo lectura: /proc, /sys, ip, ss, ps. Sin red, sin sudo.
  datos.py rapido  -> CPU, RAM, temperatura, bateria, red, procesos (cada ~2 s)
  datos.py lento   -> puertos en escucha, servicios caidos, identidad del equipo (cada ~20 s)
Modo demo (capturas sin datos reales de red): touch ~/.config/aegis/demo
Salida: JSON por stdout."""
import glob, json, os, platform, re, shutil, socket, subprocess, sys, time

MODO = sys.argv[1] if len(sys.argv) > 1 else 'rapido'
ESTADO = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), f'aegis-hud-{MODO}.json')
DEMO = os.path.exists(os.path.expanduser('~/.config/aegis/demo'))


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


def estado():
    try:
        with open(ESTADO) as f:
            return json.load(f)
    except Exception:
        return {}


def guardar(e):
    try:
        with open(ESTADO, 'w') as f:
            json.dump(e, f)
    except Exception:
        pass


# ------------------------------------------------------------------ rapido
def cpu(e):
    v = [int(x) for x in open('/proc/stat').readline().split()[1:9]]
    idle, total = v[3] + v[4], sum(v)
    ant, e['cpu'] = e.get('cpu'), [idle, total]
    if not ant or total == ant[1]:
        return 0.0
    return round(100.0 * (1 - (idle - ant[0]) / (total - ant[1])), 1)


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
        if v and int(v) > 0:
            return round(int(v) / 1000.0, 1)
    return None


def bateria():
    for b in glob.glob('/sys/class/power_supply/BAT*'):
        return dict(pct=int(leer(b + '/capacity', '0')), estado=leer(b + '/status'))
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
        rx = int(leer(f'/sys/class/net/{iface}/statistics/rx_bytes', '0'))
        tx = int(leer(f'/sys/class/net/{iface}/statistics/tx_bytes', '0'))
        ant = e.get('net')
        if ant and ant[0] == iface and ahora > ant[3]:
            dt = ahora - ant[3]
            out['rx'], out['tx'] = max(0, int((rx - ant[1]) / dt)), max(0, int((tx - ant[2]) / dt))
        e['net'] = [iface, rx, tx, ahora]
        if os.path.exists(f'/sys/class/net/{iface}/wireless') and shutil.which('iw'):
            m = re.search(r'SSID: (.+)', sh(['iw', 'dev', iface, 'link']))
            out['ssid'] = m.group(1).strip() if m else None
    for v in sorted(os.listdir('/sys/class/net')):
        if re.match(r'(tailscale|tun|wg|proton|nordlynx|vpn)', v) and leer(f'/sys/class/net/{v}/operstate') != 'down':
            out['vpn'] = v
            break
    if DEMO:
        out.update(ip='10.0.7.42', gw='10.0.7.1', ssid='AEGIS-NET' if out['ssid'] else None)
    return out


def procesos():
    top = []
    for l in sh(['ps', '-eo', 'comm,%cpu,%mem', '--sort=-%cpu', '--no-headers']).splitlines()[:8]:
        p = l.split()
        if len(p) >= 3 and p[0] not in ('ps', 'python3') and len(top) < 4:
            top.append(dict(n=' '.join(p[:-2])[:18], c=float(p[-2]), m=float(p[-1])))
    return top


def rapido():
    e = estado()
    du = shutil.disk_usage('/')
    d = dict(t=int(time.time()), cpu=cpu(e), ram=memoria(), temp=temperatura(), bat=bateria(), net=red(e),
             load=[float(x) for x in leer('/proc/loadavg', '0 0 0').split()[:3]],
             up=int(float(leer('/proc/uptime', '0').split()[0])),
             disco=round(100.0 * du.used / du.total, 1), libre=round(du.free / 2 ** 30), top=procesos(), nuc=os.cpu_count())
    guardar(e)
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
        local = host.startswith('127.') or host in ('[::1]',) or host.startswith('127.0.0.53')
        if p not in vistos:
            vistos[p] = dict(p=p, n=(pr.group(1) if pr else NOMBRES.get(p, ''))[:8], local=local)
        elif not local:
            vistos[p]['local'] = False
    return sorted(vistos.values(), key=lambda x: (x['local'], x['p']))[:12]


def lento():
    fallos = len([l for l in sh(['systemctl', '--failed', '--no-legend', '--plain']).splitlines() if l.strip()])
    fallos += len([l for l in sh(['systemctl', '--user', '--failed', '--no-legend', '--plain']).splitlines() if l.strip()])
    host = 'aegis-node' if DEMO else socket.gethostname()
    return dict(puertos=puertos(), fallos=fallos, host=host, kernel=platform.release().split('-')[0],
                so=(re.search(r'^PRETTY_NAME="?([^"\n]+)', leer('/etc/os-release'), re.M) or [None, 'Linux'])[1])


if __name__ == '__main__':
    print(json.dumps(lento() if MODO == 'lento' else rapido()))
