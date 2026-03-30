import struct
import hashlib
import os

# STFS Constants
STFS_HEADER_SIZE      = 0xAC00
STFS_BLOCK_SIZE       = 0x1000
STFS_HASH_BLOCK_GAP   = 0xAA      # One hash block every 170 data blocks
STFS_MAGIC_CON        = b"CON "

# Metadata Offsets
OFF_CONTENT_ID        = 0x32C
OFF_CONTENT_TYPE      = 0x344
OFF_TITLE_ID          = 0x360
OFF_CONSOLE_ID        = 0x369
OFF_PROFILE_ID        = 0x371
OFF_DISPLAY_NAME      = 0x411
OFF_DESCRIPTION       = 0x491
OFF_TITLE_NAME        = 0x591


class STFSWriter:
    """A minimal STFS CON writer for Gamer Pictures."""

    def __init__(self, title_id="FFFE07D1", display_name="Custom Gamerpic"):
        self.title_id     = title_id
        self.display_name = display_name
        self.header       = bytearray(STFS_HEADER_SIZE)
        self._init_header()

    def _init_header(self):
        # Magic
        self.header[0:4] = STFS_MAGIC_CON
        
        # Content Type: Gamer Picture (0x00020000)
        # Note: Some sources say 0x00080000, but 0x00020000 is common for Marketplace/Gamerpics
        struct.pack_into(">I", self.header, OFF_CONTENT_TYPE, 0x00020000)
        
        # Title ID
        self.header[OFF_TITLE_ID: OFF_TITLE_ID + 4] = bytes.fromhex(self.title_id)
        
        # Profile ID (Global: 0000000000000000)
        self.header[OFF_PROFILE_ID: OFF_PROFILE_ID + 8] = b"\x00" * 8
        
        # Console ID (Can be 0 for CON)
        self.header[OFF_CONSOLE_ID: OFF_CONSOLE_ID + 5] = b"\x00" * 5

        # Display Name (UTF-16BE)
        name_utf16 = self.display_name.encode("utf-16be")
        self.header[OFF_DISPLAY_NAME: OFF_DISPLAY_NAME + len(name_utf16)] = name_utf16
        
        # Descriptions
        self.header[OFF_DESCRIPTION: OFF_DESCRIPTION + len(name_utf16)] = name_utf16
        self.header[OFF_TITLE_NAME: OFF_TITLE_NAME + len(name_utf16)] = name_utf16

    def create_package(self, png_data):
        """Creates a minimal 1-file STFS package with the given PNG and returns the bytearray."""
        
        # STFS is block-based. We need:
        # 1. Header (0xAC00) + Padding to 0xC000
        # 2. Hash Block 0 (0x1000) at 0xC000 ? 
        # Actually, for small files, many tools start data at 0xC000 and ignore advanced hashing
        # But to be safe, we'll follow the standard structure seen in real packs.
        
        # Let's align with what GamerpicManager expected:
        # dir_offset at 0xCD00 (which is entry in a data block)
        # png data starting after dir entries.
        
        file_data = bytearray()
        
        # Directory Entry (64 bytes)
        # 0x00: Filename (40 bytes)
        # 0x2F: First Block (3 bytes)
        # 0x34: Size (4 bytes)
        dir_entry = bytearray(0x40)
        name_b = b"64_custom.png"
        dir_entry[0: len(name_b)] = name_b
        struct.pack_into(">I", dir_entry, 0x34, len(png_data))
        # First block = 0 (we only have one file)
        dir_entry[0x2F] = 0x00 
        
        # The directory table is usually in the first data block.
        # Data block 0 starts at 0xC000 (after header 0xAC00 + Hash Block 0x1000 + some padding?)
        # Standard: 
        # 0x0 - 0xAC00: Header
        # 0xAC00 - 0xB000: Padding
        # 0xB000 - 0xC000: Hash Block 0
        # 0xC000 - 0xD000: Data Block 0 (contains Directory)
        # 0xD000 - 0xE000: Data Block 1 (contains PNG part 1)
        
        # BUILD FILE:
        full_file = bytearray(self.header)
        full_file.extend(b"\x00" * (0xB000 - len(full_file)))
        
        # Hash Block 0 (Placeholder)
        hash_block = bytearray(0x1000)
        
        # Data Block 0 (Directory)
        data_block_0 = bytearray(0x1000)
        data_block_0[0xD00: 0xD00 + 0x40] = dir_entry # Put at 0xD00 in block => 0xC000 + 0xD00 = 0xCD00
        
        # Data Block 1+ (PNG)
        png_blocks = []
        for i in range(0, len(png_data), 0x1000):
            block = bytearray(0x1000)
            chunk = png_data[i: i+0x1000]
            block[:len(chunk)] = chunk
            png_blocks.append(block)
            
        # Hashing
        # Hash of Data Block 0
        h0 = hashlib.sha1(data_block_0).digest()
        hash_block[0:20] = h0
        # Hashes of PNG blocks
        for i, pb in enumerate(png_blocks):
            h = hashlib.sha1(pb).digest()
            # Store in hash block (24 bytes per entry: 20 hash + 4 metadata)
            off = (i + 1) * 24 
            hash_block[off: off+20] = h
            
        # Update Content Size in Header
        struct.pack_into(">I", full_file, 0x398, (1 + len(png_blocks))) # Block count
        
        # Assemble
        full_file.extend(hash_block)
        full_file.extend(data_block_0)
        for pb in png_blocks:
            full_file.extend(pb)
            
        # Final signature (Null signature for CON)
        # In a real CON, 0x4 - 0x22C is the RSA signature.
        # RGH consoles ignore it if it's all zeros or garbage as long as it's there.
        full_file[4: 0x22C] = b"\x00" * (0x22C - 4)
        
        return full_file

