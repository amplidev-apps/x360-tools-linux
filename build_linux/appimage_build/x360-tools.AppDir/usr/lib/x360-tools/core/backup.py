import os
import zipfile
import shutil
import subprocess
import json
import time
from core.usb import detect_removable_drives

class BackupManager:
    """Manages full device backup and restoration for Xbox 360 USB drives."""
    
    EXTENSION = ".x360b"

    @staticmethod
    def get_summary(mount_point):
        """
        Scans the mount point and returns a categorized summary of contents.
        Useful for showing the user what will be backed up.
        """
        if not os.path.exists(mount_point):
            return []
            
        summary = []
        try:
            items = os.listdir(mount_point)
            for item in items:
                item_path = os.path.join(mount_point, item)
                is_dir = os.path.isdir(item_path)
                
                category = "Outros"
                icon = "miscellaneous_services"

                # Categorize by known names
                lower_item = item.lower()
                if lower_item == "content":
                    category = "Jogos e Perfis"
                    icon = "sports_esports"
                elif lower_item in ["aurora", "freestyle", "fsd", "dashlaunch"]:
                    category = "Dashboards"
                    icon = "dashboard"
                elif lower_item in ["games", "emulators", "apps", "homebrews"]:
                    category = "Homebrews & Apps"
                    icon = "apps"
                elif lower_item.endswith(".ini") or lower_item == "launch.ini":
                    category = "Configurações"
                    icon = "settings"
                elif lower_item in ["$systemupdate", "$su"]:
                    category = "Atualização de Sistema"
                    icon = "system_update"

                # Get size
                size = 0
                if is_dir:
                    for root, dirs, files in os.walk(item_path):
                        for f in files:
                            size += os.path.getsize(os.path.join(root, f))
                else:
                    size = os.path.getsize(item_path)

                summary.append({
                    "name": item,
                    "category": category,
                    "icon": icon,
                    "is_dir": is_dir,
                    "size_bytes": size
                })
        except Exception as e:
            print(f"Summary error: {e}")
            
        return summary

    @staticmethod
    def get_zip_summary(zip_file):
        """
        Scans a .x360b zip file and returns a categorized summary of top-level items.
        Also returns the backup label if metadata exists.
        """
        if not os.path.exists(zip_file):
            return {"summary": [], "label": None}

        summary_map = {} # item_name -> {category, size}
        label = None
        try:
            with zipfile.ZipFile(zip_file, 'r') as zipf:
                # Try to read metadata first
                if "metadata.json" in zipf.namelist():
                    try:
                        with zipf.open("metadata.json") as f:
                            meta = json.load(f)
                            label = meta.get("label")
                    except: pass

                for info in zipf.infolist():
                    if info.filename == "metadata.json": continue
                    
                    # Get top level part
                    parts = info.filename.split('/')
                    top_item = parts[0]
                    if not top_item: continue

                    if top_item not in summary_map:
                        category = "Outros"
                        icon = "miscellaneous_services"
                        lower_item = top_item.lower()
                        
                        if lower_item == "content":
                            category = "Jogos e Perfis"
                            icon = "sports_esports"
                        elif lower_item in ["aurora", "freestyle", "fsd", "dashlaunch"]:
                            category = "Dashboards"
                            icon = "dashboard"
                        elif lower_item in ["games", "emulators", "apps", "homebrews"]:
                            category = "Homebrews & Apps"
                            icon = "apps"
                        elif lower_item.endswith(".ini"):
                            category = "Configurações"
                            icon = "settings"

                        summary_map[top_item] = {
                            "name": top_item,
                            "category": category,
                            "icon": icon,
                            "is_dir": info.is_dir() or '/' in info.filename,
                            "size_bytes": 0
                        }
                    
                    summary_map[top_item]["size_bytes"] += info.file_size
        except Exception as e:
            print(f"Zip Summary error: {e}")

        return {"summary": list(summary_map.values()), "label": label}

    @staticmethod
    def create_backup(source_mount, dest_file, label=None, progress_cb=None):
        """
        Creates a file-level backup of the source mount point.
        """
        if not os.path.exists(source_mount):
            raise FileNotFoundError(f"Source mount point {source_mount} not found.")

        # Ensure dest_file has the correct extension
        if not dest_file.lower().endswith(BackupManager.EXTENSION):
            dest_file += BackupManager.EXTENSION

        try:
            with zipfile.ZipFile(dest_file, 'w', zipfile.ZIP_DEFLATED, allowZip64=True) as zipf:
                # 1. Add metadata if label provided
                if label:
                    zipf.writestr("metadata.json", json.dumps({"label": label}))

                # 2. Count total items for progress
                file_list = []
                total_bytes = 0
                for root, dirs, files in os.walk(source_mount):
                    if any(sys_dir in root for sys_dir in [".Trash-1000", "System Volume Information", "$RECYCLE.BIN"]):
                        continue
                        
                    for file in files:
                        full_path = os.path.join(root, file)
                        if os.path.abspath(full_path) == os.path.abspath(dest_file):
                            continue
                        f_size = os.path.getsize(full_path)
                        file_list.append((full_path, f_size))
                        total_bytes += f_size

                if progress_cb: progress_cb(f"Found {len(file_list)} files. Total: {total_bytes // (1024*1024)} MB. Starting compression...")

                # 3. Add files to zip
                processed_bytes = 0
                for i, (file_path, f_size) in enumerate(file_list):
                    rel_path = os.path.relpath(file_path, source_mount)
                    zipf.write(file_path, rel_path)
                    processed_bytes += f_size
                    
                    if progress_cb:
                        percent = int((processed_bytes / total_bytes) * 100) if total_bytes > 0 else 100
                        percent = min(percent, 99)
                        progress_cb(f"Progress: {percent}% - Archiving {rel_path}")

                if progress_cb: progress_cb("Progress: 100% - Backup concluído.")
            return True
        except Exception as e:
            if os.path.exists(dest_file):
                os.remove(dest_file)
            raise e

    @staticmethod
    def format_partition(device_path, label="X360USB"):
        """Formats the partition as FAT32 for Xbox 360 compatibility."""
        import glob
        
        # 1. Aggressive Unmount
        patterns = [device_path, f"{device_path}[0-9]*", f"{device_path}p[0-9]*"]
        for p in patterns:
            for node in glob.glob(p):
                subprocess.run(["udisksctl", "unmount", "-b", node, "--force"], capture_output=True, check=False)
        
        # 2. Privileged Formatting
        label_upper = str(label)[:11].upper()
        bash_cmd = f"wipefs -af {device_path} && partprobe {device_path} && sleep 1 && mkfs.vfat -I -F 32 -n \"{label_upper}\" {device_path} && partprobe {device_path} && sync"
        privileged_cmd = ["pkexec", "bash", "-c", bash_cmd]
        
        try:
            subprocess.run(privileged_cmd, check=True)
            time.sleep(2.0)
        except subprocess.CalledProcessError as e:
            if e.returncode in [126, 127]:
                raise Exception("A autorização foi cancelada pelo usuário.")
            raise Exception("Falha na formatação: O dispositivo pode estar bloqueado pelo sistema.")
            
        # 3. Remount
        mount_cmd = ["udisksctl", "mount", "-b", device_path]
        try:
            res = subprocess.run(mount_cmd, capture_output=True, text=True, check=True)
            if "at " in res.stdout:
                return res.stdout.split("at ")[1].strip()
        except subprocess.CalledProcessError:
            time.sleep(2)
            
        for drive in detect_removable_drives():
            if drive.device == device_path and drive.mount_point:
                return drive.mount_point
        return None

    @staticmethod
    def restore_backup(backup_zip, target_device, new_label=None, progress_cb=None):
        """Formats the device and extracts the backup content."""
        if not os.path.exists(backup_zip):
            raise FileNotFoundError("Backup file not found")
            
        # 1. Determine Label
        final_label = new_label
        if not final_label:
            # Try to read from zip metadata
            with zipfile.ZipFile(backup_zip, 'r') as zipf:
                if "metadata.json" in zipf.namelist():
                    try:
                        meta = json.loads(zipf.read("metadata.json").decode("utf-8"))
                        final_label = meta.get("label")
                    except: pass
        if not final_label:
            final_label = "X360BACKUP"

        # 2. Real Format
        if progress_cb: progress_cb(f"Progress: 5% - Formatando dispositivo como {final_label}...")
        target_mount = BackupManager.format_partition(target_device, final_label)
        
        if not target_mount or not os.path.exists(target_mount):
            raise Exception("Erro ao remontar dispositivo após formatação.")

        # 3. Extract
        if progress_cb: progress_cb("Progress: 15% - Formatação concluída. Iniciando extração...")
        
        with zipfile.ZipFile(backup_zip, 'r') as zipf:
            info_list = zipf.infolist()
            total_bytes = sum(info.file_size for info in info_list if info.filename != "metadata.json")
            processed_bytes = 0
            
            for i, info in enumerate(info_list):
                if info.filename == "metadata.json": continue
                
                zipf.extract(info, target_mount)
                processed_bytes += info.file_size
                
                if progress_cb:
                    if total_bytes > 0:
                        percent = 15 + int((processed_bytes / total_bytes) * 84)
                    else:
                        percent = 99
                    progress_cb(f"Progress: {percent}% - Extraindo {info.filename}")
                    
        if progress_cb: progress_cb("Progress: 100% - Restauração concluída com sucesso.")
        return True
