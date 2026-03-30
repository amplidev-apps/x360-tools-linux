#!/usr/bin/env python3
import sys
import json
import argparse
import os
import threading
import tempfile
import shutil
import subprocess

# Ensure we can import the core modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from core.usb import detect_removable_drives, format_fat32
from core.packages import ALL_PACKAGES, Category, resolve_package_url
from core.freemarket import FreemarketEngine
from core.stfs import install_package, get_stfs_metadata, list_usb_content, extract_package
from core.converter import GameConverter
from core.utils import extract_zip, download_file
from core.gamerpics import get_manager
from core.backup import BackupManager
from core.library import LibraryScanner
from core.dashlaunch import DashLaunchEditor
from core.ftp_client import XboxFTPClient
from core.save_manager import SaveManager
from core.metadata_service import MetadataService

def main():
    parser = argparse.ArgumentParser(description="x360 Tools Service Bridge")
    parser.add_argument("--cmd", required=True, help="Command to execute")
    parser.add_argument("--arg", help="Argument for the command")
    parser.add_argument("--platform", help="Platform for freemarket (360/classic)")
    parser.add_argument("--category", help="Package category filter")
    parser.add_argument("--packages", help="JSON list of package filenames to install")
    parser.add_argument("--device", help="Target device for installation")
    parser.add_argument("--src", help="Source file for conversion")
    parser.add_argument("--dest", help="Destination folder for conversion")
    parser.add_argument("--mode", help="Conversion mode (god/extract)")
    parser.add_argument("--id", help="Icon ID for gamerpics")
    parser.add_argument("--name", help="Display name for custom gamerpic")
    parser.add_argument("--gallery", action="store_true", help="Save to local gallery")
    parser.add_argument("--cleanup", action="store_true", help="Delete source files after successful install")
    parser.add_argument("--crop", help="JSON crop box [left,top,right,bottom] in image pixels")
    parser.add_argument("--label", help="Custom label for backup/format")
    parser.add_argument("--url", help="URL for game download")
    parser.add_argument("--on-device", help="Install directly to device (True/False)")
    parser.add_argument("--refresh", action="store_true", help="Force refresh game list cache")
    parser.add_argument("--lang", default="pt", help="Language for translation")
    parser.add_argument("--title-id", help="Title ID for TU/DLC installation")
    parser.add_argument("--host", help="FTP Host/IP")
    parser.add_argument("--port", type=int, default=21, help="FTP Port")
    parser.add_argument("--user", default="xbox", help="FTP Username")
    parser.add_argument("--passwd", default="xbox", help="FTP Password")
    parser.add_argument("--remote-path", help="FTP remote path")
    parser.add_argument("--local-path", help="FTP local path")
    parser.add_argument("--is-dir", action="store_true", help="Is directory (for delete)")
    parser.add_argument("--type", help="Item type (XEX, GOD, DLC, TU)")
    parser.add_argument("--cookie", help="Archive.org authentication cookie")
    parser.add_argument("--ia-user", help="Archive.org username/email")
    parser.add_argument("--ia-pass", help="Archive.org password")
    
    args = parser.parse_args()
    
    result = {"status": "error", "message": "Unknown command"}
    
    try:
        if args.cmd == "list_drives":
            drives = detect_removable_drives()
            result = {
                "status": "success", 
                "data": [{"device": d.device, "label": d.label, "mount": d.mount_point, "size_gb": d.size_gb} for d in drives]
            }
            
        elif args.cmd == "format_drive":
            if not args.arg:
                result = {"status": "error", "message": "Missing device argument"}
            else:
                success = format_fat32(args.arg)
                result = {"status": "success" if success else "error"}
                
        elif args.cmd == "get_packages":
            pkgs = ALL_PACKAGES
            if args.category:
                pkgs = [p for p in ALL_PACKAGES if p.category == args.category]
            
            result = {
                "status": "success",
                "data": [{"name": p.name, "file": p.filename, "desc": p.description, "category": p.category} for p in pkgs]
            }
            
        elif args.cmd == "fetch_games":
            platform = args.platform or "360"
            engine = FreemarketEngine()
            games = engine.fetch_game_list(platform=platform, force_refresh=args.refresh)
            result = {"status": "success", "data": games}

        elif args.cmd == "open_folder":
            if not args.dest:
                result = {"status": "error", "message": "Missing destination path"}
            else:
                sys.stderr.write(f"DEBUG: Opening folder {args.dest}\n")
                if not os.path.exists(args.dest):
                    result = {"status": "error", "message": f"Caminho não encontrado: {args.dest}"}
                else:
                    try:
                        if sys.platform == "win32":
                            os.startfile(args.dest)
                        else:
                            subprocess.Popen(["xdg-open", args.dest])
                        result = {"status": "success", "message": f"Abrindo pasta: {args.dest}"}
                    except Exception as e:
                        sys.stderr.write(f"DEBUG: Error opening folder: {e}\n")
                        result = {"status": "error", "message": f"Erro ao abrir pasta: {e}"}

        elif args.cmd == "install_game":
            if not args.url or not args.name or not args.platform or not args.device:
                result = {"status": "error", "message": "Missing arguments for game installation"}
            else:
                engine = FreemarketEngine()
                def progress_callback(msg):
                    print(msg, flush=True)
                
                try:
                    success = engine.install_game(
                        args.url, 
                        args.name, 
                        args.platform, 
                        args.device, 
                        on_device=(args.on_device.lower() == 'true'),
                        progress_cb=progress_callback,
                        task_id=args.id # V103
                    )
                    result = {"status": "success" if success else "error", "message": "Instalação concluída" if success else "Falha na instalação"}
                except Exception as e:
                    result = {"status": "error", "message": str(e)}

        elif args.cmd == "pause_download":
            if args.id:
                temp_base = os.path.join(os.path.expanduser("~/.x360tools/freemarket"), "install_temp")
                temp_dir = os.path.join(temp_base, args.id)
                os.makedirs(temp_dir, exist_ok=True)
                with open(os.path.join(temp_dir, "pause.flag"), "w") as f: f.write("1")
                result = {"status": "success", "message": "Threaded download paused"}
        
        elif args.cmd == "resume_download":
            if args.id:
                temp_base = os.path.join(os.path.expanduser("~/.x360tools/freemarket"), "install_temp")
                flag = os.path.join(temp_base, args.id, "pause.flag")
                if os.path.exists(flag): os.remove(flag)
                result = {"status": "success", "message": "Threaded download resumed"}

        elif args.cmd == "cancel_download":
            if args.id:
                temp_base = os.path.join(os.path.expanduser("~/.x360tools/freemarket"), "install_temp")
                temp_dir = os.path.join(temp_base, args.id)
                os.makedirs(temp_dir, exist_ok=True)
                with open(os.path.join(temp_dir, "stop.flag"), "w") as f: f.write("1")
                # Kill subprocesses (aria2c/extractors) tracked by the engine
                pid_file = os.path.join(temp_dir, "pid.txt")
                if os.path.exists(pid_file):
                    try:
                        with open(pid_file, "r") as f:
                            pids = f.readlines()
                            for p in pids:
                                try: os.kill(int(p.strip()), 9)
                                except: pass
                    except: pass
                result = {"status": "success", "message": "Download cancelado e processos encerrados"}

        elif args.cmd == "get_game_details":
            if args.name:
                # ... (removed local import)
                service = MetadataService()
                details = service.search_unity_by_name(args.name, args.platform, lang=args.lang)
                result = {"status": "success", "data": details}

        elif args.cmd == "install_dlc":
            if not args.url or not args.name or not args.title_id or not args.device:
                result = {"status": "error", "message": "Missing arguments for DLC installation"}
            else:
                engine = FreemarketEngine()
                def progress_callback(msg):
                    print(msg, flush=True)

                try:
                    success = engine.install_dlc(
                        args.url, 
                        args.name, 
                        args.title_id, 
                        args.device, 
                        progress_cb=progress_callback,
                        task_id=args.id # V103
                    )
                    result = {"status": "success" if success else "error", "message": "Instalação da DLC concluída" if success else "Falha na instalação da DLC"}
                except Exception as e:
                    progress_callback(f"PHASE:Erro: {e}")
                    result = {"status": "error", "message": str(e)}

        elif args.cmd == "install_tu":
            if not args.url or not args.name or not args.title_id or not args.device:
                result = {"status": "error", "message": "Missing arguments for TU installation"}
            else:
                engine = FreemarketEngine()
                def progress_callback(msg):
                    print(msg, flush=True)

                try:
                    success = engine.install_tu(
                        args.url, 
                        args.name, 
                        args.title_id, 
                        args.device, 
                        progress_cb=progress_callback
                    )
                    result = {"status": "success" if success else "error", "message": "Title Update instalada com sucesso" if success else "Falha na instalação da TU"}
                except Exception as e:
                    result = {"status": "error", "message": str(e)}


        elif args.cmd == "set_ia_cookie":
            if not args.cookie:
                result = {"status": "error", "message": "Cookie não fornecido"}
            else:
                try:
                    cookie_path = os.path.expanduser("~/.x360tools/ia_cookie.txt")
                    os.makedirs(os.path.dirname(cookie_path), exist_ok=True)
                    with open(cookie_path, "w") as f:
                        f.write(args.cookie.strip())
                    result = {"status": "success", "message": "Cookie do Archive.org salvo com sucesso!"}
                except Exception as e:
                    result = {"status": "error", "message": str(e)}

        elif args.cmd == "login_ia":
            if not args.ia_user or not args.ia_pass:
                result = {"status": "error", "message": "E-mail e senha são obrigatórios"}
            else:
                engine = FreemarketEngine()
                success, msg = engine.login_ia(args.ia_user, args.ia_pass)
                result = {"status": "success" if success else "error", "message": msg}

        elif args.cmd == "check_ia_login":
            engine = FreemarketEngine()
            cookies = engine._load_cookie()
            is_logged = False
            if cookies and isinstance(cookies, dict):
                # Look for Archive.org specific login cookies
                if "logged-in-user" in cookies:
                    is_logged = True
            result = {"status": "success", "logged_in": is_logged}

        elif args.cmd == "scan_library":
            if not args.device:
                result = {"status": "error", "message": "Missing device for library scan"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Dispositivo não está montado"}
                else:
                    scanner = LibraryScanner()
                    data = scanner.scan_drive(drive.mount_point)
                    result = {"status": "success", "data": data}

        elif args.cmd == "rename_library_item":
            if not args.src or not args.arg or not args.type:
                result = {"status": "error", "message": "Missing path, new name or type"}
            else:
                scanner = LibraryScanner()
                new_path = scanner.rename_entry(args.src, args.arg, args.type)
                if new_path:
                    result = {"status": "success", "new_path": new_path}
                else:
                    result = {"status": "error", "message": "Falha ao renomear item"}

        elif args.cmd == "set_custom_icon":
            if not args.src or not args.arg: # src=game_path, arg=icon_path
                result = {"status": "error", "message": "Missing game path or icon path"}
            else:
                scanner = LibraryScanner()
                if scanner.set_custom_icon(args.src, args.arg):
                    result = {"status": "success"}
                else:
                    result = {"status": "error", "message": "Falha ao definir capa personalizada"}

        elif args.cmd == "export_library_item":
            if not args.src or not args.dest:
                result = {"status": "error", "message": "Missing src or dest"}
            else:
                scanner = LibraryScanner()
                if scanner.export_item(args.src, args.dest):
                    result = {"status": "success"}
                else:
                    result = {"status": "error", "message": "Falha ao exportar item para o PC"}

        elif args.cmd == "delete_library_item":
            if not args.src:
                result = {"status": "error", "message": "Missing path for deletion"}
            else:
                scanner = LibraryScanner()
                if scanner.delete_entry(args.src):
                    result = {"status": "success"}
                else:
                    result = {"status": "error", "message": "Falha ao excluir item"}

        elif args.cmd == "explore_library_item":
            if not args.src:
                result = {"status": "error", "message": "Missing path for exploration"}
            else:
                # ... (removed local import)
                # If it's a file (GOD), explore the directory
                target = args.src if os.path.isdir(args.src) else os.path.dirname(args.src)
                try:
                    if sys.platform == "win32":
                        os.startfile(target)
                    else:
                        subprocess.Popen(["xdg-open", target])
                    result = {"status": "success"}
                except:
                    result = {"status": "error", "message": "Falha ao abrir o explorador"}

        elif args.cmd == "get_dashlaunch":
            if not args.src:
                result = {"status": "error", "message": "Missing path for launch.ini"}
            else:
                editor = DashLaunchEditor()
                result = editor.read_ini(args.src)

        elif args.cmd == "update_dashlaunch":
            if not args.dest or not args.arg: # args.arg as JSON data
                result = {"status": "error", "message": "Missing path or data for launch.ini update"}
            else:
                editor = DashLaunchEditor()
                data = json.loads(args.arg)
                result = editor.write_ini(args.dest, data)

        elif args.cmd == "install":
            if not args.packages or not args.device:
                result = {"status": "error", "message": "Missing packages or device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo para instalação não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Dispositivo para instalação não está montado"}
                else:
                    package_list = json.loads(args.packages)
                    success_count = 0
                    base_dir = os.path.dirname(os.path.abspath(__file__))
                    
                    for pkg_file in package_list:
                        pkg = next((p for p in ALL_PACKAGES if p.filename == pkg_file), None)
                        if pkg:
                            try:
                                # 1. Find or Download the package
                                asset_path = os.path.join(base_dir, "assets", pkg.filename)
                                temp_path = os.path.join(base_dir, "temp", pkg.filename)
                                final_path = ""
                                
                                if os.path.exists(asset_path):
                                    final_path = asset_path
                                elif os.path.exists(temp_path):
                                    final_path = temp_path
                                else:
                                    # Fallback to download
                                    url = resolve_package_url(pkg.filename)
                                    final_path = download_file(url, pkg.filename)
                                
                                # 2. Extract or Install
                                if final_path.lower().endswith(".zip"):
                                    extract_zip(final_path, drive.mount_point)
                                    success_count += 1
                                else:
                                    if install_package(final_path, drive.mount_point):
                                        success_count += 1
                            except Exception as e:
                                print(f"Error installing {pkg.filename}: {e}", file=sys.stderr)
                                continue
                    
                    result = {"status": "success", "message": f"Installed {success_count}/{len(package_list)} packages."}

        elif args.cmd == "get_stfs_meta":
            if not args.src:
                result = {"status": "error", "message": "Missing source file"}
            else:
                meta = get_stfs_metadata(args.src, extract_icon=True)
                result = {"status": "success", "data": meta}

        elif args.cmd == "list_content":
            if not args.device:
                result = {"status": "error", "message": "Missing device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Dispositivo não montado"}
                else:
                    content = list_usb_content(drive.mount_point)
                    result = {"status": "success", "data": content}
                
        elif args.cmd == "install_stfs":
            if not args.src or not args.device:
                result = {"status": "error", "message": "Missing src or device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Ponto de montagem não encontrado"}
                else:
                    dest = install_package(args.src, drive.mount_point)
                    result = {"status": "success", "data": {"dest": dest}}

        elif args.cmd == "get_gamerpics":
            manager = get_manager()
            pics = manager.extract_all()
            pics.sort(key=lambda x: x["name"])
            result = {"status": "success", "data": pics}

        elif args.cmd == "get_installed_gamerpics":
            if not args.device:
                result = {"status": "error", "message": "Missing device for installed gamerpics"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo não detectado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Ponto de montagem indisponível"}
                else:
                    manager = get_manager()
                    pics = manager.extract_from_device(drive.mount_point)
                    pics.sort(key=lambda x: x["name"])
                    result = {"status": "success", "data": pics}


        elif args.cmd == "create_custom_gamerpic":
            if not args.src:
                result = {"status": "error", "message": "No image path provided"}
            else:
                manager = get_manager()
                name = args.name or "Custom Gamerpic"
                gallery = args.gallery
                crop_box = None
                if args.crop:
                    try:
                        crop_box = tuple(int(x) for x in json.loads(args.crop))
                    except Exception:
                        crop_box = None

                # Resolve device mount path if requested
                device_mount = None
                if args.device:
                    drives = detect_removable_drives()
                    drive = next((d for d in drives if d.device == args.device), None)
                    if drive and drive.mount_point:
                        device_mount = drive.mount_point

                res = manager.create_custom_gamerpic(
                    args.src,
                    name=name,
                    crop_box=crop_box,
                    device_path=device_mount,
                    save_to_gallery=gallery,
                )
                result = res

        elif args.cmd == "delete_device_gamerpic":
            # args.src = absolute path to the .stfs file on the device
            if not args.src:
                result = {"status": "error", "message": "Missing file path (--src)"}
            else:
                try:
                    if os.path.isfile(args.src):
                        os.remove(args.src)
                        result = {"status": "success", "message": f"Deleted: {args.src}"}
                    else:
                        result = {"status": "error", "message": "File not found"}
                except Exception as e:
                    result = {"status": "error", "message": str(e)}

        elif args.cmd == "export_device_gamerpic":
            # args.src = source .stfs path, args.dest = destination directory
            if not args.src or not args.dest:
                result = {"status": "error", "message": "Missing src or dest"}
            else:
                # ... (removed local import)
                try:
                    if not os.path.isfile(args.src):
                        result = {"status": "error", "message": "Source file not found"}
                    else:
                        os.makedirs(args.dest, exist_ok=True)
                        dest_path = os.path.join(args.dest, os.path.basename(args.src))
                        shutil.copy2(args.src, dest_path)
                        result = {"status": "success", "data": {"path": dest_path}}
                except Exception as e:
                    result = {"status": "error", "message": str(e)}

        elif args.cmd == "inject_gamerpic":
            if not args.id or not args.device:
                result = {"status": "error", "message": "Missing id or device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo para injeção não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Ponto de montagem não disponível para injeção"}
                else:
                    manager = get_manager()
                    temp_dir = tempfile.gettempdir()
                    # We ensure extraction has happened
                    manager.extract_all()
                    temp_pkg = os.path.join(temp_dir, f"gp_{args.id}.stfs")
                    if manager.create_mini_stfs(args.id, temp_pkg, manager.last_metadata):
                        dest = install_package(temp_pkg, drive.mount_point)
                        print(f"DEBUG: Injected Gamerpic to: {dest}", file=sys.stderr)
                        result = {"status": "success", "data": {"dest": dest}}
                    else:
                        result = {"status": "error", "message": "Failed to create package"}

        elif args.cmd == "extract_stfs":
            if not args.src or not args.dest:
                result = {"status": "error", "message": "Missing src or dest"}
            else:
                final_dest = extract_package(args.src, args.dest)
                result = {"status": "success", "data": {"dest": final_dest}}

        elif args.cmd == "convert_iso":
            if not args.src or not args.dest or not args.mode:
                result = {"status": "error", "message": "Missing arguments"}
            else:
                converter = GameConverter()
                # 1. Capture state before
                before = set(os.listdir(args.dest))
                
                if args.mode == "god":
                    converter.iso_to_god(args.src, args.dest)
                else:
                    converter.extract_xiso(args.src, args.dest)
                
                # 2. Capture state after
                after = set(os.listdir(args.dest))
                new_items = list(after - before)
                
                if args.device and new_items:
                    drives = detect_removable_drives()
                    drive = next((d for d in drives if d.device == args.device), None)
                    if drive and drive.mount_point:
                        for item in new_items:
                            src_item = os.path.join(args.dest, item)
                            if args.mode == "god":
                                # GOD: Content/0000000000000000/<TitleID>
                                target_parent = os.path.join(drive.mount_point, "Content", "0000000000000000")
                            else:
                                # Classic: Games/<GameFolder>
                                target_parent = os.path.join(drive.mount_point, "Games")
                            
                            os.makedirs(target_parent, exist_ok=True)
                            dest_path = os.path.join(target_parent, item)
                            
                            if os.path.isdir(src_item):
                                if os.path.exists(dest_path): shutil.rmtree(dest_path)
                                shutil.copytree(src_item, dest_path)
                            else:
                                shutil.copy2(src_item, dest_path)
                                
                        if args.cleanup:
                            # Cleanup the whole dest folder after install
                            shutil.rmtree(args.dest, ignore_errors=True)
                
                result = {"status": "success"}
                
        elif args.cmd == "create_backup":
            if not args.dest or not args.device:
                result = {"status": "error", "message": "Missing destination or device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Disco de origem não encontrado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Disco de origem não está montado"}
                else:
                    BackupManager.create_backup(drive.mount_point, args.dest, label=args.label, progress_cb=lambda m: print(m, flush=True))
                    result = {"status": "success"}

        elif args.cmd == "restore_backup":
            if not args.src or not args.device:
                result = {"status": "error", "message": "Missing backup file or device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Drive missing from system"}
                else:
                    BackupManager.restore_backup(args.src, drive.device, new_label=args.label, progress_cb=lambda m: print(m, flush=True))
                    result = {"status": "success"}

        elif args.cmd == "get_device_summary":
            if not args.device:
                result = {"status": "error", "message": "Missing device"}
            else:
                drives = detect_removable_drives()
                drive = next((d for d in drives if d.device == args.device), None)
                if not drive:
                    result = {"status": "error", "message": "Dispositivo não identificado"}
                elif not drive.mount_point:
                    result = {"status": "error", "message": "Montagem não encontrada para resumo"}
                else:
                    summary = BackupManager.get_summary(drive.mount_point)
                    result = {"status": "success", "summary": summary}

        elif args.cmd == "get_backup_summary":
            if not args.src:
                result = {"status": "error", "message": "Missing source file"}
            else:
                res = BackupManager.get_zip_summary(args.src)
                result = {"status": "success", "summary": res["summary"], "label": res["label"]}
                
        # --- FTP COMMANDS ---
        elif args.cmd.startswith("ftp_"):
            if not args.host:
                result = {"status": "error", "message": "Missing FTP host"}
            else:
                ftp = XboxFTPClient(args.host, args.port, args.user, args.passwd)
                conn_res = ftp.connect()
                if conn_res["status"] != "success":
                    result = conn_res
                else:
                    if args.cmd == "ftp_connect":
                        result = conn_res
                        
                    elif args.cmd == "ftp_list":
                        result = ftp.list_dir(args.remote_path or "")
                        
                    elif args.cmd == "ftp_upload":
                        if not args.local_path:
                            result = {"status": "error", "message": "Missing local path"}
                        else:
                            success, msg = ftp.upload_file(
                                args.local_path, 
                                args.remote_path,
                                progress_cb=lambda up, tot: print(f"Progress: {(up/tot)*100:.2f}%", flush=True) if tot > 0 else None
                            )
                            result = {"status": "success" if success else "error", "message": msg}
                            
                    elif args.cmd == "ftp_delete":
                        if not args.remote_path:
                            result = {"status": "error", "message": "Missing remote path"}
                        else:
                            success, msg = ftp.delete_item(args.remote_path, args.is_dir)
                            result = {"status": "success" if success else "error", "message": msg}
                            
                    elif args.cmd == "ftp_mkdir":
                        if not args.remote_path:
                            result = {"status": "error", "message": "Missing remote path"}
                        else:
                            success, msg = ftp.mkdir(args.remote_path)
                            result = {"status": "success" if success else "error", "message": msg}
                            
                    ftp.disconnect()
                    
        # --- SAVE MANAGER COMMANDS ---
        elif args.cmd.startswith("save_"):
            save_mgr = SaveManager()
            
            if args.cmd == "save_scan":
                result = {"status": "success", "data": save_mgr.scan_vault()}
                
            elif args.cmd == "save_import":
                if not args.src:
                    result = {"status": "error", "message": "Missing source file"}
                else:
                    result = save_mgr.import_save(args.src)
                    
            elif args.cmd == "save_delete":
                if not args.arg:
                    result = {"status": "error", "message": "Missing save filename to delete"}
                else:
                    result = save_mgr.delete_save(args.arg)
            
            
    except Exception as e:
        result = {"status": "error", "message": str(e)}
        
    print(json.dumps(result))

if __name__ == "__main__":
    main()
