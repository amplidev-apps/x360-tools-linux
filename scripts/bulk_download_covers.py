import os
import json
import requests
import concurrent.futures
import time

def download_cover(url, title_id, cache_dir):
    if title_id == "Desconhecido" or not url:
        return False
        
    local_path = os.path.join(cache_dir, f"{title_id}.jpg")
    
    # Skip if already exists and is valid
    if os.path.exists(local_path) and os.path.getsize(local_path) > 1024:
        return True
        
    try:
        r = requests.get(url, timeout=10, stream=True, verify=False)
        if r.status_code == 200:
            with open(local_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
    except:
        pass
    return False

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    map_path = os.path.join(base_dir, "applib", "freemarket_covers_map.json")
    cache_dir = os.path.join(base_dir, "applib", "cache", "covers")
    
    if not os.path.exists(cache_dir):
        os.makedirs(cache_dir, exist_ok=True)
        
    if not os.path.exists(map_path):
        print(f"Error: Map not found at {map_path}")
        return

    with open(map_path, "r", encoding="utf-8") as f:
        covers_map = json.load(f)
        
    print(f"Found {len(covers_map)} games in map. Starting bulk download...")
    
    # Deduplicate by TitleID to avoid redundant downloads
    tasks = []
    seen_tids = set()
    for name, data in covers_map.items():
        tid = data.get("id")
        url = data.get("boxart") # Fixed field name
        if tid and url and tid not in seen_tids:
            tasks.append((url, tid))
            seen_tids.add(tid)
            
    print(f"Unique covers to download: {len(tasks)}")
    
    success_count = 0
    total = len(tasks)
    finished = 0
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        future_to_tid = {executor.submit(download_cover, url, tid, cache_dir): tid for url, tid in tasks}
        
        for future in concurrent.futures.as_completed(future_to_tid):
            finished += 1
            if future.result():
                success_count += 1
            
            if finished % 50 == 0:
                print(f"Progress: {finished}/{total} (Success: {success_count})")
                
    print(f"\nDownload finished! Successfully cached {success_count} covers.")
    print(f"Total files in cache: {len(os.listdir(cache_dir))}")

if __name__ == "__main__":
    main()
