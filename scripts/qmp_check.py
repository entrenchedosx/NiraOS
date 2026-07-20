"""Check guest status via QMP."""
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
    time.sleep(1)
    resp = s.recv(4096)
    return resp.decode('utf-8', errors='replace')

cmds = ['info graphics', 'info vnc', 'info vga', 'screendump /tmp/test.ppm']
for cmd in cmds:
    print(f"CMD: {cmd}")
    print(f"  {hmp(cmd)[:200]}")
    print()

s.close()
