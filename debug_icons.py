import os
from core.library import LibraryScanner

scanner = LibraryScanner()
# We need a dummy mount point or just check the logic
# Actually, I'll just check what OGMetadataService returns now
from core.og_meta_loader import OGMetadataService
service = OGMetadataService()

tid = "4D530004" # Halo
path = service.get_icon_path(tid)
print(f"Icon path for {tid}: {path}")
print(f"Exists: {os.path.exists(path)}")
