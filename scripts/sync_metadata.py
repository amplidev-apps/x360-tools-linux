import sqlite3
import json
import os
import requests
import threading
import sys
import re
from queue import Queue
from core.utils import normalize_for_map

# Configuration
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "applib", "metadata.db")
COVERS_MAP_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "applib", "freemarket_covers_map.json")
GAME_LIST_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "temp", "freemarket", "game_list.json")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Games table
    cur.execute('''
        CREATE TABLE IF NOT EXISTS games (
            title_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            normalized_name TEXT,
            description TEXT,
            developer TEXT,
            publisher TEXT,
            release_date TEXT,
            rating TEXT,
            genre TEXT,
            cover_url TEXT,
            local_path TEXT
        )
    ''')
    
    # Title Updates table
    cur.execute('''
        CREATE TABLE IF NOT EXISTS title_updates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title_id TEXT NOT NULL,
            media_id TEXT,
            version TEXT,
            tu_id TEXT,
            download_url TEXT,
            size TEXT,
            FOREIGN KEY (title_id) REFERENCES games (title_id)
        )
    ''')
    
    # DLCs table
    cur.execute('''
        CREATE TABLE IF NOT EXISTS dlcs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            base_title_id TEXT NOT NULL,
            name TEXT NOT NULL,
            download_url TEXT,
            size TEXT,
            FOREIGN KEY (base_title_id) REFERENCES games (title_id)
        )
    ''')
    
    conn.commit()
    conn.close()
    print(f"[*] Database initialized at {DB_PATH}")

def sync_from_json():
    """Seed the database with names and title_ids from current maps."""
    if not os.path.exists(COVERS_MAP_PATH):
        print("[!] No covers map found to seed from.")
        return

    with open(COVERS_MAP_PATH, 'r') as f:
        covers_map = json.load(f)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    count = 0
    for norm_name, info in covers_map.items():
        tid = info.get("id")
        if not tid or tid == "Desconhecido": continue
        
        # Insert or ignore to keep existing descriptions if we re-run
        cur.execute('''
            INSERT OR IGNORE INTO games (title_id, name, normalized_name, cover_url, rating)
            VALUES (?, ?, ?, ?, ?)
        ''', (tid.upper(), info.get("name", norm_name), norm_name, info.get("boxart"), "4.8"))
        count += 1
    
    conn.commit()
    conn.close()
    print(f"[*] Seeded {count} games from local map.")

def fetch_detailed_info(title_id):
    """Fetch description, developer, publisher from x360db and TUs from Xbox Unity."""
    details = {
        "description": "Disponível para download via x360 Tools Library.",
        "genre": "Ação e Aventura",
        "developer": "Microsoft Studios",
        "publisher": "Microsoft",
        "release_date": "2010"
    }
    
    # Step 1: x360db info.json (V44)
    x360db_url = f"https://raw.githubusercontent.com/xenia-manager/x360db/main/titles/{title_id.upper()}/info.json"
    try:
        resp = requests.get(x360db_url, timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            details["description"] = data.get("description", {}).get("full", details["description"])
            details["developer"] = data.get("developer", details["developer"])
            details["publisher"] = data.get("publisher", details["publisher"])
            details["release_date"] = data.get("release_date", details["release_date"])
            genres = data.get("genre", [])
            if genres:
                details["genre"] = ", ".join(genres)
    except:
        pass

    # Step 2: TUs from Xbox Unity
    tus = []
    tu_url = "https://xboxunity.net/Resources/Lib/TitleUpdateInfo.php"
    headers = {"X-Requested-With": "XMLHttpRequest", "Referer": "https://xboxunity.net/"}
    try:
        resp = requests.get(tu_url, params={"titleid": title_id}, headers=headers, timeout=5, verify=False)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, dict):
                if data.get("Type") == 1 and "MediaIDS" in data:
                    for media in data["MediaIDS"]:
                        for up in media.get("Updates", []):
                            tus.append({
                                "media_id": media.get("MediaID"),
                                "version": up.get("Version"),
                                "tu_id": up.get("TitleUpdateID"),
                                "url": f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={up.get('TitleUpdateID')}"
                            })
                elif data.get("Type") == 2 and "Updates" in data:
                    for up in data["Updates"]:
                        tus.append({
                            "media_id": "Any",
                            "version": up.get("Version"),
                            "tu_id": up.get("TitleUpdateID"),
                            "url": f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={up.get('TitleUpdateID')}"
                        })
    except:
        pass
    
    return details, tus

