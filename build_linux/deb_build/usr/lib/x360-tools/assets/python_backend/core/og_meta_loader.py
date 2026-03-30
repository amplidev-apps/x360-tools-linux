import sqlite3
import os
import requests
import json

class OGMetadataService:
    def __init__(self, db_path=None):
        self.project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.db_path = db_path or os.path.join(self.project_root, "titleIDs.db")
        # Use assets/gamecovers/ for instant loading as requested
        self.icon_cache = os.path.join(self.project_root, "assets", "gamecovers")
        os.makedirs(self.icon_cache, exist_ok=True)
        self.base_url = "https://raw.githubusercontent.com/MobCat/MobCats-original-xbox-game-list/main/icon"

    def get_game_info(self, title_id):
        """Fetches game info from the SQLite database by TitleID."""
        if not os.path.exists(self.db_path):
            return None
        
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT Full_Name, Publisher, Region, Features, Serial_Num FROM TitleIDs WHERE Title_ID = ?", (title_id.upper(),))
            row = cursor.fetchone()
            conn.close()
            
            if row:
                return {
                    "name": row[0],
                    "publisher": row[1],
                    "region": row[2],
                    "features": row[3],
                    "titleid": title_id,
                    "serial": row[4]
                }
        except Exception as e:
            print(f"Error querying OG DB by ID: {e}")
        return None

    def search_by_name(self, name):
        """Searches game info by name/AKA."""
        if not os.path.exists(self.db_path):
            return None
            
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            # Search by Full_Name or AKA
            cursor.execute("SELECT Title_ID, Full_Name, Publisher, Region, Features FROM TitleIDs WHERE Full_Name LIKE ? OR AKA LIKE ? LIMIT 1", (f"%{name}%", f"%{name}%"))
            row = cursor.fetchone()
            conn.close()
            
            if row:
                return {
                    "titleid": row[0],
                    "name": row[1],
                    "publisher": row[2],
                    "region": row[3],
                    "features": row[4]
                }
        except Exception as e:
            print(f"Error searching OG DB by name: {e}")
        return None

    def get_icon_path(self, title_id):
        """Returns the local path to the icon, downloading it if necessary."""
        local_path = os.path.join(self.icon_cache, f"{title_id}.png")
        if os.path.exists(local_path):
            return local_path
        
        # Try to download
        prefix = title_id[:4].upper()
        url = f"{self.base_url}/{prefix}/{title_id.upper()}.png"
        
        try:
            print(f"Downloading OG cover: {url}")
            resp = requests.get(url, timeout=5)
            if resp.status_code == 200:
                with open(local_path, "wb") as f:
                    f.write(resp.content)
                return local_path
        except:
            pass
            
        return None
