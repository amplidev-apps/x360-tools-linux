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
        
        # Use absolute path relative to this file to avoid CWD issues (V47)
        self.cache_dir = cache_dir or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.cache_path = os.path.join(self.cache_dir, "applib", "title_cache.json")
        self.map_path = os.path.join(self.cache_dir, "applib", "freemarket_covers_map.json")
        self.db_path = os.path.join(self.cache_dir, "applib", "metadata.db")
        self.secondary_map_path = os.path.join(self.cache_dir, "applib", "title_ids.json")
        
        self.covers_map = {}
        self.secondary_map = {}
        os.makedirs(os.path.dirname(self.cache_path), exist_ok=True)
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
                
                conn = sqlite3.connect(db_path)
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
            local_path = os.path.join(self.cache_dir, "applib", "cache", "covers", f"{tid}.jpg")

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
                conn = sqlite3.connect(db_path)
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
                conn = sqlite3.connect(self.db_path, timeout=10)
                conn.execute("PRAGMA journal_mode=WAL;")
                cur = conn.cursor()
                norm = normalize_for_map(name)
                cur.execute("SELECT * FROM games WHERE normalized_name = ? OR name = ?", (norm, name))
                row = cur.fetchone()
                if row:
                    # 📜 Ensure description is translated (V78)
                    description = row[3] or "Disponível para download via x360 Tools Library."
                    translated_desc = self.translate_text(description, lang)
                    
                    res = {
                        "TitleID": row[0],
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
                    cur.execute("SELECT media_id, version, tu_id, download_url FROM title_updates WHERE title_id = ?", (row[0],))
                    for tu in cur.fetchall():
                        res["TitleUpdates"].append({
                            "MediaID": tu[0], "Version": tu[1], "TitleUpdateID": tu[2], "downloadUrl": tu[3]
                        })
                    
                    # Fetch Linked DLCs (V45)
                    res["DLCs"] = []
                    cur.execute("SELECT name, download_url FROM dlcs WHERE base_title_id = ?", (row[0],))
                    for dlc in cur.fetchall():
                        res["DLCs"].append({
                            "Name": dlc[0],
                            "DownloadUrl": dlc[1]
                        })

                    conn.close()
                    # Perform translation if needed (V55)
                    if res.get("Description"):
                        res["Description"] = self.translate_text(res["Description"], lang)
                    
                    self._unity_cache[cache_key] = res
                    return res
                conn.close()
            except Exception as e:
                print(f"[!] SQLite Error: {e}")

        # PHASE 2: Unity Scraping Fallback (Online)
        # Final Fallback: use 4B4D07E2.jpg (V41)
        fallback_path = os.path.join(self.cache_dir, "assets", "gamecovers", "4B4D07E2.jpg")
        fallback_res = {
            "TitleID": "Desconhecido",
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
        dest = os.path.join(self.cache_dir, "applib", "cache", "covers", f"{title_id}.jpg")
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

    def get_title_updates(self, title_id):
        """Legacy compatibility."""
        res = self.search_unity_by_name(title_id)
        return res.get("TitleUpdates", [])

    def get_dlcs(self, title_id):
        """Legacy compatibility."""
        res = self.search_unity_by_name(title_id)
        return res.get("DLCs", [])

def get_service():
    """Singleton provider."""
    return MetadataService()

def get_title_updates(title_id):
    return get_service().get_title_updates(title_id)
