#!/usr/bin/env python3
"""Connect to QEMU serial Unix socket, log in as root, run diagnostics."""
import socket
import time
import sys
import os

SOCK_PATH = '/tmp/nira-serial.sock'

def main():
    # Wait for boot
    print("Waiting 60s for boot...", flush=True)
    time.sleep(60)
    
    # Connect to serial socket
    print("Connecting to serial socket...", flush=True)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect(SOCK_PATH)
    
    # Read any buffered output
    time.sleep(2)
    try:
        initial = s.recv(65536)
        print(f"Initial output: {len(initial)} bytes", flush=True)
    except:
        initial = b''
    
    # Send Enter to get prompt
    s.send(b'\n')
    time.sleep(2)
    
    # Read response
    try:
        resp = s.recv(65536)
        output = resp.decode('utf-8', errors='replace')
        print(f"After Enter: {output[:200]}", flush=True)
    except:
        output = ''
    
    # Login as root
    s.send(b'root\n')
    time.sleep(3)
    try:
        resp = s.recv(65536)
        output = resp.decode('utf-8', errors='replace')
        print(f"After root: {output[:200]}", flush=True)
    except:
        pass
    
    # Run commands
    commands = [
        'journalctl -b -p err --no-pager 2>&1 | head -80',
        'echo "===FAILED==="; systemctl --failed --no-pager 2>&1',
        'echo "===COREDUMPS==="; coredumpctl list --no-pager 2>&1',
        'echo "===COREDUMP_INFO==="; coredumpctl info -1 2>&1 | head -40',
        'echo "===COMPOSITOR_LOG==="; cat /var/log/niraos/nira-compositor.log 2>&1 | tail -60',
        'echo "===SHELL_LOG==="; cat /var/log/niraos/nira-shell.log 2>&1 | tail -60',
        'echo "===SESSION_LOG==="; cat /var/log/niraos/nira-session.log 2>&1 | tail -60',
        'echo "===GREETER_LOG==="; cat /var/log/niraos/nira-greeter.log 2>&1 | tail -40',
        'echo "===INPUT_DEV==="; ls -la /dev/input/ 2>&1',
        'echo "===DRM_DEV==="; ls -la /dev/dri/ 2>&1',
        'echo "===RUNTIME==="; ls -la /run/user/1000/ 2>&1',
        'echo "===QML_ERRORS==="; journalctl -b --no-pager 2>&1 | grep -iE "qml|qt|wayland|compositor|shell|eglfs|cursor" | tail -40',
        'echo "===DONE==="',
    ]
    
    all_output = initial.decode('utf-8', errors='replace') + '\n' + output + '\n'
    
    for cmd in commands:
        print(f"Sending: {cmd[:60]}...", flush=True)
        s.send((cmd + '\n').encode())
        time.sleep(4)
        try:
            resp = s.recv(65536)
            chunk = resp.decode('utf-8', errors='replace')
            all_output += chunk
        except socket.timeout:
            pass
    
    s.close()
    
    # Save output
    with open('/tmp/serial-diag.txt', 'w') as f:
        f.write(all_output)
    
    print("\n=== FULL OUTPUT ===", flush=True)
    print(all_output, flush=True)

if __name__ == '__main__':
    main()
