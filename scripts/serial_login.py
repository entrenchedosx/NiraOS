#!/usr/bin/env python3
"""Log into VM via serial console using QMP sendkey, run diagnostics, capture output."""

import socket
import json
import time
import sys

class QMP:
    def __init__(self, host='127.0.0.1', port=4444):
        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.s.settimeout(15)
        self.s.connect((host, port))
        self.s.recv(1024)  # greeting
        self._cmd({'execute': 'qmp_capabilities'})
    
    def _cmd(self, obj):
        self.s.send((json.dumps(obj) + '\n').encode())
        time.sleep(0.05)
        try:
            return json.loads(self.s.recv(65536).decode())
        except:
            return {}
    
    def hmp(self, cmd):
        return self._cmd({'execute': 'human-monitor-command',
                         'arguments': {'command-line': cmd}})
    
    def sendkey(self, key, hold=1):
        self.hmp(f'sendkey {key}')
    
    def type_text(self, text, delay=0.03):
        KEY_MAP = {
            '\n': 'ret', '\r': 'ret', ' ': 'spc',
            '.': 'dot', '-': 'minus', '_': 'underscore',
            '/': 'slash', ':': 'shift-semicolon',
            '=': 'equal', '+': 'shift-equal',
            '@': 'shift-2', '!': 'shift-1',
            '|': 'shift-backslash', '~': 'shift-grave',
            '#': 'shift-3', ';': 'semicolon',
            ',': 'comma', '<': 'shift-comma',
            '>': 'shift-dot', '"': 'shift-apostrophe',
            "'": 'apostrophe', '\\': 'backslash',
            '?': 'shift-slash', '&': 'shift-7',
            '(': 'shift-9', ')': 'shift-0',
            '*': 'shift-8', '{': 'shift-bracketleft',
            '}': 'shift-bracketright', '[': 'bracketleft',
            ']': 'bracketright', '$': 'shift-4',
            '%': 'shift-5', '^': 'shift-6',
        }
        for ch in text:
            if ch.isupper():
                key = f'shift-{ch.lower()}'
            elif ch.isdigit():
                key = ch
            elif ch.isalpha() and ch.islower():
                key = ch
            else:
                key = KEY_MAP.get(ch, ch)
            self.sendkey(key)
            time.sleep(delay)
    
    def type_line(self, text, delay=0.03):
        self.type_text(text, delay)
        self.sendkey('ret')
    
    def screendump(self, path):
        return self.hmp(f'screendump {path}')

def main():
    q = QMP()
    
    # Step 1: Wait for login prompt, then log in as root
    print("=== Step 1: Login as root via serial console ===")
    time.sleep(1)
    
    # Send Enter to get a fresh prompt
    q.sendkey('ret')
    time.sleep(2)
    
    # Type "root" and Enter
    q.type_line('root')
    time.sleep(3)
    
    # Step 2: Run diagnostic commands
    commands = [
        'journalctl -b -p err --no-pager 2>&1 | tail -50',
        'systemctl --failed --no-pager 2>&1',
        'systemctl --user --failed --no-pager 2>&1',
        'coredumpctl list 2>&1',
        'cat /var/log/niraos/nira-compositor.log 2>&1 | tail -80',
        'cat /var/log/niraos/nira-shell.log 2>&1 | tail -80',
        'cat /var/log/niraos/nira-session.log 2>&1 | tail -80',
        'cat /var/log/niraos/nira-greeter.log 2>&1 | tail -40',
        'ls -la /run/user/1000/ 2>&1',
        'ls -la /dev/dri/ 2>&1',
        'ls -la /dev/input/ 2>&1',
        'cat /tmp/nira-compositor.log 2>&1 | tail -50',
        'cat /tmp/nira-shell.log 2>&1 | tail -50',
    ]
    
    for cmd in commands:
        print(f"\n=== CMD: {cmd[:60]}... ===")
        q.type_line(cmd, delay=0.02)
        time.sleep(3)  # Wait for output
    
    # Take a final screendump
    q.screendump('/tmp/diag.ppm')
    print("\n=== Diagnostics sent. Check serial log. ===")

if __name__ == '__main__':
    main()
