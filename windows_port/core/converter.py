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
        from core.paths import get_bin_ext
        ext = get_bin_ext()
        
        # Check if name already has extension
        if ext and not bin_name.endswith(ext):
            bin_name_ext = bin_name + ext
        else:
            bin_name_ext = bin_name

        # Check in bin_dir first
        local_path = os.path.join(self.bin_dir, bin_name_ext)
        if os.path.exists(local_path):
            if sys.platform != "win32" and not os.access(local_path, os.X_OK):
                pass # Continue to fallback if not executable on Linux
            else:
                return local_path
            
        # Fallback to system PATH
        path = shutil.which(bin_name_ext) or shutil.which(bin_name)
        return path

    def check_rar_support(self):
        """Checks if 7z or unrar supports extraction of the current archive."""
        # Try unrar first as it's the most reliable for RAR
        if self.get_bin_path("unrar"):
            return "unrar"
        
        # Check if 7z has RAR codec
        bin_7z = self.get_bin_path("7z") or self.get_bin_path("7zz")
        if bin_7z:
            try:
                # 7z i lists codecs. We check for 'Rar' with decompression support
                res = subprocess.check_output([bin_7z, "i"], text=True, stderr=subprocess.STDOUT)
                for line in res.splitlines():
                    if "Rar " in line and ("D" in line or "." not in line.split()[1]): # simplistic check
                        return "7z"
            except:
                pass
        return None

    def extract_xiso(self, iso_path, dest_dir, progress_cb=None, allow_errors=False, **kwargs):
        """Extracts an Original Xbox ISO."""
        bin_path = self.get_bin_path("extract-xiso")
        if not bin_path:
            raise FileNotFoundError("extract-xiso binary not found.")
            
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [bin_path, "-x", "-d", dest_dir, iso_path]
        return self._run_command(cmd, progress_cb, allow_errors, process_callback=kwargs.get('process_callback'))

    def extract_archive(self, archive_path, dest_dir, progress_cb=None, **kwargs):
        """Extracts any archive (.zip, .7z, .rar, .iso) using 7z or unrar."""
        is_rar = archive_path.lower().endswith('.rar') or kwargs.get('is_rar', False)
        
        # Priority 1: unrar (best for RAR)
        unrar_bin = self.get_bin_path("unrar")
        if is_rar and unrar_bin:
            os.makedirs(dest_dir, exist_ok=True)
            cmd = [unrar_bin, "x", "-y", archive_path, dest_dir]
            return self._run_command(cmd, progress_cb, process_callback=kwargs.get('process_callback'))

        # Priority 2: 7z
        bin_path = self.get_bin_path("7z") or self.get_bin_path("7zz") or self.get_bin_path("7za")
        if not bin_path:
            raise FileNotFoundError("7z binary not found. Please install p7zip-full or 7zip.")
            
        os.makedirs(dest_dir, exist_ok=True)
        # -y: assume yes on all queries
        # -o: output directory
        cmd = [bin_path, "x", archive_path, f"-o{dest_dir}", "-y"]
        
        try:
            return self._run_command(cmd, progress_cb, process_callback=kwargs.get('process_callback'))
        except Exception as e:
            if "Unsupported Method" in str(e) and is_rar:
                raise Exception("Erro: Suporte a RAR ausente no 7-Zip (DFSG). Por favor, instale o pacote 'unrar' via terminal: sudo apt install unrar")
            raise e

    def iso_to_god(self, iso_path, dest_dir, progress_cb=None, allow_errors=False, **kwargs):
        """Converts an ISO to GOD."""
        bin_path = self.get_bin_path("iso2god-rs") or self.get_bin_path("iso2god")
        if not bin_path:
            raise FileNotFoundError("ISO2GOD binary not found.")
            
        os.makedirs(dest_dir, exist_ok=True)
        cmd = [bin_path, iso_path, dest_dir]
        return self._run_command(cmd, progress_cb, allow_errors, process_callback=kwargs.get('process_callback'))

    def _run_command(self, cmd, progress_cb=None, allow_errors=False, process_callback=None):
        """Runs a subprocess and monitors output."""
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            if process_callback:
                process_callback(process)

            last_lines = []
            if process.stdout is not None:
                for line in process.stdout:
                    clean_line = line.strip()
                    if clean_line:
                        last_lines.append(clean_line)
                        if len(last_lines) > 5: last_lines.pop(0)
                    if progress_cb:
                        progress_cb(clean_line)

            process.wait()
            if process.returncode != 0:
                error_context = "\n".join(last_lines)
                if allow_errors:
                    if progress_cb: progress_cb(f"Warning: Command exited with code {process.returncode} (Continued as requested).")
                    return True
                raise Exception(f"Command failed with exit code {process.returncode}\nDetalhes do Erro:\n{error_context}")

            
            return True
        except Exception as e:
            if progress_cb:
                progress_cb(f"Error: {str(e)}")
            raise e
