#!/bin/bash
# Connect to the serial console, log in as root, run diagnostics
SOCK=/tmp/nira-serial.sock
OUT=/tmp/serial-diag-output.txt

# Wait for login prompt
echo "Waiting for boot..."
sleep 60

# Use socat to interact with the serial socket
# Send login and commands, capture all output
{
    sleep 2
    echo ""
    sleep 1
    echo "root"
    sleep 3
    echo "journalctl -b -p err --no-pager 2>&1 | head -80"
    sleep 5
    echo "===FAILED==="
    echo "systemctl --failed --no-pager 2>&1"
    sleep 3
    echo "===COREDUMPS==="
    echo "coredumpctl list --no-pager 2>&1"
    sleep 3
    echo "===COREDUMP_INFO==="
    echo "coredumpctl info -1 2>&1 | head -40"
    sleep 3
    echo "===COMPOSITOR_LOG==="
    echo "cat /var/log/niraos/nira-compositor.log 2>&1 | tail -60"
    sleep 3
    echo "===SHELL_LOG==="
    echo "cat /var/log/niraos/nira-shell.log 2>&1 | tail -60"
    sleep 3
    echo "===SESSION_LOG==="
    echo "cat /var/log/niraos/nira-session.log 2>&1 | tail -60"
    sleep 3
    echo "===GREETER_LOG==="
    echo "cat /var/log/niraos/nira-greeter.log 2>&1 | tail -40"
    sleep 3
    echo "===INPUT_DEVICES==="
    echo "ls -la /dev/input/ 2>&1"
    sleep 2
    echo "===DRM_DEVICES==="
    echo "ls -la /dev/dri/ 2>&1"
    sleep 2
    echo "===RUNTIME_DIR==="
    echo "ls -la /run/user/1000/ 2>&1"
    sleep 2
    echo "===QML_ERRORS==="
    echo "journalctl -b --no-pager 2>&1 | grep -iE 'qml|qt|wayland|compositor|shell|eglfs|cursor' | tail -40"
    sleep 5
    echo "===DONE==="
    sleep 2
    echo "exit"
    sleep 1
} | socat - UNIX-CONNECT:$SOCK > $OUT 2>&1 &

# Wait for socat to finish
SOCAT_PID=$!
echo "socat PID: $SOCAT_PID"
wait $SOCAT_PID 2>/dev/null || true

echo "=== Output saved to $OUT ==="
cat $OUT