def sync_details(limit=1350):
    """Main loop to enrich database records."""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    # Find titles that have generic descriptions or are missing them
    cur.execute("SELECT title_id FROM games WHERE description IS NULL OR description = 'Indisponível' OR description LIKE '%download via x360 Tools%'")
    titles = [row[0] for row in cur.fetchall()]
    conn.close()

    if not titles:
        print("[*] All titles are already enriched.")
        return

    print(f"[*] Enriching {min(len(titles), limit)} titles...")
    
    q = Queue()
    results = Queue()
    
    def db_saver():
        conn = sqlite3.connect(DB_PATH)
        while True:
            res = results.get()
            if res is None: break
            tid, info, tus = res
            cur = conn.cursor()
            try:
                cur.execute('''
                    UPDATE games SET 
                        description = ?, genre = ?, developer = ?, publisher = ?, release_date = ?
                    WHERE title_id = ?
                ''', (info['description'], info['genre'], info['developer'], info['publisher'], info['release_date'], tid))
                
                for tu in tus:
                    cur.execute('''
                        INSERT OR IGNORE INTO title_updates (title_id, media_id, version, tu_id, download_url)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (tid, tu['media_id'], tu['version'], tu['tu_id'], tu['url']))
                conn.commit()
            except Exception as e:
                print(f"[!] DB Save error: {e}")
            results.task_done()
        conn.close()

    saver = threading.Thread(target=db_saver)
    saver.start()

    def worker():
        while True:
            tid = q.get()
            if tid is None: break
            try:
                info, tus = fetch_detailed_info(tid)
                results.put((tid, info, tus))
                print(f"[+] Processed {tid}")
            except Exception as e:
                print(f"[!] Error processing {tid}: {e}")
            q.task_done()

    threads = []
    thread_count = 15
    for _ in range(thread_count): 
        t = threading.Thread(target=worker)
        t.start()
        threads.append(t)

    for tid in titles[:limit]:
        q.put(tid)

    q.join()
    for _ in range(thread_count): q.put(None)
    for t in threads: t.join()
    
    # Stop saver
    results.put(None)
    saver.join()
    print(f"[*] Enrichment pass complete.")

def sync_dlcs_from_ia():
    """Scan Archive.org SQLite meta files for DLCs and link them to games."""
    ia_dbs_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "temp", "freemarket", "ia_dbs")
    if not os.path.exists(ia_dbs_path):
        print("[!] No Archive.org DBs found to scan for DLCs.")
        return

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Get all game normalized names for matching
    cur.execute("SELECT title_id, normalized_name FROM games")
    # Sort by length descending to match longest titles first (e.g. "Halo 3" before "Halo")
    games = sorted(cur.fetchall(), key=lambda x: len(x[1]), reverse=True)
    
    dlc_count = 0
    for filename in os.listdir(ia_dbs_path):
        if "_DLC_" in filename and filename.endswith(".sqlite"):
            db_file = os.path.join(ia_dbs_path, filename)
            try:
                ia_conn = sqlite3.connect(db_file)
                ia_cur = ia_conn.cursor()
                ia_cur.execute("SELECT s3key FROM s3api_per_key_metadata")
                for (s3key,) in ia_cur.fetchall():
                    norm_key = normalize_for_map(s3key)
                    
                    # Search for the most specific game match
                    match_found = False
                    for tid, norm_game in games:
                        if norm_key.startswith(norm_game):
                            cur.execute('''
                                INSERT OR IGNORE INTO dlcs (base_title_id, name, download_url)
                                VALUES (?, ?, ?)
                            ''', (tid, s3key.replace(".zip", "").replace(".rar", ""), s3key))
                            dlc_count += 1
                            match_found = True
                            break # Found the longest match
                ia_conn.close()
            except Exception as e:
                print(f"[!] Error reading IA DB {filename}: {e}")

    conn.commit()
    conn.close()
    print(f"[*] Linked {dlc_count} DLCs from Archive.org caches.")

def run_sync():
    init_db()
    sync_from_json()
    sync_details()
    sync_dlcs_from_ia()
    print("[*] All metadata synced successfully.")

if __name__ == "__main__":
    run_sync()
