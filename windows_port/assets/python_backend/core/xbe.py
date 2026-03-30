import struct
import os

def get_xbe_metadata(path):
    """
    Extracts TitleID and other basic info from an Original Xbox XBE file.
    """
    if not os.path.exists(path):
        return None

    try:
        with open(path, "rb") as f:
            # Check magic
            if f.read(4) != b"XBEH":
                return None
            
            # Certificate offset is at 0x118
            f.seek(0x118)
            cert_offset = struct.unpack("<I", f.read(4))[0]
            
            # Title ID is at cert_offset + 8 (4 bytes)
            f.seek(cert_offset + 8)
            title_id = f.read(4).hex().upper()
            
            return {
                "title_id": title_id,
                "type": "XBE (OG)"
            }
    except Exception as e:
        print(f"Error reading XBE: {e}")
        return None
