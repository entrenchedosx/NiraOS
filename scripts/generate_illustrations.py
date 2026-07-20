import os

BASE_DIR = r"d:\AetherOS\assets\filemanager"
os.makedirs(BASE_DIR, exist_ok=True)

ILLUSTRATIONS = {
    "empty-folder": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="100%" height="100%">
  <defs>
    <linearGradient id="illGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF" stop-opacity="0.2" />
      <stop offset="100%" stop-color="#7000FF" stop-opacity="0.4" />
    </linearGradient>
  </defs>
  <circle cx="128" cy="128" r="100" fill="url(#illGrad)" />
  <path d="M 80 140 L 128 90 L 176 140 M 128 90 V 170" fill="none" stroke="#00F0FF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.8" />
  <rect x="70" y="70" width="116" height="116" rx="16" fill="none" stroke="#7000FF" stroke-width="4" stroke-dasharray="12 12" opacity="0.6" />
</svg>''',
    "permission-denied": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="100%" height="100%">
  <circle cx="128" cy="128" r="100" fill="rgba(255,46,99,0.1)" />
  <path d="M 80 170 L 128 80 L 176 170 Z" fill="none" stroke="#FF2E63" stroke-width="8" stroke-linejoin="round" />
  <line x1="128" y1="110" x2="128" y2="140" stroke="#FF2E63" stroke-width="8" stroke-linecap="round" />
  <circle cx="128" cy="160" r="4" fill="#FF2E63" />
</svg>'''
}

count = 0
for name, svg in ILLUSTRATIONS.items():
    filepath = os.path.join(BASE_DIR, f"{name}.svg")
    with open(filepath, "w") as f:
        f.write(svg)
    count += 1

print(f"Generated {count} illustration SVGs.")
