import os
from core.stfs import get_stfs_metadata

class LibraryScanner:
    def __init__(self):
        pass

    def scan_drive(self, mount_point):
        """
        Scans a drive for installed content.
        Looks into /Content/0000000000000000 (GOD/DLC) and /Games (XEX).
        """
        results = {
            "360": [],
            "OG": [],
            "DLC": [],
            "TU": []
        }

        # 1. Scan /Content/0000000000000000 (GOD and DLC)
        content_root = os.path.join(mount_point, "Content", "0000000000000000")
        if os.path.exists(content_root):
            for title_id in os.listdir(content_root):
                title_path = os.path.join(content_root, title_id)
                if not os.path.isdir(title_path): continue
                
                # Check for GOD (000D0000)
                god_dir = os.path.join(title_path, "000D0000")
                if os.path.exists(god_dir):
                    for data_file in os.listdir(god_dir):
                        if len(data_file) == 42 and not data_file.endswith(".data"):
                            meta = get_stfs_metadata(os.path.join(god_dir, data_file), extract_icon=True)
                            if meta:
                                results["360"].append({
                                    "name": meta.get("display_name", f"Game {title_id}"),
                                    "titleId": meta.get("title_id", title_id),
                                    "path": os.path.join(god_dir, data_file),
                                    "icon": meta.get("icon_path"),
                                    "type": "GOD"
                                })
                
                # Check for DLC (00000002)
                dlc_dir = os.path.join(title_path, "00000002")
                if os.path.exists(dlc_dir):
                    for dlc_file in os.listdir(dlc_dir):
                        results["DLC"].append({
                            "name": f"DLC for {title_id}",
                            "titleId": title_id,
                            "filename": dlc_file
                        })
                
                # Check for TU (000B0000)
                tu_dir = os.path.join(title_path, "000B0000")
                if os.path.exists(tu_dir):
                    for tu_file in os.listdir(tu_dir):
                        results["TU"].append({
                            "name": f"TU for {title_id}",
                            "titleId": title_id,
                            "filename": tu_file
                        })

        # 2. Scan /Games (XEX / Original Xbox)
        games_root = os.path.join(mount_point, "Games")
        if os.path.exists(games_root):
            for game_dir in os.listdir(games_root):
                game_path = os.path.join(games_root, game_dir)
                if not os.path.isdir(game_path): continue
                
                if os.path.exists(os.path.join(game_path, "default.xex")):
                    results["360"].append({
                        "name": game_dir,
                        "path": game_path,
                        "type": "XEX"
                    })
                elif os.path.exists(os.path.join(game_path, "default.xbe")):
                    results["OG"].append({
                        "name": game_dir,
                        "path": game_path,
                        "type": "XBE"
                    })

        return results
