import os
import json
import shutil
from core.stfs import get_stfs_metadata

class LibraryScanner:
    def __init__(self):
        # Persistent storage for user-defined names (TitleID -> Name)
        self.data_dir = os.path.join(os.path.expanduser("~"), ".x360tools")
        os.makedirs(self.data_dir, exist_ok=True)
        self.user_titles_path = os.path.join(self.data_dir, "user_titles.json")
        self.user_titles = self._load_user_titles()

    def _load_user_titles(self):
        if os.path.exists(self.user_titles_path):
            try:
                with open(self.user_titles_path, "r") as f:
                    return json.load(f)
            except: pass
        return {}

    def _save_user_titles(self):
        try:
            with open(self.user_titles_path, "w") as f:
                json.dump(self.user_titles, f, indent=4)
        except: pass

    def scan_drive(self, mount_point):
        """
        Performs a full recursive scan of the device to find all games and content.
        """
        results = {"360": [], "OG": [], "DLC": [], "TU": []}
        title_id_map = {} # Map TitleID to Display Name
        
        # Folders to skip for performance and to avoid junk
        skip_dirs = ["$RECYCLE.BIN", "System Volume Information", "Cache", "LOST.DIR"]

        for dirpath, dirnames, filenames in os.walk(mount_point):
            # Optimization: Skip hidden and system directories
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and not d.endswith(".data") and d not in skip_dirs]
            
            # 1. Check for XEX/XBE (Extracted Games)
            if "default.xex" in filenames:
                game_name = os.path.basename(dirpath)
                data = self.user_titles.get(dirpath, {})
                display_name = data.get("name", game_name) if isinstance(data, dict) else game_name
                custom_icon = data.get("icon") if isinstance(data, dict) else None

                results["360"].append({
                    "name": display_name,
                    "path": dirpath,
                    "type": "XEX",
                    "icon": custom_icon
                })
                dirnames[:] = [] 
                continue

            if "default.xbe" in filenames:
                file_path = os.path.join(dirpath, "default.xbe")
                game_name = os.path.basename(dirpath)
                data = self.user_titles.get(dirpath, {})
                display_name = data.get("name", game_name) if isinstance(data, dict) else game_name
                custom_icon = data.get("icon") if isinstance(data, dict) else None

                # Try to get metadata from MobCat DB
                from core.xbe import get_xbe_metadata
                from core.og_meta_loader import OGMetadataService
                og_service = OGMetadataService()
                
                xbe_meta = get_xbe_metadata(file_path)
                if xbe_meta and xbe_meta.get("title_id"):
                    tid = xbe_meta["title_id"]
                    mob_meta = og_service.get_game_info(tid)
                    if mob_meta:
                        display_name = data.get("name", mob_meta["name"])
                        custom_icon = data.get("icon", og_service.get_icon_path(tid))

                results["OG"].append({
                    "name": display_name,
                    "path": dirpath,
                    "type": "XBE",
                    "icon": custom_icon,
                    "titleId": xbe_meta.get("title_id") if xbe_meta else None
                })
                dirnames[:] = []
                continue

            # 2. Check for STFS Packages (GOD, XBLA, DLC, TU)
            for filename in filenames:
                if filename.lower().endswith((".data", ".img", ".rpf", ".cpk", ".bin", ".ini", ".xex", 
                                            ".xbe", ".txt", ".log", ".inf", ".pdf", ".db")):
                    continue
                
                file_path = os.path.join(dirpath, filename)
                
                try:
                    if os.path.getsize(file_path) < 0x971B:
                        continue
                except: continue

                meta = get_stfs_metadata(file_path, extract_icon=True)
                if meta and meta.get("title_id"):
                    tid = meta["title_id"]
                    tname = meta["type_name"]
                    
                    # Use user-defined name/icon if it exists in our local DB
                    data = self.user_titles.get(tid, {})
                    if not isinstance(data, dict): # Migrate old flat strings
                        data = {"name": data}
                    
                    display_name = data.get("name", meta["display_name"])
                    display_icon = data.get("icon", meta["icon_path"])

                    item_data = {
                        "name": display_name,
                        "titleId": tid,
                        "path": file_path,
                        "icon": display_icon
                    }

                    if any(x in tname for x in ["Game", "GoD", "Arcade", "Demo"]):
                        item_data["type"] = "GOD"
                        results["360"].append(item_data)
                        # Save mapping for DLC/TU renaming and icons
                        title_id_map[tid] = {"name": display_name, "icon": display_icon}
                    elif any(x in tname for x in ["DLC", "Marketplace"]):
                        results["DLC"].append({
                            "name": f"DLC de {display_name}", # Default, refined below
                            "titleId": tid,
                            "path": file_path,
                            "filename": filename,
                            "icon": display_icon # Use own icon if available
                        })
                    elif any(x in tname for x in ["Update", "TU"]):
                        results["TU"].append({
                            "name": f"TU de {display_name}",
                            "titleId": tid,
                            "path": file_path,
                            "filename": filename,
                            "icon": display_icon
                        })

        # Post-process DLC and TU to use game names and icons from the map if not already set
        for dlc in results["DLC"]:
            tid = dlc["titleId"]
            if tid in title_id_map:
                if "de " + tid in dlc["name"]:
                    dlc["name"] = f"DLC de {title_id_map[tid]['name']}"
                if dlc.get("icon") is None or not os.path.exists(str(dlc.get("icon", ""))):
                    dlc["icon"] = title_id_map[tid]["icon"]
                
        for tu in results["TU"]:
            tid = tu["titleId"]
            if tid in title_id_map:
                if "de " + tid in tu["name"]:
                    tu["name"] = f"TU de {title_id_map[tid]['name']}"
                if tu.get("icon") is None or not os.path.exists(str(tu.get("icon", ""))):
                    tu["icon"] = title_id_map[tid]["icon"]
        
        return results

    def rename_entry(self, path, new_name, entry_type):
        """Renames a game or content."""
        if not os.path.exists(path):
            return None

        key = None
        if entry_type in ["XEX", "XBE"]:
            # For extracted games, we rename the directory AND record it by path
            dir_path = path if os.path.isdir(path) else os.path.dirname(path)
            parent = os.path.dirname(dir_path)
            new_path = os.path.join(parent, new_name)
            os.rename(dir_path, new_path)
            key = new_path
        else:
            # For STFS games, we update the local override DB by TitleID
            meta = get_stfs_metadata(path)
            if meta and meta.get("title_id"):
                key = meta["title_id"]
        
        if key:
            if key not in self.user_titles or not isinstance(self.user_titles[key], dict):
                self.user_titles[key] = {"name": new_name}
            else:
                self.user_titles[key]["name"] = new_name
            self._save_user_titles()
            return key if entry_type not in ["XEX", "XBE"] else new_path
            
        return None

    def set_custom_icon(self, path, icon_path):
        """Overrides the game's icon with a custom one."""
        if not os.path.exists(path) or not os.path.exists(icon_path):
            return False

        # Determine key: Path for XEX/XBE, TitleID for STFS
        key = None
        if os.path.isdir(path) or "default.xex" in path.lower() or "default.xbe" in path.lower():
            key = path if os.path.isdir(path) else os.path.dirname(path)
        else:
            meta = get_stfs_metadata(path)
            if meta and meta.get("title_id"):
                key = meta["title_id"]

        if key:
            if key not in self.user_titles or not isinstance(self.user_titles[key], dict):
                self.user_titles[key] = {}
            
            # Copy the icon to a local persistent storage to avoid losing it
            local_icon_name = f"icon_{key.replace('/', '_')}{os.path.splitext(icon_path)[1]}"
            local_icon_path = os.path.join(self.data_dir, "icons", local_icon_name)
            os.makedirs(os.path.dirname(local_icon_path), exist_ok=True)
            shutil.copy2(icon_path, local_icon_path)
            
            self.user_titles[key]["icon"] = local_icon_path
            self._save_user_titles()
            return True
        return False

    def export_item(self, path, dest_dir):
        """Copies a game/content to a local PC directory."""
        if not os.path.exists(path):
            return False
            
        try:
            os.makedirs(dest_dir, exist_ok=True)
            target_name = os.path.basename(path)
            dest_path = os.path.join(dest_dir, target_name)
            
            if os.path.isdir(path):
                if os.path.exists(dest_path): shutil.rmtree(dest_path)
                shutil.copytree(path, dest_path)
            else:
                shutil.copy2(path, dest_path)
                # If it's a GOD game, copy the .data folder too
                data_folder = path + ".data"
                if os.path.exists(data_folder):
                    shutil.copytree(data_folder, dest_path + ".data")
            return True
        except:
            return False

    def delete_entry(self, path):
        """Safely removes a file or directory."""
        if not os.path.exists(path):
            return False
        
        try:
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
                # If it's a GOD file, also try to remove the .data folder
                data_folder = path + ".data"
                if os.path.exists(data_folder):
                    shutil.rmtree(data_folder)
            return True
        except:
            return False
