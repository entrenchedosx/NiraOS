import os

BASE_DIR = r"d:\AetherOS\assets\wallpapers"
os.makedirs(BASE_DIR, exist_ok=True)

WALLPAPERS = {
    "nira-dark-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <defs>
    <radialGradient id="darkBg" cx="50%" cy="50%" r="75%">
      <stop offset="0%" stop-color="#151C33" />
      <stop offset="100%" stop-color="#05070D" />
    </radialGradient>
  </defs>
  <rect width="3840" height="2160" fill="url(#darkBg)" />
  <circle cx="1920" cy="1080" r="800" fill="rgba(0,240,255,0.02)" />
  <circle cx="1920" cy="1080" r="1200" fill="none" stroke="rgba(112,0,255,0.05)" stroke-width="2" />
</svg>''',

    "nira-light-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <defs>
    <radialGradient id="lightBg" cx="50%" cy="50%" r="75%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </radialGradient>
  </defs>
  <rect width="3840" height="2160" fill="url(#lightBg)" />
  <path d="M 0 1080 Q 1920 0 3840 1080 T 0 1080" fill="rgba(0,240,255,0.05)" />
</svg>''',

    "nira-minimal-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#0B0F19" />
  <line x1="1920" y1="0" x2="1920" y2="2160" stroke="#1E293B" stroke-width="2" />
  <line x1="0" y1="1080" x2="3840" y2="1080" stroke="#1E293B" stroke-width="2" />
</svg>''',

    "nira-cyber-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#0B0F19" />
  <path d="M 0 2160 L 1920 1080 L 3840 2160" fill="none" stroke="#00F0FF" stroke-width="4" opacity="0.3" />
  <path d="M 0 0 L 1920 1080 L 3840 0" fill="none" stroke="#B026FF" stroke-width="4" opacity="0.3" />
</svg>''',

    "nira-aurora-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <defs>
    <linearGradient id="auroraGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF" stop-opacity="0.2" />
      <stop offset="100%" stop-color="#7000FF" stop-opacity="0" />
    </linearGradient>
    <filter id="blur"><feGaussianBlur stdDeviation="150" /></filter>
  </defs>
  <rect width="3840" height="2160" fill="#05070D" />
  <path d="M -500 500 C 1000 0, 2000 2000, 4000 1000 L 4000 2500 L -500 2500 Z" fill="url(#auroraGrad)" filter="url(#blur)" />
</svg>''',

    "nira-glass-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#0B0F19" />
  <rect x="920" y="580" width="2000" height="1000" rx="40" fill="rgba(255,255,255,0.02)" stroke="rgba(255,255,255,0.1)" stroke-width="2" />
</svg>''',

    "nira-abstract-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#0B0F19" />
  <circle cx="1000" cy="800" r="500" fill="#7000FF" opacity="0.1" />
  <polygon points="2000,500 3000,1800 1000,1800" fill="#00F0FF" opacity="0.05" />
</svg>''',

    "nira-space-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#000000" />
  <circle cx="1920" cy="1080" r="400" fill="#111827" stroke="#334155" stroke-width="2" />
  <circle cx="100" cy="200" r="2" fill="#FFF" opacity="0.5" />
  <circle cx="3500" cy="1900" r="3" fill="#FFF" opacity="0.8" />
  <circle cx="2800" cy="400" r="1.5" fill="#FFF" opacity="0.4" />
</svg>''',

    "nira-ai-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#0B0F19" />
  <polygon points="1920,500 2400,1080 2400,1600 1920,2100 1440,1600 1440,1080" fill="none" stroke="#00F0FF" stroke-width="4" opacity="0.2" />
  <circle cx="1920" cy="1080" r="100" fill="#7000FF" opacity="0.5" />
</svg>''',

    "nira-developer-4k": '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="100%" height="100%">
  <rect width="3840" height="2160" fill="#090D16" />
  <text x="100" y="200" font-family="monospace" font-size="24" fill="#1E293B">sys.kernel.init()</text>
  <text x="100" y="250" font-family="monospace" font-size="24" fill="#1E293B">Loading NiraOS dependencies...</text>
  <text x="100" y="300" font-family="monospace" font-size="24" fill="#00F0FF" opacity="0.5">OK</text>
</svg>'''
}

count = 0
for name, svg in WALLPAPERS.items():
    filepath = os.path.join(BASE_DIR, f"{name}.svg")
    with open(filepath, "w") as f:
        f.write(svg)
    count += 1

print(f"Generated {count} 4K SVG Wallpapers.")
