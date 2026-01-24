#!/usr/bin/env python3

import json
import sys

def validate_report(file_path):
    try:
        with open(file_path, 'r') as f:
            report = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Report file not found: {file_path}")
        return False
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}")
        return False

    required_keys = ["version", "timestamp", "project", "files", "worst_offenders"]
    for key in required_keys:
        if key not in report:
            print(f"ERROR: Missing required key: {key}")
            return False

    project = report["project"]
    required_project_keys = ["total_files", "successful_files", "failed_files", "totals", "averages"]
    for key in required_project_keys:
        if key not in project:
            print(f"ERROR: Missing project key: {key}")
            return False
    
    totals = project["totals"]
    if "cc" not in totals or "cog" not in totals:
        print("ERROR: Missing totals.cc or totals.cog")
        return False
    
    averages = project["averages"]
    if "cc" not in averages or "cog" not in averages or "confidence" not in averages:
        print("ERROR: Missing averages.cc, averages.cog, or averages.confidence")
        return False
    
    worst = report["worst_offenders"]
    if "cc" not in worst or "cog" not in worst:
        print("ERROR: Missing worst_offenders.cc or worst_offenders.cog")
        return False
    
    if not isinstance(report["files"], list):
        print("ERROR: files must be an array")
        return False
    
    if len(report["files"]) == 0:
        print("ERROR: No files in report")
        return False
    
    for file_data in report["files"]:
        required_file_keys = ["file", "success", "cc", "cog", "confidence"]
        for key in required_file_keys:
            if key not in file_data:
                print(f"ERROR: Missing file key: {key}")
                return False
    
    print("Report validation passed")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 validate_report.py <report.json>")
        sys.exit(1)
    
    report_path = sys.argv[1]
    if validate_report(report_path):
        sys.exit(0)
    else:
        sys.exit(1)

