import subprocess
import os
import json
import time
import sys
import re

class DriveInfo:
    def __init__(self, device, label, size_gb, mount_point, fstype, is_removable):
        self.device = device # For Linux e.g. /dev/sdb1, for Windows e.g. E:
        self.label = label
        self.size_gb = size_gb
        self.mount_point = mount_point # For Windows same as device
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
    if sys.platform == "win32":
        return _detect_windows_drives()
    return _detect_linux_drives()

def _detect_windows_drives():
    drives = []
    try:
        # Get logical disks where DriveType=2 (Removable)
        output = subprocess.check_output(["wmic", "logicaldisk", "where", "drivetype=2", "get", "deviceid,volumename,size", "/format:list"], text=True)
        
        current_drive = {}
        for line in output.splitlines():
            line = line.strip()
            if not line:
                if current_drive.get("DeviceID"):
                    drives.append(DriveInfo(
                        device=current_drive["DeviceID"],
                        label=current_drive.get("VolumeName") or "NO_LABEL",
                        size_gb=float(str(current_drive.get("Size", "0"))) / (1024**3),
                        mount_point=current_drive["DeviceID"],
                        fstype="FAT32", # Most Xbox drives are FAT32
                        is_removable=True
                    ))
                    current_drive = {}
                continue
            
            if "=" in line:
                key, val = line.split("=", 1)
                current_drive[key] = val
        
        # Catch last one
        if current_drive.get("DeviceID"):
            drives.append(DriveInfo(
                device=current_drive["DeviceID"],
                label=current_drive.get("VolumeName") or "NO_LABEL",
            size_gb=float(str(current_drive.get("Size", "0"))) / (1024**3),
                mount_point=current_drive["DeviceID"],
                fstype="FAT32",
                is_removable=True
            ))
    except Exception as e:
        sys.stderr.write(f"Windows Drive Detection Error: {e}\n")
    return drives

def _detect_linux_drives():
    drives = []
    try:
        output = subprocess.check_output(["lsblk", "-o", "NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,RM,TYPE,TRAN", "-J"]).decode()
        data = json.loads(output)
        
        def process_device(dev, parent_removable=False, parent_usb=False):
            rm_val = str(dev.get("rm", ""))
            is_removable = parent_removable or rm_val == "1" or rm_val.lower() == "true"
            is_usb = parent_usb or dev.get("tran") == "usb"
            
            children = dev.get("children", [])
            if children:
                for child in children:
                    process_device(child, is_removable, is_usb)
                return

            if is_removable or is_usb or dev.get("type") == "part":
                if not is_removable and not is_usb:
                    return
                
                name = dev.get("name")
                if not name.startswith("/dev/"):
                    name = f"/dev/{name}"
                
                mpts = dev.get("mountpoints") or []
                mpt = dev.get("mountpoint")
                if not mpt and mpts:
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
    if sys.platform == "win32":
        return _format_windows_fat32(device)
    return _format_linux_fat32(device)

def _format_windows_fat32(device):
    try:
        # device is usually E:
        drive_letter = device.rstrip(":/\\")
        cmd = ["format", f"{drive_letter}:", "/FS:FAT32", "/Q", "/V:X360TOOLS", "/Y"]
        subprocess.run(cmd, check=True)
        return True
    except Exception as e:
        sys.stderr.write(f"Windows Format Error: {e}\n")
        return False

def _format_linux_fat32(device):
    try:
        for _ in range(3):
            res = subprocess.run(["udisksctl", "unmount", "-b", device, "--force"], capture_output=True)
            if res.returncode == 0 or b"not mounted" in res.stderr:
                break
            time.sleep(1)

        subprocess.run(["udisksctl", "wipe-fs", "-b", device], check=False)
        cmd = ["mkfs.vfat", "-F", "32", "-I", "-n", "X360TOOLS", device]
        res = subprocess.run(cmd, capture_output=True)
        if res.returncode != 0:
            subprocess.run(["pkexec"] + cmd, check=True)
        return True
    except Exception as e:
        print(f"Format error: {e}")
        return False
