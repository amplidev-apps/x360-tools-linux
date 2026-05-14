try:
    from core.crypto import STFSCrypto
except ImportError:
    from .crypto import STFSCrypto
import struct
import hashlib
import os
import binascii

# STFS V1 Constants
STFS_HEADER_SIZE      = 0xAC00
STFS_BLOCK_SIZE       = 0x1000
STFS_MAGIC_LIVE       = b"LIVE"

# Metadata Offsets (STFS V1 Standard)
OFF_SIGNATURE         = 0x004
OFF_HEADER_HASH       = 0x32C
OFF_DESCRIPTOR        = 0x344
OFF_CONTENT_TYPE      = 0x344
OFF_TITLE_ID          = 0x360
OFF_MASTER_HASH       = 0x381
OFF_DISPLAY_NAME      = 0x411
OFF_DESCRIPTION       = 0x491
OFF_TITLE_NAME        = 0x591


class STFSWriter:
    """A professional STFS LIVE signer for Xbox 360."""

    def __init__(self, title_id="FFFE07D1", display_name="Custom Gamerpic"):
        self.title_id     = title_id
        self.display_name = display_name
        self.header       = bytearray(STFS_HEADER_SIZE)
        self._init_header()

    def _init_header(self):
        # 1. Start with Magic
        self.header[0:4] = STFS_MAGIC_LIVE
        
        # 2. Try to load original metadata structure from base template
        base_dir = os.path.dirname(os.path.abspath(__file__))
        template_path = os.path.join(base_dir, "..", "applib", "custom_gp_40150.stfs")
        if os.path.exists(template_path):
            with open(template_path, "rb") as f:
                # Read the entire first metadata area
                self.header[:] = f.read(STFS_HEADER_SIZE)
                
        # 3. Force Magic to LIVE
        self.header[0:4] = STFS_MAGIC_LIVE
        
        # 4. Patch Metadata with custom info
        # Title ID (Big Endian)
        struct.pack_into(">I", self.header, OFF_TITLE_ID, int(self.title_id, 16))
        # Content Type (Big Endian, 0x00020000 = Gamerpic)
        struct.pack_into(">I", self.header, OFF_CONTENT_TYPE, 0x00020000)
        
        # Display Name & Descriptions (UTF-16BE strictly 128 bytes)
        name_utf16 = self.display_name.encode("utf-16be")
        limit = 128
        for off in [OFF_DISPLAY_NAME, OFF_DESCRIPTION, OFF_TITLE_NAME]:
            # Clear area
            self.header[off: off + 128 * 2] = b"\x00" * (128 * 2) 
            # Write name
            self.header[off: off + min(len(name_utf16), 128 * 2)] = name_utf16[:128 * 2]

        # 5. Clear signature area before calculation
        self.header[OFF_SIGNATURE : OFF_SIGNATURE + 256] = b"\x00" * 256
        self.header[OFF_HEADER_HASH : OFF_HEADER_HASH + 20] = b"\x00" * 20
        self.header[OFF_MASTER_HASH : OFF_MASTER_HASH + 20] = b"\x00" * 20

    def create_package(self, png_data):
        """Creates a signed 64KB LIVE package using MS Retail keys."""
        
        # 1. Prepare Directory Entry (V1 Block 0)
        # Offset 0xC000 in file
        dir_entry = bytearray(0x40)
        name_b = b"64_Gamerpic.png" 
        dir_entry[0: len(name_b)] = name_b
        dir_entry[0x28] = len(name_b) # STFS Name Length
        
        blocks_allocated = (len(png_data) + 0xFFF) // 0x1000
        # Allocated Count: Little Endian (3 bytes)
        dir_entry[0x29:0x2C] = blocks_allocated.to_bytes(3, 'little') 
        # Start Block Number: Little Endian (3 bytes) (Gamerpic PNG starts at block 1)
        dir_entry[0x2C:0x2F] = (1).to_bytes(3, 'little') 
        dir_entry[0x2F] = 0x00 # Type = File
        # File Size: Big Endian (4 bytes)
        struct.pack_into(">I", dir_entry, 0x30, len(png_data)) 
        
        # 2. Create Data Blocks
        # Block 0: Directory listing
        data_block_0 = bytearray(0x1000)
        data_block_0[0:0x40] = dir_entry
        
        # Block 1+: PNG data
        png_blocks = []
        for i in range(0, len(png_data), 0x1000):
            block = bytearray(0x1000)
            chunk = png_data[i: i+0x1000]
            block[:len(chunk)] = chunk
            png_blocks.append(block)
            
        # 3. Generate Level 0 Hash Block (at 0xAC00)
        # Each record is 24 bytes (20 hash + 4 status)
        hash_block_l0 = bytearray(0x1000)
        
        # Hash record for Block 0 (Directory)
        hash_block_l0[0:20] = hashlib.sha1(data_block_0).digest()
        hash_block_l0[20:24] = binascii.unhexlify("80000000") # EOF
        
        # Hash records for PNG blocks
        for i, pb in enumerate(png_blocks):
            off = (i + 1) * 24 
            hash_block_l0[off : off+20] = hashlib.sha1(pb).digest()
            status = 0x80 if i == len(png_blocks) - 1 else 0xC0
            next_p = 0 if i == len(png_blocks) - 1 else i + 2
            val = (status << 24) | next_p
            struct.pack_into(">I", hash_block_l0, off+20, val)
            
        # 4. Merkle Tree & Header Re-Hashing
        # Master Hash = SHA1(Level 0 Hash Table)
        master_hash = hashlib.sha1(hash_block_l0).digest()
        self.header[OFF_MASTER_HASH : OFF_MASTER_HASH + 20] = master_hash
        
        # Header Hash = SHA1(header[0x344 : 0xAC00])
        meta_to_hash = self.header[OFF_DESCRIPTOR : STFS_HEADER_SIZE]
        header_hash = hashlib.sha1(meta_to_hash).digest()
        self.header[OFF_HEADER_HASH : OFF_HEADER_HASH + 20] = header_hash
        
        # 5. RSA Resign
        # MS Retail Signer for LIVE/PIRS: signs exactly 0x118 bytes starting at 0x22C
        signature = STFSCrypto.sign_stfs_header(self.header)
        self.header[OFF_SIGNATURE : OFF_SIGNATURE + 256] = signature
        
        # 6. Assembly
        full_file = bytearray(self.header)
        # Hash Table area (starts immediately after header)
        full_file.extend(hash_block_l0) # 0xAC00 - 0xBC00
        # Data area (starts at 0xC000 for standard small STFS packages)
        full_file.extend(b"\x00" * (0xC000 - len(full_file)))
        full_file.extend(data_block_0)
        for pb in png_blocks:
            full_file.extend(pb)
            
        # Pad to exactly 64KB (minimum valid 360 STFS size)
        if len(full_file) < 0x10000:
            full_file.extend(b"\x00" * (0x10000 - len(full_file)))
            
        return full_file
