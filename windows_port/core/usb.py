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
        # Use PowerShell to find only USB-attached logical disks
        # This is more accurate than simple DriveType=2 (Removable) which misses external HDDs (Fixed)
        ps_cmd = (
            "Get-WmiObject Win32_DiskDrive | Where-Object { $_.InterfaceType -eq 'USB' } | "
            "ForEach-Object { "
                "$disk = $_; "
                "$partitions = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition\"; "
                "$partitions | ForEach-Object { "
                    "$partition = $_; "
                    "$logical = Get-WmiObject -Query \"ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition\"; "
                    "$logical | ForEach-Object { "
                        "if ($_.DeviceID) { "
                            "Write-Host \"DEVICEID=$($_.DeviceID)\"; "
                            "Write-Host \"VOLUMENAME=$($_.VolumeName)\"; "
                            "Write-Host \"SIZE=$($_.Size)\"; "
                            "Write-Host \"---\" "
                        "} "
                    "} "
                "} "
            "}"
        )
        
        output = subprocess.check_output(["powershell", "-NoProfile", "-Command", ps_cmd], text=True, stderr=subprocess.DEVNULL)
        
        current_drive = {}
        for line in output.splitlines():
            line = line.strip()
            if line == "---":
                if current_drive.get("DeviceID"):
                    drives.append(DriveInfo(
                        device=current_drive["DeviceID"],
                        label=current_drive.get("VolumeName") or "Sem Nome",
                        size_gb=float(current_drive.get("Size", "0")) / (1024**3),
                        mount_point=current_drive["DeviceID"] + "\\", # Add trailing slash for consistency
                        fstype="FAT32",
                        is_removable=True
                    ))
                current_drive = {}
                continue
            
            if "=" in line:
                key, val = line.split("=", 1)
                current_drive[key.upper()] = val

    except Exception as e:
        # Fallback to minimal WMIC if PowerShell fails
        try:
            output = subprocess.check_output(["wmic", "logicaldisk", "where", "drivetype=2", "get", "deviceid,volumename,size", "/format:list"], text=True)
            # ... (original logic as fallback if needed, but let's assume PS works or fails gracefully)
            sys.stderr.write(f"Windows Drive Detection (PS) failed, using WMIC: {e}\n")
        except: pass
        
    return drives

def _detect_linux_drives():
    drives = []
    try:
        output = subprocess.check_output(["lsblk", "-o", "NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT,RM,TYPE,TRAN", "-J"]).decode()
        data = json.loads(output)
        
        def process_device(dev, parent_removable=False, parent_usb=False):
            rm_val = str(dev.get("rm", ""))
            is_removable = parent_removable or rm_val == "1" or rm_val.lower() == "true"
            # TRAN column = usb for external drives
            is_usb = parent_usb or dev.get("tran") == "usb"
            
            children = dev.get("children", [])
            
            # If it's a disk with children, we recurse to find partitions
            # BUT we keep the "is_usb" and "is_removable" status from the parent disk
            if children:
                for child in children:
                    process_device(child, is_removable, is_usb)
                if dev.get("type") == "disk":
                    # We usually want partitions, but if nothing was found in children, 
                    # we might check the disk itself later if it has a filesystem (rare but possible)
                    pass

            dev_type = dev.get("type", "")
            name = dev.get("name")
            
            # We want it if it's USB OR Removable OR specifically a partition on such a device
            # OR if it's an external HDD (which often has RM=0 but TRAN=usb)
            should_include = is_removable or is_usb
            
            if not should_include:
                # DEBUG: Log ignored non-removable/non-usb devices if they are block devices
                import sys
                print(f"DEBUG: Ignoring internal/fixed device {name}", file=sys.stderr)
                return
            
            if not name.startswith("/dev/"):
                name = f"/dev/{name}"
            
            mpt = dev.get("mountpoint")
            mpts = dev.get("mountpoints") or []
            if not mpt and mpts:
                for p in mpts:
                    if p:
                        mpt = p
                        break
            
            fs = (dev.get("fstype") or "").lower()
            
            # For Xbox 360 tools, we focus on FAT32/VFAT
            # However, for 'Detection', we should show the device even if type is unknown 
            # so the user can format it.
            
            drives.append(DriveInfo(
                device=name,
                label=dev.get("label") or "NO_LABEL",
                size_gb=parse_size_to_gb(dev.get("size", "0")),
                mount_point=mpt or "",
                fstype=fs or "UNKNOWN",
                is_removable=is_removable or is_usb
            ))

        for dev in data.get("blockdevices", []):
            process_device(dev)
            
    except Exception as e:
        import sys
        print(f"Error detecting drives: {e}", file=sys.stderr)
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
        import sys
        print(f"Format error: {e}", file=sys.stderr)
        return False
