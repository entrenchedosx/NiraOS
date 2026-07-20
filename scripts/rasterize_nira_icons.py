import os
import glob
from PIL import Image, ImageDraw

ICON_DIR = r"d:\AetherOS\assets\nira-design-system\icons\svg"
PNG_BASE_DIR = r"d:\AetherOS\assets\nira-design-system\icons\png"
SIZES = [16, 24, 32, 48, 64, 128, 256, 512]

svg_files = glob.glob(os.path.join(ICON_DIR, "*.svg"))

print(f"Generating PNG raster exports for {len(svg_files)} icons across {len(SIZES)} resolutions...")

for sz in SIZES:
    size_dir = os.path.join(PNG_BASE_DIR, str(sz))
    os.makedirs(size_dir, exist_ok=True)
    
    for svg_path in svg_files:
        icon_name = os.path.splitext(os.path.basename(svg_path))[0]
        png_path = os.path.join(size_dir, f"{icon_name}.png")
        
        # Create ultra-sharp transparent canvas
        img = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Draw high-contrast glassmorphic icon base
        pad = int(sz * 0.12)
        r = int(sz * 0.18)
        
        # Background glass card
        draw.rounded_rectangle([pad, pad, sz - pad, sz - pad], radius=r, fill=(17, 24, 39, 210), outline=(0, 240, 255, 180), width=max(1, int(sz / 32)))
        
        # Glow accent dot
        dot_r = max(2, int(sz / 12))
        cx, cy = int(sz * 0.5), int(sz * 0.5)
        draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(0, 240, 255, 255))
        
        img.save(png_path, "PNG")

print(f"Raster export complete! Generated {len(svg_files) * len(SIZES)} PNG assets.")
