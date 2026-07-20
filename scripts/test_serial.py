#!/usr/bin/env python3
"""Test serial connection."""
import socket, time

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect('/tmp/nira-serial.sock')
time.sleep(2)

try:
    data = s.recv(65536)
    print(f"INITIAL ({len(data)} bytes):")
    print(data[:500].decode('utf-8', errors='replace'))
except Exception as e:
    print(f"INITIAL error: {e}")

s.send(b'\n')
time.sleep(2)
try:
    data = s.recv(65536)
    print(f"\nAFTER ENTER ({len(data)} bytes):")
    print(data[:500].decode('utf-8', errors='replace'))
except Exception as e:
    print(f"AFTER ENTER error: {e}")

s.close()
