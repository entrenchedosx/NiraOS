"""Log into VM via serial console and check system status."""
import socket, json, time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(10)
s.connect(('127.0.0.1', 4444))
s.recv(1024)
s.send(json.dumps({'execute': 'qmp_capabilities'}).encode() + b'\n')
time.sleep(0.5)
s.recv(4096)

def hmp(cmd):
    args = {'execute':'human-monitor-command','arguments':{'command-line':cmd}}
    s.send(json.dumps(args).encode() + b'\n')
    time.sleep(0.5)
    resp = s.recv(8192)
    return resp.decode('utf-8', errors='replace')

# Map characters to HMP key names
KEY_MAP = {
    'a': 'a', 'b': 'b', 'c': 'c', 'd': 'd', 'e': 'e', 'f': 'f', 'g': 'g',
    'h': 'h', 'i': 'i', 'j': 'j', 'k': 'k', 'l': 'l', 'm': 'm', 'n': 'n',
    'o': 'o', 'p': 'p', 'q': 'q', 'r': 'r', 's': 's', 't': 't', 'u': 'u',
    'v': 'v', 'w': 'w', 'x': 'x', 'y': 'y', 'z': 'z',
    '0': '0', '1': '1', '2': '2', '3': '3', '4': '4', '5': '5', '6': '6',
    '7': '7', '8': '8', '9': '9',
    '\n': 'ret', ' ': 'spc', '.': 'dot', '-': 'minus', '_': 'underscore',
    '/': 'slash', ':': 'shift-semicolon', '=': 'equal', '+': 'shift-equal',
    '@': 'shift-2', '!': 'shift-1', '~': 'shift-grave',
}

def type_text(text, delay=0.1):
    for ch in text:
        key = KEY_MAP.get(ch, ch)
        hmp(f'sendkey {key}')
        time.sleep(delay)

# Login as root on serial console
print("Sending login...")
type_text('root\n', 0.05)
time.sleep(2)

# Check greeter status
type_text('journalctl -u greetd.service --no-pager\n', 0.02)
time.sleep(5)

# Check processes
type_text('ps aux | grep -E "nira|greetd|greeter"\n', 0.02)
time.sleep(3)

# Check logs
type_text('cat /var/log/niraos/nira-greeter.log 2>/dev/null; echo ---; cat /tmp/nira-greeter.log 2>/dev/null\n', 0.02)
time.sleep(3)

# Check display
type_text('cat /sys/class/drm/card0/status; echo; ls -la /dev/dri/\n', 0.02)
time.sleep(3)

# Check if nira-greeter binary exists
type_text('which nira-greeter; file /usr/bin/nira-greeter\n', 0.02)
time.sleep(3)

# Try running greeter manually with debug output
type_text('QT_DEBUG_PLUGINS=1 timeout 5 nira-greeter 2>&1 | head -30\n', 0.02)
time.sleep(8)

# Take screendump after our commands
result = hmp('screendump /tmp/after-login.ppm')
print(f"Screendump: {result}")

time.sleep(2)
s.close()
print("Done")
