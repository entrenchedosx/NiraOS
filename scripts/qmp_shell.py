"""Send commands to VM via QMP and read serial response."""
import socket, json, time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(10)
s.connect(('127.0.0.1', 4444))
s.recv(1024)
s.send(json.dumps({'execute': 'qmp_capabilities'}).encode() + b'\n')
time.sleep(0.5)
resp = s.recv(4096)

def hmp(cmd):
    args = {'execute':'human-monitor-command','arguments':{'command-line':cmd}}
    s.send(json.dumps(args).encode() + b'\n')
    time.sleep(1)
    resp = s.recv(4096)
    return resp.decode('utf-8', errors='replace')

# Send keys to the serial console via HMP sendkey
# The escape character is \r (enter) at the end
def type_text(text):
    for ch in text:
        key = ch
        if ch == '\n':
            key = 'ret'
        elif ch == ' ':
            key = 'spc'
        elif ch == '/':
            key = 'slash'
        elif ch == '-':
            key = 'minus'
        elif ch == '_':
            key = 'underscore'
        elif ch == '.':
            key = 'dot'
        elif ch == '|':
            key = 'pipe'
        hmp(f'sendkey {key}')

def type_line(text):
    for ch in text:
        hmp(f'sendkey {ch}')
    hmp('sendkey ret')

if __name__ == '__main__':
    # Take screendump first
    result = hmp('screendump /tmp/after.ppm')
    print(f"Screendump: {result}")
    
    # Read serial output
    result = hmp('qemu-io g:serial0 "read -v 0 256"')
    print(f"Serial: {result[:300]}")
    
    s.close()
