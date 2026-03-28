import os
import json
import re
import requests
import time
import sys
import difflib
import sqlite3
from core.utils import normalize_for_map

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
        if not text or not GoogleTranslator: return text
        if len(text) < 5: return text # Skip tiny strings
        
        # Map human names to codes
        lang_map = {
            "Português": "pt",
            "English": "en",
            "Español": "es",
            "pt": "pt", "en": "en", "es": "es"
        }
        dest = lang_map.get(target_lang, "pt")
        
        try:
            # Detect source automatically
            return GoogleTranslator(source='auto', target=dest).translate(text)
        except Exception as e:
            print(f"Translation Error: {e}")
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

    def fast_batch_lookup(self, name):
        """Ultra-fast lookup for grid batch rendering. No I/O, no fuzzy search."""
        norm_name = normalize_for_map(name)
        tid = "Desconhecido"
        url = None
        
        # 1. Primary Map (High accuracy)
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
            url = "https://xboxunity.net/Resources/Lib/Images/Covers/4D5707E1.jpg"

        # Simple path reconstruction without checking file existence (MUCH faster)
        local_path = None
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
                    res = {
                        "TitleID": row[0],
                        "Name": row[1],
                        "Description": row[3] or "Disponível para download via x360 Tools Library.",
                        "Developer": row[4] or "Microsoft Studios",
                        "Publisher": row[5] or "Microsoft",
                        "ReleaseDate": row[6] or "2010",
                        "Rating": row[7] or "4.8",
                        "Genre": row[8] or "Ação e Aventura",
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
        # Final Fallback: use 4D5707E1.jpg (V41)
        fallback_path = os.path.join(self.cache_dir, "applib", "cache", "covers", "4D5707E1.jpg")
        fallback_res = {
            "TitleID": "Desconhecido",
            "CoverUrl": "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg",
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
