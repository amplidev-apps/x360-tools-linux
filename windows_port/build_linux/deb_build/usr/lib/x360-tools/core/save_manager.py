import os
import shutil
from core.stfs import get_stfs_metadata
import time

class SaveManager:
    def __init__(self):
        # Local vault directory for keeping a copy of saves on the Linux machine
        self.vault_dir = os.path.expanduser("~/.config/x360_tools/saves")
        os.makedirs(self.vault_dir, exist_ok=True)

    def scan_vault(self):
        """ Scans the local vault for save files and returns their metadata. """
        saves = []
        for file in os.listdir(self.vault_dir):
            path = os.path.join(self.vault_dir, file)
            if os.path.isfile(path):
                meta = get_stfs_metadata(path, extract_icon=True)
                if meta:
                    meta['file_name'] = file
                    meta['file_path'] = path
                    meta['size'] = os.path.getsize(path)
                    meta['modified'] = os.path.getmtime(path)
                    saves.append(meta)
        
        # Sort by recently modified
        saves.sort(key=lambda x: x['modified'], reverse=True)
        return saves

    def import_save(self, source_path):
        """ Imports a save file into the local vault. """
        if not os.path.exists(source_path):
            return {"status": "error", "message": "Source file not found"}
            
        meta = get_stfs_metadata(source_path)
        if not meta or meta.get('type_id') not in [1, 2, 4]: # Save, DLC, Profile
            # Note: Content Type 1 is Save Game. 4 is Profile. We'll allow importing both as "saves"
            return {"status": "error", "message": "Arquivo selecionado não parece ser um Save ou Perfil STFS válido."}
            
        filename = os.path.basename(source_path)
        # Ensure unique name if conflict
        dest_path = os.path.join(self.vault_dir, filename)
        if os.path.exists(dest_path):
            base, ext = os.path.splitext(filename)
            dest_path = os.path.join(self.vault_dir, f"{base}_{int(time.time())}{ext}")
            
        try:
            shutil.copy2(source_path, dest_path)
            # Re-read full metadata for response
            final_meta = get_stfs_metadata(dest_path, extract_icon=True)
            if final_meta:
                final_meta['file_name'] = os.path.basename(dest_path)
                final_meta['file_path'] = dest_path
                final_meta['size'] = os.path.getsize(dest_path)
                final_meta['modified'] = os.path.getmtime(dest_path)
            
            return {"status": "success", "message": "Save importado para o cofre com sucesso", "data": final_meta}
        except Exception as e:
            return {"status": "error", "message": f"Erro na importação: {e}"}

    def delete_save(self, save_filename):
        """ Deletes a save from the local vault. """
        path = os.path.join(self.vault_dir, save_filename)
        if os.path.exists(path):
            try:
                os.remove(path)
                return {"status": "success", "message": "Save apagado do cofre."}
            except Exception as e:
                return {"status": "error", "message": str(e)}
        return {"status": "error", "message": "Save não encontrado."}
