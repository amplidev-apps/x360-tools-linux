import urllib.request
import urllib.parse
import re
import os
import requests
import json
import sqlite3
import threading
import shutil
import urllib3
import time
import sys


# Suppress SSL warnings so they don't break the Flutter service bridge
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from core.converter import GameConverter
from core.utils import get_free_space, format_size

IA_360_IDS = [
    "XBOX_360_1", "XBOX_360_2", "XBOX_360_3", "XBOX_360_4", "XBOX_360_5", "XBOX_360_6", "XBOX_360_1_OTHER",
    "msx360gcdlc"
]

IA_CLASSIC_IDS = ["mxogcx-xbox-ztm"]

class FreemarketEngine:
    def __init__(self, cache_dir=None):
        # 📂 V110: Hybrid Path Management
        # PROJECT_ROOT is where the app is installed (/usr/lib/x360-tools/ or dev dir)
        self.project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.shipped_dbs_dir = os.path.join(self.project_root, "applib", "ia_dbs")
        
        # USER_DIR is where we store writable cache (~/.x360tools/)
        self.user_dir = os.path.expanduser("~/.x360tools/freemarket")
        self.cache_dir = cache_dir or self.user_dir
        os.makedirs(self.cache_dir, exist_ok=True)
        
        # ia_dbs_dir points to home by default for downloads, but logic will check shipped_dbs first
        self.ia_dbs_dir = os.path.join(self.cache_dir, "ia_dbs")
        os.makedirs(self.ia_dbs_dir, exist_ok=True)
        
        # Per-platform cache files
        self.cache_file_360 = os.path.join(self.cache_dir, "game_list_360_v117.json")
        self.cache_file_classic = os.path.join(self.cache_dir, "game_list_classic_v117.json")
        self.cache_file = self.cache_file_360
        
        # Initialize persistent session
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "en-US,en;q=0.9,pt-BR;q=0.8,pt;q=0.7",
            "Referer": "https://archive.org/"
        })
        
        # Load existing cookies into the session cookie jar (V97)
        self._inject_session_cookies()
        
        # V106: Automatic DB Cleanup (Remove legacy databases no longer in IA_IDS)
        try:
            valid_ids = set(IA_360_IDS + IA_CLASSIC_IDS)
            if os.path.exists(self.ia_dbs_dir):
                for db_name in os.listdir(self.ia_dbs_dir):
                    if db_name.endswith("_meta.sqlite"):
                        ia_id = db_name.replace("_meta.sqlite", "")
                        if ia_id not in valid_ids:
                            print(f"DEBUG: Removing legacy/unsupported IA DB: {ia_id}", file=sys.stderr)
                            os.remove(os.path.join(self.ia_dbs_dir, db_name))
        except Exception as e:
            print(f"Error during legacy DB cleanup: {e}", file=sys.stderr)

        # V103: Task management for Cancel/Pause
        self._stop_events = {} # task_id -> threading.Event

        self._processes = {}   # task_id -> subprocess.Popen
        self._paused_tasks = set()


    def _detect_dlc_info(self, name):
        """Returns (is_dlc, base_name)."""
        # More aggressive patterns to catch noisy archive names
        dlc_patterns = [
            r"[\s\-:\.]+dlc\b", 
            r"\bdownloadable content\b",
            r"[\s\-:\.]+season pass\b",
            r"[\s\-:\.]+bundle pack\b",
            r"[\s\-:\.]+pack\b", 
            r"[\s\-:\.]+expansion\b",
            r"[\s\-:\.]+add-on\b", 
            r"\baddon\b",
            r"[\s\-:\.]+content pack\b", 
            r"[\s\-:\.]+map pack\b",
        ]

        lower_name = name.lower()
        for pattern in dlc_patterns:
            match = re.search(pattern, lower_name, re.IGNORECASE)
            if match:
                base_name = name[:match.start()].strip(" -:").strip()
                if base_name:
                    return True, base_name
        
        # Also check for (DLC) or [DLC] tags
        if re.search(r'[\(\[]DLC[\)\]]', name, re.IGNORECASE):
            base_name = re.sub(r'[\(\[]DLC[\)\]]', '', name, flags=re.IGNORECASE).strip(" -:").strip()
            return True, base_name

        return False, name

    def _clean_name(self, name):
        """Clean archive/redump name for searching (remove (USA), [v1.0], XBOX-ZTM, etc)."""
        import html
        name = html.unescape(name)
        # 1. Remove anything in parentheses or square brackets
        clean = re.sub(r'\s*[\(\[].*?[\)\]]', '', name).strip()
        # 2. Remove common scene/archive tags that might not be in brackets
        tags = r'\b(USA|XBOX|ZTM|XBOX-ZTM|EURO|PAL|NTSC|JAP|JAG|REDUMP|REV|DUMP|Disc\s*\d+)\b'
        clean = re.sub(tags, '', clean, flags=re.IGNORECASE).strip()
        # 3. Final cleanup: Remove all non-alphanumeric at start/end, and collapse middle separators
        clean = re.sub(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$', '', clean)
        clean = re.sub(r'[\s\-:_]+', ' ', clean).strip()
        return clean

    def _resolve_bare_url(self, url):
        """Resolves a bare filename to a full Archive.org URL by searching local IA DBs (V105)"""
        if not url or url.startswith("http"):
            return url
            
        import urllib.parse
        filename = url
        # Search in all IA databases
        if not os.path.exists(self.ia_dbs_dir):
            return url # Fallback to original
            
        for db_name in os.listdir(self.ia_dbs_dir):
            if not db_name.endswith("_meta.sqlite"): continue
            ia_id = db_name.replace("_meta.sqlite", "")
            db_path = os.path.join(self.ia_dbs_dir, db_name)
            try:
                # Use a separate connection to avoid locking issues
                with sqlite3.connect(db_path, timeout=5) as conn:
                    cur = conn.cursor()
                    cur.execute("SELECT s3key FROM s3api_per_key_metadata WHERE s3key = ? LIMIT 1", (filename,))
                    row = cur.fetchone()
                    if row:
                        return f"https://archive.org/download/{ia_id}/{urllib.parse.quote(row[0])}"
            except: pass
        return url # Return original if not found

    def fetch_game_list(self, platform="360", force_refresh=False):

        """Fetch game list from IA SQLites. Uses per-platform cache files (V97)."""
        import sys
        raw_games = []
        
        # V97: Select the correct cache file based on platform
        cache_file = self.cache_file_360 if platform == "360" else self.cache_file_classic
        
        # Also check the old merged cache and migrate if needed
        if not force_refresh and not os.path.exists(cache_file) and os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, "r") as f:
                    old_cache = json.load(f)
                if old_cache and old_cache[0].get("platform") == platform:
                    raw_games = old_cache
                    print(f"DEBUG: Migrating old cache to {cache_file}", file=sys.stderr)
            except:
                pass
        
        if not force_refresh and not raw_games:
            if os.path.exists(cache_file):
                with open(cache_file, "r") as f:
                    try:
                        raw_games_cache = json.load(f)
                        if raw_games_cache:
                            # V72: Emergency Cache Invalidation for OG Xbox
                            if platform == "classic" and any("ZTM" in g.get("name", "") for g in raw_games_cache[:10]):
                                print("DEBUG: Dirty OG cache detected. Forcing refresh...", file=sys.stderr)
                                raw_games = []
                            else:
                                raw_games = raw_games_cache
                    except:
                        pass

        if not raw_games or force_refresh:
            ids = IA_360_IDS if platform == "360" else IA_CLASSIC_IDS
            import sys
            
            def download_db(ia_id):
                db_path = os.path.join(self.ia_dbs_dir, f"{ia_id}_meta.sqlite")
                if not os.path.exists(db_path) or os.path.getsize(db_path) < 1000:
                    url = f"https://archive.org/download/{ia_id}/{ia_id}_meta.sqlite"
                    print(f"Downloading IA DB: {ia_id}...", file=sys.stderr)
                    try:
                        r = self.session.get(url, timeout=15, stream=True)
                        r.raise_for_status()
                        with open(db_path, "wb") as f:
                            for chunk in r.iter_content(chunk_size=1024*1024):
                                f.write(chunk)
                    except Exception as e:
                        print(f"Failed to download {ia_id}: {e}", file=sys.stderr)
            
            # 🚀 Download standard IDs in background NO JOIN (V113)
            # This prevents bridge timeout while catalog is downloading.
            for ia_id in ids:
                t = threading.Thread(target=download_db, args=(ia_id,), daemon=True)
                t.start()
            
            # 📂 Automatic Discovery (Merge shipped + downloaded)
            # Proceed immediately with existing files.
            all_db_files = []
            # Priority 1: Shipped databases (Full release)
            if os.path.exists(self.shipped_dbs_dir):
                for f in os.listdir(self.shipped_dbs_dir):
                    if f.endswith("_meta.sqlite"):
                        all_db_files.append(os.path.join(self.shipped_dbs_dir, f))
            
            # Priority 2: Downloaded databases (Cache)
            if os.path.exists(self.ia_dbs_dir):
                for f in os.listdir(self.ia_dbs_dir):
                    if f.endswith("_meta.sqlite"):
                        path = os.path.join(self.ia_dbs_dir, f)
                        # Avoid duplicates
                        if not any(os.path.basename(p) == f for p in all_db_files):
                            all_db_files.append(path)

            raw_games = []
            for db_path in all_db_files:
                fname = os.path.basename(db_path)
                # 🆔 Extract correct IA Identifier (V116)
                current_ia_id = fname.replace("_meta.sqlite", "")
                
                # 🎮 Determine platform based on DB name
                db_platform = "classic" if ("classic" in fname.lower() or "mxogcx" in fname.lower() or "og" in fname.lower()) else "360"
                
                try:
                    # 📜 Open in read-only mode for packaged builds (V114)
                    db_uri = f"file:{db_path}?mode=ro"
                    conn = sqlite3.connect(db_uri, uri=True, timeout=10)
                    cur = conn.cursor()
                    cur.execute("SELECT s3key FROM s3api_per_key_metadata WHERE s3key LIKE '%.zip' OR s3key LIKE '%.iso' OR s3key LIKE '%.rar' OR s3key LIKE '%.7z'")
                    for row in cur.fetchall():
                        filename = row[0]
                        if isinstance(filename, bytes):
                            filename = filename.decode('utf-8', errors='ignore')
                        
                        name = filename
                        for ext in [".zip", ".iso", ".rar", ".7z"]:
                            if name.lower().endswith(ext):
                                name = name[:-4]
                                
                        # V106: Always replace dots with spaces for a cleaner UI display
                        name = name.replace(".", " ")

                        is_dlc, base_name = self._detect_dlc_info(name)
                        # V117: Preserve slashes in IA URLs to support subdirectories
                        raw_games.append({
                            "name": name,
                            "url": f"https://archive.org/download/{current_ia_id}/{urllib.parse.quote(filename, safe='/')}",
                            "platform": db_platform,
                            "ia_id": current_ia_id,
                            "is_dlc": is_dlc,
                            "base_game_name": base_name
                        })
                    conn.close()
                except Exception as e:
                    print(f"Error reading DB {fname}: {e}", file=sys.stderr)
            
            if raw_games:
                with open(cache_file, "w") as f:
                    json.dump(raw_games, f)
        
        if not raw_games: return []

        grouped = {}
        for game in raw_games:
            if game.get("platform") != platform:
                continue
            
            is_dlc = game.get("is_dlc", False)
            clean = self._clean_name(game['name'])
            if not clean: clean = game['name']
            
            # If it's a DLC, we want it to be a separate entry in the 'games' list 
            # so the Flutter UI can filter it out. If we group it with the base game,
            # it might be shown in the main grid.
            group_key = game['name'] if is_dlc else clean
            
            if group_key not in grouped:
                grouped[group_key] = {
                    "name": clean if not is_dlc else game['name'],
                    "platform": platform,
                    "is_dlc": is_dlc,
                    "base_game_name": game.get("base_game_name", clean),
                    "versions": []
                }
            grouped[group_key]["versions"].append(game)
        
        result_list = list(grouped.values())
        result_list.sort(key=lambda x: x['name'])

        # --- BATCH METADATA RESOLUTION (V27) ---
        # Resolve TitleID and Covers for all games in ONE GO to prevent process spam in the grid.
        from core.metadata_service import get_service
        meta_service = get_service()
        
        for item in result_list:
            # OPTIMIZED: Use fast_batch_lookup for the grid (V35)
            # This handles all fallbacks (including 4D5707E1.jpg) in the MetadataService (V41).
            meta = meta_service.fast_batch_lookup(item['name'], platform=platform)
            item['titleId'] = meta['TitleID']
            item['coverUrl'] = meta['CoverUrl']
            item['localPath'] = meta['LocalPath']
            item['region'] = meta.get("Region", "Region-Free")
            item['rating'] = meta.get("Rating", "4.8")
            
            # V98: Propagate metadata to all versions so specific regions show covers (Naughty Bear Fix)
            for v in item.get('versions', []):
                v['titleId'] = item['titleId']
                v['coverUrl'] = item['coverUrl']
                v['rating'] = item['rating']
                # Region is usually specific to the version, so we keep v.get('region') if available
                if not v.get('region'): v['region'] = item['region']

        return result_list

    def search_metadata(self, game_name, platform="360"):
        from core.metadata_service import get_service
        meta_service = get_service()
        search_name = self._clean_name(game_name)
        
        # Deep resolution (V43/V47 handles Persistent DB + Scraper Fallback)
        info = meta_service.search_unity_by_name(search_name, platform=platform)
        
        # Standardize for Flutter bridge
        title_id = info.get("TitleID", "Desconhecido")
        cover_url = info.get("CoverUrl")
        
        # If search_unity_by_name couldn't resolve TitleID, fall back to fast_batch_lookup
        if not title_id or title_id == "Desconhecido":
            fast = meta_service.fast_batch_lookup(search_name, platform=platform)
            if fast.get("TitleID") and fast["TitleID"] != "Desconhecido":
                title_id = fast["TitleID"]
                if not cover_url:
                    cover_url = fast.get("CoverUrl")

        
        # Build technical description for legacy UI fallback
        tech_sheet = f"DESENVOLVEDOR: {info.get('Developer', 'Microsoft')}\n"
        tech_sheet += f"DISTRIBUIDORA: {info.get('Publisher', 'Microsoft')}\n"
        tech_sheet += f"GÊNERO: {info.get('Genre', 'Ação e Aventura')}\n"
        tech_sheet += f"LANÇAMENTO: {info.get('ReleaseDate', '2010')}\n\n"
        tech_sheet += info.get("Description", f"Game: {game_name}\nPlataforma: {'Xbox 360' if platform == '360' else 'Xbox Classic'}")

        # Ensure DLCs are passed through
        dlcs = info.get("DLCs", [])
        tus = info.get("TitleUpdates", [])

        return {
            "version": "v48-PREMIUM-OFFLINE",
            "coverUrl": cover_url or "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg",
            "description": tech_sheet,
            "titleId": title_id,
            "localPath": info.get("LocalPath"),
            "region": info.get("Region", "Region-Free"),
            "sizeFormatted": "Verifique o dispositivo",
            "rating": info.get("Rating", "4.8"),
            "titleUpdates": tus,
            "dlcs": dlcs,
            # Forward individual fields for Flutter rich text (V45)
            "developer": info.get("Developer"),
            "publisher": info.get("Publisher"),
            "genre": info.get("Genre"),
            "releaseDate": info.get("ReleaseDate")
        }

    def find_dlcs_for_game(self, game_name):
        """Finds DLCs for a game by matching normalized names in the catalog (V106)."""
        import os, json
        from core.utils import normalize_for_map
        
        catalog_path = self.cache_file_360
        if not os.path.exists(catalog_path):
            return []
            
        try:
            with open(catalog_path, "r") as f:
                catalog = json.load(f)
        except:
            return []
            
        norm_target = normalize_for_map(game_name)
        results = []
        for item in catalog:
            if not item.get("is_dlc"): continue
            
            # The is_dlc flag already split the name into base_name (V97)
            # But we re-normalize for maximum compatibility (e.g. V vs 5)
            norm_item = normalize_for_map(item.get("name", ""))
            
            # Match if the game name is part of the dlc name or vice-versa
            if norm_target in norm_item or norm_item in norm_target:
                results.append({
                    "Name": item.get("name"),
                    "DownloadUrl": item.get("url")
                })
        return results

    def _download_threaded(self, url, dest_path, headers, progress_cb, num_threads=32, task_id=None):

        # Resolve final URL and size
        with self.session.get(url, headers=headers, stream=True, timeout=60, verify=False) as r:
            # V106: Detect Archive.org restrictions early
            if r.status_code in (401, 403):
                 raise Exception("Acesso Negado (401/403). Este item é restrito e requer Login do Archive.org ou privilégios especiais.")
            
            r.raise_for_status()
            
            # Diagnostic Peak (V106): Detect Archive.org restrictions and file validity early
            # We read the first 1KB to check Content-Type, HTML errors, and ZIP headers
            head_chunk = next(r.iter_content(chunk_size=1024), b'')
            
            # Check for HTML/XML error pages
            ctype = r.headers.get('Content-Type', '').lower()
            is_html = 'text/html' in ctype or b'<html' in head_chunk.lower() or b'<!doctype html' in head_chunk.lower()
            is_xml = 'application/xml' in ctype or b'<?xml' in head_chunk[:20].lower() or b'<error' in head_chunk[:20].lower()

            if is_html or is_xml:
                 reason = "Redirecionado para Login ou Erro do Archive.org"
                 if b'login' in head_chunk.lower() or 'login' in ctype:
                      reason = "Acesso Negado (Login Requerido no Archive.org)"
                 elif b'access' in head_chunk.lower() or b'restricted' in head_chunk.lower():
                      reason = "Item Restrito ou Inacessível no Archive.org"
                 raise Exception(f"{reason}. Por favor, tente refazer o login ou verifique se o item está disponível publicamente.")

            # Validate ZIP Magic Bytes if it's supposed to be a ZIP
            if url.lower().endswith('.zip') and head_chunk:
                 if not head_chunk.startswith(b'PK'):
                      # Not a ZIP Archive!
                      snippet = head_chunk[:20].decode('utf-8', errors='ignore')
                      raise Exception(f"ERRO: O servidor retornou um arquivo que NÃO é um ZIP válido (Início: '{snippet}'). O download foi interrompido para evitar erros de extração.")

            final_url = r.url
            total_size = int(r.headers.get('Content-Length', 0))
            accept_ranges = r.headers.get('Accept-Ranges', '').lower() == 'bytes'
            
            # If total_size is 0, we can try to get it from the chunk if we have to, 
            # but usually Content-Length is present for valid direct links.


            
        if total_size <= 0 or not accept_ranges or num_threads <= 1:
            # Fallback to single stream
            downloaded = 0
            start_time = time.time()
            last_time = start_time
            last_dw = 0
            with self.session.get(url, headers=headers, stream=True, timeout=60, verify=False) as r:
                r.raise_for_status()
                with open(dest_path, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=1024*1024):
                        if not chunk: break
                        f.write(chunk)
                        downloaded += len(chunk)
                        if progress_cb and total_size > 0:
                            current_time = time.time()
                            if current_time - last_time >= 1.0 or downloaded == total_size:
                                speed_bps = (downloaded - last_dw) / (current_time - last_time) if current_time > last_time else 0
                                speed_mbs = speed_bps / (1024*1024)
                                last_time = current_time
                                last_dw = downloaded
                                percent = min(100.0, downloaded * 100.0 / total_size)
                                progress_cb(f"Progress: {percent:.2f}%|{speed_mbs:.1f} MB/s|{format_size(downloaded)} / {format_size(total_size)}")
            return True

        # Threaded download
        chunk_size = total_size // num_threads
        ranges = []
        for i in range(num_threads):
            start = i * chunk_size
            end = start + chunk_size - 1 if i < num_threads - 1 else total_size - 1
            ranges.append((start, end, f"{dest_path}.part{i}"))

        downloaded = 0
        start_time = time.time()
        last_time = start_time
        last_dw = 0
        lock = threading.Lock()
        has_error = False

        def download_chunk(range_info):
            nonlocal downloaded, last_time, last_dw, has_error
            start, end, part_path = range_info
            chunk_headers = headers.copy()
            chunk_headers['Range'] = f'bytes={start}-{end}'
            
            try:
                # V103 Support Pause (File-based)
                task_dir = os.path.join(self.cache_dir, "install_temp", task_id if task_id else "def")
                stop_flag = os.path.join(task_dir, "stop.flag")
                pause_flag = os.path.join(task_dir, "pause.flag")

                while os.path.exists(pause_flag):
                    if os.path.exists(stop_flag): break
                    time.sleep(1)

                if os.path.exists(stop_flag):
                    has_error = True
                    return

                with self.session.get(final_url, headers=chunk_headers, stream=True, timeout=60, verify=False) as rc:
                    rc.raise_for_status()
                    if rc.status_code == 200 and start > 0:
                        raise Exception("Servidor não suporta retomada/Range para Múltiplas Conexões.")
                    with open(part_path, 'ab') as f:
                        for chunk in rc.iter_content(chunk_size=1024*512):
                            # V103 Check for stop/pause
                            if has_error or os.path.exists(stop_flag):
                                break
                            
                            while os.path.exists(pause_flag):
                                if os.path.exists(stop_flag): break
                                time.sleep(1)
                            
                            if not chunk: break
                            f.write(chunk)
                            with lock:
                                downloaded += len(chunk)
                                if progress_cb:
                                    current_time = time.time()
                                    if current_time - last_time >= 1.0 or downloaded == total_size:
                                        speed_bps = (downloaded - last_dw) / (current_time - last_time) if current_time > last_time else 0
                                        speed_mbs = speed_bps / (1024*1024)
                                        last_time = current_time
                                        last_dw = downloaded
                                        percent = min(100.0, downloaded * 100.0 / total_size)
                                        progress_cb(f"Progress: {percent:.2f}%|{speed_mbs:.1f} MB/s|{format_size(downloaded)} / {format_size(total_size)}")
            except Exception as e:
                has_error = True
                raise e

        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures = [executor.submit(download_chunk, r) for r in ranges]
            for future in concurrent.futures.as_completed(futures):
                future.result()

        if not has_error:
            if progress_cb: progress_cb("PHASE:Finalizando download (I/O)...")
            with open(dest_path, 'wb') as outfile:
                for i in range(num_threads):
                    part_path = f"{dest_path}.part{i}"
                    with open(part_path, 'rb') as infile:
                        shutil.copyfileobj(infile, outfile, length=1024*1024*2)
                    os.remove(part_path)
            
            # V102: Robust Login Detection (Detect if we downloaded an HTML/Login page instead of game)
            try:
                with open(dest_path, "rb") as f:
                    header = f.read(1024).decode('utf-8', errors='ignore').lower()
                    if "<!doctype html" in header or "<html" in header or "login" in header:
                        os.remove(dest_path)
                        raise Exception("Acesso Negado ou Redirecionamento. Por favor, faça login no Archive.org no botão acima.")
                    # Also check for minimum size for a game (V102)
                    f.seek(0, 2)
                    if f.tell() < 1024 * 1024:
                        os.remove(dest_path)
                        raise Exception("Arquivo baixado é muito pequeno. Download pode estar bloqueado ou corrompido.")
            except Exception as e:
                if "login" in str(e).lower(): raise e
                pass

        return True

    def install_title_update(self, tu_url, tu_name, title_id, dest_drive, progress_cb=None):
        # Resolve bare URL if needed (V105)
        tu_url = self._resolve_bare_url(tu_url)
        
        has_error = False

        if not title_id or title_id == "Desconhecido":
             if progress_cb: progress_cb("Error: Title ID inválido para instalação de TU.")
             return False

        tu_dir = os.path.join(dest_drive, "Content", "0000000000000000", title_id, "000B0000")
        os.makedirs(tu_dir, exist_ok=True)
        dest_path = os.path.join(tu_dir, tu_name)
        
        # V106: Use unique temp path to prevent race conditions during parallel TU installs
        import uuid
        temp_dest = os.path.join(self.cache_dir, f"tu_temp_{str(uuid.uuid4())[:8]}")
        
        # V99: Progress scaling (TU: 0-90% download, 90-100% install)
        def tu_wrapped_cb(msg):
            if not progress_cb: return
            if msg.startswith("Progress:"):
                # "Progress: 50.0%|1.2 MB/s|00:05"
                try:
                    parts = msg.split("|")
                    p_orig = float(parts[0].replace("Progress:", "").replace("%", "").strip())
                    p_scaled = p_orig * 0.9 # Scale 0-100 to 0-90
                    progress_cb(f"Progress: {p_scaled:.1f}%|{parts[1]}|{parts[2]}")
                except:
                    progress_cb(msg)
            else:
                progress_cb(msg)

        try:
            if progress_cb: progress_cb(f"PHASE:Baixando Title Update {tu_name}...")
            headers = self._get_headers(tu_url)
            self._download_threaded(tu_url, temp_dest, headers, tu_wrapped_cb, num_threads=32)
            
            if progress_cb: progress_cb("Progress: 100.0%|Finalizado|--:--")
            if progress_cb: progress_cb("PHASE:Finalizando Title Update...")
            
            # Move from temp to final destination
            if os.path.exists(dest_path): os.remove(dest_path)
            shutil.move(temp_dest, dest_path)
            
            if progress_cb: progress_cb("PHASE:Title Update instalado com sucesso!")
            return True
        except Exception as e:
            if os.path.exists(temp_dest): os.remove(temp_dest)
            if progress_cb: progress_cb(f"PHASE:Erro: {e}")
            return False

    def install_dlc(self, dlc_url, dlc_name, title_id, dest_drive, progress_cb=None, task_id=None):
        # Resolve bare URL if needed (V105)
        dlc_url = self._resolve_bare_url(dlc_url)
        
        has_error = False
        if not title_id or title_id == "Desconhecido":
             if progress_cb: progress_cb("PHASE:Erro: Title ID inválido para instalação de DLC.")
             return False

        dlc_dest_dir = os.path.join(dest_drive, "Content", "0000000000000000", title_id, "00000002")
        os.makedirs(dlc_dest_dir, exist_ok=True)
        
        import uuid
        install_id = task_id or str(uuid.uuid4())[:8]
        temp_dir = os.path.join(self.cache_dir, f"dlc_temp_{install_id}")
        os.makedirs(temp_dir, exist_ok=True)
        # Fallback to display name if URL resolution fails later
        temp_archive = os.path.join(temp_dir, dlc_name)


        # V99: Progress scaling (DLC: 0-80% download, 80-100% extraction)
        def dlc_wrapped_cb(msg):
            if not progress_cb: return
            if msg.startswith("Progress:"):
                try:
                    parts = msg.split("|")
                    p_orig = float(parts[0].replace("Progress:", "").replace("%", "").strip())
                    p_scaled = p_orig * 0.8 # Scale 0-100 to 0-80
                    progress_cb(f"Progress: {p_scaled:.1f}%|{parts[1]}|{parts[2]}")
                except:
                    progress_cb(msg)
            else:
                progress_cb(msg)

        # Derive real filename and extension from the download URL (display name has no extension)
        from urllib.parse import urlparse, unquote
        url_path = unquote(urlparse(dlc_url).path)
        url_filename = os.path.basename(url_path)  # e.g. "London Map Pack (World) (Addon).zip"
        _, url_ext = os.path.splitext(url_filename)  # e.g. ".zip"

        # Use the URL filename as the temp archive name (preserves extension for extraction)
        if url_filename:
            temp_archive = os.path.join(temp_dir, url_filename)
        # else temp_archive already set above (fallback)

        try:
            # 1. Download
            if progress_cb: progress_cb(f"PHASE:Baixando DLC {dlc_name}...")
            headers = self._get_headers(dlc_url)
            self._download_threaded(dlc_url, temp_archive, headers, dlc_wrapped_cb, num_threads=32)
            
            # V102: Robust Login Detection (Detect if we downloaded an HTML/Login page instead of archive)
            try:
                with open(temp_archive, "rb") as f:
                    header = f.read(1024).decode('utf-8', errors='ignore').lower()
                    if "<!doctype html" in header or "<html" in header or "login" in header:
                        os.remove(temp_archive)
                        raise Exception("Acesso Negado ou Redirecionamento. Por favor, faça login no Archive.org no botão acima ou verifique se o item está disponível.")
                    # Also check for minimum size for a DLC (V102)
                    f.seek(0, 2)
                    if f.tell() < 1024 * 10: # Minimum 10KB
                        os.remove(temp_archive)
                        raise Exception(f"Arquivo da DLC é muito pequeno ({f.tell()} bytes). Download bloqueado ou arquivo inexistente no Archive.org.")
            except Exception as e:
                if "login" in str(e).lower() or "bloqueado" in str(e).lower(): raise e
                pass

            # 2. Check if it's an archive — use URL extension, NOT dlc_name

            if url_ext.lower() in ('.zip', '.rar', '.7z'):
                if progress_cb: progress_cb("PHASE:Extraindo DLC...")
                if progress_cb: progress_cb("Progress: 90.0%|I/O|--:--")
                converter = GameConverter()
                extract_path = os.path.join(temp_dir, "extracted")
                os.makedirs(extract_path, exist_ok=True)
                converter.extract_archive(temp_archive, extract_path, progress_cb=progress_cb)
                
                if progress_cb: progress_cb("PHASE:Copiando arquivos da DLC...")
                # Move all files to Content/.../00000002/
                for root, dirs, files in os.walk(extract_path):
                    for f in files:
                        src = os.path.join(root, f)
                        dst = os.path.join(dlc_dest_dir, f)
                        shutil.copy2(src, dst)
            else:
                # Direct file copy (raw STFS or unknown format)
                if progress_cb: progress_cb("PHASE:Instalando arquivo de DLC...")
                dest_filename = url_filename if url_filename else dlc_name
                shutil.copy2(temp_archive, os.path.join(dlc_dest_dir, dest_filename))


            if progress_cb: progress_cb("PHASE:DLC instalada com sucesso!")
            return True
        except Exception as e:
            has_error = True
            if progress_cb: progress_cb(f"PHASE:Erro: {e}")
            return False
        finally:
            if not has_error and os.path.exists(temp_dir):
                try: shutil.rmtree(temp_dir)
                except: pass

    def install_tu(self, tu_url, tu_name, title_id, dest_drive, progress_cb=None, task_id=None):
        """Installs a Title Update (TU) to the correct device directory."""
        has_error = False
        if not title_id or title_id == "Desconhecido":
             if progress_cb: progress_cb("PHASE:Erro: Title ID inválido para instalação de TU.")
             return False

        # TU Destination: Content/0000000000000000/<TitleID>/000B0000/
        tu_dest_dir = os.path.join(dest_drive, "Content", "0000000000000000", title_id, "000B0000")
        os.makedirs(tu_dest_dir, exist_ok=True)
        
        import uuid
        temp_id = f"tu_temp_{str(uuid.uuid4())[:8]}"
        temp_dir = os.path.join(self.cache_dir, temp_id)
        os.makedirs(temp_dir, exist_ok=True)
        temp_file = os.path.join(temp_dir, tu_name)

        try:
            # 1. Download (TU is usually a single small file)
            if progress_cb: progress_cb(f"PHASE:Baixando Title Update {tu_name}...")
            
            # V106: Add specific Referer for XboxUnity if needed
            headers = self._get_headers(tu_url)
            if "xboxunity.net" in tu_url:
                headers['Referer'] = 'https://xboxunity.net/'
                headers['X-Requested-With'] = 'XMLHttpRequest'

            # Use multi-threaded download even for TU to ensure speed from Archive.org
            self._download_threaded(tu_url, temp_file, headers, progress_cb, num_threads=16)
            
            # 2. Install (Move to final destination)
            if progress_cb: progress_cb("PHASE:Instalando Title Update...")
            final_path = os.path.join(tu_dest_dir, tu_name)
            shutil.copy2(temp_file, final_path)

            if progress_cb: progress_cb("PHASE:Title Update instalada com sucesso!")
            return True
        except Exception as e:
            has_error = True
            if progress_cb: progress_cb(f"PHASE:Erro: {e}")
            return False
        finally:
            if os.path.exists(temp_dir):
                try: shutil.rmtree(temp_dir)
                except: pass


    def download_cover(self, game_name, dest_path):
        try:
            url = "https://raw.githubusercontent.com/x360-tools/assets/main/generic_cover.jpg"
            with open(dest_path, "w") as f:
                f.write("Cover Placeholder")
            return True
        except:
            return False

    def _check_archive_login(self, response_text):
        """Minimal check for login/restriction indicators in HTML responses."""
        if not response_text: return False
        lower_text = response_text.lower()
        # V106: Expanded detection for 403 Forbidden redirects and standard login forms
        indicators = ["login", "email", 'type="password"', "sign in", "restricted", "log in"]
        return any(ind in lower_text for ind in indicators)

    def login_ia(self, email, password):
        """Programmatically authenticates with Archive.org using the modern JSON API."""
        api_url = "https://archive.org/services/account/login/"
        login_page = "https://archive.org/account/login"
        
        session = requests.Session()
        session.headers.update({
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Origin": "https://archive.org",
            "Referer": login_page,
            "X-Requested-With": "XMLHttpRequest"
        })
        
        try:
            # 1. Get the login page first to initialize session/cookies
            session.get(login_page, timeout=15)
            
            # 2. Get the CSRF token from the services endpoint
            r_token = session.get(api_url, timeout=15)
            csrf_token = None
            try:
                token_data = r_token.json()
                csrf_token = token_data.get("value", {}).get("token")
            except:
                pass
            
            if not csrf_token:
                # Fallback to HTML scraping for token if API fails
                r_html = session.get(login_page, timeout=15)
                import re
                match = re.search(r'window\.ArchiveAccount\s*=\s*\{[^}]*t:\s*\'([^\']+)\'', r_html.text)
                if match:
                    csrf_token = match.group(1)
            
            if not csrf_token:
                return False, "Não foi possível obter o token de segurança (CSRF)."

            # 3. Post login with JSON payload
            payload = {
                "username": email,
                "password": password,
                "remember": "true",
                "t": csrf_token
            }
            
            r = session.post(api_url, json=payload, timeout=20)
            res_data = r.json()
            
            if res_data.get("success", False):
                # Persistence (V106): Save cookies to a file for the downloader
                cookie_json = os.path.join(self.cache_dir, "ia_cookies.json")
                with open(cookie_json, "w") as f:
                    json.dump(requests.utils.dict_from_cookiejar(session.cookies), f)
                
                # Also update current engine session
                self._inject_session_cookies()
                return True, "Login realizado com sucesso!"
            else:
                reason = res_data.get("value", {}).get("reason", "E-mail ou senha incorretos.")
                return False, f"Falha na autenticação: {reason}"
                
        except Exception as e:
            return False, f"Erro na conexão com Archive.org: {str(e)}"

    def _load_cookie(self):
        """Loads Archive.org cookies from JSON (modern) or TXT (legacy)."""
        json_path = os.path.join(self.cache_dir, "ia_cookies.json")
        legacy_txt_path = os.path.expanduser("~/.x360tools/ia_cookie.txt")
        
        # 1. Try Modern JSON (Full Jar)
        if os.path.exists(json_path):
            try:
                with open(json_path, "r") as f:
                    return json.load(f)
            except: pass
            
        # 2. Try Legacy TXT (Raw String)
        if os.path.exists(legacy_txt_path):
            try:
                with open(legacy_txt_path, "r") as f:
                    raw = f.read().strip()
                    # Convert raw string to a simple dict if it looks like cookies
                    if "=" in raw:
                        cookies = {}
                        for part in raw.split(";"):
                            if "=" in part:
                                k, _, v = part.strip().partition("=")
                                cookies[k] = v
                        return cookies
            except: pass
        return None

    def _inject_session_cookies(self):
        """Injects saved cookies into the session jar for all Archive.org domains."""
        cookies_dict = self._load_cookie()
        if not cookies_dict:
            return
            
        # If it's a dict (from JSON or parsed TXT), inject properly
        if isinstance(cookies_dict, dict):
            for name, value in cookies_dict.items():
                # Set for main and all subdomains (dn720002.ca.archive.org, etc)
                self.session.cookies.set(name, value, domain="archive.org")
                self.session.cookies.set(name, value, domain=".archive.org")
                # Also set specifically for common CDNs (Archive.org specific logic)
                for i in range(1, 15):
                    self.session.cookies.set(name, value, domain=f"dn72{str(i).zfill(4)}.ca.archive.org")


    def _get_headers(self, url):
        """Generates browser-like headers for Archive.org stability."""
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Connection': 'keep-alive',
        }
        
        # Add user cookie if available (V95)
        cookies_dict = self._load_cookie()
        if cookies_dict and isinstance(cookies_dict, dict):
            # Convert dict to "key=value; key2=value2" string
            cookie_str = "; ".join([f"{k}={v}" for k, v in cookies_dict.items()])
            headers['Cookie'] = cookie_str

        # Try to extract Archive.org identifier for Referer
        if "archive.org/download/" in url:
            try:
                parts = url.split('/')
                # url is usually .../download/IDENTIFIER/FILENAME
                idx = parts.index("download")
                identifier = parts[idx+1]
                headers['Referer'] = f"https://archive.org/details/{identifier}"
            except:
                headers['Referer'] = "https://archive.org/"
        return headers

    def cancel_task(self, task_id):
        if task_id in self._stop_events:
            self._stop_events[task_id].set()
        if task_id in self._processes:
            try: self._processes[task_id].terminate()
            except: pass
        if task_id in self._paused_tasks:
            self._paused_tasks.remove(task_id)

    def pause_task(self, task_id):
        self._paused_tasks.add(task_id)

    def resume_task(self, task_id):
        if task_id in self._paused_tasks:
            self._paused_tasks.remove(task_id)

    def install_game(self, game_url, game_name, platform, dest_dir, on_device=True, progress_cb=None, task_id=None):
        has_error = False
        converter = GameConverter()
        
        temp_dir = os.path.join(self.cache_dir, "install_temp", task_id if task_id else "def")
        os.makedirs(temp_dir, exist_ok=True)
        temp_archive = os.path.join(temp_dir, "downloaded_game")
        
        stop_flag = os.path.join(temp_dir, "stop.flag")
        pid_file = os.path.join(temp_dir, "pid.txt")

        # Record bridge PID
        with open(pid_file, "w") as f: f.write(str(os.getpid()))

        try:
            # 1. Preliminary Space Check
            if progress_cb: progress_cb("PHASE:Verificando espaço em disco...")
            
            headers = self._get_headers(game_url)
            total_size = 0
            try:
                # Use engine session for HEAD to handle cookies/redirects (V98)
                with self.session.head(game_url, headers=headers, timeout=15, allow_redirects=True, verify=False) as r:
                    total_size = int(r.headers.get('Content-Length', 0))
            except:
                try:
                    with self.session.get(game_url, headers=headers, timeout=15, stream=True, verify=False) as r:
                        total_size = int(r.headers.get('Content-Length', 0))
                except:
                    pass

            # A. Check Local PC space
            pc_free = get_free_space(temp_dir)
            pc_required = int(total_size * 2.1) if total_size > 0 else 8 * 1024*1024*1024
            if pc_free < pc_required:
                raise Exception(f"Espaço insuficiente no PC! Disponível: {format_size(pc_free)}, Necessário: {format_size(pc_required)}")

            # B. Check Target Device space
            if on_device:
                target_free = get_free_space(dest_dir)
                target_required = int(total_size * 1.1) if total_size > 0 else 7 * 1024*1024*1024
                if target_free < target_required:
                    raise Exception(f"Espaço insuficiente no Dispositivo! Disponível: {format_size(target_free)}, Necessário: {format_size(target_required)}")

            # V99: Progress scaling (Game: 0-60% download, 60-80% extraction, 80-100% conversion)
            def game_download_cb(msg):
                if not progress_cb: return
                if msg.startswith("Progress:"):
                    try:
                        parts = msg.split("|")
                        p_orig = float(parts[0].replace("Progress:", "").replace("%", "").strip())
                        p_scaled = p_orig * 0.6 # Scale 0-100 to 0-60
                        progress_cb(f"Progress: {p_scaled:.1f}%|{parts[1]}|{parts[2]}")
                    except:
                        progress_cb(msg)
                else:
                    progress_cb(msg)

            # 2. Download
            if progress_cb: progress_cb(f"PHASE:Baixando {game_name}...")
            
            # Use engine session to ensure cookies are passed (V96)
            headers = self._get_headers(game_url)
            
            # V106: Advance Redirect/Login detector before full threaded download
            # If Archive.org gives 403 or HTML instead of binary, it means we must login.
            try:
                with self.session.get(game_url, headers=headers, stream=True, timeout=15, verify=False) as r:
                    if r.status_code == 403 or r.status_code == 401:
                        raise Exception("Acesso Negado (403/401). Este jogo é restrito e requer Login do Archive.org.")
                    
                    ctype = r.headers.get('Content-Type', '').lower()
                    if 'text/html' in ctype:
                        # Inspect HTML content for login cues
                        first_chunk = next(r.iter_content(chunk_size=4096)).decode('utf-8', errors='ignore')
                        if self._check_archive_login(first_chunk):
                            raise Exception("Redirecionado para Login. Por favor, autentique com seu e-mail do Archive.org.")
            except Exception as e:
                if "Login" in str(e) or "Acesso Negado" in str(e): raise e
                pass

            self._download_threaded(game_url, temp_archive, headers, game_download_cb, num_threads=32, task_id=task_id)

            if os.path.exists(stop_flag):
                raise Exception("Download Cancelado pelo Usuário.")

            # 3. Extraction
            if progress_cb: progress_cb("PHASE:Extraindo arquivos...")
            if progress_cb: progress_cb("Progress: 65.0%|I/O|--:--")
            
            extract_path = os.path.join(temp_dir, "extracted")
            if os.path.exists(extract_path): shutil.rmtree(extract_path)
            os.makedirs(extract_path, exist_ok=True)
            
            # V103 Process tracking
            def pc(proc):
                with open(pid_file, "a") as f: f.write(f"\n{proc.pid}")

            # V106: Detect RAR to provide better error guidance on DFSG systems
            is_rar_file = game_url.lower().split('?')[0].endswith('.rar')
            converter.extract_archive(temp_archive, extract_path, process_callback=pc, is_rar=is_rar_file)
            
            if os.path.exists(stop_flag):
                raise Exception("Download Cancelado pelo Usuário.")

            if progress_cb: progress_cb("Progress: 80.0%|Finalizando I/O|--:--")
            
            # V88 Clean intermediate ZIP to free PC space for conversion
            try: os.remove(temp_archive)
            except: pass

            # 4. Find the main game file (ISO or XBE)
            full_iso_path = None
            for root, dirs, files in os.walk(extract_path):
                for f in files:
                    if f.lower().endswith(('.iso', '.xbe', '.xex')):
                        # Prioritize ISO or largest one
                        current_path = os.path.join(root, f)
                        if not full_iso_path or os.path.getsize(current_path) > os.path.getsize(full_iso_path):
                            full_iso_path = current_path
            
            if not full_iso_path:
                raise Exception("Nenhum arquivo de jogo válido (.iso, .xbe, .xex) encontrado no pacote.")

            # 5. Conversion / Installation
            is_ftp = dest_dir.startswith("ftp://")

            if platform == "360":
                if progress_cb: progress_cb("PHASE:Convertendo para formato GOD (Xbox 360)...")
                if is_ftp:
                    god_dest = os.path.join(temp_dir, "god_output")
                else:
                    god_dest = os.path.join(dest_dir, "Content", "0000000000000000") if on_device else dest_dir
                
                os.makedirs(god_dest, exist_ok=True)
                
                def god_cb(line):
                    # iso2god output can be parsed, for now we do a simple mapping
                    if progress_cb: progress_cb("Progress: 85.0%|Convertendo|--:--")
                
                converter.iso_to_god(full_iso_path, god_dest, progress_cb=god_cb, process_callback=pc)
                
                if is_ftp:
                    if progress_cb: progress_cb("Progress: 90.0%|Subindo via FTP|--:--")
                    self._upload_folder_ftp(god_dest, dest_dir.replace("ftp://", ""), "/Hdd1/Content/0000000000000000", progress_cb)
                
                if progress_cb: progress_cb(f"LocalPath:{god_dest}")
                if progress_cb: progress_cb("Progress: 100.0%|Finalizado|--:--")
            else:
                # Xbox Classic
                if progress_cb: progress_cb("PHASE:Processando jogo Xbox Classic...")
                
                if is_ftp:
                    classic_dest = os.path.join(temp_dir, "classic_output", game_name)
                else:
                    classic_dest = os.path.join(dest_dir, "Games", game_name) if on_device else os.path.join(dest_dir, game_name)
                    
                os.makedirs(classic_dest, exist_ok=True)
                
                if full_iso_path.lower().endswith(".iso"):
                    if progress_cb: progress_cb("PHASE:Extraindo ISO (Xbox Classic)...")
                    if progress_cb: progress_cb("Progress: 85.0%|Extraindo ISO|--:--")
                    converter.extract_xiso(full_iso_path, classic_dest, progress_cb=progress_cb, process_callback=pc)
                else:
                    if progress_cb: progress_cb("PHASE:Copiando arquivos...")
                    if progress_cb: progress_cb("Progress: 85.0%|Copiando|--:--")
                    src_dir = os.path.dirname(full_iso_path)
                    for item in os.listdir(src_dir):
                        s = os.path.join(src_dir, item)
                        d = os.path.join(classic_dest, item)
                        if os.path.isdir(s):
                            shutil.copytree(s, d, dirs_exist_ok=True)
                        else:
                            shutil.copy2(s, d)
                
                if is_ftp:
                    if progress_cb: progress_cb("Progress: 95.0%|Subindo via FTP|--:--")
                    self._upload_folder_ftp(classic_dest, dest_dir.replace("ftp://", ""), f"/Hdd1/Games/{game_name}", progress_cb)
                
                if progress_cb: progress_cb(f"LocalPath:{classic_dest}")
                if progress_cb: progress_cb("Progress: 100.0%|Finalizado|--:--")

            if progress_cb: progress_cb("PHASE:Instalação concluída com sucesso!")
            return True
        except Exception as e:
            has_error = True
            if progress_cb: progress_cb(f"PHASE:Erro: {e}")
            return False
        finally:
            if not has_error and os.path.exists(temp_dir):
                try: shutil.rmtree(temp_dir)
                except: pass

    def _upload_folder_ftp(self, local_folder, host, remote_base, progress_cb=None):
        if progress_cb: progress_cb(f"PHASE:Enviando via FTP para {host}...")
        from core.ftp_client import XboxFTPClient
        ftp = XboxFTPClient(host)
        
        conn = ftp.connect()
        if conn["status"] != "success":
            raise Exception(f"Falha ao conectar via FTP: {conn['message']}")
            
        try:
            for root, dirs, files in os.walk(local_folder):
                rel_path = os.path.relpath(root, local_folder)
                if rel_path == ".":
                    remote_dir = remote_base
                else:
                    remote_dir = f"{remote_base}/{rel_path.replace(os.sep, '/')}"
                    
                # Try to create directory tree on FTP
                parts = remote_dir.split('/')
                cur = ""
                for p in parts:
                    if not p: continue
                    cur += "/" + p
                    try: ftp.mkdir(cur)
                    except: pass
                
                for f in files:
                    local_f = os.path.join(root, f)
                    if progress_cb: progress_cb(f"PHASE:Enviando {f}...")
                    ftp.upload_file(local_f, remote_dir)
        finally:
            ftp.disconnect()
