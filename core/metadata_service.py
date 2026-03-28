import os
import json
import re
import requests
import time
import sys

class MetadataService:
    def __init__(self, cache_dir):
        self.cache_dir = cache_dir
        self.cache_path = os.path.join(cache_dir, "metadata_cache.json")
        os.makedirs(cache_dir, exist_ok=True)
        self.cache = self._load_cache()
        self.base_url = "https://dbox.tools/api"
        self.unity_base_url = "http://xboxunity.net/api"
        self.unity_api_key = "EA486DB0B43192E8846A7EB374AD7BED"
        # In-memory cache for Unity lookups this session
        self._unity_cache = {}

    # ------------------------------------------------------------------ #
    #  Name normalization helpers
    # ------------------------------------------------------------------ #
    _DLC_KEYWORDS = [
        " - dlc", " dlc", " - season pass", " season pass",
        " - bundle", " bundle pack", " - pack", " - expansion",
        " - add-on", " add-on", " - addon", " addon",
        " - content pack", " content pack", " - map pack",
    ]
    _EDITION_TAGS = [
        "game of the year edition", "goty edition", "goty",
        "complete edition", "ultimate edition", "platinum hits",
        "greatest hits", "classic edition", "special edition",
        "definitive edition", "enhanced edition", "gold edition",
        "premium edition", "anniversary edition", "directors cut",
        "director's cut", "remastered",
    ]
    _ROMAN_MAP = {
        "V": "5",
        "II": "2", "III": "3", "IV": "4", "VI": "6",
        "VII": "7", "VIII": "8", "IX": "9", "XI": "11",
        "XII": "12", "XIII": "13", "XIV": "14",
    }
    _NUM_WORD_MAP = {
        "zero": "0", "one": "1", "two": "2", "three": "3",
        "four": "4", "five": "5", "six": "6", "seven": "7",
        "eight": "8", "nine": "9", "ten": "10",
        # reverse: digits → words  (populated at end of map)
    }

    def _build_variations(self, raw_name):
        """Return an ordered, deduplicated list of search query variations."""
        import html as html_mod

        name = html_mod.unescape(raw_name or "")
        # Strip region/version tags in parens/brackets
        name = re.sub(r'\s*[\(\[].*?[\)\]]', '', name).strip()
        # Strip disc tags
        name = re.sub(r'\s+Disc\s+\d+', '', name, flags=re.IGNORECASE).strip()
        name = name.lower().strip()
        if name.startswith("- "):
            name = name[2:].strip()

        seen = []
        def add(v):
            v = v.strip()
            if v and v not in seen:
                seen.append(v)

        # --- 1. Clean base name (colon substitution) ---
        colon = name.replace(" - ", ": ")
        add(colon)

        # --- 2. Dash removed ---
        nodash = name.replace(" - ", " ")
        add(nodash)

        # --- 3. Segments around first " - " ---
        if " - " in name:
            parts = name.split(" - ", 1)
            add(parts[0])         # first segment
            add(parts[1])         # second segment
            # colon only on first segment
            add(parts[0].replace(" - ", ": "))

        # --- 4. Strip DLC / expansion suffixes to get base game name ---
        base_dlc = name
        for kw in self._DLC_KEYWORDS:
            idx = base_dlc.lower().find(kw)
            if idx > 0:
                base_dlc = base_dlc[:idx].strip(" -:").strip()
                break
        if base_dlc != name:
            add(base_dlc)
            add(base_dlc.replace(" - ", ": "))
            add(base_dlc.replace(" - ", " "))
            if " - " in base_dlc:
                add(base_dlc.split(" - ", 1)[0].strip())

        # --- 5. Strip known edition tags ---
        edition_stripped = name
        for tag in self._EDITION_TAGS:
            edition_stripped = re.sub(r'\s*,?\s*' + re.escape(tag), '', edition_stripped, flags=re.IGNORECASE).strip(" -:").strip()
        if edition_stripped != name:
            add(edition_stripped)
            add(edition_stripped.replace(" - ", ": "))

        # --- 6. Roman numeral ↔ digit conversion ---
        for roman, digit in self._ROMAN_MAP.items():
            # roman → digit
            v = re.sub(r'\b' + roman + r'\b', digit, colon, flags=re.IGNORECASE)
            if v != colon: add(v)
            # digit → roman
            v2 = re.sub(r'\b' + re.escape(digit) + r'\b', roman, colon, flags=re.IGNORECASE)
            if v2 != colon: add(v2)

        # --- 7. Written numbers ↔ digit (e.g. "five" ↔ "5") ---
        for word, digit in self._NUM_WORD_MAP.items():
            v = re.sub(r'\b' + re.escape(word) + r'\b', digit, colon, flags=re.IGNORECASE)
            if v != colon: add(v)
            v2 = re.sub(r'\b' + re.escape(digit) + r'\b', word, colon, flags=re.IGNORECASE)
            if v2 != colon: add(v2)

        # --- 8. Strip leading number/article if all else fails ---
        # e.g. "2006 FIFA World Cup" → "FIFA World Cup"
        stripped_prefix = re.sub(r'^\d+\s+', '', colon).strip()
        if stripped_prefix != colon:
            add(stripped_prefix)

        # --- 9. Colon → nothing (bare subtitle, e.g. "Blood Stone") ---
        if ": " in colon:
            add(colon.split(": ", 1)[1].strip())

        return seen

    def search_unity_by_name(self, name):
        """Search Xbox Unity by game name to get TitleID and Cover (multi-pass)."""
        cache_key = name.lower().strip()
        if cache_key in self._unity_cache:
            return self._unity_cache[cache_key]

        variations = self._build_variations(name)
        headers = {"X-Requested-With": "XMLHttpRequest", "Referer": "https://xboxunity.net/"}
        unity_url = "https://xboxunity.net/Resources/Lib/TitleList.php"

        for search_query in variations:
            if not search_query:
                continue
            self.log(f"Searching Unity for '{search_query}'...")
            try:
                params = {
                    "page": 0, "count": 5, "search": search_query,
                    "sort": 3, "direction": 1, "category": 0, "filter": 0,
                }
                resp = requests.get(unity_url, params=params, headers=headers, timeout=10)
                if resp.status_code != 200:
                    continue
                data = resp.json()
                items = data.get("Items", [])
                if not items:
                    continue

                best = items[0]
                title_id = best.get("TitleID")
                cover_url = None

                # Fetch cover if available
                if int(best.get("Covers", "0") or 0) > 0:
                    try:
                        c_resp = requests.get(
                            f"https://xboxunity.net/Resources/Lib/CoverInfo.php?titleid={title_id}",
                            headers=headers, timeout=5,
                        )
                        if c_resp.status_code == 200:
                            covers = c_resp.json().get("Covers", [])
                            if covers:
                                cover_id = covers[0].get("CoverID")
                                cover_url = f"https://xboxunity.net/Resources/Lib/Cover.php?size=large&cid={cover_id}"
                    except Exception:
                        pass

                result = {
                    "TitleID": title_id,
                    "CoverUrl": cover_url,
                    "Name": best.get("Name"),
                    "Region": best.get("RegionStr", "Region-Free"),
                    "Rating": str(best.get("Rating", "4.8")),
                }
                self._unity_cache[cache_key] = result
                self.log(f"✓ Found '{best.get('Name')}' (TID: {title_id}) via query '{search_query}'")
                return result

            except Exception as e:
                self.log(f"Unity Search Error [{search_query}]: {e}")

        self._unity_cache[cache_key] = None
        return None

    def get_title_updates(self, title_id):
        """Fetch Title Updates for a given Title ID."""
        if not title_id or title_id == "Desconhecido": return []
        self.log(f"Fetching TUs for {title_id} from Unity...")
        try:
            url = "https://xboxunity.net/Resources/Lib/TitleUpdateInfo.php"
            headers = {"X-Requested-With": "XMLHttpRequest", "Referer": "https://xboxunity.net/"}
            resp = requests.get(url, params={"titleid": title_id}, headers=headers, timeout=10)
            if resp.status_code == 200:
                data = resp.json()
                if isinstance(data, dict):
                    tus = []
                    if data.get("Type") == 1 and "MediaIDS" in data:
                        for media in data["MediaIDS"]:
                            for up in media.get("Updates", []):
                                up["MediaID"] = media.get("MediaID")
                                # Construct the download URL and map keys to what Flutter expects
                                up["downloadUrl"] = f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={up.get('TitleUpdateID')}"
                                up["Version"] = up.get("Version")
                                tus.append(up)
                    elif data.get("Type") == 2 and "Updates" in data:
                        for up in data["Updates"]:
                            up["downloadUrl"] = f"https://xboxunity.net/Resources/Lib/TitleUpdate.php?tuid={up.get('TitleUpdateID')}"
                            up["Version"] = up.get("Version")
                            tus.append(up)
                    
                    # Sort TUs by Version descending for UI convenience
                    tus.sort(key=lambda x: int(x.get("Version", 0)), reverse=True)
                    return tus
        except Exception as e:
            self.log(f"Unity TU Error: {e}")
        return []

    def _load_cache(self):
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r") as f:
                    return json.load(f)
            except:
                return {}
        return {}

    def _save_cache(self):
        with open(self.cache_path, "w") as f:
            json.dump(self.cache, f, indent=4)

    def log(self, msg):
        print(f"[MetadataService] {msg}", file=sys.stderr)

    def get_title_info(self, title_id):
        if not title_id: return None
        title_id = title_id.upper()
        if title_id in self.cache:
            return self.cache[title_id]

        self.log(f"Fetching metadata for {title_id} from DBox...")
        try:
            resp = requests.get(f"{self.base_url}/title_ids/{title_id}", timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                info = {
                    "name": data.get("name", "Unknown Game"),
                    "systems": data.get("systems", []),
                    "bing_id": data.get("bing_id"),
                    "genre": self.get_genre_heuristic(title_id),
                    "developer": None,
                    "publisher": None
                }
                
                self.cache[title_id] = info
                self._save_cache()
                return info
        except Exception as e:
             self.log(f"Error fetching metadata: {e}")

        return None

    def get_genre_heuristic(self, tid):
        if not tid: return "Outros"
        if tid.startswith("5841"): return "Arcade (XBLA)"
        if tid.startswith("5855"): return "Indie Games"
        if tid.startswith("4541"): return "Electronic Arts"
        if tid.startswith("5454"): return "Take-Two / Rockstar"
        if tid.startswith("4156"): return "Activision"
        if tid.startswith("5553"): return "Ubisoft"
        if tid.startswith("4D53"): return "Microsoft Studios"
        if tid.startswith("4253"): return "Bethesda / Zenimax"
        if tid.startswith("5345"): return "SEGA"
        if tid.startswith("4343"): return "Capcom"
        if tid.startswith("4B4E"): return "Konami"
        if tid.startswith("5451"): return "THQ"
        if tid.startswith("574D"): return "Warner Bros"
        return "Jogos em Disco / Apps"

def get_service():
    cache_dir = "/home/amplimusic/Documentos/BadStickLinux/v1.1/applib"
    return MetadataService(cache_dir)
