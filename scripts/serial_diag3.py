#!/usr/bin/env python3
"""Connect to serial, log in as nira, run diagnostics with audit suppressed."""
import socket
import time

SOCK_PATH = '/tmp/nira-serial.sock'

def main():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(8)
    s.connect(SOCK_PATH)
    
    # Drain initial output
    time.sleep(3)
    try: s.recv(65536)
    except: pass
    
    # Get fresh prompt
    s.send(b'\n')
    time.sleep(2)
    try: s.recv(65536)
    except: pass
    
    # Login as nira
    s.send(b'nira\n')
    time.sleep(2)
    try: s.recv(65536)
    except: pass
    
    s.send(b'nira\n')
    time.sleep(3)
    try: s.recv(65536)
    except: pass
    
    # Disable audit messages on this terminal
    s.send(b'stty -echo 2>/dev/null; export TERM=dumb\n')
    time.sleep(1)
    try: s.recv(65536)
    except: pass
    
    # Run each command and collect output
    cmds = [
        'journalctl -b -p err --no-pager 2>&1 | head -80',
        'systemctl --failed --no-pager 2>&1',
        'systemctl --user --failed --no-pager 2>&1',
        'coredumpctl list --no-pager 2>&1',
        'cat /var/log/niraos/nira-compositor.log 2>&1 | tail -60',
        'cat /var/log/niraos/nira-shell.log 2>&1 | tail -60',
        'cat /var/log/niraos/nira-session.log 2>&1 | tail -80',
        'cat /var/log/niraos/nira-greeter.log 2>&1 | tail -40',
        'ls -la /dev/input/ 2>&1',
        'ls -la /dev/dri/ 2>&1',
        'ls -la /run/user/1000/ 2>&1',
        'journalctl -b --no-pager 2>&1 | grep -iE "nira-compositor|nira-shell|eglfs|wayland|cursor|qml.*error" | tail -50',
        'journalctl -b --no-pager 2>&1 | grep -iE "segfault|killed|signal|crash" | tail -20',
    ]
    
    all_output = ""
    for cmd in cmds:
        # Send command with a unique marker
        marker = f"CMD_{abs(hash(cmd))%100000}"
        s.send(f'echo {marker}_START; {cmd}; echo {marker}_END\n'.encode())
        time.sleep(6)
        try:
            resp = s.recv(131072)
            chunk = resp.decode('utf-8', errors='replace')
            all_output += chunk
        except socket.timeout:
            all_output += f"[TIMEOUT for {cmd}]\n"
    
    s.close()
    
    # Save
    with open('/tmp/diag3.txt', 'w') as f:
        f.write(all_output)
    print(all_output[-6000:])

if __name__ == '__main__':
    main()
