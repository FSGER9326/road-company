import os
import sys
import json
import argparse
import shutil
import math

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError:
    print("Error: Pillow (PIL) is required for visual comparison. Please 'pip install Pillow'.")
    sys.exit(1)

def compare_images(img1_path, img2_path, diff_out_path, tolerance=0.01):
    try:
        img1 = Image.open(img1_path).convert('RGB')
        img2 = Image.open(img2_path).convert('RGB')
    except Exception as e:
        return False, str(e)
        
    if img1.size != img2.size:
        return False, f"Size mismatch: {img1.size} != {img2.size}"
        
    diff = ImageChops.difference(img1, img2)
    stat = ImageStat.Stat(diff)
    
    # Calculate the average pixel difference (0-255 scale)
    # stat.mean is a tuple (R, G, B)
    mean_diff = sum(stat.mean) / len(stat.mean)
    
    # If the difference is below tolerance, consider it identical
    # tolerance is roughly % difference
    diff_percent = mean_diff / 255.0
    
    if diff_percent > tolerance:
        diff = diff.point(lambda p: min(p * 5, 255))
        diff.save(diff_out_path)
        return False, f"Differs by {diff_percent * 100:.3f}% (threshold {tolerance*100:.3f}%)"
        
    return True, "Match"

def get_tolerance_for_screen(screen: str) -> float:
    # combat_board.png requires stricter tolerance because UI changes are small
    if screen == "combat_board.png":
        return 0.0005 # 0.05%
    return 0.01 # 1% default

def main():
    parser = argparse.ArgumentParser(description="Compare visual smoke tests")
    parser.add_argument("--accept-baseline", action="store_true", help="Accept new baseline screenshots")
    args = parser.parse_args()

    latest_dir = os.path.join("tests", "visual", "runs", "latest")
    baseline_dir = os.path.join("tests", "visual", "baselines")
    
    if not os.path.exists(latest_dir):
        print(f"Error: Could not find latest run directory at {latest_dir}")
        sys.exit(1)
        
    os.makedirs(baseline_dir, exist_ok=True)
    
    report = {
        "summary": {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "missing_baseline": 0,
            "accepted": 0
        },
        "details": []
    }
    
    # Expected screens from capture script
    expected_screens = [
        "main_menu.png",
        "road_map.png",
        "contract_board.png",
        "combat_board.png",
        "aftermath_camp.png"
    ]
    
    # Find all pngs in latest run
    run_images = [f for f in os.listdir(latest_dir) if f.endswith(".png") and not f.endswith("_diff.png")]
    
    for screen in expected_screens:
        if screen not in run_images:
            report["details"].append({
                "file": screen,
                "status": "failed",
                "reason": "Missing from capture"
            })
            report["summary"]["failed"] += 1
            report["summary"]["total"] += 1
            continue
            
        run_img = os.path.join(latest_dir, screen)
        base_img = os.path.join(baseline_dir, screen)
        
        report["summary"]["total"] += 1
        
        if not os.path.exists(base_img):
            if args.accept_baseline:
                shutil.copy2(run_img, base_img)
                report["details"].append({
                    "file": screen,
                    "status": "accepted",
                    "reason": "New baseline accepted"
                })
                report["summary"]["accepted"] += 1
                report["summary"]["passed"] += 1
            else:
                report["details"].append({
                    "file": screen,
                    "status": "missing_baseline",
                    "reason": "Baseline not found. Run with --accept-baseline to create it."
                })
                report["summary"]["missing_baseline"] += 1
                report["summary"]["failed"] += 1
        else:
            diff_img = os.path.join(latest_dir, screen.replace(".png", "_diff.png"))
            tol = get_tolerance_for_screen(screen)
            match, msg = compare_images(base_img, run_img, diff_img, tolerance=tol)
            
            if match:
                report["details"].append({
                    "file": screen,
                    "status": "passed",
                    "reason": msg
                })
                report["summary"]["passed"] += 1
            else:
                if args.accept_baseline:
                    shutil.copy2(run_img, base_img)
                    report["details"].append({
                        "file": screen,
                        "status": "accepted",
                        "reason": f"Baseline updated (was: {msg})"
                    })
                    report["summary"]["accepted"] += 1
                    report["summary"]["passed"] += 1
                else:
                    report["details"].append({
                        "file": screen,
                        "status": "failed",
                        "reason": msg,
                        "diff_file": os.path.basename(diff_img)
                    })
                    report["summary"]["failed"] += 1
                    
    # Write JSON report
    json_path = os.path.join(latest_dir, "report.json")
    with open(json_path, 'w') as f:
        json.dump(report, f, indent=2)
        
    # Write Markdown report
    md_path = os.path.join(latest_dir, "report.md")
    with open(md_path, 'w') as f:
        f.write("# Visual Comparison Report\n\n")
        f.write(f"**Total:** {report['summary']['total']} | ")
        f.write(f"**Passed:** {report['summary']['passed']} | ")
        f.write(f"**Failed:** {report['summary']['failed']} | ")
        f.write(f"**Accepted:** {report['summary']['accepted']}\n\n")
        
        f.write("| File | Status | Reason | Diff |\n")
        f.write("|---|---|---|---|\n")
        for detail in report["details"]:
            diff_col = detail.get('diff_file', '')
            f.write(f"| {detail['file']} | {detail['status']} | {detail['reason']} | {diff_col} |\n")
            
    print("\n--- Visual Comparison Summary ---")
    print(f"Passed: {report['summary']['passed']}/{report['summary']['total']}")
    if report['summary']['failed'] > 0:
        print(f"Failed: {report['summary']['failed']}")
        for detail in report["details"]:
            if detail['status'] in ('failed', 'missing_baseline'):
                print(f"  - {detail['file']}: {detail['reason']}")
                
    if report["summary"]["failed"] > 0:
        sys.exit(1)
        
if __name__ == "__main__":
    main()
