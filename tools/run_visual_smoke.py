import os
import sys
import subprocess
import shutil
from datetime import datetime
import argparse

def get_godot_bin():
    if "GODOT_BIN" in os.environ:
        return os.environ["GODOT_BIN"]
    
    # Common local paths
    common_paths = [
        "godot",
        "godot.exe",
        "Godot_v4.2.1-stable_win64.exe",
        "Godot_v4.2.2-stable_win64.exe",
        "C:\\Program Files\\Godot\\Godot_v4.2.1-stable_win64.exe",
        "C:\\Program Files\\Godot\\Godot_v4.2.2-stable_win64.exe",
        ".godot\\bin\\Godot_v4.6.2-stable_win64.exe"
    ]
    for path in common_paths:
        if shutil.which(path):
            return shutil.which(path)
        if os.path.exists(path):
            return path
            
    return None

def main():
    parser = argparse.ArgumentParser(description="Run visual smoke tests")
    parser.add_argument("--accept-baseline", action="store_true", help="Accept new baseline screenshots")
    args = parser.parse_args()

    godot_bin = get_godot_bin()
    if not godot_bin:
        print("Error: Could not find Godot executable. Set GODOT_BIN environment variable.")
        sys.exit(1)
        
    print(f"Using Godot binary: {godot_bin}")
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    runs_dir = os.path.join("tests", "visual", "runs")
    run_dir = os.path.join(runs_dir, timestamp)
    latest_dir = os.path.join(runs_dir, "latest")
    
    os.makedirs(run_dir, exist_ok=True)
    
    godot_cmd = [
        godot_bin,
        "-s", "tools/godot/capture_visual_screens.gd",
        "--out", run_dir
    ]
    
    print(f"Running command: {' '.join(godot_cmd)}")
    
    try:
        result = subprocess.run(godot_cmd, capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired as e:
        print("\nError: Godot capture timed out!")
        if e.stdout:
            print("--- Godot Output ---")
            print(e.stdout)
        sys.exit(1)
    
    print("\n--- Godot Output ---")
    print(result.stdout)
    if result.stderr:
        print("--- Godot Errors ---")
        print(result.stderr)
        
    if result.returncode != 0:
        print(f"\nError: Capture failed with exit code {result.returncode}")
        sys.exit(result.returncode)
        
    print("\nVisual capture completed successfully.")
    
    # Update latest pointer (by copying for Windows compatibility)
    if os.path.exists(latest_dir):
        shutil.rmtree(latest_dir)
    shutil.copytree(run_dir, latest_dir)
    print(f"Copied results to {latest_dir}")
    
    # Run compare script
    compare_script = os.path.join("tools", "compare_visual_screens.py")
    if os.path.exists(compare_script):
        print("\nRunning visual comparison...")
        compare_cmd = [sys.executable, compare_script]
        if args.accept_baseline:
            compare_cmd.append("--accept-baseline")
        compare_result = subprocess.run(compare_cmd)
        sys.exit(compare_result.returncode)
        
if __name__ == "__main__":
    main()
