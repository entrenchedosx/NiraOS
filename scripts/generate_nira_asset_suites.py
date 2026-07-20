import os

BASE = r"d:\AetherOS\assets\nira-design-system"

def make_dir(subpath):
    d = os.path.join(BASE, subpath)
    os.makedirs(d, exist_ok=True)
    return d

# 1. File Manager Toolbar Assets
fm_toolbar_dir = make_dir(r"file-manager\toolbar-icons")
fm_icons = {
    "copy": '<rect x="12" y="12" width="28" height="28" rx="4" fill="none" stroke="#00F0FF" stroke-width="3"/><rect x="24" y="24" width="28" height="28" rx="4" fill="rgba(112,0,255,0.3)" stroke="#7000FF" stroke-width="3"/>',
    "paste": '<rect x="16" y="16" width="32" height="38" rx="4" fill="none" stroke="#00F0FF" stroke-width="3"/><rect x="24" y="8" width="16" height="8" rx="2" fill="#7000FF"/>',
    "rename": '<path d="M12 48 L20 48 L48 20 L40 12 L12 40 Z" fill="none" stroke="#00F0FF" stroke-width="3"/><line x1="12" y1="52" x2="52" y2="52" stroke="#7000FF" stroke-width="3"/>',
    "delete": '<path d="M16 20 L20 52 H44 L48 20 M10 20 H54 M24 20 V12 H40 V20" fill="none" stroke="#FF2E63" stroke-width="3"/>',
    "new_folder": '<path d="M8 16 C8 12.7 10.7 10 14 10 H24 L30 16 H50 C53.3 16 56 18.7 56 22 V48 C56 51.3 53.3 54 50 54 H14 C10.7 54 8 51.3 8 48 Z" fill="none" stroke="#00F0FF" stroke-width="3"/><line x1="32" y1="28" x2="32" y2="44" stroke="#00E676" stroke-width="3"/><line x1="24" y1="36" x2="40" y2="36" stroke="#00E676" stroke-width="3"/>',
    "move": '<path d="M12 32 H52 M40 20 L52 32 L40 44" fill="none" stroke="#00F0FF" stroke-width="3" stroke-linecap="round"/>',
    "search": '<circle cx="26" cy="26" r="14" fill="none" stroke="#00F0FF" stroke-width="3"/><line x1="36" y1="36" x2="52" y2="52" stroke="#7000FF" stroke-width="4" stroke-linecap="round"/>',
    "refresh": '<path d="M32 10 A22 22 0 1 1 14 24" fill="none" stroke="#00F0FF" stroke-width="3"/><polygon points="14,10 14,24 28,24" fill="#00F0FF"/>',
    "sort": '<path d="M20 12 V52 M20 12 L12 20 M20 12 L28 20 M44 12 V52 M44 52 L36 44 M44 52 L52 44" fill="none" stroke="#00F0FF" stroke-width="3" stroke-linecap="round"/>',
    "view_modes": '<rect x="10" y="10" width="18" height="18" rx="3" fill="#00F0FF"/><rect x="36" y="10" width="18" height="18" rx="3" fill="none" stroke="#00F0FF" stroke-width="2"/><rect x="10" y="36" width="18" height="18" rx="3" fill="none" stroke="#00F0FF" stroke-width="2"/><rect x="36" y="36" width="18" height="18" rx="3" fill="#00F0FF"/>',
    "back": '<path d="M44 32 H16 M28 18 L14 32 L28 46" fill="none" stroke="#00F0FF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "forward": '<path d="M20 32 H48 M36 18 L50 32 L36 46" fill="none" stroke="#00F0FF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "up": '<path d="M32 48 V20 M18 34 L32 20 L46 34" fill="none" stroke="#00F0FF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "history": '<circle cx="32" cy="32" r="22" fill="none" stroke="#00F0FF" stroke-width="3"/><path d="M32 18 V32 L42 38" fill="none" stroke="#7000FF" stroke-width="3" stroke-linecap="round"/>',
    "favorites": '<polygon points="32,8 39,23 56,25 43,37 47,54 32,45 17,54 21,37 8,25 25,23" fill="#FFB300" stroke="#FFB300" stroke-width="2"/>',
    "properties": '<circle cx="32" cy="32" r="22" fill="none" stroke="#00F0FF" stroke-width="3"/><line x1="32" y1="20" x2="32" y2="24" stroke="#00F0FF" stroke-width="4" stroke-linecap="round"/><line x1="32" y1="30" x2="32" y2="44" stroke="#00F0FF" stroke-width="4" stroke-linecap="round"/>',
    "permissions": '<rect x="16" y="26" width="32" height="28" rx="4" fill="none" stroke="#00E676" stroke-width="3"/><path d="M22 26 V18 A10 10 0 0 1 42 18 V26" fill="none" stroke="#00E676" stroke-width="3"/>'
}

