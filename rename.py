import os
import sys

TARGET_DIR = 'd:/AetherOS'
EXCLUDE_DIRS = {'.git', 'target', 'build', '.zcode'}

REPLACEMENTS = [
    ("AetherOS", "NiraOS"),
    ("aetheros", "niraos"),
    ("AETHEROS", "NIRAOS"),
    ("Aether", "Nira"),
    ("aether", "nira"),
    ("AETHER", "NIRA")
]

def rename_content(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return False # Binary file or non-utf8
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return False

    new_content = content
    for old, new in REPLACEMENTS:
        new_content = new_content.replace(old, new)

    if new_content != content:
        with open(file_path, 'w', encoding='utf-8', newline='') as f:
            f.write(new_content)
        return True
    return False

def get_new_name(name):
    new_name = name
    for old, new in REPLACEMENTS:
        new_name = new_name.replace(old, new)
    return new_name

def main():
    files_modified = 0
    files_renamed = 0
    dirs_renamed = 0

    # Walk bottom-up so renaming directories doesn't break traversal
    for root, dirs, files in os.walk(TARGET_DIR, topdown=False):
        path_parts = set(root.replace('\\', '/').split('/'))
        if path_parts.intersection(EXCLUDE_DIRS):
            continue
            
        for file in files:
            # Skip this script
            if file == 'rename.py':
                continue
                
            file_path = os.path.join(root, file)
            
            # 1. Rename content
            if rename_content(file_path):
                files_modified += 1
                
            # 2. Rename file
            new_file_name = get_new_name(file)
            if new_file_name != file:
                new_file_path = os.path.join(root, new_file_name)
                os.rename(file_path, new_file_path)
                files_renamed += 1

        # 3. Rename directory
        # Do not rename the target directory itself
        if root.replace('\\', '/').rstrip('/') == TARGET_DIR.rstrip('/'):
            continue
            
        current_dir_name = os.path.basename(root)
        new_dir_name = get_new_name(current_dir_name)
        
        if new_dir_name != current_dir_name:
            parent_dir = os.path.dirname(root)
            new_root = os.path.join(parent_dir, new_dir_name)
            os.rename(root, new_root)
            dirs_renamed += 1
            
    print(f"Migration complete:")
    print(f"Files modified: {files_modified}")
    print(f"Files renamed: {files_renamed}")
    print(f"Directories renamed: {dirs_renamed}")

if __name__ == '__main__':
    main()
