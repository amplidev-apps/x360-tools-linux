import os
import sys
import tempfile
import shutil

# Ensure access to core
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.gamerpics import GamerpicManager

def test_extraction_logic():
    print("=== Gamerpic Extraction Unit Test ===")
    
    # Simple mock check: We can't easily bake a full STFS here, 
    # but we can verify the manager initializes and can resolve IDs.
    lib_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../applib'))
    manager = GamerpicManager(lib_dir)
    
    # Test Resolution
    name, genre = manager._resolve("4D5307E6") # Halo 3
    print(f"Resolved 4D5307E6: {name} ({genre})")
    
    if "Halo 3" in name:
        print("[OK] Metadata resolution working.")
    else:
        print("[WARNING] Metadata resolution returned unexpected name (check applib/games.json)")

    # Test PNG End Seeking (IEND Chunk)
    # Mock PNG: Header + IHDR + ... + IEND
    # PNG Sig: 8 bytes, IEND chunk: 4 len (0) + 4 type (IEND) + 4 crc = 12 bytes
    mock_png = b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0DIHDR" + (b"\x00"*13) + b"CRC " + b"\x00\x00\x00\x00IEND\xAE\x42\x60\x82"
    
    import mmap
    with tempfile.NamedTemporaryFile() as tf:
        tf.write(mock_png)
        tf.flush()
        with open(tf.name, "r+b") as f:
            mm = mmap.mmap(f.fileno(), 0)
            end_pos = manager._find_png_end(mm, 0)
            print(f"Seeked PNG end: {end_pos} (Expected around {len(mock_png)})")
            
            if end_pos > 0:
                print("[OK] IEND-based seeking successful.")
            else:
                print("[ERROR] IEND-based seeking failed!")
            mm.close()

    print("\n=== TEST COMPLETE ===")

if __name__ == "__main__":
    test_extraction_logic()
