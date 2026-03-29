import os
import mmap
import struct
import tempfile
import sys
import json
import re
try:
    from PIL import Image
except ImportError:
    Image = None

from io import BytesIO

# Use absolute import for release-ready consistency
try:
    from core.stfs_writer import STFSWriter
except ImportError:
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
        if not Image:
            print("WARNING: PIL/Pillow not found. Gamerpic extraction may fail.", file=sys.stderr)

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

    # ──── STFS Header helper ──────────────────────────────────────────── #

    def _read_stfs_title_id(self, mm):
        """Read the real Title ID from the STFS header at offset 0x360."""
        try:
            header = mm[0:4]
            if header not in (b"CON ", b"LIVE", b"PIRS"):
                return None
            raw = mm[0x360:0x364]
            tid = raw.hex().upper()
            # 00000000 and FFFE07D1 mean "no game" (avatar / system)
            if tid in ("00000000", "FFFE07D1"):
                return None
            return tid
        except Exception:
            return None

    # ──── Scanning logic ──────────────────────────────────────────────── #

    def _find_png_end(self, mm: mmap.mmap, start: int) -> int:
        """Traverse PNG chunks to find the true end (after IEND)."""
        IEND = b"IEND"
        pos = start + 8  # skip PNG signature
        size = len(mm)
        while pos <= size - 12:
            try:
                # Read 4 bytes for chunk length
                raw_len = mm[pos:pos+4]
                if len(raw_len) < 4: break
                chunk_len = struct.unpack(">I", raw_len)[0]
                chunk_type = mm[pos+4:pos+8]
                # sys.stderr.write(f"DEBUG: Found chunk {chunk_type} len {chunk_len} at {pos}\n")
                
                if chunk_len > 1_000_000: break
                
                pos += 8 + chunk_len + 4        # len + type + data + CRC
                if chunk_type == IEND:
                    return pos
            except Exception:
                break
        return -1

    def _collect_valid_pngs(self, mm, target_w):
        """
        Walk the mmap from 0x1000 forward, hopping between PNG_SIG occurrences
        and using IEND to find true boundaries.  Returns list of (offset, data)
        for every valid, loadable PNG whose width == target_w.
        """
        valid = []
        p = 0x1000
        while True:
            idx = mm.find(PNG_SIG, p)
            if idx < 0:
                break
            try:
                w = struct.unpack(">I", mm[idx+16:idx+20])[0]
                h = struct.unpack(">I", mm[idx+20:idx+24])[0]
            except Exception:
                p = idx + 8
                continue

            end = self._find_png_end(mm, idx)
            if end <= idx:
                p = idx + 8
                continue

            if w == target_w and h == target_w:   # must be square (64×64 or 32×32)
                data = bytes(mm[idx:end])
                try:
                    img = Image.open(BytesIO(data))
                    img.verify()
                    valid.append((idx, data))
                except Exception:
                    pass
            p = end   # jump past this PNG, avoiding false inner signatures

        return valid

    def _extract_from_files(self, files):
        all_meta = []
        for pack_path in files:
            pack_name = os.path.basename(pack_path)
            # V109: Include hash of filename to prevent ID collisions between packs with similar names
            import hashlib
            h = hashlib.md5(pack_name.encode()).hexdigest()[:6]
            prefix = "".join(c for c in pack_name if c.islower() or c.isdigit())[:6] or "pkg"
            prefix = f"{prefix}_{h}"

            with open(pack_path, "rb") as fh:
                with mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                    # ── 0. Pack-level Title ID fallback ──────────────────────────
                    pack_tid = self._read_stfs_title_id(mm)

                    # ── 1. Find the STFS internal directory offset ───────────────
                    dir_off = None
                    for off in [0xCD00, 0xBD00, 0xAD00, 0x9D00, 0x24C000]:
                        sig = mm[off:off+3]
                        if sig.startswith((b"64_", b"32_", b"gp_")):
                            dir_off = off; break
                    if dir_off is None:
                        continue

                    # ── 2. Read only 64px directory entries ──────────────────────
                    entries_64 = []
                    pos = dir_off
                    for i in range(20000):
                        chunk = mm[pos:pos+0x40]; pos += 0x40
                        if not chunk or chunk[0] == 0: break
                        try:
                            raw_name = chunk[:0x28].decode("ascii", errors="ignore").split("\x00")[0]
                            if not raw_name or not raw_name.startswith("64_"):
                                continue
                            body = raw_name[3:]           # strip "64_"
                            m = re.match(r"([0-9A-Fa-f]{8})", body)
                            tid = m.group(1).upper() if m else None
                            if tid in ("00000000", "FFFE07D1"):
                                tid = None
                            sz  = struct.unpack(">I", chunk[0x34:0x38])[0]
                            entries_64.append({"idx": i, "tid": tid or pack_tid, "sz": sz})
                        except Exception:
                            continue

                    if not entries_64:
                        continue

                    # ── 3. Collect all valid 64×64 PNGs in file order ────────────
                    pngs_64 = self._collect_valid_pngs(mm, 64)

                    # ── 4. Pair by sequential position (entry[i] ↔ png[i]) ───────
                    for i, entry in enumerate(entries_64):
                        if i >= len(pngs_64):
                            break

                        off, png_data = pngs_64[i]
                        tid        = entry["tid"]
                        game_title, genre = self._resolve(tid)
                        icon_id    = f"{prefix}_{entry['idx']}"
                        h_cont     = hashlib.md5(png_data).hexdigest()[:8]
                        icon_path  = os.path.join(self.temp_dir, f"gp_{icon_id}_{h_cont}.png")

                        # V111: Always write the icon to ensure it's fresh
                        with open(icon_path, "wb") as f:
                            f.write(png_data)

                        all_meta.append({
                            "id": icon_id, "name": game_title, "pack": pack_name,
                            "genre": genre, "path": icon_path, "size": len(png_data),
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
            # V110: Use STFSWriter for a clean, valid package instead of manual patching
            from .stfs_writer import STFSWriter
            
            with open(it["path"], "rb") as f:
                png_data = f.read()
            
            display_name = it.get("name", "Gamerpic")
            writer = STFSWriter(title_id="FFFE07D1", display_name=display_name)
            stfs_data = writer.create_package(png_data)
            
            with open(output_path, "wb") as f:
                f.write(stfs_data)
            
            print(f"DEBUG: Created mini-STFS for {icon_id} (size: {len(stfs_data)})", file=sys.stderr)
            return True
        except Exception as e:
            print(f"Error in create_mini_stfs: {e}")
            return False


def get_manager():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    applib_path = os.path.join(base_dir, "..", "applib")
    return GamerpicManager(applib_path)
