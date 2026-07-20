#!/usr/bin/env python3
"""Log in, check AI daemon crash, start compositor, capture output."""
import socket, time, re

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect('/tmp/nira-serial.sock')

def recv(timeout=3):
    s.settimeout(timeout)
    out = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk: break
            out += chunk
        except socket.timeout:
            break
    text = out.decode('utf-8', errors='replace')
    text = re.sub(r'\x1b\][^\x07\x1b]*[\x07\x1b\\]', '', text)
    text = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', text)
    return text

# Wait for login prompt
print("Waiting for boot...", flush=True)
time.sleep(60)
out = recv(3)
s.send('\n'.encode())
time.sleep(2)
out = recv(3)
print(f"Prompt found: {'NiraOS login' in out}")

# Login
s.send('nira\n'.encode())
time.sleep(2)
out = recv(3)
s.send('nira\n'.encode())
time.sleep(3)
out = recv(5)
print(f"Login: {'OK' if 'nira@' in out else 'FAILED'}")

if 'nira@' not in out:
    print(f"Login output: {out[-200:]}")
    s.close()
    exit(1)

# Check nira-ai
s.send('systemctl is-active nira-ai.service\n'.encode())
time.sleep(2)
out = recv(3)
print(f"nira-ai: {out.strip()[-40:]}")

# Start compositor
print("Starting nira-compositor...", flush=True)
s.send('QT_DEBUG_PLUGINS=1 timeout 15 nira-compositor 2>&1 | tail -40\n'.encode())
time.sleep(20)
out = recv(15)
lines = out.split('\n')
print(f"Compositor output ({len(lines)} lines):")
for l in lines[-30:]:
    stripped = l.strip()
    if stripped and 'nira@' not in stripped and '$' not in stripped and stripped not in ['']:
        print(f"  {stripped}")

# Check input devices
s.send('ls /dev/input/\n'.encode())
time.sleep(1)
out = recv(2)
print(f"Input: {out.strip()[:100]}")

# Check DRM
s.send('ls /dev/dri/\n'.encode())
time.sleep(1)
out = recv(2)
print(f"DRM: {out.strip()[:100]}")

s.close()
