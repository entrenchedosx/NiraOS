#!/usr/bin/env python3
"""Log in as nira via serial, check nira-ai status, then manually start session."""
import socket
import time
import re

SOCK_PATH = '/tmp/nira-serial.sock'

def clean(text):
    text = re.sub(r'\x1b\][^\x07\x1b]*[\x07\x1b\\]', '', text)
    text = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', text)
    text = re.sub(r'\x1b[=>N]', '', text)
    return text

def recv(s, timeout=3):
    s.settimeout(timeout)
    out = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk: break
            out += chunk
        except socket.timeout:
            break
    return clean(out.decode('utf-8', errors='replace'))

def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(3)
    s.connect(SOCK_PATH)
    
    # Wait for boot and drain
    print("Waiting 90s for boot...", flush=True)
    time.sleep(90)
    
    # Drain initial
    recv(s, 1)
    
    # Login as nira
    s.send(b'nira\n')
    time.sleep(1)
    recv(s, 1)
    s.send(b'nira\n')
    time.sleep(3)
    out = recv(s, 3)
    print(f"Login: {'success' if 'nira@' in out else 'failed'}")
    
    # Check nira-ai status
    s.send(b'systemctl status nira-ai.service 2>&1 | head -20\n'.encode())
    time.sleep(4)
    out = recv(s, 4)
    ai_lines = [l for l in out.split('\n') if 'Active' in l or 'CGroup' in l or 'nira-ai' in l]
    print(f"nira-ai status: {' | '.join(ai_lines)}")
    
    # Check coredumpctl
    s.send(b'coredumpctl list --no-pager 2>&1 | wc -l\n'.encode())
    time.sleep(2)
    out = recv(s, 2)
    print(f"Coredumps: {out.strip()}")
    
    # Try to manually start nira-compositor and capture output
    print("Starting nira-compositor manually...", flush=True)
    s.send(b'QT_DEBUG_PLUGINS=1 timeout 10 nira-compositor 2>&1\n'.encode())
    time.sleep(12)
    out = recv(s, 12)
    
    # Filter for relevant output
    lines = out.split('\n')
    relevant = [l for l in lines if any(x in l.lower() for x in ['error', 'warn', 'fatal', 'crash', 'signal', 'eglfs', 'kms', 'drm', 'cursor', 'compositor', 'library', 'module', 'plugin'])]
    for l in relevant[:20]:
        print(f"  {l.strip()}")
    
    # Print last 20 lines of raw output
    print("\n--- Last 20 lines ---")
    for l in lines[-20:]:
        print(f"  {l.strip()}")
    
    s.close()

if __name__ == '__main__':
    main()
