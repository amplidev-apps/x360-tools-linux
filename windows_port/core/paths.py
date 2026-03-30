import os
import sys

def get_user_data_dir():
    """Returns the platform-specific user data directory for x360tools."""
    if sys.platform == "win32":
        # Windows: %APPDATA%\x360tools
        appdata = os.environ.get("APPDATA")
        if appdata:
            return os.path.join(appdata, "x360tools")
        return os.path.join(os.path.expanduser("~"), "AppData", "Roaming", "x360tools")
    else:
        # Linux: ~/.x360tools
        return os.path.expanduser("~/.x360tools")

def get_bin_ext():
    """Returns the platform-specific binary extension."""
    return ".exe" if sys.platform == "win32" else ""

def ensure_user_dirs():
    """Ensures all required user data subdirectories exist."""
    root = get_user_data_dir()
    subdirs = [
        "",
        "freemarket",
        "freemarket/ia_dbs",
        "freemarket/install_temp",
        "cache",
        "cache/covers",
        "gallery",
        "gallery/gamerpics",
        "logs"
    ]
    for sd in subdirs:
        path = os.path.join(root, sd)
        os.makedirs(path, exist_ok=True)
    return root
