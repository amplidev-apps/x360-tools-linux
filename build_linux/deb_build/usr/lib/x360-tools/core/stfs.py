import struct
import os
import shutil
import tempfile

# STFS Offsets (Reference: Free60 / Arkem)
OFFSET_TITLE_ID = 0x360
OFFSET_CONTENT_TYPE = 0x344
OFFSET_MEDIA_ID = 0x354
OFFSET_DISPLAY_NAME = 0x411 
OFFSET_DESCRIPTION = 0x491
OFFSET_THUMBNAIL_SIZE = 0x1716
OFFSET_THUMBNAIL_DATA = 0x171A

CONTENT_TYPES = {
    0x00000001: "Game Save",
    0x00000002: "DLC / Marketplace",
    0x00001000: "Video",
    0x00002000: "Game Demo",
    0x00007000: "Games on Demand (GoD)",
    0x00010000: "Installed Game",
    0x00020000: "Xbox 360 Original Game",
    0x00030000: "Avatar Item",
    0x00040000: "Profile",
    0x00070000: "Theme",
    0x00080000: "Gamer Picture",
    0x000D0000: "XBLA Game / Arcade",
    0x000B0000: "Title Update (TU)"
}

def get_stfs_metadata(path, extract_icon=False):
    """
    Reads detailed metadata from an Xbox 360 STFS package.
    """
    if not os.path.exists(path):
        return None

    try:
        with open(path, "rb") as f:
            header = f.read(0x4)
            if header not in [b"CON ", b"LIVE", b"PIRS"]:
                return None 

            # Read Title ID
            f.seek(OFFSET_TITLE_ID)
            title_id = f.read(4).hex().upper()

            # Read Media ID
            f.seek(OFFSET_MEDIA_ID)
            media_id = f.read(4).hex().upper()

            # Read Content Type
            f.seek(OFFSET_CONTENT_TYPE)
            type_id = struct.unpack(">I", f.read(4))[0]
            type_name = CONTENT_TYPES.get(type_id, f"Unknown ({hex(type_id)})")

            # Read Console ID (5 bytes)
            f.seek(0x369)
            console_id = f.read(5).hex().upper()

            # Read Profile ID (8 bytes)
            f.seek(0x371)
            profile_id = f.read(8).hex().upper()

            # Read Display Name (UTF-16BE)
            f.seek(OFFSET_DISPLAY_NAME)
            name_raw = f.read(128)
            display_name = name_raw.decode("utf-16be").split("\x00")[0]

            # Read Description (UTF-16BE)
            f.seek(OFFSET_DESCRIPTION)
            desc_raw = f.read(128)
            description = desc_raw.decode("utf-16be").split("\x00")[0]

            icon_path = None
            if extract_icon:
                f.seek(OFFSET_THUMBNAIL_SIZE)
                icon_size = struct.unpack(">I", f.read(4))[0]
                if 0 < icon_size < 0x8000: # Sanity check
                    f.seek(OFFSET_THUMBNAIL_DATA)
                    icon_data = f.read(icon_size)
                    
                    # 🛡️ Icon Validation (V107): Ensure we have valid image data
                    # Check for common magic bytes: PNG (\x89PNG), JPEG (\xFF\xD8), BMP (BM)
                    is_valid = False
                    if icon_data.startswith(b"\x89PNG") or icon_data.startswith(b"\xff\xd8") or icon_data.startswith(b"BM"):
                        is_valid = True
                    
                    if is_valid:
                        # Save to temp file
                        # V108: Unique icon path per package (Fix for overlapping thumbnails)
                        import hashlib
                        h_path = hashlib.md5(path.encode()).hexdigest()[:8]
                        h_cont = hashlib.md5(icon_data).hexdigest()[:8]
                        temp_dir = tempfile.gettempdir()
                        icon_path = os.path.join(temp_dir, f"x360_icon_{title_id}_{h_path}_{h_cont}.png")
                        with open(icon_path, "wb") as icon_f:
                            icon_f.write(icon_data)
                    else:
                        icon_path = None # Return None if data is not a recognizable image

            return {
                "title_id": title_id,
                "media_id": media_id,
                "type_id": type_id,
                "type_hex": hex(type_id).upper().replace("0X", ""),
                "type_name": type_name,
                "display_name": display_name or "Unknown",
                "description": description or "",
                "console_id": console_id,
                "profile_id": profile_id,
                "icon_path": icon_path
            }
    except Exception as e:
        print(f"Error reading STFS: {e}")
        return None

def install_package(pkg_path, usb_root):
    """
    Installs an STFS package to the correct directory structure.
    """
    meta = get_stfs_metadata(pkg_path)
    if not meta:
        raise ValueError("Invalid STFS package")

    if not meta or not meta.get("title_id"):
        raise ValueError("Invalid STFS package or Title ID")

    dest_dir = os.path.join(
        str(usb_root), 
        "Content", 
        "0000000000000000", 
        str(meta["title_id"]), 
        str(meta["type_hex"]).zfill(8)
    )

    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, str(os.path.basename(pkg_path)))
    shutil.copy2(pkg_path, dest_path)
    return dest_path

def list_usb_content(usb_root):
    """
    Scans the Xbox 360 Content folder on a USB drive and returns a grouped dictionary.
    Structure: { title_id: { "name": "Game Name", "icon": "path", "items": [...] } }
    """
    content_dir = os.path.join(usb_root, "Content")
    if not os.path.exists(content_dir):
        return {}

    games = {} # title_id -> { "name": str, "icon": str, "items": [] }

    # Walk the directory structure
    for root, dirs, files in os.walk(content_dir):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                # Basic size check to skip small files
                if os.path.getsize(file_path) < 0x971B:
                    continue
                    
                meta = get_stfs_metadata(file_path, extract_icon=True)
                if meta and meta.get("title_id"):
                    tid = meta["title_id"]
                    if tid not in games:
                        games[tid] = {
                            "name": meta["display_name"],
                            "icon": meta["icon_path"],
                            "items": []
                        }
                    
                    # Update game name if we find a better one (some DLCs have generic names)
                    if meta["type_name"] == "Marketplace Content" and games[tid]["name"] == "Unknown":
                        games[tid]["name"] = meta["display_name"]
                        
                    meta["file_path"] = file_path
                    games[tid]["items"].append(meta)
            except:
                continue
                
    return games

def extract_package(pkg_path, dest_path):
    """Copies a package from USB back to the computer."""
    if not os.path.exists(pkg_path):
        raise FileNotFoundError("Package not found on device")
    
    # Ensure destination is a full path including filename
    if os.path.isdir(dest_path):
        dest_path = os.path.join(dest_path, os.path.basename(pkg_path))
        
    shutil.copy2(pkg_path, dest_path)
    return dest_path
