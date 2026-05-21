import os
import re

def find_missing_resources(project_root):
    res_pattern = re.compile(r'res://([^\"\'\s]+)')
    missing = []
    
    for root, dirs, files in os.walk(project_root):
        if '.godot' in root or '.git' in root:
            continue
        for f in files:
            if f.endswith(('.tscn', '.tres', '.gd')):
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as file:
                    content = file.read()
                    matches = res_pattern.findall(content)
                    for match in matches:
                        res_path = os.path.join(project_root, match)
                        res_path = res_path.replace('/', os.sep)
                        if not os.path.exists(res_path):
                            # Godot sometimes truncates paths in specific patterns or uses imported files.
                            # But missing source files are an issue.
                            if not match.startswith('.godot'):
                                missing.append((path, "res://" + match))
                                
    return missing

if __name__ == "__main__":
    missing = find_missing_resources(".")
    if missing:
        for file, res in missing:
            print(f"{file} -> {res}")
    else:
        print("No missing resources found.")
