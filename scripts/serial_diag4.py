#!/usr/bin/env python3
"""Run single command on serial and capture output."""
import socket
import time
import sys

SOCK_PATH = '/tmp/nira-serial.sock'

def run_cmd(s, cmd, wait=8):
    """Send command and capture output until prompt returns."""
    # Clear buffer
    try: s.recv(65536)
    except: pass
    
    # Send command
    s.send((cmd + '\n').encode())
    time.sleep(wait)
    
    # Read response
    output = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk:
                break
            output += chunk
        except socket.timeout:
            break
    
    # Clean ANSI escape sequences
    text = output.decode('utf-8', errors='replace')
    # Remove OSC sequences (terminal title)
    import re
    text = re.sub(r'\x1b\][^\x07\x1b]*[\x07\x1b\\]', '', text)
    # Remove CSI sequences
    text = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', text)
    # Remove other escape sequences
    text = re.sub(r'\x1b[=>N]', '', text)
    # Remove the command echo and prompt
    lines = text.split('\n')
    # Skip first line (command echo) and last line (prompt)
    clean = '\n'.join(lines[1:-1]) if len(lines) > 2 else text
    return clean.strip()

def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(3)
    s.connect(SOCK_PATH)
    
    # Drain
    time.sleep(2)
    try: s.recv(65536)
    except: pass
    
    # Login
    s.send(b'\n')
    time.sleep(1)
    try: s.recv(65536)
    except: pass
    
    s.send(b'nira\n')
    time.sleep(2)
    try: s.recv(65536)
    except: pass
    
    s.send(b'nira\n')
    time.sleep(3)
    try: s.recv(65536)
    except: pass
    
    # Now run commands
    cmds = [
        ('ERRORS', 'journalctl -b -p err --no-pager 2>&1 | head -60'),
        ('FAILED_SVC', 'systemctl --failed --no-pager 2>&1'),
        ('FAILED_USER', 'systemctl --user --failed --no-pager 2>&1'),
        ('COREDUMPS', 'coredumpctl list --no-pager 2>&1'),
        ('COMPOSITOR_LOG', 'cat /var/log/niraos/nira-compositor.log 2>&1 | tail -50'),
        ('SHELL_LOG', 'cat /var/log/niraos/nira-shell.log 2>&1 | tail -50'),
        ('SESSION_LOG', 'cat /var/log/niraos/nira-session.log 2>&1 | tail -60'),
        ('INPUT', 'ls /dev/input/ 2>&1'),
        ('DRM', 'ls /dev/dri/ 2>&1'),
        ('QML', 'journalctl -b --no-pager 2>&1 | grep -i "nira-compositor\|nira-shell\|eglfs\|QML\|Qt" | tail -30'),
    ]
    
    results = {}
    for name, cmd in cmds:
        print(f"--- {name} ---", flush=True)
        result = run_cmd(s, cmd, wait=8)
        results[name] = result
        print(result[:2000], flush=True)
        print("", flush=True)
    
    s.close()
    
    # Save all results
    with open('/tmp/diag_clean.txt', 'w') as f:
        for name, result in results.items():
            f.write(f"=== {name} ===\n{result}\n\n")

if __name__ == '__main__':
    main()