for name, svg in fm_icons.items():
    with open(os.path.join(fm_toolbar_dir, f"{name}.svg"), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="100%" height="100%">{svg}</svg>')

# 2. Notepad Suite
notepad_dir = make_dir(r"notepad\toolbar-icons")
np_icons = {
    "save": '<path d="M12 10 H44 L52 18 V54 H12 Z" fill="none" stroke="#00F0FF" stroke-width="3"/><rect x="20" y="10" width="20" height="14" fill="#7000FF"/><rect x="18" y="34" width="28" height="20" fill="none" stroke="#00F0FF" stroke-width="2"/>',
    "save_as": '<path d="M12 10 H44 L52 18 V42 H12 Z" fill="none" stroke="#00F0FF" stroke-width="3"/><path d="M34 44 L44 54 M44 44 L34 54" stroke="#00E676" stroke-width="3"/>',
    "undo": '<path d="M22 22 L10 32 L22 42 M10 32 H40 A12 12 0 0 1 52 44" fill="none" stroke="#00F0FF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "redo": '<path d="M42 22 L54 32 L42 42 M54 32 H24 A12 12 0 0 0 12 44" fill="none" stroke="#00F0FF" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "cut": '<circle cx="20" cy="46" r="8" fill="none" stroke="#FF2E63" stroke-width="3"/><circle cx="44" cy="46" r="8" fill="none" stroke="#FF2E63" stroke-width="3"/><path d="M25 40 L44 12 M39 40 L20 12" stroke="#FF2E63" stroke-width="3.5"/>',
    "find": '<circle cx="28" cy="28" r="16" fill="none" stroke="#00F0FF" stroke-width="3"/><line x1="40" y1="40" x2="54" y2="54" stroke="#00F0FF" stroke-width="4"/>',
    "replace": '<path d="M14 26 H44 M36 18 L44 26 L36 34" fill="none" stroke="#00F0FF" stroke-width="3"/><path d="M50 38 H20 M28 46 L20 38 L28 30" fill="none" stroke="#7000FF" stroke-width="3"/>',
    "print": '<path d="M18 20 V10 H46 V20 M18 42 H12 C9 42 6 39 6 36 V26 C6 23 9 20 12 20 H52 C55 20 58 23 58 26 V36 C58 39 55 42 52 42 H46 M18 34 H46 V54 H18 Z" fill="none" stroke="#00F0FF" stroke-width="3"/>'
}

for name, svg in np_icons.items():
    with open(os.path.join(notepad_dir, f"{name}.svg"), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="100%" height="100%">{svg}</svg>')

# 3. AI Nira Intelligence Suite Assets
ai_dir = make_dir(r"ai-nira-intelligence")
ai_thinking_svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="100%" height="100%">
  <defs>
    <linearGradient id="aiGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00F0FF"/>
      <stop offset="100%" stop-color="#7000FF"/>
    </linearGradient>
  </defs>
  <circle cx="100" cy="100" r="80" fill="none" stroke="url(#aiGrad)" stroke-width="4" stroke-dasharray="16 8">
    <animateTransform attributeName="transform" type="rotate" from="0 100 100" to="360 100 100" dur="4s" repeatCount="indefinite"/>
  </circle>
  <circle cx="100" cy="100" r="50" fill="none" stroke="#B026FF" stroke-width="3" stroke-dasharray="10 5">
    <animateTransform attributeName="transform" type="rotate" from="360 100 100" to="0 100 100" dur="3s" repeatCount="indefinite"/>
  </circle>
  <circle cx="100" cy="100" r="20" fill="#00F0FF">
    <animate attributeName="r" values="16;24;16" dur="2s" repeatCount="indefinite"/>
  </circle>
</svg>'''

with open(os.path.join(ai_dir, "thinking-animation.svg"), "w") as f:
    f.write(ai_thinking_svg)

# 4. Error State Illustrations (12 Custom Vector Illustrations)
err_dir = make_dir(r"illustrations\error-states")
err_states = [
    ("missing_file", "Missing File", "#FF2E63"),
    ("empty_folder", "Empty Folder", "#64748B"),
    ("permission_denied", "Access Denied", "#FF2E63"),
    ("network_unavailable", "Network Offline", "#FFB300"),
    ("no_internet", "No Connection", "#FFB300"),
    ("ai_offline", "Nira AI Offline", "#7000FF"),
    ("model_missing", "Model Missing", "#7000FF"),
    ("app_crashed", "Application Fault", "#FF2E63"),
    ("recovery_mode", "Recovery Mode", "#FFB300"),
    ("low_storage", "Storage Warning", "#FFB300"),
    ("low_battery", "Battery Low", "#FF2E63"),
    ("system_repair", "System Repair", "#00F0FF")
]

for code, title, color in err_states:
    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300" width="100%" height="100%">
  <rect width="400" height="300" rx="16" fill="#111827" stroke="{color}" stroke-width="2" opacity="0.9"/>
  <circle cx="200" cy="120" r="45" fill="none" stroke="{color}" stroke-width="4"/>
  <path d="M 175 145 L 225 95 M 175 95 L 225 145" stroke="{color}" stroke-width="4" stroke-linecap="round"/>
  <text x="200" y="210" font-family="'Outfit', sans-serif" font-weight="700" font-size="20" fill="#F8FAFC" text-anchor="middle">{title}</text>
  <text x="200" y="240" font-family="'Inter', sans-serif" font-size="14" fill="#94A3B8" text-anchor="middle">NiraOS Protection Shield Active</text>
</svg>'''
    with open(os.path.join(err_dir, f"{code}.svg"), "w") as f:
        f.write(svg_content)

print("All asset suites generated successfully!")
