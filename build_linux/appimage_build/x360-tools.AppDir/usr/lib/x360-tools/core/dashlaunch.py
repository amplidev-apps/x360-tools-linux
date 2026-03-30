import os
import configparser

class DashLaunchEditor:
    def __init__(self):
        # DashLaunch uses a slightly non-standard INI format (sometimes no sections)
        # but we'll try to handle it as a standard INI if [paths] and [settings] are present.
        pass

    def read_ini(self, path):
        if not os.path.exists(path):
            return {"status": "error", "message": "Arquivo launch.ini não encontrado."}
        
        try:
            with open(path, 'r', encoding='utf-16', errors='replace') as f:
                content = f.read()
            
            # If it doesn't have sections, we'll wrap it in a dummy [settings] section
            if '[' not in content:
                content = "[settings]\n" + content
                
            config = configparser.ConfigParser(allow_no_value=True, strict=False)
            config.read_string(content)
            
            data = {}
            for section in config.sections():
                data[section] = {}
                for key in config[section]:
                    data[section][key] = config[section][key]
            
            return {"status": "success", "data": data}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def write_ini(self, path, data):
        try:
            output = ""
            for section, keys in data.items():
                # We typically don't want the dummy [settings] if the user didn't have one
                # But for DashLaunch, having sections like [paths] and [settings] is standard
                output += f"[{section}]\n"
                for key, value in keys.items():
                    if value is None or value == "":
                        output += f"{key} =\n"
                    else:
                        output += f"{key} = {value}\n"
                output += "\n"
            
            with open(path, 'w', encoding='utf-16') as f:
                f.write(output)
            
            return {"status": "success"}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def create_default_rgh(self):
        """Returns a default optimized launch.ini structure for RGH"""
        return {
            "paths": {
                "default": "Usb:\\Aurora\\Aurora.xex",
            },
            "settings": {
                "pingpatch": "true",
                "contpatch": "true",
                "livestrong": "false",
                "liveblock": "true",
                "noontp": "true",
                "xhttp": "true"
            },
            "plugins": {
                "plugin1": "Usb:\\Plugins\\XBDM.xex"
            }
        }
