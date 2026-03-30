import ftplib
import os
import time

class XboxFTPClient:
    def __init__(self, host, port=21, user="xbox", passwd="xbox"):
        self.host = host
        self.port = port
        self.user = user
        self.passwd = passwd
        self.ftp = None
        self.connected = False

    def connect(self):
        try:
            self.ftp = ftplib.FTP()
            self.ftp.connect(self.host, self.port, timeout=5)
            # FSD/Aurora often allow anonymous, but xbox/xbox is common default
            try:
                self.ftp.login(self.user, self.passwd)
            except ftplib.error_perm:
                self.ftp.login("anonymous", "anonymous")
                
            self.ftp.set_pasv(True)
            self.connected = True
            return {"status": "success", "message": f"Connected to {self.host}"}
        except Exception as e:
            self.connected = False
            return {"status": "error", "message": str(e)}

    def disconnect(self):
        if self.ftp and self.connected:
            try:
                self.ftp.quit()
            except:
                self.ftp.close()
        self.connected = False
        self.ftp = None

    def list_dir(self, path=""):
        if not self.connected:
            return {"status": "error", "message": "Not connected"}
            
        try:
            if path:
                # Ensure we change to the directory to list it correctly
                # Some Xbox FTP servers have issues with `dir /path`
                original_pwd = self.ftp.pwd()
                self.ftp.cwd(path)
                
            items = []
            def line_callback(line):
                # Simple MLSD or LIST parsing 
                # Aurora LIST format: drwxrwxrwx 1 ftp ftp 0 Jan 01 2000 Hdd1
                parts = line.split(maxsplit=8)
                if len(parts) >= 9:
                    is_dir = parts[0].startswith('d')
                    size = parts[4]
                    name = parts[8]
                    items.append({
                        "name": name,
                        "is_dir": is_dir,
                        "size": size,
                        "raw_line": line
                    })

            self.ftp.retrlines('LIST', line_callback)
            
            if path:
                self.ftp.cwd(original_pwd)
                
            return {"status": "success", "data": items, "path": path or "/"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def upload_file(self, local_path, remote_dir, progress_cb=None):
        if not self.connected:
            return False, "Not connected"
            
        if not os.path.exists(local_path):
            return False, "Local file not found"
            
        file_name = os.path.basename(local_path)
        remote_path = f"{remote_dir}/{file_name}" if remote_dir else file_name
        
        file_size = os.path.getsize(local_path)
        uploaded = 0
        
        try:
            # Change to target directory to avoid path parsing issues on Xbox
            original_pwd = self.ftp.pwd()
            if remote_dir:
                try:
                    self.ftp.cwd(remote_dir)
                except ftplib.error_perm:
                    # Directory might not exist
                    return False, f"Directory {remote_dir} not found on server"

            with open(local_path, 'rb') as f:
                def callback(data):
                    nonlocal uploaded
                    uploaded += len(data)
                    if progress_cb:
                        progress_cb(uploaded, file_size)
                        
                # Upload
                self.ftp.storbinary(f'STOR {file_name}', f, 8192, callback)
                
            if remote_dir:
                self.ftp.cwd(original_pwd)
                
            return True, "Upload complete"
        except Exception as e:
            return False, str(e)

    def download_file(self, remote_file, local_dir, progress_cb=None):
        if not self.connected:
            return False, "Not connected"
            
        try:
            self.ftp.voidcmd('TYPE I')
            file_size = self.ftp.size(remote_file)
        except:
            file_size = 0
            
        local_path = os.path.join(local_dir, os.path.basename(remote_file))
        downloaded = 0
        
        try:
            with open(local_path, 'wb') as f:
                def callback(data):
                    nonlocal downloaded
                    f.write(data)
                    downloaded += len(data)
                    if progress_cb:
                        progress_cb(downloaded, file_size)
                        
                self.ftp.retrbinary(f'RETR {remote_file}', callback, 8192)
            return True, "Download complete"
        except Exception as e:
            if os.path.exists(local_path):
                os.remove(local_path)
            return False, str(e)

    def delete_item(self, remote_path, is_dir=False):
        if not self.connected:
            return False, "Not connected"
        try:
            if is_dir:
                self.ftp.rmd(remote_path)
            else:
                self.ftp.delete(remote_path)
            return True, "Deleted"
        except Exception as e:
            return False, str(e)

    def mkdir(self, remote_path):
        if not self.connected:
            return False, "Not connected"
        try:
            self.ftp.mkd(remote_path)
            return True, "Directory created"
        except Exception as e:
            return False, str(e)
