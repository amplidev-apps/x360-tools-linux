import urllib.request
import urllib.parse
import re
import os
import json
import sqlite3
import threading
import shutil
from core.converter import GameConverter
from core.utils import get_free_space, format_size

IA_360_IDS = [
    "XBOX_360_1", "XBOX_360_2", "XBOX_360_3", "XBOX_360_4", "XBOX_360_5", "XBOX_360_6", "XBOX_360_1_OTHER",
    "XBOX_360_DLC_1", "XBOX_360_DLC_2", "XBOX_360_DLC_3", "XBOX_360_DLC_4", "XBOX_360_DLC_5", "XBOX_360_DLC_6"
]
IA_CLASSIC_IDS = ["mxogcx-xbox-ztm"]

class FreemarketEngine:
    def __init__(self, cache_dir=None):
        if cache_dir is None:
            self.cache_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "temp", "freemarket")
        else:
            self.cache_dir = cache_dir
        os.makedirs(self.cache_dir, exist_ok=True)
        self.ia_dbs_dir = os.path.join(self.cache_dir, "ia_dbs")
        os.makedirs(self.ia_dbs_dir, exist_ok=True)
        self.cache_file = os.path.join(self.cache_dir, "game_list.json")

    def _detect_dlc_info(self, name):
        """Returns (is_dlc, base_name)."""
        # More aggressive patterns to catch noisy archive names
        dlc_patterns = [
            r"[\s\-:]+dlc\b", 
            r"\bdownloadable content\b",
            r"[\s\-:]+season pass\b",
            r"[\s\-:]+bundle pack\b",
            r"[\s\-:]+pack\b", 
            r"[\s\-:]+expansion\b",
            r"[\s\-:]+add-on\b", 
            r"\baddon\b",
            r"[\s\-:]+content pack\b", 
            r"[\s\-:]+map pack\b",
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
        """Clean archive/redump name for searching (remove (USA), [v1.0], etc)."""
        import html
        name = html.unescape(name)
        clean = re.sub(r'\s*[\(\[].*?[\)\]]', '', name).strip()
        clean = re.sub(r'\s+Disc\s+\d+', '', clean, flags=re.IGNORECASE)
        clean = re.sub(r'\s+v\d+\.\d+', '', clean, flags=re.IGNORECASE)
        return clean

    def fetch_game_list(self, platform="360", force_refresh=False):
        """Fetch game list from IA SQLites."""
        raw_games = []
        
        if not force_refresh:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, "r") as f:
                    try:
                        raw_games_cache = json.load(f)
                        if raw_games_cache and raw_games_cache[0].get("platform") == platform:
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
                        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                        with urllib.request.urlopen(req, timeout=15) as response:
                            with open(db_path, "wb") as f:
                                f.write(response.read())
                    except Exception as e:
                        print(f"Failed to download {ia_id}: {e}", file=sys.stderr)
            
            threads = []
            for ia_id in ids:
                t = threading.Thread(target=download_db, args=(ia_id,))
                t.start()
                threads.append(t)
            for t in threads: t.join()
            
            raw_games = []
            for ia_id in ids:
                db_path = os.path.join(self.ia_dbs_dir, f"{ia_id}_meta.sqlite")
                if not os.path.exists(db_path): continue
                try:
                    conn = sqlite3.connect(db_path, timeout=10)
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
                                
                        if platform != "360":
                            name = name.replace(".", " ")
                        
                        is_dlc, base_name = self._detect_dlc_info(name)
                        raw_games.append({
                            "name": name,
                            "url": f"https://archive.org/download/{ia_id}/{urllib.parse.quote(filename)}",
                            "platform": platform,
                            "is_dlc": is_dlc,
                            "base_game_name": base_name
                        })
                    conn.close()
                except Exception as e:
                    print(f"Error reading DB {ia_id}: {e}", file=sys.stderr)
            
            if raw_games:
                with open(self.cache_file, "w") as f:
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
            meta = meta_service.fast_batch_lookup(item['name'])
            item['titleId'] = meta['TitleID']
            item['coverUrl'] = meta['CoverUrl']
            item['localPath'] = meta['LocalPath']
            item['region'] = meta.get("Region", "Region-Free")
            item['rating'] = meta.get("Rating", "4.8")

        return result_list

    def search_metadata(self, game_name, platform="360"):
        from core.metadata_service import get_service
        meta_service = get_service()
        search_name = self._clean_name(game_name)
        
        # Deep resolution (V43/V47 handles Persistent DB + Scraper Fallback)
        info = meta_service.search_unity_by_name(search_name)
        
        # Standardize for Flutter bridge
        title_id = info.get("TitleID", "Desconhecido")
        cover_url = info.get("CoverUrl")
        
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
            "CoverUrl": cover_url or "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg",
            "Description": tech_sheet,
            "TitleID": title_id,
            "Region": info.get("Region", "Region-Free"),
            "SizeFormatted": "Verifique o dispositivo",
            "Rating": info.get("Rating", "4.8"),
            "TitleUpdates": tus,
            "DLCs": dlcs,
            # Forward individual fields for Flutter rich text (V45)
            "Developer": info.get("Developer"),
            "Publisher": info.get("Publisher"),
            "Genre": info.get("Genre"),
            "ReleaseDate": info.get("ReleaseDate")
        }

    def install_title_update(self, tu_url, tu_name, title_id, dest_drive, progress_cb=None):
        if not title_id or title_id == "Desconhecido":
             if progress_cb: progress_cb("Error: Title ID inválido para instalação de TU.")
             return False

        tu_dir = os.path.join(dest_drive, "Content", "0000000000000000", title_id, "000B0000")
        os.makedirs(tu_dir, exist_ok=True)
        dest_path = os.path.join(tu_dir, tu_name)
        
        try:
            if progress_cb: progress_cb(f"Status: Baixando Title Update {tu_name}...")
            headers = {'User-Agent': 'Mozilla/5.0'}
            req = urllib.request.Request(tu_url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as response:
                total_size = int(response.info().get('Content-Length', 0))
                downloaded = 0
                with open(dest_path, 'wb') as f:
                    while True:
                        chunk = response.read(1024*1024)
                        if not chunk: break
                        f.write(chunk)
                        downloaded += len(chunk)
                        if progress_cb and total_size > 0:
                            percent = int(downloaded * 100 / total_size)
                            progress_cb(f"Progress: {percent}%")
            
            if progress_cb: progress_cb("Status: Title Update instalado com sucesso!")
            return True
        except Exception as e:
            if progress_cb: progress_cb(f"Error: {e}")
            return False

    def download_cover(self, game_name, dest_path):
        try:
            url = "https://raw.githubusercontent.com/x360-tools/assets/main/generic_cover.jpg"
            with open(dest_path, "w") as f:
                f.write("Cover Placeholder")
            return True
        except:
            return False

    def install_game(self, game_url, game_name, platform, dest_dir, on_device=True, progress_cb=None):
        converter = GameConverter()
        temp_dir = os.path.join(self.cache_dir, "install_temp")
        os.makedirs(temp_dir, exist_ok=True)
        temp_archive = os.path.join(temp_dir, "downloaded_game") # extension will be added or implicit

        try:
            # 1. Preliminary Space Check
            if progress_cb: progress_cb("PHASE:Verificando espaço em disco...")
            req = urllib.request.Request(game_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response:
                total_size = int(response.info().get('Content-Length', 0))
            
            free_space = get_free_space(dest_dir)
            required = int(total_size * 2.2) if total_size > 0 else 8 * 1024*1024*1024
            
            if free_space < required:
                raise Exception(f"Espaço insuficiente! Disponível: {format_size(free_space)}, Necessário: {format_size(required)}")

            # 2. Download
            if progress_cb: progress_cb(f"PHASE:Baixando {game_name} ({format_size(total_size)})...")
            downloaded = 0
            block_size = 1024 * 1024
            with urllib.request.urlopen(req) as response:
                # ... download logic ...
                with open(temp_archive, 'wb') as f:
                    while True:
                        buffer = response.read(block_size)
                        if not buffer: break
                        downloaded += len(buffer)
                        f.write(buffer)
                        if progress_cb and total_size > 0:
                            percent = int(downloaded * 100 / total_size)
                            progress_cb(f"Progress: {percent}%")

            # 3. Extraction
            if progress_cb: progress_cb("PHASE:Extraindo arquivos...")
            extract_path = os.path.join(temp_dir, "extracted")
            os.makedirs(extract_path, exist_ok=True)
            converter.extract_archive(temp_archive, extract_path, progress_cb=progress_cb)

            # 4. Find the main game file (ISO or XBE)
            full_iso_path = None
            for root, dirs, files in os.walk(extract_path):
                for f in files:
                    if f.lower().endswith(('.iso', '.xbe', '.xex')):
                        # Prioritize ISO or largest one
                        if not full_iso_path or os.path.getsize(os.path.join(root, f)) > os.path.getsize(full_iso_path):
                            full_iso_path = os.path.join(root, f)
            
            if not full_iso_path:
                raise Exception("Nenhum arquivo de jogo válido (.iso, .xbe, .xex) encontrado no pacote.")

            # 5. Conversion / Installation
            if platform == "360":
                if progress_cb: progress_cb("PHASE:Convertendo para formato GOD (Xbox 360)...")
                # GOD games should preferably go to Content/0000000000000000
                god_dest = os.path.join(dest_dir, "Content", "0000000000000000") if on_device else dest_dir
                os.makedirs(god_dest, exist_ok=True)
                converter.iso_to_god(full_iso_path, god_dest, progress_cb=progress_cb)
            else:
                # Xbox Classic
                if progress_cb: progress_cb("PHASE:Processando jogo Xbox Classic...")
                classic_dest = os.path.join(dest_dir, "Games", game_name) if on_device else os.path.join(dest_dir, game_name)
                os.makedirs(classic_dest, exist_ok=True)
                
                if full_iso_path.lower().endswith(".iso"):
                    if progress_cb: progress_cb("PHASE:Extraindo ISO (Xbox Classic)...")
                    converter.extract_xiso(full_iso_path, classic_dest, progress_cb=progress_cb)
                else:
                    # It's an XBE or ALREADY extracted
                    if progress_cb: progress_cb("PHASE:Copiando arquivos...")
                    # If it's an XBE in a subfolder, move the whole subfolder content
                    src_dir = os.path.dirname(full_iso_path)
                    for item in os.listdir(src_dir):
                        s = os.path.join(src_dir, item)
                        d = os.path.join(classic_dest, item)
                        if os.path.isdir(s):
                            shutil.copytree(s, d, dirs_exist_ok=True)
                        else:
                            shutil.copy2(s, d)

            if progress_cb: progress_cb("PHASE:Instalação concluída com sucesso!")
            return True
        except Exception as e:
            if progress_cb: progress_cb(f"Error: {e}")
            return False
        finally:
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
