import os
import sys

def get_user_data_dir():
    """Returns the platform-specific user data directory for x360tools."""
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        if appdata:
            return os.path.join(appdata, "x360tools")
        return os.path.join(os.path.expanduser("~"), "AppData", "Roaming", "x360tools")
    else:
        user_home = os.environ.get("HOME")
        sudo_user = os.environ.get("SUDO_USER")
        if sudo_user and os.getuid() == 0:
            user_home = os.path.expanduser(f"~{sudo_user}")
        return os.path.join(user_home, ".x360tools")

def get_bin_ext():
    """Returns the platform-specific binary extension."""
    return ".exe" if sys.platform == "win32" else ""

def get_user_agent():
    """Returns a platform-appropriate User-Agent string."""
    if sys.platform == "win32":
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    return "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

def sqlite_uri(path):
    """Converts a filesystem path to a valid SQLite file: URI, cross-platform.

    On Windows, SQLite's URI mode requires backslashes converted to forward
    slashes and an extra slash before the drive letter.
    Example: C:\\Users\\x\\db.sqlite -> file:/C:/Users/x/db.sqlite?mode=ro
    """
    abs_path = os.path.abspath(path)
    if sys.platform == "win32":
        forward = abs_path.replace("\\", "/")
        return f"file:/{forward}?mode=ro"
    return f"file:{abs_path}?mode=ro"

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
