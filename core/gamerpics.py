import os
import mmap
import struct
import tempfile
import sys
import json
import re
from PIL import Image
from io import BytesIO
from .stfs_writer import STFSWriter

PNG_SIG = b"\x89PNG\r\n\x1a\n"


class GamerpicManager:
    def __init__(self, lib_dir):
        self.lib_dir    = lib_dir
        self.temp_dir   = os.path.join(tempfile.gettempdir(), "x360_gamerpics")
        os.makedirs(self.temp_dir, exist_ok=True)
        self.game_db    = self._load_json(os.path.join(lib_dir, "games.json"), is_list=True)
        self.meta_cache = self._load_json(os.path.join(lib_dir, "metadata_cache.json"))
        self.last_metadata = []

    # ──── DB helpers ─────────────────────────────────────────────────── #

    def _load_json(self, path, is_list=False):
        if not os.path.exists(path): return {}
        try:
            with open(path) as f: d = json.load(f)
            if is_list:
                db = {}
                for it in d:
                    tid = it.get("id","").upper()
                    if tid: db[tid] = it.get("title","?")
                    for alt in it.get("alternative_id", []): db[alt.upper()] = it.get("title","?")
                return db
            return {k.upper(): v for k, v in d.items()}
        except Exception: return {}

    def _resolve(self, tid):
        if not tid: return "System / Unknown", "Outros"
        c = self.meta_cache.get(tid, {})
        name = c.get("name") or c.get("title")
        if name:
            gs = c.get("genres", [])
            return name, (gs[0] if isinstance(gs, list) and gs else "Outros")
        name = self.game_db.get(tid)
        return (name, "Outros") if name else (f"ID: {tid}", "Outros")

    # ──── Scanning logic ──────────────────────────────────────────────── #

    def _extract_from_files(self, files):
        all_meta = []
        for pack_path in files:
            pack_name = os.path.basename(pack_path)
            prefix    = "".join(c for c in pack_name if c.isalnum())[:8]

            with open(pack_path, "rb") as fh:
                with mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                    # 1. Find dir offset
                    dir_off = None
                    for off in [0xCD00, 0xBD00, 0xAD00, 0x9D00, 0x24C000]:
                        sig = mm[off:off+3]
                        if sig.startswith((b"64_", b"32_", b"gp_")): 
                            dir_off = off; break
                    if dir_off is None: continue

                    # 2. Read entries (32+64)
                    entries = []
                    pos = dir_off
                    for i in range(20000):
                        chunk = mm[pos:pos+0x40]; pos += 0x40
                        if not chunk or chunk[0] == 0: break
                        try:
                            name = chunk[:0x28].decode('ascii', errors='ignore').split('\x00')[0]
                            if not name: continue
                            m = re.search(r"([0-9A-Fa-f]{8})", name)
                            entries.append({
                                "idx": i, "w": 64 if name.startswith("64_") else 32,
                                "tid": m.group(1).upper() if m else None,
                                "sz": struct.unpack(">I", chunk[0x34: 0x38])[0]
                            })
                        except: continue

                    # 3. Read all PNGs (idx, width)
                    pngs, p = [], 0
                    while True:
                        idx = mm.find(PNG_SIG, p)
                        if idx < 0: break
                        try:
                            w = struct.unpack(">I", mm[idx+16:idx+20])[0]
                            pngs.append((idx, w))
                        except: pass
                        p = idx + 8

                    # 4. Resilient skip & match logic
                    skip = 0
                    for s in range(50):
                        matches = sum(1 for j in range(min(20, len(entries))) 
                                      if s+j < len(pngs) and entries[j]['w'] == pngs[s+j][1])
                        if matches >= 10: skip = s; break

                    # Match each entry to the NEXT available PNG of correct width
                    p_idx = skip
                    for entry in entries:
                        found_at = -1
                        for attempt in range(p_idx, min(p_idx + 20, len(pngs))):
                            if pngs[attempt][1] == entry['w']:
                                found_at = attempt; break
                        
                        if found_at >= 0:
                            p_idx = found_at + 1
                            if entry['w'] == 32: continue 
                            
                            off = pngs[found_at][0]
                            sz  = entry['sz']
                            tid = entry['tid']
                            png_data = bytes(mm[off:off+sz])
                            
                            if not png_data.startswith(PNG_SIG): continue
                            
                            game_title, genre = self._resolve(tid)
                            icon_id = f"{prefix}_{entry['idx']}"
                            icon_path = os.path.join(self.temp_dir, f"gp_{icon_id}.png")
                            
                            if not os.path.exists(icon_path):
                                with open(icon_path, "wb") as f: f.write(png_data)
                            
                            all_meta.append({
                                "id": icon_id, "name": game_title, "pack": pack_name,
                                "genre": genre, "path": icon_path, "size": sz, 
                                "tid": tid, "pack_path": pack_path
                            })

        return all_meta

    def extract_all(self):
        packs = [os.path.join(self.lib_dir, f) for f in os.listdir(self.lib_dir) 
                 if os.path.isfile(os.path.join(self.lib_dir, f)) and not f.endswith(".json")]
        all_meta = self._extract_from_files(packs)
        self.last_metadata = all_meta
        return all_meta

    def extract_from_device(self, device_path):
        """Scans a specified USB device for installed STFS Gamerpics."""
        base_dir = os.path.join(device_path, "Content", "0000000000000000", "FFFE07D1")
        print(f"DEBUG: Scanning device gamerpics in: {base_dir}", file=sys.stderr)
        if not os.path.exists(base_dir):
            print(f"DEBUG: Folder not found: {base_dir}", file=sys.stderr)
            return []
            
        packs = []
        for root, _, files in os.walk(base_dir):
            for f in files:
                if f.startswith("."): continue
                pack_path = os.path.join(root, f)
                # Quick STFS check: size > 0xAC00 and first 4 bytes are CON/LIVE/PIRS
                if os.path.getsize(pack_path) > 0xAC00:
                    try:
                        with open(pack_path, "rb") as fh:
                            if fh.read(4) in [b"CON ", b"LIVE", b"PIRS"]:
                                packs.append(pack_path)
                    except: pass
                 
        return self._extract_from_files(packs)

    def create_custom_gamerpic(self, src_image_path, name="Custom Gamerpic",
                                crop_box=None, device_path=None, save_to_gallery=False):
        """
        Converts a local image into an STFS Gamerpic package.
        crop_box: (left, top, right, bottom) in image pixels, or None for auto-center-crop.
        device_path: mount point of the Xbox 360 USB drive to install to.
        save_to_gallery: if True, saves STFS + thumbnail PNG to local gallery.
        """
        import shutil
        from PIL import Image
        from io import BytesIO
        from .stfs_writer import STFSWriter

        if not os.path.exists(src_image_path):
            return {"status": "error", "message": "Image not found"}

        try:
            # 1. Image Processing with crop support
            img = Image.open(src_image_path)
            img = img.convert("RGBA")

            if crop_box:
                # crop_box = (left, top, right, bottom) from the dialog
                img = img.crop(crop_box)
            else:
                # Auto center-square crop
                w, h = img.size
                if w > h:
                    left = (w - h) // 2
                    img = img.crop((left, 0, left + h, h))
                elif h > w:
                    top = (h - w) // 2
                    img = img.crop((0, top, w, top + w))

            img = img.resize((64, 64), Image.LANCZOS)

            # Save to PNG in memory
            buf = BytesIO()
            img.save(buf, format="PNG")
            png_data = buf.getvalue()

            # 2. Build STFS package
            safe_name = re.sub(r'[^\w\-_\. ]', '_', name)[:32] or "custom_gamerpic"
            display_name = name[:128]
            writer = STFSWriter(title_id="FFFE07D1", display_name=display_name)
            stfs_data = writer.create_package(png_data)

            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            result = {"status": "success", "installed_path": None, "gallery_path": None, "name": name}

            # 3. Install to device if requested
            if device_path:
                target_dir = os.path.join(device_path, "Content", "0000000000000000",
                                           "FFFE07D1", "00020000")
                os.makedirs(target_dir, exist_ok=True)
                stfs_filename = f"{safe_name}.stfs"
                installed_path = os.path.join(target_dir, stfs_filename)
                with open(installed_path, "wb") as f:
                    f.write(stfs_data)
                result["installed_path"] = installed_path

            # 4. Save to local gallery if requested
            if save_to_gallery:
                gallery_dir = os.path.join(project_root, "data", "gamerpics", "custom")
                os.makedirs(gallery_dir, exist_ok=True)
                stfs_filename = f"{safe_name}.stfs"
                gallery_stfs_path = os.path.join(gallery_dir, stfs_filename)
                with open(gallery_stfs_path, "wb") as f:
                    f.write(stfs_data)
                # Also save a PNG thumbnail for the gallery UI
                thumb_path = os.path.join(gallery_dir, f"{safe_name}.png")
                img.save(thumb_path, format="PNG")
                result["gallery_path"] = gallery_stfs_path

            return result

        except Exception as e:
            return {"status": "error", "message": str(e)}


    # ──── Injection ───────────────────────────────────────────────────── #

    def create_mini_stfs(self, icon_id, output_path, metadata_list):
        it = next((m for m in metadata_list if m["id"] == icon_id), None)
        if not it or not os.path.exists(it["path"]): 
            print(f"DEBUG: Icon not found or PNG path missing: {icon_id}", file=sys.stderr)
            return False
        try:
            import struct
            import shutil
            # Check if it's already a custom STFS
            if it.get("pack_path", "").endswith(".stfs"):
                print(f"DEBUG: Copying existing STFS for {icon_id}", file=sys.stderr)
                shutil.copy2(it["pack_path"], output_path)
                return True

            print(f"DEBUG: Creating mini-STFS for {icon_id} from {it['pack_path']}", file=sys.stderr)
            with open(it["pack_path"], "rb") as f: h = bytearray(f.read(0xAC00))
            with open(it["path"],      "rb") as f: d = f.read()
            
            # ── Fix: Force FFFE07D1 Title ID and 00020000 Content Type ──────────────────
            # This ensures it's installed in the correct Xbox 360 Gamerpic directory.
            h[0x360:0x364] = b"\xFF\xFE\x07\xD1"
            struct.pack_into(">I", h, 0x344, 0x00020000) 
            
            with open(output_path, "wb") as f:
                f.write(h); f.write(b"\x00" * (0x10000 - len(h)))
                f.seek(0xCD00); e = bytearray(0x40)
                # INTERNAL FILENAME: Must start with 64_ or 32_ for best compatibility
                n = f"64_gp_{icon_id}.png".encode("ascii", "ignore")[:39]
                e[:len(n)] = n
                e[0x34:0x38] = struct.pack(">I", len(d))
                f.write(e); f.seek(0xD000); f.write(d)
            return True
        except Exception as e:
            print(f"Error in create_mini_stfs: {e}")
            return False


def get_manager():
    return GamerpicManager("/home/amplimusic/Documentos/BadStickLinux/v1.1/applib")
