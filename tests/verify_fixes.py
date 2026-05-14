import os
import sys
import shutil

# Ensure we can import core
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.converter import GameConverter

def test_zip_fallback():
    print("Testing ZIP Fallback...")
    converter = GameConverter(bin_dir="/tmp/empty_bin") # Force no 7z
    os.makedirs("/tmp/empty_bin", exist_ok=True)
    
    zip_path = "/tmp/test_freemarket/test.zip"
    extract_path = "/tmp/test_freemarket/extracted"
    if os.path.exists(extract_path): shutil.rmtree(extract_path)
    
    # Try extract
    try:
        success = converter.extract_archive(zip_path, extract_path)
        if success and os.path.exists(os.path.join(extract_path, "test.txt")):
            print("SUCCESS: ZIP Fallback worked!")
        else:
            print("FAILURE: ZIP Fallback failed!")
    except Exception as e:
        print(f"FAILURE: ZIP Fallback raised exception: {e}")

def test_binary_perms():
    print("Testing Binary Permissions...")
    bin_dir = "/tmp/test_freemarket"
    converter = GameConverter(bin_dir=bin_dir)
    
    # dummy_bin was created without +x
    bin_path = converter.get_bin_path("dummy_bin")
    if bin_path and os.access(bin_path, os.X_OK):
        print("SUCCESS: Binary permissions auto-fixed!")
    else:
        print("FAILURE: Binary permissions NOT fixed!")

if __name__ == "__main__":
    test_zip_fallback()
    test_binary_perms()
