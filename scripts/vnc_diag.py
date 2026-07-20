"""Debug VNC connection to QEMU."""
import socket
import struct
import sys
import time

def debug_vnc(host, port):
    print(f"Connecting to [{host}]:{port}...")
    s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect((host, port, 0, 0))
    
    data = s.recv(12)
    print(f"Server version: {data}")
    s.send(b'RFB 003.008\n')
    
    auth_count = s.recv(1)[0]
    print(f"Auth types count: {auth_count}")
    auth_types = list(s.recv(auth_count)) if auth_count > 0 else []
    print(f"Auth types: {auth_types}")
    s.send(b'\x01')
    
    result = s.recv(4)
    print(f"Security result: {result}")
    
    s.send(b'\x01')
    
    fb_width, fb_height = struct.unpack('!HH', s.recv(4))
    print(f"Framebuffer: {fb_width}x{fb_height}")
    
    fb_format = s.recv(16)
    bpp = fb_format[0]
    depth = fb_format[1]
    big_endian = fb_format[2]
    true_color = fb_format[3]
    rmax, gmax, bmax = struct.unpack('!HHH', fb_format[4:10])
    rshift, gshift, bshift = struct.unpack('BBB', fb_format[10:13])
    padding = fb_format[13:16]
    print(f"Format: bpp={bpp} depth={depth} big_endian={big_endian} true_color={true_color}")
    print(f"  Rmax={rmax} Gmax={gmax} Bmax={bmax} shifts={rshift},{gshift},{bshift} pad={padding}")
    
    name_len = struct.unpack('!I', s.recv(4))[0]
    name = s.recv(name_len).decode('latin1')
    print(f"Name: '{name}'")
    
    s.send(b'\x00' + b'\x00' + fb_format)
    
    encodings = [0, 0xFFFFFF11, 0xFFFFFF21]
    s.send(b'\x02' + b'\x00' + struct.pack('!H', len(encodings)))
    for enc in encodings:
        s.send(struct.pack('!I', enc))
    
    s.send(b'\x03' + b'\x01' + struct.pack('!HHHH', 0, 0, fb_width, fb_height))
    
    time.sleep(2)
    s.settimeout(3)
    data = b''
    try:
        data = s.recv(65536)
        print(f"Response: {len(data)} bytes")
    except socket.timeout:
        print("Timeout reading response!")
    
    if len(data) >= 4:
        msg_type = data[0]
        rect_count = struct.unpack('!H', data[2:4])[0]
        print(f"Message type: {msg_type}, rectangles: {rect_count}")
        remaining = data[4:]
        
        for i in range(rect_count):
            if len(remaining) < 12:
                print(f"  Rect {i}: incomplete header")
                break
            rx, ry, rw, rh = struct.unpack('!HHHH', remaining[:8])
            enc_type = struct.unpack('!I', remaining[8:12])[0]
            print(f"  Rect {i}: x={rx} y={ry} w={rw} h={rh} enc=0x{enc_type:08x}")
            remaining = remaining[12:]
            
            if enc_type == 0:
                px_size = rw * rh * int(bpp / 8)
                if len(remaining) >= px_size:
                    px = remaining[:px_size]
                    non_black = sum(1 for i in range(0, len(px), 4) if px[i] != 0 or px[i+1] != 0 or px[i+2] != 0)
                    print(f"    Raw pixels: {len(px)} bytes, {non_black} non-black pixels")
                    remaining = remaining[px_size:]
            elif enc_type == 0xFFFFFF11:
                # Cursor pseudo-encoding
                cursor_pixels = remaining[:rw * rh * int(bpp / 8)]
                cursor_mask = remaining[rw * rh * int(bpp / 8):rw * rh * int(bpp / 8) + ((rw + 7) // 8) * rh]
                print(f"    Cursor: {len(cursor_pixels)} px, {len(cursor_mask)} mask")
                remaining = remaining[rw * rh * int(bpp / 8) + ((rw + 7) // 8) * rh:]
            elif enc_type == 0xFFFFFF21:
                fb_width, fb_height = rw, rh
                print(f"    Desktop resize: {fb_width}x{fb_height}")
    else:
        print(f"Short response: {data}")
    
    s.close()

if __name__ == '__main__':
    debug_vnc('::1', 5902)
