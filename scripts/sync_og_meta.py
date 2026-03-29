import sqlite3
import os
import requests
from core.og_meta_loader import OGMetadataService

def sync_all():
    service = OGMetadataService()
    print("Starting OG Xbox Metadata Sync...")
    
    if not os.path.exists("titleIDs.db"):
        print("Error: titleIDs.db not found. Please download it first.")
        return

    try:
        conn = sqlite3.connect("titleIDs.db")
        cursor = conn.cursor()
        # Use DISTINCT to avoid redundant downloads for multi-region entries
        cursor.execute("SELECT DISTINCT Title_ID, Full_Name FROM TitleIDs")
        rows = cursor.fetchall()
        conn.close()
        
        print(f"Found {len(rows)} unique games in database.")
        
        from concurrent.futures import ThreadPoolExecutor
        
        def download_task(item):
            tid, name = item
            icon = service.get_icon_path(tid)
            if icon:
                return f"[OK] {tid}: {name}"
            return f"[FAIL] {tid}: {name}"

        # Increased workers for high-speed sync
        with ThreadPoolExecutor(max_workers=15) as executor:
            for result in executor.map(download_task, rows):
                print(result)
                
        print(f"\nSync complete. All covers are now cached in ~/.x360tools/icons/og/")
        
    except Exception as e:
        print(f"Sync error: {e}")

if __name__ == "__main__":
    sync_all()
