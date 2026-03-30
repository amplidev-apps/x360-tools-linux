import os
import json
import re
import requests
import time
import sys
import difflib
import sqlite3
from core.utils import normalize_for_map
from core.og_meta_loader import OGMetadataService

try:
    from deep_translator import GoogleTranslator
except ImportError:
    GoogleTranslator = None

class MetadataService:
    _instance = None
    
    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(MetadataService, cls).__new__(cls)
        return cls._instance

    def __init__(self, cache_dir=None):
        if hasattr(self, '_initialized'): return
        self._initialized = True
        
        # 📂 V110: Hybrid Path Management
        # project_root is where the app is installed (/usr/lib/x360-tools/ or dev dir)
        self.project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        # self.cache_dir is the legacy project root pointer
        self.cache_dir = cache_dir or self.project_root
        
        # 📁 READ-ONLY Assets (shipped with the app)
        self.shipped_applib = os.path.join(self.cache_dir, "applib")
        self.map_path = os.path.join(self.shipped_applib, "freemarket_covers_map.json")
        self.db_path = os.path.join(self.shipped_applib, "metadata.db")
        self.secondary_map_path = os.path.join(self.shipped_applib, "title_ids.json")
        
        # 📁 WRITABLE Cache (~/.x360tools/)
        self.user_dir = os.path.expanduser("~/.x360tools")
        self.user_cache_dir = os.path.join(self.user_dir, "cache")
        os.makedirs(self.user_cache_dir, exist_ok=True)
        os.makedirs(os.path.join(self.user_cache_dir, "covers"), exist_ok=True)
        
        self.cache_path = os.path.join(self.user_cache_dir, "title_cache.json")
        
        self.covers_map = {}
        self.secondary_map = {}
        self._load_maps()
        
        self.cache = self._load_cache()
        self.base_url = "https://dbox.tools/api"
        # In-memory cache for Unity lookups this session
        self._unity_cache = {}

    def translate_text(self, text, target_lang="pt"):
        if not text: return text
        if len(text) < 5: return text # Skip tiny strings
        
        # Map human names to codes
        lang_map = {
            "Português": "pt", "Portuguese": "pt",
            "English": "en", "Español": "es", "Spanish": "es",
            "pt": "pt", "en": "en", "es": "es"
        }
        dest = lang_map.get(target_lang, "pt")

        # 1. Try Deep Translator if available
        if GoogleTranslator:
            try:
                return GoogleTranslator(source='auto', target=dest).translate(text)
            except: pass
        
        # 2. 🛡️ Robust Fallback (V77): Google Translate Web API (No Key Required)
        try:
            import urllib.parse
            # Split text into chunks to avoid URL length limits
            chunks = [text[i:i+1000] for i in range(0, len(text), 1000)]
            translated_chunks = []
            for chunk in chunks:
                url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={dest}&dt=t&q={urllib.parse.quote(chunk)}"
                resp = requests.get(url, timeout=10, verify=False)
                if resp.status_code == 200:
                    data = resp.json()
                    # Response structure: [[["translated", "original", ...], ...]]
                    translated_chunks.append("".join([part[0] for part in data[0] if part[0]]))
                else:
                    translated_chunks.append(chunk) # Fallback to original for this chunk
            return "".join(translated_chunks)
        except Exception as e:
            print(f"Translation Fallback Error: {e}")
            return text

    def _load_cache(self):
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except: pass
        return {}

    def _load_maps(self):
        try:
            # 1. Primary Mapping (V5)
            if os.path.exists(self.map_path):
                with open(self.map_path, "r") as f:
                    self.covers_map = json.load(f)
            
            # 2. Secondary TitleID map (V50)
            if os.path.exists(self.secondary_map_path):
                with open(self.secondary_map_path, "r") as f:
                    data = json.load(f)
                    for item in data:
                        if isinstance(item, dict) and "title" in item and "titleid" in item:
                            n = normalize_for_map(item["title"])
                            self.secondary_map[n] = item["titleid"].upper()
        except Exception as e:
            print(f"Error loading maps: {e}")

    def fast_batch_lookup(self, name, platform="360"):
        """Ultra-fast lookup for grid batch rendering. No I/O, no fuzzy search."""
        norm_name = normalize_for_map(name)
        tid = "Desconhecido"
        url = None
        local_path = None
        
        if platform == "classic":
            # 🎮 OG Xbox Robust Search (V58)
            og_service = OGMetadataService()
            db_path = os.path.join(self.cache_dir, "titleIDs.db")
            if os.path.exists(db_path):
                # Clean name: remove (USA), [ZTM], etc.
                clean = re.sub(r'\(.*?\)|\[.*?\]', '', name)
                clean = re.sub(r'\b(USA|XBOX-ZTM|ZTM|EURO|PAL|NTSC|JAP|JAG|Disc\s*\d+)\b', '', clean, flags=re.IGNORECASE)
                
                # 🛡️ Hyper-Aggressive SQL Pattern (V68)
                # Replace any non-alphanumeric with '%' for maximum LIKE flexibility
                search_pattern = re.sub(r'[^a-zA-Z0-9]', '%', clean)
                search_pattern = re.sub(r'%+', '%', search_pattern).strip('%')
                
                # 📜 Open in read-only mode for packaged builds (V114)
                db_uri = f"file:{db_path}?mode=ro"
                conn = sqlite3.connect(db_uri, uri=True)
                cur = conn.cursor()
                
                # Search Strategy:
                # 1. Try aggressive pattern mapping
                cur.execute("SELECT Title_ID FROM TitleIDs WHERE Full_Name LIKE ? OR AKA LIKE ? LIMIT 1", (f"%{search_pattern}%", f"%{search_pattern}%"))
                row = cur.fetchone()
                
                # 2. Hardcore fallback: Try first 3 words only if still not found
                if not row and len(clean.split()) > 2:
                    short_clean = " ".join(clean.split()[:3])
                    short_pattern = re.sub(r'[^a-zA-Z0-9]', '%', short_clean).strip('%')
                    cur.execute("SELECT Title_ID FROM TitleIDs WHERE Full_Name LIKE ? LIMIT 1", (f"%{short_pattern}%",))
                    row = cur.fetchone()
                
                if row:
                    tid = row[0].upper()
                    local_path = os.path.join(self.cache_dir, "assets", "gamecovers", f"{tid}.png")
                    # 🚀 OG Xbox Cover Fallback (V101: Prioritize MobCat covers for OG Xbox)
                    prefix = tid[:4].upper()
                    url = f"https://raw.githubusercontent.com/MobCat/MobCats-original-xbox-game-list/main/icon/{prefix}/{tid}.png"
                conn.close()
            
            # Final fallback for OG Xbox if no specific TID found
            if tid == "Desconhecido":
                url = "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_classic.jpg"
            
            return {
                "TitleID": tid,
                "CoverUrl": url,
                "LocalPath": local_path,
                "Region": "Region-Free",
                "Rating": "4.8"
            }

        # 1. Primary Mapping (High accuracy - 360)
        mapping = self.covers_map.get(norm_name)
        if mapping:
            tid = mapping.get("id", "Desconhecido")
            url = mapping.get("boxart")
            if url and url.startswith("http://"):
                url = url.replace("http://", "https://")
        
        # 2. Secondary Map (General coverage fallback - V50)
        if tid == "Desconhecido" and norm_name in self.secondary_map:
            tid = self.secondary_map[norm_name]
        
        # 3. Build URLs (Prioritize x360db per user request - V54)
        if tid != "Desconhecido":
            url = f"https://raw.githubusercontent.com/xenia-manager/x360db/main/titles/{tid.upper()}/artwork/boxart.jpg"
        else:
            url = "https://xboxunity.net/Resources/Lib/Images/Covers/4B4D07E2.jpg"

        # Simple path reconstruction without checking file existence (MUCH faster)
        if tid != "Desconhecido":
            local_path = os.path.join(self.user_cache_dir, "covers", f"{tid}.jpg")

        return {
            "TitleID": tid,
            "CoverUrl": url,
            "LocalPath": local_path,
            "Region": "Region-Free",
            "Rating": "4.8" if tid != "Desconhecido" else "4.0"
        }

    def search_unity_by_name(self, name, platform="360", lang="pt"):
        """Search Unity and Cache metadata (The 'Deep' resolution path)."""
        if platform == "classic":
            # 🎮 OG Xbox Robust Search (V65)
            # Clean name: remove (USA), [ZTM], etc.
            clean = re.sub(r'\(.*?\)|\[.*?\]', '', name)
            clean = re.sub(r'\b(USA|XBOX-ZTM|ZTM|EURO|PAL|NTSC|JAP|JAG|Disc\s*\d+)\b', '', clean, flags=re.IGNORECASE)
            
            # 🛡️ Hyper-Aggressive SQL Pattern (V68)
            search_pattern = re.sub(r'[^a-zA-Z0-9]', '%', clean)
            search_pattern = re.sub(r'%+', '%', search_pattern).strip('%')
            
            og_service = OGMetadataService()
            db_path = os.path.join(self.cache_dir, "titleIDs.db")
            row = None
            if os.path.exists(db_path):
                # 📜 Open in read-only mode for packaged builds (V114)
                db_uri = f"file:{db_path}?mode=ro"
                conn = sqlite3.connect(db_uri, uri=True)
                cur = conn.cursor()
                # ⚔️ Dynamic Search (V106): Try exact first, then fuzzy
                cur.execute("SELECT Title_ID, Full_Name, Publisher, Region, Features FROM TitleIDs WHERE Full_Name = ? OR AKA = ? LIMIT 1", (clean.strip(), clean.strip()))
                row = cur.fetchone()
                
                if not row:
                    cur.execute("SELECT Title_ID, Full_Name, Publisher, Region, Features FROM TitleIDs WHERE Full_Name LIKE ? OR AKA LIKE ? LIMIT 1", (f"%{search_pattern}%", f"%{search_pattern}%"))
                    row = cur.fetchone()
                
                # Fallback: First 3 words
                words = clean.split()
                if not row and len(words) > 2:
                    short_pattern = re.sub(r'[^a-zA-Z0-9]', '%', " ".join(words[:3])).strip('%')
                    cur.execute("SELECT Title_ID, Full_Name, Publisher, Region, Features FROM TitleIDs WHERE Full_Name LIKE ? LIMIT 1", (f"%{short_pattern}%",))
                    row = cur.fetchone()
                conn.close()
            
            if row:
                tid = row[0].upper()
                game_name = row[1]
                
                # 🎨 Clean and Professional Technical Sheet (V80)
                # Instead of raw JSON 'Recursos', we show a clean summary
                publisher = row[2] or "Publicadora Clássica"
                region = row[3] or "Region-Free"
                
                features_str = ""
                # Optional: Simple parser for MobCat features if needed, but for now we hide raw JSON
                # features = row[4] # e.g. {"0":[[1,1,1,4],[1,3]...]}
                
                tech_sheet = (
                    f"**Editora:** {publisher}\n"
                    f"**Região:** {region}\n"
                )
                
                # 🕵️ Synopsis Fallback: Search XboxUnity by Name (V77)
                # Many OG games have 360 counterparts, we can fetch their descriptions.
                import urllib.parse
                try:
                    search_url = f"http://xboxunity.net/Resources/Lib/TitleSearch.php"
                    params = {"search": game_name, "apiKey": "EA486DB0B43192E8846A7EB374AD7BED"}
                    resp = requests.get(search_url, params=params, timeout=8)
                    if resp.status_code == 200:
                        data = resp.json()
                        # The Unity PHP API returns a list of games
                        if data and isinstance(data, list) and len(data) > 0:
                            # Try to find a good description in the matches
                            for match in data[:3]: # Check top 3 results
                                synopsis = match.get("Description")
                                if synopsis and len(synopsis) > 50:
                                    tech_sheet = f"{synopsis}\n\n---\nFICHA TÉCNICA (ORIGINAL XBOX):\n{tech_sheet}"
                                    break
                except Exception as e:
                    print(f"Unity Synopsis Fallback Error: {e}")
                
                # 🚀 V82: Professional Fallback (If no synopsis was found)
                if "---\nFICHA TÉCNICA" not in tech_sheet:
                    game_intro = (
                        f"Em {game_name}, os jogadores vivenciam uma experiência fundamental da era Xbox Original. "
                        f"Este título, publicado pela {publisher}, é reconhecido como uma peça essencial para qualquer biblioteca retrô. "
                        f"Reviva este clássico agora com a conveniência e performance do seu PC."
                    )
                    tech_sheet = f"{game_intro}\n\n---\n**FICHA TÉCNICA:**\n{tech_sheet}"
                
                # 🌐 Translate if possible (V85)
                translated_desc = self.translate_text(tech_sheet, lang)
                
                return {
                    "TitleID": tid,
                    "Name": game_name,
                    "Description": translated_desc,
                    "Developer": "Xbox Classic Dev",
                    "Publisher": row[2],
                    "ReleaseDate": "Nov 2001 - 2006",
                    "Rating": "4.8",
                    "Genre": "Classic",
                    "Region": row[3],
                    "CoverUrl": f"https://raw.githubusercontent.com/MobCat/MobCats-original-xbox-game-list/main/icon/{tid[:4].upper()}/{tid}.png",
                    "LocalPath": os.path.join(self.cache_dir, "assets", "gamecovers", f"{tid}.png"),
                    "Source": "OG DB",
                    "TitleUpdates": []
                }

        cache_key = f"{name}_{platform}_{lang}"
        if cache_key in self._unity_cache:
            return self._unity_cache[cache_key]

        # PHASE 1: Try Local SQLite Metadata DB (V43 - Offline First)
        if os.path.exists(self.db_path):
            try:
                # 📜 Open in read-only mode and DISABLE WAL for stability in packages (V114)
                db_uri = f"file:{self.db_path}?mode=ro"
                conn = sqlite3.connect(db_uri, uri=True, timeout=10)
                # Removed problematic WAL pragma from read-only fs
                cur = conn.cursor()
                norm = normalize_for_map(name)
                cur.execute("SELECT * FROM games WHERE title_id = ? OR normalized_name = ? OR name = ?", (name, norm, name))

                row = cur.fetchone()
                if row:
                    # 📜 Ensure description is translated (V78)
                    description = row[3] or "Disponível para download via x360 Tools Library."
                    translated_desc = self.translate_text(description, lang)
                    
                    res = {
                        "TitleID": row[0],
                        "title_id": row[0], # 📜 Alias for UI parity (V109)
                        "Name": row[1],
                        "Description": translated_desc,
                        "Developer": row[4] or "Xbox Studios",
                        "Publisher": row[5] or "Microsoft",
                        "ReleaseDate": row[6] or "2010",
                        "Rating": row[7] or "4.8",
                        "Genre": row[8] or "Ação",
                        "Region": "Region Free",
                        "CoverUrl": row[9],
                        "LocalPath": row[10],
                        "Source": "LOCAL DB",
                        "TitleUpdates": []
                    }
                    # Resolve URLs using FreemarketEngine if they are bare filenames (V105)
                    from core.freemarket import FreemarketEngine
                    engine = FreemarketEngine()
                    
                    # Fetch Title Updates Dynamically (V106)
                    res["TitleUpdates"] = self._fetch_tus_dynamically(res["TitleID"])

                    
                    # Fetch Linked DLCs Dynamically from Freemarket Engine (V106)
                    # This replaces the hardcoded and stale 'dlcs' table in metadata.db
                    res["DLCs"] = engine.find_dlcs_for_game(row[1]) # Pass game name



                    conn.close()
                    # Perform translation if needed (V55)
                    if res.get("Description"):
                        res["Description"] = self.translate_text(res["Description"], lang)
                    
                    self._unity_cache[cache_key] = res
                    return res
                conn.close()
            except Exception as e:
                print(f"[!] SQLite Error: {e}")

        # PHASE 1.5: Check Secondary JSON Map (V118)
        norm = normalize_for_map(name)
        if norm in self.secondary_map:
            tid = self.secondary_map[norm]
            res = {
                "TitleID": tid,
                "title_id": tid,
                "Name": name,
                "Description": "Metadata resolvida via mapeamento local off-line.",
                "Developer": "Unknown",
                "Publisher": "Unknown",
                "ReleaseDate": "Unknown",
                "Rating": "4.5",
                "Genre": "General",
                "Region": "Region Free",
                "CoverUrl": f"https://xboxunity.net/Resources/Lib/Images/Covers/{tid}.jpg",
                "Source": "OFFLINE MAP",
                "TitleUpdates": []
            }
            self._unity_cache[cache_key] = res
            return res

        # PHASE 2: Unity Scraping Fallback (Online) (V108)
        try:
            url = "https://xboxunity.net/Resources/Lib/TitleSearch.php"
            params = {"search": name, "count": 5}
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://xboxunity.net/'
            }
            resp = requests.get(url, params=params, headers=headers, timeout=12, verify=False)
            if resp.status_code == 200:
                data = resp.json()
                if data.get('Items') and len(data['Items']) > 0:
                    item = data['Items'][0]
                    tid = item.get('TitleID', 'Desconhecido')
                    
                    # 📜 Metadata field standardization for maximum UI compatibility (V109)
                    res = {
                        "TitleID": tid,
                        "title_id": tid, # Lowercase/Snake alias for UI
                        "Name": item.get('Name', name),
                        "Description": "Baixado de XboxUnity. Disponível via x360 Tools Library.",
                        "Developer": "Unity Developer",
                        "Publisher": "Xbox Unity",
                        "ReleaseDate": "Unknown",
                        "Rating": "4.5",
                        "Genre": "General",
                        "Region": "Region Free",
                        "CoverUrl": f"https://xboxunity.net/Resources/Lib/Images/Covers/{tid}.jpg",
                        "Source": "UNITY LIVE",
                        "TitleUpdates": self._fetch_tus_dynamically(tid)
                    }
                    
                    # Cache successful online lookup
                    self._unity_cache[cache_key] = res
                    return res
        except Exception as e:
            print(f"[!] Phase 2 Scraper Error: {e}")

        # Final Fallback: use 4B4D07E2.jpg (V41)
        fallback_path = os.path.join(self.cache_dir, "assets", "gamecovers", "4B4D07E2.jpg")
        fallback_res = {
            "TitleID": "Desconhecido",
            "title_id": "Desconhecido",
            "CoverUrl": "https://xboxunity.net/Resources/Lib/Images/Covers/4B4D07E2.jpg",
            "LocalPath": fallback_path if os.path.exists(fallback_path) else None,
            "Name": name,
            "Region": "Region-Free",
            "Rating": "4.0",
            "Source": "FALLBACK 4D5707E1",
            "TitleUpdates": []
        }
        self._unity_cache[cache_key] = fallback_res
        return fallback_res

    def _download_to_cache(self, url, title_id):
        if not url: return None
        if url.startswith("http://"): url = url.replace("http://", "https://")
        dest = os.path.join(self.user_cache_dir, "covers", f"{title_id}.jpg")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.exists(dest): return dest
        try:
            resp = requests.get(url, timeout=10, verify=False)
            if resp.status_code == 200:
                with open(dest, 'wb') as f:
                    f.write(resp.content)
                return dest
        except: pass
        return None

    def _fetch_tus_dynamically(self, title_id):
        """Fetches TUs in real-time from XboxUnity (V106)."""
        if not title_id or title_id == "Desconhecido": return []
        
        try:
            url = "https://xboxunity.net/Resources/Lib/TitleUpdateInfo.php"
            params = {"titleid": title_id}
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Referer': 'https://xboxunity.net/'
            }
            resp = requests.get(url, params=params, headers=headers, timeout=12, verify=False)
            if resp.status_code != 200: return []
            
            data = resp.json()
            tus = []
            
            # Type 1: MediaIDS structure (e.g. GTA V)
            if data.get('Type') == 1 and 'MediaIDS' in data:
                for media in data['MediaIDS']:
                    mid = media.get('MediaID', '')
                    for up in media.get('Updates', []):
                        tu_id = up.get('TitleUpdateID', '')
                        tus.append({
                            "MediaID": mid,
                            "Version": up.get('Version', ''),
                            "TitleUpdateID": tu_id,
                            "downloadUrl": f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={tu_id}"
                        })
            
            # Type 2: Direct Updates structure
            elif data.get('Type') == 2 and 'Updates' in data:
                for up in data['Updates']:
                    tu_id = up.get('TitleUpdateID', '')
                    tus.append({
                        "MediaID": up.get('MediaID', ''),
                        "Version": up.get('Version', ''),
                        "TitleUpdateID": tu_id,
                        "downloadUrl": f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={tu_id}"
                    })
            
            return tus
        except Exception as e:
            print(f"[!] Dynamic TU Fetch Error: {e}")
            return []

    def get_title_updates(self, title_id):
        """Legacy compatibility."""
        return self._fetch_tus_dynamically(title_id)

    def get_dlcs(self, title_id):
        """Legacy compatibility."""
        # First resolve title_id to name if it's an ID
        res = self.search_unity_by_name(title_id)
        return res.get("DLCs", [])


def get_service():
    """Singleton provider."""
    return MetadataService()

def get_title_updates(title_id):
    return get_service().get_title_updates(title_id)
