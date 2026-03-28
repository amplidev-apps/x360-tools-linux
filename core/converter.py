import os
import subprocess
import threading
import shutil

class GameConverter:
    def __init__(self, bin_dir=None):
        if bin_dir is None:
            # Default to 'bin' directory next to the script
            self.bin_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
        else:
            self.bin_dir = bin_dir
            
    def get_bin_path(self, bin_name):
        """Find the binary in bin/ or system PATH."""
        # Check in bin_dir first
        local_path = os.path.join(self.bin_dir, bin_name)
        if os.path.exists(local_path) and os.access(local_path, os.X_OK):
            return local_path
            
        # Fallback to system PATH
        path = shutil.which(bin_name)
        return path

    def extract_xiso(self, iso_path, dest_dir, progress_cb=None, allow_errors=False):
        """Extracts an Original Xbox ISO."""
        bin_path = self.get_bin_path("extract-xiso")
        if not bin_path:
            raise FileNotFoundError("extract-xiso binary not found.")
            
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [bin_path, "-x", "-d", dest_dir, iso_path]
        return self._run_command(cmd, progress_cb, allow_errors)

    def extract_archive(self, archive_path, dest_dir, progress_cb=None):
        """Extracts any archive (.zip, .7z, .rar, .iso) using 7z."""
        bin_path = self.get_bin_path("7z") or self.get_bin_path("7za")
        if not bin_path:
            raise FileNotFoundError("7z binary not found. Please install p7zip-full.")
            
        os.makedirs(dest_dir, exist_ok=True)
        # -y: assume yes on all queries
        # -o: output directory
        cmd = [bin_path, "x", archive_path, f"-o{dest_dir}", "-y"]
        return self._run_command(cmd, progress_cb)

    def iso_to_god(self, iso_path, dest_dir, progress_cb=None, allow_errors=False):
        """Converts an ISO to GOD."""
        bin_path = self.get_bin_path("iso2god-rs") or self.get_bin_path("iso2god")
        if not bin_path:
            raise FileNotFoundError("ISO2GOD binary not found.")
            
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [bin_path, iso_path, dest_dir]
        return self._run_command(cmd, progress_cb, allow_errors)

    def _run_command(self, cmd, progress_cb=None, allow_errors=False):
        """Runs a subprocess and monitors output."""
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            if process.stdout:
                for line in process.stdout:
                    if progress_cb:
                        # simplistic progress parsing (can be refined per tool)
                        progress_cb(line.strip())

            process.wait()
            if process.returncode != 0:
                if allow_errors:
                    if progress_cb: progress_cb(f"Warning: Command exited with code {process.returncode} (Continued as requested).")
                    return True
                raise Exception(f"Command failed with exit code {process.returncode}")
            
            return True
        except Exception as e:
            if progress_cb:
                progress_cb(f"Error: {str(e)}")
            raise e
