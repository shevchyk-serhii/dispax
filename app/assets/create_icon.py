from math import *
import struct

def create_simple_png(width, height, bg_color):
    """Create a simple PNG with colored background"""
    
    # PNG signature
    png_data = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr_crc = 0x2144DF1C  # Pre-calculated CRC for this specific IHDR
    png_data += struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)
    
    # Create simple image data (solid color with octopus-like pattern)
    image_data = b''
    r, g, b = bg_color
    
    for y in range(height):
        row_data = b'\x00'  # Filter type: None
        for x in range(width):
            # Create octopus shape
            cx, cy = width//2, height//2
            dx, dy = x - cx, y - cy
            dist = sqrt(dx*dx + dy*dy)
            
            # Head
            if dist < 150:
                pixel = b'\xFF\x6B\x6B'  # Red octopus head
            # Eyes
            elif (abs(dx - 50) < 30 and abs(dy + 30) < 30) or (abs(dx + 50) < 30 and abs(dy + 30) < 30):
                if (abs(dx - 50) < 15 and abs(dy + 30) < 15) or (abs(dx + 50) < 15 and abs(dy + 30) < 15):
                    pixel = b'\x00\x00\x00'  # Black pupils
                else:
                    pixel = b'\xFF\xFF\xFF'  # White eyes
            # Tentacles (8 directions)
            elif dist > 150 and dist < 400:
                angle = atan2(dy, dx) + pi
                tentacle = int(angle / (2*pi/8)) % 8
                tentacle_angle = tentacle * 2*pi/8
                angle_diff = abs(angle - tentacle_angle)
                if angle_diff > pi: angle_diff = 2*pi - angle_diff
                
                if angle_diff < 0.3:  # Width of tentacle
                    pixel = b'\xE7\x4C\x3C'  # Darker red tentacles
                else:
                    pixel = bytes([r, g, b])  # Background
            else:
                pixel = bytes([r, g, b])  # Background
                
            row_data += pixel
        image_data += row_data
    
    # Compress image data (simplified - no actual compression)
    import zlib
    compressed_data = zlib.compress(image_data)
    
    # IDAT chunk
    png_data += struct.pack('>I', len(compressed_data)) + b'IDAT' + compressed_data
    idat_crc = zlib.crc32(b'IDAT' + compressed_data) & 0xffffffff
    png_data += struct.pack('>I', idat_crc)
    
    # IEND chunk
    png_data += struct.pack('>I', 0) + b'IEND' + struct.pack('>I', 0xAE426082)
    
    return png_data

# Create icon
icon_data = create_simple_png(1024, 1024, (0x4A, 0x90, 0xE2))
with open('oktopus_icon.png', 'wb') as f:
    f.write(icon_data)
    
print("Icon created\!")
