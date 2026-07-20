"""Send commands to VM serial console via QMP."""
import socket, json, time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(10)
s.connect(('127.0.0.1', 4444))
data = s.recv(1024)
s.send(json.dumps({'execute': 'qmp_capabilities'}).encode() + b'\n')
time.sleep(0.5)
s.recv(4096)

def hmp(cmd):
    args = {'execute':'human-monitor-command','arguments':{'command-line':cmd}}
    s.send(json.dumps(args).encode() + b'\n')
    time.sleep(0.3)
    resp = s.recv(4096)
    return resp.decode('utf-8', errors='replace')

# Method 1: Use HMP to send data to serial port
# We can use the HMP 'sendkey' to send keys the guest's keyboard
# The serial console is not the keyboard input, but we can try
# sending to the greeter on VT1 via keyboard

# Alternative: we can use 'qemu-io' on serial device, but that's complex

# Let's try checking if the greeter is running by examining the serial log
# The serial log file is /tmp/nira-serial.log in WSL

# Actually, let me try sending data through the serial port via the chardev
# The serial0 is a file-based chardev (serial file:/tmp/nira-serial.log)
# So we CAN'T send input through it. It's read-only from guest side.

# Let me just take a screendump and analyze it
result = hmp('screendump /tmp/final.ppm')
print(f"Screendump: {result}")

# Copy to Windows
hmp('human-monitor-command { "command-line": "shell cp /tmp/final.ppm /mnt/d/AetherOS/" }')
# That won't work, let's just access via WSL mount

s.close()
print("Done")
