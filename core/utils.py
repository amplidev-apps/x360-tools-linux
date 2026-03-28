import urllib.request
import zipfile
import os

def download_file(url, filename, progress_callback=None, cancel_event=None):
    os.makedirs("temp", exist_ok=True)
    target_path = os.path.join("temp", filename)
    
    def report(block_num, block_size, total_size):
        if cancel_event and cancel_event.is_set():
            raise Exception("CancelledByUser")
        if progress_callback and total_size > 0:
            percent = min(100, int(block_num * block_size * 100 / total_size))
            progress_callback(percent)

    # Check if URL is valid (avoid 404s)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            if response.status != 200:
                raise Exception(f"Failed to download: HTTP {response.status}")
    except Exception as e:
        raise Exception(f"URL Unreachable: {url} ({e})")

    # urlretrieve doesn't easily support custom headers, but we can install an opener
    opener = urllib.request.build_opener()
    opener.addheaders = [('User-Agent', 'Mozilla/5.0')]
    urllib.request.install_opener(opener)
    
    urllib.request.urlretrieve(url, target_path, reporthook=report)
    return target_path

def extract_zip(zip_path, extract_path, cancel_event=None):
    if not extract_path or not os.path.exists(extract_path):
        raise ValueError(f"Invalid extraction path: {extract_path}")
    
    with zipfile.ZipFile(zip_path, "r") as z:
        for member in z.infolist():
            if cancel_event and cancel_event.is_set():
                raise Exception("CancelledByUser")
            member_path = os.path.normpath(member.filename)
            if member_path.startswith("..") or member_path.startswith("/"):
                continue
            
            # Ensure we are extracting into the target directory
            z.extract(member, extract_path)

def get_free_space(path):
    """Returns the free space in bytes for the given path."""
    import shutil
    try:
        # If path doesn't exist, check its parent
        check_path = path
        while not os.path.exists(check_path) and check_path != "/":
            check_path = os.path.dirname(check_path)
        stat = shutil.disk_usage(check_path)
        return stat.free
    except:
        return 0

def format_size(size_bytes):
    """Formats bytes to a human-readable string."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} PB"
def normalize_for_map(name):
    """Normalize names for static map lookup (consistent with builder v5)."""
    import re
    if not name: return ""
    name = name.lower()
    
    # Synonyms and common Scene/Archive noise
    name = name.replace("_", " ")
    name = name.replace(" - ", " ")
    name = re.sub(r'\bwm\b', 'world cup', name)
    name = re.sub(r'\bhx\b', '', name)
    name = re.sub(r'\bmajor league baseball\b', 'mlb', name)
    name = re.sub(r'\bxbox360\b', '', name)
    name = re.sub(r'\b360\b', '', name)
    name = re.sub(r'\bredump\b', '', name)
    name = re.sub(r'\bntsc\b', '', name)
    name = re.sub(r'\bpal\b', '', name)
    name = re.sub(r'\bjtag\b', '', name)
    name = re.sub(r'\brgh\b', '', name)
    name = re.sub(r'\bgod\b', '', name)
    
    replacements = {
        r'\b1\b': 'i', r'\b2\b': 'ii', r'\b3\b': 'iii',
        r'\b4\b': 'iv', r'\b5\b': 'v', r'\b6\b': 'vi',
        r'\b7\b': 'vii', r'\b8\b': 'viii', r'\b9\b': 'ix',
        r'\b10\b': 'x'
    }
    for arabic, roman in replacements.items():
        name = re.sub(arabic, roman, name)
    
    # Remove metadata tags
    name = re.sub(r'\(.*?\)', '', name)
    name = re.sub(r'\[.*?\]', '', name)
    
    # Strip non-alphanumeric
    name = re.sub(r'[^a-z0-9]', '', name)
    return name
