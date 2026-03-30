DEFAULT_LAUNCH_INI = {
    "Config": {
        "autoboot": "Aurora",
        "liveblock": "true",
        "livestrong": "false",
    },
    "Plugins": {
        "plugin1": "Usb:\\Plugins\\JRPC2.xex",
        "plugin2": "Usb:\\Plugins\\xbdm.xex",
    }
}

DEFAULT_XBDM_INI = {
    "Config": {
        "debug": "true"
    }
}

DEFAULT_JRPC_INI = {
    "Config": {
        "version": "2.0"
    }
}

def get_ini_template(name):
    name = name.lower()
    if name == "launch.ini":
        return ("; x360 Tools - launch.ini template\n"
               "[Config]\n"
               "autoboot = Aurora\n"
               "liveblock = true\n"
               "livestrong = false\n"
               "nandflash = true\n"
               "remotenxe = true\n\n"
               "[Plugins]\n"
               "plugin1 = Usb:\\Plugins\\JRPC2.xex\n"
               "plugin2 = Usb:\\Plugins\\xbdm.xex\n")
    elif name == "xbdm.ini":
        return "; x360 Tools - xbdm.ini template\n[Config]\ndebug = true\n"
    elif name == "jrpc.ini":
        return "; x360 Tools - jrpc.ini template\n[Config]\nversion = 2.0\n"
    return "; Empty template"

def save_ini(path, content):
    try:
        with open(path, 'w') as f:
            f.write(content)
        return True
    except:
        return False
