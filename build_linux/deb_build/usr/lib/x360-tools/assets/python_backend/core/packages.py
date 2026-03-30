import json

class Category:
    DASHBOARD = "Dashboard"
    HOMEBREW = "Homebrew"
    STEALTH = "Stealth"
    PLUGIN = "Plugin"
    CUSTOMIZATION = "Customization"
    BACKCOMPAT = "Backwards Compatibility"
    OTHER = "Other"

class Package:
    def __init__(self, filename, category, description="", always_download=False, name=None):
        self.filename = filename
        self.category = category
        self.description = description
        self.always_download = always_download
        self.name = name if name else filename.replace(".zip", "")

GITHUB_URL_BASE = "https://github.com/LxcyDr0p/BadStick/releases/download/packages/"
GITHUB_URL_RBB  = "https://github.com/LxcyDr0p/BadStick/releases/download/RBB/"

def resolve_package_url(filename):
    """
    Returns the URL for the given package. 
    In the future, this could use GitHub API to find the latest asset.
    """
    if filename == "RBB.zip":
        return f"{GITHUB_URL_RBB}{filename}"
    return f"{GITHUB_URL_BASE}{filename}"

ALL_PACKAGES = [
    # Dashboards
    Package("Aurora.zip", Category.DASHBOARD),
    Package("Freestyle.zip", Category.DASHBOARD),
    Package("Emerald.zip", Category.DASHBOARD),
    Package("Viper360.zip", Category.DASHBOARD),
    Package("XeXMenu.zip", Category.DASHBOARD, always_download=True),
    Package("XeXLoader.zip", Category.DASHBOARD),
    Package("Xenu.zip", Category.DASHBOARD),
    Package("NXE2GOD.zip", Category.DASHBOARD),
    Package("IngeniouX.zip", Category.DASHBOARD),
    Package("XPG.Chameleon.zip", Category.DASHBOARD),
    
    # Homebrew
    Package("Dashlauncher.zip", Category.HOMEBREW),
    Package("FFPlay.zip", Category.HOMEBREW),
    Package("GOD.Unlocker.zip", Category.HOMEBREW),
    Package("XM360.zip", Category.HOMEBREW),
    Package("XNA.Offline.zip", Category.HOMEBREW),
    Package("HDDx.Fixer.zip", Category.HOMEBREW),
    Package("Flasher.zip", Category.HOMEBREW),
    
    # Stealth
    Package("CipherLive.zip", Category.STEALTH),
    Package("xbGuard.zip", Category.STEALTH),
    Package("Proto.zip", Category.STEALTH),
    Package("Nfinite.zip", Category.STEALTH),
    Package("TetheredLive.zip", Category.STEALTH),
    Package("XBL.Kyuubii.zip", Category.STEALTH),
    Package("XBLS.zip", Category.STEALTH),
    Package("xbNetwork.zip", Category.STEALTH),
    
    # Plugins & Other
    Package("Plugins.zip", Category.PLUGIN),
    Package("xbPirate.zip", Category.PLUGIN),
    Package("hiddriver360.zip", Category.PLUGIN),
    Package("HvP2.zip", Category.PLUGIN),
    
    # Customization
    Package("X-Notify.Pack.zip", Category.CUSTOMIZATION),
    Package("FakeAnim.zip", Category.CUSTOMIZATION),
    Package("Boot.Animations.zip", Category.CUSTOMIZATION),
    
    # Backwards Compatibility
    Package("Hacked.Compatibility.Files.zip", Category.BACKCOMPAT),
    Package("Original.Compatibility.Files.zip", Category.BACKCOMPAT),
    Package("Xbox.One.Files.zip", Category.BACKCOMPAT),
    Package("XEFU.Spoofer.zip", Category.BACKCOMPAT),
    
    # Exploit/Required (Always Download)
    Package("Payload-XeUnshackle.zip", Category.OTHER, always_download=True, name="ABadAvatar"),
    Package("BUPayload-XeUnshackle.zip", Category.OTHER, always_download=True),
    Package("ABadMemUnit0.zip", Category.OTHER, always_download=True, name="ABadMemUnit"),
    Package("ABadAvatarHDD.zip", Category.OTHER, always_download=True),
    Package("BUPayload-FreeMyXe.zip", Category.OTHER, always_download=True),
    Package("RBB.zip", Category.OTHER, always_download=True),
]

# Note: The Go version had ~43 packages, I will expand this list in the actual implementation 
# or use the full list gathered from the audit.
