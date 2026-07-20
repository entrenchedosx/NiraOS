import os

BASE_DIR = r"d:\AetherOS\assets\animations"
os.makedirs(BASE_DIR, exist_ok=True)

ANIMATIONS = {
    "boot-spinner": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="100%" height="100%">
  <defs>
    <linearGradient id="spinGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF" />
      <stop offset="100%" stop-color="#7000FF" stop-opacity="0" />
    </linearGradient>
  </defs>
  <circle cx="64" cy="64" r="48" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="8" />
  <circle cx="64" cy="64" r="48" fill="none" stroke="url(#spinGrad)" stroke-width="8" stroke-dasharray="150 150" stroke-linecap="round">
    <animateTransform attributeName="transform" type="rotate" from="0 64 64" to="360 64 64" dur="1.2s" repeatCount="indefinite" />
  </circle>
</svg>''',
    "thinking-indicator": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 32" width="100%" height="100%">
  <circle cx="32" cy="16" r="8" fill="#00F0FF">
    <animate attributeName="opacity" values="0.2;1;0.2" dur="1.5s" begin="0s" repeatCount="indefinite" />
  </circle>
  <circle cx="64" cy="16" r="8" fill="#7000FF">
    <animate attributeName="opacity" values="0.2;1;0.2" dur="1.5s" begin="0.3s" repeatCount="indefinite" />
  </circle>
  <circle cx="96" cy="16" r="8" fill="#B026FF">
    <animate attributeName="opacity" values="0.2;1;0.2" dur="1.5s" begin="0.6s" repeatCount="indefinite" />
  </circle>
</svg>'''
}

count = 0
for name, svg in ANIMATIONS.items():
    filepath = os.path.join(BASE_DIR, f"{name}.svg")
    with open(filepath, "w") as f:
        f.write(svg)
    count += 1

print(f"Generated {count} SVG animations.")
