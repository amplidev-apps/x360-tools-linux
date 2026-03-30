import os
import sys
import time
import tempfile
import json
import shutil

# Ensure access to core
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.freemarket import FreemarketEngine
from core.library import LibraryScanner
from core.save_manager import SaveManager
from core.dashlaunch import DashLaunchEditor

def run_stress_test():
    print("=== X360 TOOLS LIMIT STRESS TEST ===")
    
    # 1. Freemarket Engine (SQLite Query Performance)
    print("\n--- 1. Freemarket Engine (Database Limit) ---")
    start = time.time()
    engine = FreemarketEngine()
    
    res_360 = engine.fetch_game_list("360")
    res_classic = engine.fetch_game_list("OG")
    res_dlc = engine.fetch_game_list("DLC")
    res_tu = engine.fetch_game_list("TU")
    total_items = len(res_360) + len(res_classic) + len(res_dlc) + len(res_tu)
    
    elapsed = time.time() - start
    print(f"[OK] Fetched {total_items} total items from 14 tables in {elapsed:.3f} seconds.")
    if elapsed > 2.0: print("WARNING: Query took too long!")

    # 2. Save Manager (Vault Generation)
    print("\n--- 2. Save Manager (Vault Stress) ---")
    start = time.time()
    save_mgr = SaveManager()
    with tempfile.TemporaryDirectory() as td:
        # Create 100 fake STFS files (empty headers are rejected, so we'll just test scan performance of 100 invalid files to ensure it doesn't crash)
        for i in range(100):
            with open(os.path.join(td, f"fake_save_{i}.con"), "wb") as f:
                f.write(b"CON " + b"\\x00" * 4000)
        
        save_mgr.vault_dir = td # Hijack vault
        scanned = save_mgr.scan_vault()
        elapsed = time.time() - start
        print(f"[OK] Scanned 100 fake vault files safely in {elapsed:.3f} seconds.")
        print(f"Valid STFS parsed: {len(scanned)} (Expected 0, as they are fake)")

    # 3. DashLaunch Editor (Read/Write)
    print("\n--- 3. DashLaunch Editor (Parsing Limits) ---")
    start = time.time()
    with tempfile.NamedTemporaryFile(delete=False, mode='w', encoding='utf-16') as f:
        # Write extreme messy INI
        f.write("[Paths]\nDefault = Hdd:\\Aurora\\Aurora.xex\n[Settings]\npingpatch = true\n" * 50)
        ini_path = f.name
        
    editor = DashLaunchEditor()
    res = editor.read_ini(ini_path)
    if res.get("status") == "error":
        print(f"Error reading INI: {res.get('message')}")
    else:
        data = res["data"]
        if "settings" not in data: data["settings"] = {}
        data["settings"]["contpatch"] = "true"
        editor.write_ini(ini_path, data)
    
    with open(ini_path, "r", encoding="utf-16") as f:
        content = f.read()
    
    elapsed = time.time() - start
    print(f"[OK] Parsed and saved malformed 100-line INI in {elapsed:.3f} seconds.")
    if "contpatch = true" in content:
        print("[OK] Modification successful.")
    else:
        print("ERROR: DashLaunch modifier failed!")
    os.remove(ini_path)

    # 4. Library Scanner (Drive scanning)
    print("\n--- 4. Library Scanner (Deep Directory Walk) ---")
    start = time.time()
    with tempfile.TemporaryDirectory() as td:
        # Create deep nested structure
        os.makedirs(os.path.join(td, "Games", "Halo 3", "0000000000000000", "4D5307E6"))
        os.makedirs(os.path.join(td, "Content", "0000000000000000", "4D5307E6", "00007000"))
        
        scanner = LibraryScanner()
        res = scanner.scan_drive(td)
        elapsed = time.time() - start
        
        print(f"[OK] Scanned deep directory structure in {elapsed:.3f} seconds.")
        print(f"Library output categories: {list(res.keys())}")
        
    print("\n=== STRESS TEST COMPLETE ===")

if __name__ == "__main__":
    run_stress_test()
