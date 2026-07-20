"""Capture VNC screenshot from QEMU."""
import socket
import struct

def capture_vnc(host, port, filename):
    s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    s.settimeout(30)
    s.connect((host, port, 0, 0))

    assert s.recv(12) == b'RFB 003.008\n'
    s.send(b'RFB 003.008\n')

    auth_count = ord(s.recv(1))
    auth_types = s.recv(auth_count) if auth_count > 0 else b''
    if 1 in auth_types or auth_count == 0:
        s.send(struct.pack('B', 1))
    else:
        s.send(struct.pack('B', 1))

    assert s.recv(4) == b'\x00\x00\x00\x00'

    s.send(b'\x01')  # ClientInit: share desktop

    fb_width, fb_height = struct.unpack('!HH', s.recv(4))
    fb_format = s.recv(16)
    name_len = struct.unpack('!I', s.recv(4))[0]
    name = s.recv(name_len).decode()
    print(f"Framebuffer: {fb_width}x{fb_height} name='{name}'")

    s.send(b'\x00' + struct.pack('!B', 0) + fb_format)

    s.send(b'\x02' + struct.pack('!B', 0) + struct.pack('!H', 3))
    s.send(struct.pack('!I', 0))
    s.send(struct.pack('!I', 0xFFFFFF11))
    s.send(struct.pack('!I', 0xFFFFFF21))

    s.send(b'\x03' + struct.pack('!B', 1) + struct.pack('!HHHH', 0, 0, fb_width, fb_height))

    pixels = bytearray()
    remaining = b''

    while True:
        data = remaining
        while len(data) < 4:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk

        if len(data) < 4:
            break

        msg_type = data[0]
        if msg_type != 0:
            break

        rect_count = struct.unpack('!H', data[2:4])[0]
        remaining = data[4:]

        for _ in range(rect_count):
            while len(remaining) < 12:
                chunk = s.recv(4096)
                if not chunk:
                    raise Exception("Connection closed")
                remaining += chunk

            rx, ry, rw, rh = struct.unpack('!HHHH', remaining[:8])
            enc_type = struct.unpack('!I', remaining[8:12])[0]
            remaining = remaining[12:]

            if enc_type == 0:
                expected = rw * rh * 4
                while len(remaining) < expected:
                    chunk = s.recv(4096)
                    if not chunk:
                        raise Exception("Connection closed")
                    remaining += chunk
                pixels.extend(remaining[:expected])
                remaining = remaining[expected:]
            elif enc_type == 0xFFFFFF21:
                fb_width, fb_height = rw, rh
                print(f"Resized to {fb_width}x{fb_height}")
            elif enc_type == 0xFFFFFF11:
                cursor_data = remaining[:rh * 4 + (rw + 7) // 8 * rh]
                remaining = remaining[len(cursor_data):]
                pass
            else:
                pass

        s.send(b'\x03' + struct.pack('!B', 1) + struct.pack('!HHHH', 0, 0, fb_width, fb_height))

    s.close()

    with open(filename + '.ppm', 'wb') as f:
        f.write(f'P6\n{fb_width} {fb_height}\n255\n'.encode())
        for i in range(0, len(pixels), 4):
            b = pixels[i]
            g = pixels[i+1]
            r = pixels[i+2]
            f.write(bytes([r, g, b]))

    print(f"Saved {filename}.ppm ({fb_width}x{fb_height}, {len(pixels)} bytes)")

if __name__ == '__main__':
    import sys
    fn = sys.argv[1] if len(sys.argv) > 1 else 'screenshot'
    capture_vnc('::1', 5902, fn)
