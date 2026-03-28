import subprocess
import os
import json
import time

class DriveInfo:
    def __init__(self, device, label, size_gb, mount_point, fstype, is_removable):
        self.device = device
        self.label = label
        self.size_gb = size_gb
        self.mount_point = mount_point
        self.fstype = fstype
        self.is_removable = is_removable

import re

def parse_size_to_gb(size_str):
    if not size_str: return 0.0
    size_str = str(size_str).upper().strip()
    
    match = re.search(r"([\d\.]+)", size_str)
    if not match: return 0.0
    
    val = float(match.group(1))
    
    if "T" in size_str: return val * 1024.0
    if "G" in size_str: return val
    if "M" in size_str: return val / 1024.0
    if "K" in size_str: return val / (1024.0**2)
    
    if "B" in size_str and not any(x in size_str for x in ["T", "G", "M", "K"]):
        return val / (1024.0**3) # Pure bytes
        
    return val / (1024.0**3) # Default assume bytes if no unit matched

def detect_removable_drives():
    drives = []
    try:
        # Get all block devices with relevant info
        # RM column is 1 for removable, TRAN is usb for external drives
        output = subprocess.check_output(["lsblk", "-o", "NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,RM,TYPE,TRAN", "-J"]).decode()
        data = json.loads(output)
        
        def process_device(dev, parent_removable=False, parent_usb=False):
            # Check if it's removable OR its parent is removable
            rm_val = str(dev.get("rm", ""))
            is_removable = parent_removable or rm_val == "1" or rm_val.lower() == "true"
            is_usb = parent_usb or dev.get("tran") == "usb"
            
            # We are interested in partitions or disks that have a filesystem OR are removable
            # If it's a disk with children, we usually want the children (partitions)
            # But if it's a disk WITHOUT children (e.g. raw formatted USB), we want the disk.
            
            children = dev.get("children", [])
            if children:
                for child in children:
                    process_device(child, is_removable, is_usb)
                return

            if is_removable or is_usb or dev.get("type") == "part":
                # Only include it if it's actually removable (USB) or on the USB bus
                if not is_removable and not is_usb:
                    return
                
                name = dev.get("name")
                if not name.startswith("/dev/"):
                    name = f"/dev/{name}"
                
                mpts = dev.get("mountpoints") or []
                mpt = dev.get("mountpoint")
                if not mpt and mpts:
                    # Get the first non-null mountpoint
                    for p in mpts:
                        if p:
                            mpt = p
                            break
                
                drives.append(DriveInfo(
                    device=name,
                    label=dev.get("label") or "NO_LABEL",
                    size_gb=parse_size_to_gb(dev.get("size", "0")),
                    mount_point=mpt or "",
                    fstype=dev.get("fstype") or "UNKNOWN",
                    is_removable=True
                ))

        for dev in data.get("blockdevices", []):
            process_device(dev)
            
    except Exception as e:
        print(f"Error detecting drives: {e}")
    return drives

def format_fat32(device):
    """Formats the given device to FAT32. WARNING: This erases data."""
    try:
        # Unmount first if mounted, use --force to avoid 'Device Busy'
        # We try multiple times if it's busy
        for _ in range(3):
            res = subprocess.run(["udisksctl", "unmount", "-b", device, "--force"], capture_output=True)
            if res.returncode == 0 or b"not mounted" in res.stderr:
                break
            time.sleep(1)

        # Attempt formatting via udisks2 (sudo-less if policy allows)
        # Note: udisksctl format is not always available, we fallback to mkfs
        # But for 'automatic' without sudo, we can try pkexec or udisks dbus
        
        # Try udisksctl wipe-fs first if it exists (some versions have it)
        subprocess.run(["udisksctl", "wipe-fs", "-b", device], check=False)

        # Re-running mkfs.vfat with -I -F 32
        # If user wants NO sudo, we must hope they have permissions or use pkexec
        # Let's try to use udisksctl to CREATE the filesystem if the command exists
        # Actually, let's use a more reliable fallback
        
        cmd = ["mkfs.vfat", "-F", "32", "-I", "-n", "X360TOOLS", device]
        # Try without sudo first (maybe user in disk group)
        res = subprocess.run(cmd, capture_output=True)
        if res.returncode != 0:
            # Try with pkexec (graphical prompt) instead of sudo (terminal prompt)
            # This is 'automatic' in the sense that it handles the auth properly in UI
            subprocess.run(["pkexec"] + cmd, check=True)
            
        return True
    except Exception as e:
        print(f"Format error: {e}")
        return False
