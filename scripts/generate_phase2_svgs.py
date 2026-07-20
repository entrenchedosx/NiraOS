import os

BASE_DIR = r"d:\AetherOS\assets"

SVG_TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="100%" height="100%">
  <defs>
    <linearGradient id="nira-grad-cyan" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF" />
      <stop offset="100%" stop-color="#00A3FF" />
    </linearGradient>
    <linearGradient id="nira-grad-violet" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#7000FF" />
      <stop offset="100%" stop-color="#B026FF" />
    </linearGradient>
    <filter id="nira-shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#000000" flood-opacity="0.5" />
    </filter>
  </defs>
  <g filter="url(#nira-shadow)">
{content}
  </g>
</svg>"""

ASSETS = {
    "icons": {
        "trash-empty": '''<path d="M 16 16 L 20 54 H 44 L 48 16 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/>
<path d="M 10 16 H 54 M 24 16 V 10 H 40 V 16" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>''',
        "trash-full": '''<path d="M 16 16 L 20 54 H 44 L 48 16 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linejoin="round"/>
<path d="M 10 16 H 54 M 24 16 V 10 H 40 V 16" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
<line x1="26" y1="26" x2="26" y2="44" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round"/><line x1="38" y1="26" x2="38" y2="44" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round"/><line x1="32" y1="26" x2="32" y2="44" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round"/>''',
        "computer": '''<rect x="6" y="10" width="52" height="34" rx="4" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 20 44 L 14 54 H 50 L 44 44 Z" fill="url(#nira-grad-violet)"/>
<circle cx="32" cy="27" r="4" fill="url(#nira-grad-cyan)"/>''',
        "network": '''<circle cx="32" cy="16" r="8" fill="url(#nira-grad-violet)"/>
<circle cx="16" cy="48" r="8" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<circle cx="48" cy="48" r="8" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 32 24 V 36 M 16 40 V 36 H 48 V 40" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>''',
        "usb": '''<rect x="24" y="6" width="16" height="14" rx="2" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 24 20 L 14 30 V 50 C 14 53.3 16.7 56 20 56 H 44 C 47.3 56 50 53.3 50 50 V 30 L 40 20 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linejoin="round"/>
<rect x="28" y="10" width="2" height="4" fill="url(#nira-grad-cyan)"/><rect x="34" y="10" width="2" height="4" fill="url(#nira-grad-cyan)"/>''',
        "start-menu": '''<path d="M 12 12 H 30 V 30 H 12 Z M 34 12 H 52 V 30 H 34 Z M 12 34 H 30 V 52 H 12 Z M 34 34 H 52 V 52 H 34 Z" fill="url(#nira-grad-cyan)" opacity="0.8"/>''',
        "terminal": '''<rect x="6" y="10" width="52" height="44" rx="4" fill="#0B0F19" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 16 22 L 26 30 L 16 38" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<line x1="30" y1="38" x2="44" y2="38" stroke="url(#nira-grad-violet)" stroke-width="2.5" stroke-linecap="round"/>''',
        "calculator": '''<rect x="12" y="6" width="40" height="52" rx="4" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<rect x="18" y="12" width="28" height="12" rx="2" fill="#0B0F19" stroke="url(#nira-grad-violet)" stroke-width="1.5"/>
<circle cx="22" cy="32" r="3" fill="url(#nira-grad-cyan)"/><circle cx="32" cy="32" r="3" fill="url(#nira-grad-cyan)"/><circle cx="42" cy="32" r="3" fill="url(#nira-grad-cyan)"/>
<circle cx="22" cy="42" r="3" fill="url(#nira-grad-cyan)"/><circle cx="32" cy="42" r="3" fill="url(#nira-grad-cyan)"/><circle cx="42" cy="42" r="3" fill="url(#nira-grad-violet)"/>''',
        "package-manager": '''<path d="M 32 6 L 54 18 V 44 L 32 56 L 10 44 V 18 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/>
<path d="M 10 18 L 32 30 L 54 18 M 32 30 V 56" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linejoin="round"/>''',
        "software-store": '''<path d="M 14 20 L 20 8 H 44 L 50 20 V 50 C 50 53.3 47.3 56 44 56 H 20 C 16.7 56 14 53.3 14 50 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/>
<path d="M 14 20 C 14 20 20 26 26 20 C 32 26 38 20 38 20 C 38 20 44 26 50 20" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2"/>''',
        "task-manager": '''<rect x="8" y="10" width="48" height="44" rx="4" fill="#0B0F19" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 14 36 L 24 36 L 28 20 L 36 44 L 42 28 L 50 28" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>''',
        "login": '''<circle cx="32" cy="22" r="10" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 14 52 C 14 42 22 36 32 36 C 42 36 50 42 50 52" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linecap="round"/>''',
        "lock-screen": '''<rect x="16" y="28" width="32" height="26" rx="4" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/>
<path d="M 22 28 V 18 C 22 12 26 10 32 10 C 38 10 42 12 42 18 V 28" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linecap="round"/>
<circle cx="32" cy="41" r="3" fill="url(#nira-grad-cyan)"/>''',
        "shutdown": '''<path d="M 32 12 V 32 M 20 18 A 20 20 0 1 0 44 18" fill="none" stroke="#FF2E63" stroke-width="3" stroke-linecap="round"/>''',
        "restart": '''<path d="M 32 10 A 22 22 0 1 1 14 24" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round"/>
<polygon points="14,10 14,24 28,24" fill="url(#nira-grad-cyan)"/>''',
        "sleep": '''<path d="M 22 14 C 12 22 12 42 22 50 C 34 56 46 48 50 38 C 40 40 28 32 30 20 C 31 16 36 12 36 12 C 30 10 26 10 22 14 Z" fill="url(#nira-grad-violet)"/>''',
    },
    "system-ui": {
        "window-close": '''<circle cx="32" cy="32" r="16" fill="#FF2E63"/><path d="M 26 26 L 38 38 M 38 26 L 26 38" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round"/>''',
        "window-min": '''<circle cx="32" cy="32" r="16" fill="#FFB300"/><line x1="24" y1="32" x2="40" y2="32" stroke="#FFF" stroke-width="2" stroke-linecap="round"/>''',
        "window-max": '''<circle cx="32" cy="32" r="16" fill="#00E676"/><rect x="24" y="24" width="16" height="16" fill="none" stroke="#FFF" stroke-width="2"/>''',
        "window-restore": '''<circle cx="32" cy="32" r="16" fill="#00E676"/><rect x="22" y="26" width="12" height="12" fill="none" stroke="#FFF" stroke-width="2"/><rect x="28" y="22" width="12" height="12" fill="none" stroke="#FFF" stroke-width="2"/>''',
        "checkbox-off": '''<rect x="16" y="16" width="32" height="32" rx="4" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2"/>''',
        "checkbox-on": '''<rect x="16" y="16" width="32" height="32" rx="4" fill="url(#nira-grad-cyan)"/><path d="M 24 32 L 30 38 L 42 24" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>''',
        "radio-off": '''<circle cx="32" cy="32" r="16" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2"/>''',
        "radio-on": '''<circle cx="32" cy="32" r="16" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/><circle cx="32" cy="32" r="8" fill="url(#nira-grad-cyan)"/>''',
        "toggle-off": '''<rect x="10" y="20" width="44" height="24" rx="12" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2"/><circle cx="22" cy="32" r="8" fill="url(#nira-grad-violet)"/>''',
        "toggle-on": '''<rect x="10" y="20" width="44" height="24" rx="12" fill="url(#nira-grad-cyan)"/><circle cx="42" cy="32" r="8" fill="#000"/>'''
    },
    "filemanager": {
        "folder": '''<path d="M 6 22 L 6 14 C 6 10.7 8.7 8 12 8 L 24 8 L 30 14 L 52 14 C 55.3 14 58 16.7 58 20 L 58 46" fill="rgba(255,255,255,0.05)" stroke="rgba(255,255,255,0.2)" stroke-width="2" stroke-linejoin="round" />
<path d="M 4 28 C 4 25.8 5.8 24 8 24 L 56 24 C 58.2 24 60 25.8 60 28 L 56 52 C 55.4 54.3 53.3 56 51 56 L 13 56 C 10.7 56 8.6 54.3 8 52 Z" fill="#0B0F19" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round" filter="url(#nira-shadow)" />''',
        "toolbar-copy": '''<rect x="14" y="14" width="24" height="24" rx="2" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/><rect x="26" y="26" width="24" height="24" rx="2" fill="rgba(112,0,255,0.3)" stroke="url(#nira-grad-violet)" stroke-width="2"/>''',
        "toolbar-paste": '''<rect x="18" y="16" width="28" height="36" rx="2" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/><rect x="24" y="10" width="16" height="8" rx="2" fill="url(#nira-grad-violet)"/>''',
        "toolbar-rename": '''<path d="M 16 46 L 22 46 L 46 22 L 40 16 L 16 40 Z" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/><line x1="16" y1="52" x2="48" y2="52" stroke="url(#nira-grad-violet)" stroke-width="2.5" stroke-linecap="round"/>''',
        "toolbar-delete": '''<path d="M 18 20 L 22 52 H 42 L 46 20 M 12 20 H 52 M 26 20 V 12 H 38 V 20" fill="none" stroke="#FF2E63" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>''',
        "sidebar-home": '''<path d="M 8 30 L 32 10 L 56 30 V 52 C 56 55.3 53.3 58 50 58 H 14 C 10.7 58 8 55.3 8 52 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/><path d="M 26 58 V 38 H 38 V 58" fill="url(#nira-grad-violet)"/>''',
        "nav-back": '''<path d="M 44 32 H 16 M 28 18 L 14 32 L 28 46" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>''',
        "nav-forward": '''<path d="M 20 32 H 48 M 36 18 L 50 32 L 36 46" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>''',
        "nav-up": '''<path d="M 32 48 V 20 M 18 34 L 32 20 L 46 34" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>''',
        "nav-refresh": '''<path d="M 32 12 A 20 20 0 1 1 14 26" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2.5" stroke-linecap="round"/><polygon points="14,12 14,26 28,26" fill="url(#nira-grad-cyan)"/>'''
    },
    "notepad": {
        "app-icon": '''<rect x="12" y="8" width="40" height="48" rx="4" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/><line x1="20" y1="20" x2="44" y2="20" stroke="url(#nira-grad-cyan)" stroke-width="1.5"/><line x1="20" y1="28" x2="44" y2="28" stroke="url(#nira-grad-cyan)" stroke-width="1.5"/><line x1="20" y1="36" x2="34" y2="36" stroke="url(#nira-grad-cyan)" stroke-width="1.5"/><path d="M 36 44 L 46 34 L 50 38 L 40 48 Z" fill="url(#nira-grad-violet)"/>''',
        "toolbar-save": '''<path d="M 14 12 H 42 L 50 20 V 52 H 14 Z" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/><rect x="22" y="12" width="20" height="12" fill="url(#nira-grad-violet)"/><rect x="20" y="36" width="24" height="16" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="1.5"/>''',
        "toolbar-undo": '''<path d="M 22 24 L 12 34 L 22 44 M 12 34 H 42 A 10 10 0 0 1 52 44" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>''',
        "toolbar-redo": '''<path d="M 42 24 L 52 34 L 42 44 M 52 34 H 22 A 10 10 0 0 0 12 44" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>''',
        "toolbar-find": '''<circle cx="28" cy="28" r="14" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="2"/><line x1="38" y1="38" x2="52" y2="52" stroke="url(#nira-grad-violet)" stroke-width="3" stroke-linecap="round"/>'''
    },
    "nira": {
        "assistant-logo": '''<polygon points="32,8 52,20 52,44 32,56 12,44 12,20" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/><circle cx="32" cy="32" r="10" fill="url(#nira-grad-violet)"/><circle cx="32" cy="32" r="4" fill="url(#nira-grad-cyan)"/>''',
        "chat-bubble": '''<path d="M 12 16 C 12 12 16 8 20 8 H 44 C 48 8 52 12 52 16 V 36 C 52 40 48 44 44 44 H 24 L 12 54 Z" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2" stroke-linejoin="round"/>''',
        "mic-on": '''<rect x="24" y="10" width="16" height="24" rx="8" fill="rgba(255,255,255,0.05)" stroke="url(#nira-grad-cyan)" stroke-width="2"/><path d="M 16 30 V 34 C 16 42 22 48 32 48 C 42 48 48 42 48 34 V 30 M 32 48 V 56 M 22 56 H 42" fill="none" stroke="url(#nira-grad-violet)" stroke-width="2" stroke-linecap="round"/>''',
        "mic-off": '''<rect x="24" y="10" width="16" height="24" rx="8" fill="rgba(255,255,255,0.05)" stroke="#FF2E63" stroke-width="2"/><path d="M 16 30 V 34 C 16 42 22 48 32 48 C 42 48 48 42 48 34 V 30 M 32 48 V 56 M 22 56 H 42 M 12 12 L 52 52" fill="none" stroke="#FF2E63" stroke-width="2" stroke-linecap="round"/>'''
    },
    "cursors": {
        "pointer": '''<path d="M 16 12 L 40 44 L 28 44 L 28 58 L 20 58 L 20 44 L 8 44 Z" fill="url(#nira-grad-cyan)" stroke="#FFFFFF" stroke-width="1.5" stroke-linejoin="round"/>''',
        "wait": '''<circle cx="32" cy="32" r="16" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="3" stroke-dasharray="20 10"/>''',
        "text": '''<path d="M 24 12 H 40 M 32 12 V 52 M 24 52 H 40" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>''',
        "crosshair": '''<path d="M 32 10 V 26 M 32 38 V 54 M 10 32 H 26 M 38 32 H 54" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>'''
    },
    "desktop": {
        "shortcut-overlay": '''<circle cx="44" cy="44" r="12" fill="#0B0F19" stroke="url(#nira-grad-cyan)" stroke-width="1.5"/><path d="M 38 48 L 48 38 M 40 38 H 48 V 46" fill="none" stroke="url(#nira-grad-cyan)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>''',
        "selection-rect": '''<rect x="8" y="8" width="48" height="36" fill="rgba(0,240,255,0.15)" stroke="#00F0FF" stroke-width="1" stroke-dasharray="4 2"/>'''
    }
}

count = 0
for category, icons in ASSETS.items():
    cat_dir = os.path.join(BASE_DIR, category)
    os.makedirs(cat_dir, exist_ok=True)
    for name, content in icons.items():
        filepath = os.path.join(cat_dir, f"{name}.svg")
        with open(filepath, "w") as f:
            f.write(SVG_TEMPLATE.replace("{content}", content))
        count += 1

print(f"Phase 2 Generation Complete: {count} master SVG assets successfully created.")
