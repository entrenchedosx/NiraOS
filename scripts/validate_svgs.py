import os
import glob
import xml.etree.ElementTree as ET

BASE_DIR = r"d:\AetherOS\assets"
svg_files = glob.glob(os.path.join(BASE_DIR, "**", "*.svg"), recursive=True)

errors = []
validated = 0

for filepath in svg_files:
    # Skip wallpapers for strict 64x64 grid check
    if "wallpapers" in filepath:
        continue
        
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
        
        # Check xmlns
        if "http://www.w3.org/2000/svg" not in root.tag:
            errors.append(f"{filepath}: Missing or incorrect xmlns")
            
        # Check viewBox
        if root.attrib.get("viewBox") != "0 0 64 64":
            errors.append(f"{filepath}: Incorrect viewBox (Expected '0 0 64 64', got '{root.attrib.get('viewBox')}')")
            
        # Check stroke widths for consistency
        for elem in root.iter():
            stroke_width = elem.attrib.get("stroke-width")
            if stroke_width:
                try:
                    val = float(stroke_width)
                    if val > 4 or val < 1:
                        errors.append(f"{filepath}: Unusual stroke-width {val} (Should be 1-4)")
                except ValueError:
                    pass
                    
        validated += 1
    except ET.ParseError as e:
        errors.append(f"{filepath}: Invalid XML format -> {e}")
    except Exception as e:
        errors.append(f"{filepath}: Unexpected error -> {e}")

print(f"Validation complete for {validated} SVG master assets.")
if errors:
    print(f"Found {len(errors)} consistency errors:")
    for err in errors:
        print(f" - {err}")
else:
    print("All SVGs passed quality gate: Clean XML, consistent viewBox, normalized strokes, proper namespace.")
