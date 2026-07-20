#!/usr/bin/env python3
"""Connect to QEMU serial Unix socket, log in as nira, run diagnostics."""
import socket
import time

SOCK_PATH = '/tmp/nira-serial.sock'

def main():
    print("Connecting to serial socket...", flush=True)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect(SOCK_PATH)
    
    # Read any buffered output
    time.sleep(2)
    try:
        initial = s.recv(65536)
    except:
        initial = b''
    
    # Send Enter to get fresh prompt
    s.send(b'\n')
    time.sleep(2)
    try:
        s.recv(65536)
    except:
        pass
    
    # Login as nira
    print("Logging in as nira...", flush=True)
    s.send(b'nira\n')
    time.sleep(2)
    try:
        resp = s.recv(65536)
        print(f"After username: {resp.decode('utf-8', errors='replace')[:200]}", flush=True)
    except:
        pass
    
    # Send password
    s.send(b'nira\n')
    time.sleep(3)
    try:
        resp = s.recv(65536)
        out = resp.decode('utf-8', errors='replace')
        print(f"After password: {out[:200]}", flush=True)
    except:
        pass
    
    # Now run commands
    commands = [
        'journalctl -b -p err --no-pager 2>&1 | head -80',
        'echo "===FAILED==="; systemctl --failed --no-pager 2>&1',
        'echo "===USER_FAILED==="; systemctl --user --failed --no-pager 2>&1',
        'echo "===COREDUMPS==="; coredumpctl list --no-pager 2>&1',
        'echo "===COMPOSITOR_LOG==="; cat /var/log/niraos/nira-compositor.log 2>&1 | tail -60',
        'echo "===SHELL_LOG==="; cat /var/log/niraos/nira-shell.log 2>&1 | tail -60',
        'echo "===SESSION_LOG==="; cat /var/log/niraos/nira-session.log 2>&1 | tail -60',
        'echo "===GREETER_LOG==="; cat /var/log/niraos/nira-greeter.log 2>&1 | tail -40',
        'echo "===INPUT_DEV==="; ls -la /dev/input/ 2>&1',
        'echo "===DRM_DEV==="; ls -la /dev/dri/ 2>&1',
        'echo "===RUNTIME==="; ls -la /run/user/1000/ 2>&1',
        'echo "===QML_ERRORS==="; journalctl -b --no-pager 2>&1 | grep -iE "qml|qt|wayland|compositor|shell|eglfs|cursor" | tail -50',
        'echo "===DONE==="',
    ]
    
    all_output = ''
    
    for cmd in commands:
        print(f"CMD: {cmd[:70]}...", flush=True)
        s.send((cmd + '\n').encode())
        time.sleep(5)
        try:
            resp = s.recv(65536)
            chunk = resp.decode('utf-8', errors='replace')
            all_output += chunk + '\n'
        except socket.timeout:
            all_output += '[timeout]\n'
    
    s.close()
    
    # Save and print
    with open('/tmp/serial-diag2.txt', 'w') as f:
        f.write(all_output)
    
    print("\n" + "="*80)
    print(all_output[-4000:])

if __name__ == '__main__':
    main()
