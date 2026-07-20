import os
import xml.etree.ElementTree as ET

ICON_DIR = r"d:\AetherOS\assets\nira-design-system\icons\svg"
PNG_DIR = r"d:\AetherOS\assets\nira-design-system\icons\png"
SIZES = [16, 24, 32, 48, 64, 128, 256, 512]

os.makedirs(ICON_DIR, exist_ok=True)
for sz in SIZES:
    os.makedirs(os.path.join(PNG_DIR, str(sz)), exist_ok=True)

# Master SVG Header Template
def create_svg(path_content, accent="#00F0FF", secondary="#7000FF"):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="100%" height="100%">
  <defs>
    <linearGradient id="gradPrimary" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="{accent}" />
      <stop offset="100%" stop-color="{secondary}" />
    </linearGradient>
    <linearGradient id="glassGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.25" />
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.03" />
    </linearGradient>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="3" result="blur" />
      <feComposite in="SourceGraphic" in2="blur" operator="over" />
    </filter>
  </defs>
  {path_content}
</svg>'''

icons_data = {
    "desktop": '''
      <rect x="8" y="10" width="48" height="32" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 24 42 L 20 54 H 44 L 40 42" fill="none" stroke="url(#gradPrimary)" stroke-width="2.5" stroke-linecap="round" />
      <circle cx="32" cy="26" r="6" fill="url(#gradPrimary)" filter="url(#glow)" />
    ''',
    "folder": '''
      <path d="M 8 16 C 8 12.7 10.7 10 14 10 H 24 L 30 16 H 50 C 53.3 16 56 18.7 56 22 V 48 C 56 51.3 53.3 54 50 54 H 14 C 10.7 54 8 51.3 8 48 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 8 22 C 8 18.7 10.7 16 14 16 H 50 C 53.3 16 56 18.7 56 22 V 48 C 56 51.3 53.3 54 50 54 H 14 C 10.7 54 8 51.3 8 48 Z" fill="url(#gradPrimary)" opacity="0.15" />
      <path d="M 22 36 H 42" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
    ''',
    "downloads": '''
      <rect x="10" y="8" width="44" height="48" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 32 18 V 38 M 22 28 L 32 38 L 42 28" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
      <line x1="20" y1="44" x2="44" y2="44" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
    ''',
    "documents": '''
      <path d="M 14 10 H 36 L 50 24 V 52 C 50 55.3 47.3 58 44 58 H 14 C 10.7 58 8 55.3 8 52 V 16 C 8 12.7 10.7 10 14 10 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 36 10 V 24 H 50" fill="none" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <line x1="16" y1="30" x2="38" y2="30" stroke="#F8FAFC" stroke-width="2" stroke-linecap="round" />
      <line x1="16" y1="38" x2="42" y2="38" stroke="#F8FAFC" stroke-width="2" opacity="0.7" stroke-linecap="round" />
      <line x1="16" y1="46" x2="30" y2="46" stroke="#F8FAFC" stroke-width="2" opacity="0.5" stroke-linecap="round" />
    ''',
    "music": '''
      <circle cx="32" cy="32" r="24" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <circle cx="24" cy="40" r="5" fill="url(#gradPrimary)" />
      <circle cx="40" cy="34" r="5" fill="url(#gradPrimary)" />
      <path d="M 29 40 V 20 L 45 14 V 34" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
    ''',
    "pictures": '''
      <rect x="8" y="12" width="48" height="40" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <circle cx="22" cy="24" r="5" fill="#00F0FF" />
      <path d="M 12 44 L 26 30 L 36 40 L 44 32 L 52 44 Z" fill="url(#gradPrimary)" opacity="0.8" />
    ''',
    "videos": '''
      <rect x="8" y="14" width="48" height="36" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <polygon points="26,22 42,32 26,42" fill="url(#gradPrimary)" filter="url(#glow)" />
    ''',
    "applications": '''
      <rect x="10" y="10" width="18" height="18" rx="5" fill="url(#gradPrimary)" />
      <rect x="36" y="10" width="18" height="18" rx="5" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2" />
      <rect x="10" y="36" width="18" height="18" rx="5" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2" />
      <rect x="36" y="36" width="18" height="18" rx="5" fill="url(#gradPrimary)" />
    ''',
    "settings": '''
      <circle cx="32" cy="32" r="10" fill="none" stroke="url(#gradPrimary)" stroke-width="3" />
      <path d="M 32 8 V 16 M 32 48 V 56 M 8 32 H 16 M 48 32 H 56 M 15 15 L 21 21 M 43 43 L 49 49 M 15 49 L 21 43 M 43 21 L 49 15" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
    ''',
    "trash": '''
      <path d="M 18 18 L 22 54 H 42 L 46 18 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 12 18 H 52 M 24 18 V 12 H 40 V 18" stroke="url(#gradPrimary)" stroke-width="2.5" stroke-linecap="round" />
      <line x1="28" y1="26" x2="28" y2="44" stroke="url(#gradPrimary)" stroke-width="2" />
      <line x1="36" y1="26" x2="36" y2="44" stroke="url(#gradPrimary)" stroke-width="2" />
    ''',
    "computer": '''
      <rect x="6" y="10" width="52" height="34" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 20 44 L 14 54 H 50 L 44 44 Z" fill="url(#gradPrimary)" />
      <circle cx="32" cy="27" r="4" fill="#00F0FF" />
    ''',
    "home": '''
      <path d="M 8 30 L 32 10 L 56 30 V 52 C 56 55.3 53.3 58 50 58 H 14 C 10.7 58 8 55.3 8 52 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 26 58 V 38 H 38 V 58" fill="url(#gradPrimary)" />
    ''',
    "network": '''
      <circle cx="32" cy="16" r="8" fill="url(#gradPrimary)" />
      <circle cx="16" cy="48" r="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2" />
      <circle cx="48" cy="48" r="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2" />
      <path d="M 32 24 V 36 M 16 40 V 36 H 48 V 40" stroke="url(#gradPrimary)" stroke-width="2.5" stroke-linecap="round" />
    ''',
    "usb": '''
      <rect x="22" y="8" width="20" height="18" rx="2" fill="none" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 22 26 L 12 36 V 48 C 12 51.3 14.7 54 18 54 H 46 C 49.3 54 52 51.3 52 48 V 36 L 42 26 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="27" y="13" width="3" height="5" fill="url(#gradPrimary)" />
      <rect x="34" y="13" width="3" height="5" fill="url(#gradPrimary)" />
    ''',
    "ssd": '''
      <rect x="10" y="8" width="44" height="48" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="18" y="16" width="28" height="16" rx="3" fill="url(#gradPrimary)" opacity="0.8" />
      <text x="32" y="27" font-family="sans-serif" font-weight="bold" font-size="10" fill="#0B0F19" text-anchor="middle">NVMe</text>
      <circle cx="20" cy="44" r="3" fill="#00E676" />
      <circle cx="32" cy="44" r="3" fill="#00F0FF" />
    ''',
    "hard_drive": '''
      <rect x="8" y="12" width="48" height="40" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <circle cx="32" cy="28" r="10" fill="none" stroke="url(#gradPrimary)" stroke-width="2" />
      <circle cx="32" cy="28" r="3" fill="url(#gradPrimary)" />
      <circle cx="48" cy="44" r="2.5" fill="#00E676" />
    ''',
    "cloud": '''
      <path d="M 18 48 C 11.4 48 6 42.6 6 36 C 6 30 10.5 25 16.5 24.2 C 18.8 16 26.3 10 35 10 C 45 10 53.2 17.5 54.7 27.2 C 58.9 28.8 62 33 62 38 C 62 44.6 56.6 50 50 50 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
    ''',
    "terminal": '''
      <rect x="6" y="10" width="52" height="44" rx="8" fill="#0B0F19" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 16 22 L 26 30 L 16 38" fill="none" stroke="#00F0FF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
      <line x1="30" y1="38" x2="44" y2="38" stroke="#7000FF" stroke-width="3" stroke-linecap="round" />
    ''',
    "notepad": '''
      <rect x="12" y="8" width="40" height="48" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <line x1="20" y1="20" x2="44" y2="20" stroke="url(#gradPrimary)" stroke-width="2" />
      <line x1="20" y1="28" x2="44" y2="28" stroke="url(#gradPrimary)" stroke-width="2" />
      <line x1="20" y1="36" x2="34" y2="36" stroke="url(#gradPrimary)" stroke-width="2" />
      <path d="M 36 44 L 46 34 L 50 38 L 40 48 Z" fill="url(#gradPrimary)" />
    ''',
    "calculator": '''
      <rect x="12" y="8" width="40" height="48" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="18" y="14" width="28" height="10" rx="3" fill="#0B0F19" stroke="url(#gradPrimary)" stroke-width="1.5" />
      <circle cx="22" cy="32" r="3" fill="url(#gradPrimary)" />
      <circle cx="32" cy="32" r="3" fill="url(#gradPrimary)" />
      <circle cx="42" cy="32" r="3" fill="url(#gradPrimary)" />
      <circle cx="22" cy="42" r="3" fill="url(#gradPrimary)" />
      <circle cx="32" cy="42" r="3" fill="url(#gradPrimary)" />
      <circle cx="42" cy="42" r="3" fill="#FFB300" />
    ''',
    "browser": '''
      <rect x="6" y="10" width="52" height="44" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <line x1="6" y1="22" x2="58" y2="22" stroke="url(#gradPrimary)" stroke-width="2" />
      <circle cx="14" cy="16" r="2.5" fill="#FF2E63" />
      <circle cx="22" cy="16" r="2.5" fill="#FFB300" />
      <circle cx="30" cy="16" r="2.5" fill="#00E676" />
      <circle cx="32" cy="38" r="8" fill="none" stroke="url(#gradPrimary)" stroke-width="2" />
    ''',
    "ai": '''
      <polygon points="32,6 54,18 54,46 32,58 10,46 10,18" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <circle cx="32" cy="32" r="12" fill="url(#gradPrimary)" filter="url(#glow)" />
      <circle cx="32" cy="32" r="5" fill="#FFFFFF" />
    ''',
    "store": '''
      <path d="M 14 20 L 20 8 H 44 L 50 20 V 50 C 50 53.3 47.3 56 44 56 H 20 C 16.7 56 14 53.3 14 50 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 14 20 C 14 20 20 26 26 20 C 32 26 38 20 38 20 C 38 20 44 26 50 20" stroke="url(#gradPrimary)" stroke-width="2" fill="none" />
    ''',
    "package_manager": '''
      <path d="M 32 6 L 54 18 V 44 L 32 56 L 10 44 V 18 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 10 18 L 32 30 L 54 18 M 32 30 V 56" stroke="url(#gradPrimary)" stroke-width="2.5" />
    ''',
    "updates": '''
      <path d="M 32 10 A 22 22 0 1 1 14 22" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
      <polygon points="14,10 14,24 28,24" fill="url(#gradPrimary)" />
    ''',
    "bluetooth": '''
      <path d="M 22 18 L 40 32 L 30 44 V 6 L 40 18 L 22 32" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
    ''',
    "wifi": '''
      <path d="M 10 20 A 30 30 0 0 1 54 20 M 18 28 A 20 20 0 0 1 46 28 M 26 36 A 10 10 0 0 1 38 36" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
      <circle cx="32" cy="46" r="4" fill="url(#gradPrimary)" />
    ''',
    "audio": '''
      <path d="M 14 24 H 22 L 34 14 V 50 L 22 40 H 14 Z" fill="url(#gradPrimary)" />
      <path d="M 42 22 A 14 14 0 0 1 42 42 M 48 16 A 22 22 0 0 1 48 48" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
    ''',
    "display": '''
      <rect x="8" y="12" width="48" height="32" rx="4" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 24 44 H 40 M 32 44 V 54 H 20 H 44" stroke="url(#gradPrimary)" stroke-width="2.5" stroke-linecap="round" />
    ''',
    "battery": '''
      <rect x="8" y="20" width="42" height="24" rx="4" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 50 28 V 36" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" />
      <rect x="14" y="25" width="22" height="14" rx="2" fill="#00E676" />
    ''',
    "keyboard": '''
      <rect x="6" y="16" width="52" height="32" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="12" y="22" width="6" height="5" rx="1" fill="url(#gradPrimary)" />
      <rect x="22" y="22" width="6" height="5" rx="1" fill="url(#gradPrimary)" />
      <rect x="32" y="22" width="6" height="5" rx="1" fill="url(#gradPrimary)" />
      <rect x="42" y="22" width="6" height="5" rx="1" fill="url(#gradPrimary)" />
      <rect x="18" y="36" width="28" height="5" rx="1" fill="url(#gradPrimary)" />
    ''',
    "mouse": '''
      <rect x="20" y="10" width="24" height="44" rx="12" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <line x1="32" y1="10" x2="32" y2="24" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <circle cx="32" cy="18" r="2.5" fill="#00F0FF" />
    ''',
    "clipboard": '''
      <rect x="12" y="12" width="40" height="44" rx="6" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="22" y="6" width="20" height="10" rx="3" fill="url(#gradPrimary)" />
      <line x1="20" y1="26" x2="44" y2="26" stroke="#F8FAFC" stroke-width="2" />
      <line x1="20" y1="34" x2="44" y2="34" stroke="#F8FAFC" stroke-width="2" opacity="0.7" />
    ''',
    "file_explorer": '''
      <path d="M 8 14 C 8 11 11 8 14 8 H 26 L 32 14 H 50 C 53 14 56 17 56 20 V 50 C 56 53 53 56 50 56 H 14 C 11 56 8 53 8 50 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="14" y="22" width="36" height="26" rx="4" fill="url(#gradPrimary)" opacity="0.4" />
    ''',
    "task_manager": '''
      <rect x="8" y="10" width="48" height="44" rx="6" fill="#0B0F19" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 14 36 L 24 36 L 28 20 L 36 44 L 42 28 L 50 28" fill="none" stroke="#00F0FF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
    ''',
    "developer_tools": '''
      <path d="M 20 18 L 8 32 L 20 46 M 44 18 L 56 32 L 44 46 M 36 12 L 28 52" fill="none" stroke="url(#gradPrimary)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
    ''',
    "text_file": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <text x="32" y="40" font-family="monospace" font-weight="bold" font-size="14" fill="#00F0FF" text-anchor="middle">TXT</text>
    ''',
    "image_file": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="12" fill="#B026FF" text-anchor="middle">IMG</text>
    ''',
    "pdf": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#FF2E63" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="12" fill="#FF2E63" text-anchor="middle">PDF</text>
    ''',
    "zip": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#FFB300" stroke-width="2.5" />
      <line x1="32" y1="12" x2="32" y2="36" stroke="#FFB300" stroke-width="3" stroke-dasharray="4 2" />
      <text x="32" y="48" font-family="sans-serif" font-weight="bold" font-size="10" fill="#FFB300" text-anchor="middle">ZIP</text>
    ''',
    "archive": '''
      <rect x="10" y="10" width="44" height="44" rx="6" fill="url(#glassGrad)" stroke="#FFB300" stroke-width="2.5" />
      <rect x="6" y="10" width="52" height="12" rx="3" fill="#FFB300" />
    ''',
    "executable": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#00E676" stroke-width="2.5" />
      <text x="32" y="40" font-family="monospace" font-weight="bold" font-size="11" fill="#00E676" text-anchor="middle">EXE</text>
    ''',
    "code_file": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 24 32 L 18 37 L 24 42 M 40 32 L 46 37 L 40 42" stroke="#00F0FF" stroke-width="2.5" stroke-linecap="round" />
    ''',
    "markdown": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="12" fill="#00F0FF" text-anchor="middle">MD</text>
    ''',
    "json": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <text x="32" y="40" font-family="monospace" font-weight="bold" font-size="10" fill="#FFB300" text-anchor="middle">&#123;JSON&#125;</text>
    ''',
    "xml": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <text x="32" y="40" font-family="monospace" font-weight="bold" font-size="11" fill="#00A3FF" text-anchor="middle">&lt;XML&gt;</text>
    ''',
    "python": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#00F0FF" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="12" fill="#00F0FF" text-anchor="middle">PY</text>
    ''',
    "cpp": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#00A3FF" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="11" fill="#00A3FF" text-anchor="middle">C++</text>
    ''',
    "rust": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#FFB300" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="10" fill="#FFB300" text-anchor="middle">RUST</text>
    ''',
    "javascript": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#FFB300" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="12" fill="#FFB300" text-anchor="middle">JS</text>
    ''',
    "html": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#FF2E63" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="11" fill="#FF2E63" text-anchor="middle">HTML</text>
    ''',
    "css": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#00F0FF" stroke-width="2.5" />
      <text x="32" y="40" font-family="sans-serif" font-weight="bold" font-size="11" fill="#00F0FF" text-anchor="middle">CSS</text>
    ''',
    "unknown_file": '''
      <path d="M 14 8 H 36 L 50 22 V 54 H 14 Z" fill="url(#glassGrad)" stroke="#64748B" stroke-width="2.5" />
      <text x="32" y="42" font-family="sans-serif" font-weight="bold" font-size="18" fill="#94A3B8" text-anchor="middle">?</text>
    ''',
    "shortcut": '''
      <circle cx="32" cy="32" r="24" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <path d="M 22 42 L 42 22 M 28 22 H 42 V 36" stroke="#00F0FF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
    ''',
    "symbolic_link": '''
      <circle cx="20" cy="40" r="10" fill="none" stroke="url(#gradPrimary)" stroke-width="3" />
      <circle cx="44" cy="24" r="10" fill="none" stroke="url(#gradPrimary)" stroke-width="3" />
      <path d="M 28 34 C 36 34, 32 28, 36 26" fill="none" stroke="#00F0FF" stroke-width="3" stroke-linecap="round" />
    ''',
    "external_drive": '''
      <rect x="12" y="10" width="40" height="44" rx="8" fill="url(#glassGrad)" stroke="url(#gradPrimary)" stroke-width="2.5" />
      <rect x="24" y="44" width="16" height="4" rx="1" fill="#00F0FF" />
      <circle cx="20" cy="46" r="2" fill="#00E676" />
    '''
}

print(f"Generating {len(icons_data)} SVG master icons...")
for name, svg_content in icons_data.items():
    full_svg = create_svg(svg_content)
    filepath = os.path.join(ICON_DIR, f"{name}.svg")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(full_svg)

print("Master SVG generation complete!")
