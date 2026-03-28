import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Handy', '1')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf, Pango, GObject, Handy
Handy.init()
import os
import sys
import threading
import time
import subprocess

# Add the project root to sys.path to import core
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from core.usb import detect_removable_drives, format_fat32
from core.packages import ALL_PACKAGES, Category
from core.stfs import get_stfs_metadata, install_package, list_usb_content, extract_package
from core.utils import download_file, extract_zip
from core.ini_logic import get_ini_template
from core.converter import GameConverter
from core.freemarket import FreemarketEngine
import core.i18n

# Simple logging for debugging startup issues
LOG_FILE = "/tmp/x360-tools.log"
with open(LOG_FILE, "a") as f:
    f.write(f"\n--- App Start: {time.ctime()} ---\n")
    f.write(f"CWD: {os.getcwd()}\n")
    f.write(f"PYTHONPATH: {os.environ.get('PYTHONPATH', 'N/A')}\n")
    f.write(f"sys.path: {sys.path}\n")

class X360Tools(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # Setup HeaderBar
        self.hb = Gtk.HeaderBar()
        self.hb.set_show_close_button(True)
        self.hb.props.title = "" # Remove text, just controls and tabs
        self.set_titlebar(self.hb)

        self.set_default_size(1000, 700)
        
        self.selections = {} # {filename: bool}
        self.drives = []
        self.selected_drive = None
        self.is_installing = False
        self.dark_mode = False 
        
        # Initialize Core Engines
        self.converter = GameConverter()
        self.freemarket = FreemarketEngine()
        
        # Base directory for assets - Handle AppImage and Deb
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.assets_dir = os.path.join(self.base_dir, "assets")
        
        # CSS Styling (Xbox / Fluent Dark Identity)
        css = """
window {
  background-color: rgb(18, 18, 18);
  color: rgb(255, 255, 255);
}
.main-container {
  background-color: rgb(18, 18, 18);
}
.sidebar {
  background-color: rgb(24, 24, 24);
  border-style: solid;
  border-width: 0 1px 0 0;
  border-color: rgb(40, 40, 40);
}
.sidebar-item {
  background-image: none;
  background-color: transparent;
  border-style: solid;
  border-width: 0 0 0 4px;
  border-color: transparent;
  color: rgb(170, 170, 170);
  font-size: 16px;
  font-weight: bold;
  padding: 12px 20px;
}
.sidebar-item:hover {
  color: rgb(255, 255, 255);
  background-color: rgb(37, 37, 37);
}
.sidebar-item.active {
  color: rgb(16, 124, 16);
  background-color: rgb(37, 37, 37);
  border-color: rgb(16, 124, 16);
}
.sidebar-logo-text {
  color: rgb(16, 124, 16);
  font-weight: 900;
  font-size: 22px;
}
headerbar {
  background-color: rgb(18, 18, 18);
  color: rgb(255, 255, 255);
  border-style: none;
}
headerbar label {
  color: rgb(255, 255, 255);
  font-weight: bold;
}
button {
  background-color: rgb(16, 124, 16);
  background-image: none;
  color: rgb(255, 255, 255);
  border-radius: 8px;
  border-style: none;
  padding: 8px 16px;
  font-weight: bold;
}
button:hover {
  background-color: rgb(21, 156, 21);
}
button:disabled {
  background-color: rgb(51, 51, 51);
  color: rgb(102, 102, 102);
}
entry {
  background-color: rgb(30, 30, 30);
  color: rgb(255, 255, 255);
  border-style: solid;
  border-width: 1px;
  border-color: rgb(51, 51, 51);
  border-radius: 6px;
  padding: 8px;
}
frame border {
  border-style: solid;
  border-width: 1px;
  border-color: rgb(40, 40, 40);
  border-radius: 12px;
  background-color: rgb(26, 26, 26);
}
frame label {
  color: rgb(16, 124, 16);
  font-weight: bold;
}
notebook {
  background-color: rgb(24, 24, 24);
  border-style: none;
}
notebook stack {
  background-color: rgb(24, 24, 24);
}
progressbar progress {
  background-color: rgb(16, 124, 16);
  border-radius: 4px;
}
.green-tile {
  background-color: rgb(16, 124, 16);
  color: rgb(255, 255, 255);
  border-radius: 8px;
}
.blue-tile {
  background-color: rgb(0, 120, 215);
  color: rgb(255, 255, 255);
  border-radius: 8px;
}
.orange-tile {
  background-color: rgb(216, 59, 1);
  color: rgb(255, 255, 255);
  border-radius: 8px;
}
label {
  color: rgb(255, 255, 255);
}
scrolledwindow {
  background-color: transparent;
}
viewport {
  background-color: transparent;
}
"""
        self.style_provider = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            self.style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Main Layout: Horizontal Box (Sidebar + Content Area)
        self.root_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.root_hbox.get_style_context().add_class("main-container")
        self.add(self.root_hbox)
        
        # 1. Sidebar
        self.sidebar_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.sidebar_vbox.set_size_request(240, -1)
        self.sidebar_vbox.get_style_context().add_class("sidebar")
        self.root_hbox.pack_start(self.sidebar_vbox, False, False, 0)
        
        # Sidebar Logo Header
        self.logo_label = Gtk.Label(label="x360 Tools")
        self.logo_label.get_style_context().add_class("sidebar-logo-text")
        self.logo_label.set_xalign(0)
        self.sidebar_vbox.pack_start(self.logo_label, False, False, 0)
        
        # 2. Content Area (HeaderBar + Stack)
        self.content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.root_hbox.pack_start(self.content_vbox, True, True, 0)
        
        # Header (Now inside content area for independent title control)
        self.header_area = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.header_area.set_size_request(-1, 60)
        self.header_area.set_margin_start(20)
        self.header_area.set_margin_end(20)
        
        self.view_title_label = Gtk.Label(label="Home")
        self.view_title_label.set_markup("<span size='x-large' weight='bold'>Home</span>")
        self.header_area.pack_start(self.view_title_label, False, False, 0)
        
        self.content_vbox.pack_start(self.header_area, False, False, 0)
        
        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.set_opacity(0.1)
        self.content_vbox.pack_start(sep, False, False, 0)
        
        # Stack for Content
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(300)
        self.content_vbox.pack_start(self.stack, True, True, 0)
        
        # Sidebar buttons navigation registry
        self.nav_buttons = {} # {id: GtkButton}
        
        # Initialize core components
        self.current_lang = "en"
        self.status_bar = Gtk.Statusbar()
        self.status_bar.set_margin_start(10)
        
        # Tab Creation Logic (preserving existing methods)
        self.tabs = [
            ("install", "🏠 Home", self.create_install_tab),
            ("dashboards", "🎮 Dashboards", self.create_dashboards_tab),
            ("homebrew", "🚀 Homebrew", self.create_homebrew_tab),
            ("stealth", "🛡️ Stealth", self.create_stealth_tab),
            ("plugins", "🔌 Plugins", self.create_plugins_tab),
            ("game_convert", "💿 Game Convert", self.create_game_convert_tab),
            ("content_manager", "📂 Content Manager", self.create_content_manager_tab),
            ("freemarket", "🛍️ Freemarket", None), # Special case
            ("settings", "⚙️ Settings", self.create_settings_tab),
        ]
        
        for tab_id, tab_label, tab_func in self.tabs:
            if tab_func:
                tab_func()
            
            # Create Sidebar Button
            btn = Gtk.Button(label=tab_label)
            btn.get_style_context().add_class("sidebar-item")
            btn.set_halign(Gtk.Align.FILL)
            if btn.get_child():
                btn.get_child().set_xalign(0)
            btn.connect("clicked", self.on_sidebar_navigate, tab_id, tab_label)
            self.sidebar_vbox.pack_start(btn, False, False, 0)
            self.nav_buttons[tab_id] = btn
        
        # Set initial active button
        self.nav_buttons["install"].get_style_context().add_class("active")
        
        # Special case: Freemarket is created inside create_game_convert_tab
        # and has its own fetch logic. 
        
        # Initialize components that need refs
        self.dark_mode = True # Default for Fluent Dark
        self.is_installing = False
        
        # Footer Box (Status + Extra Controls)
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        footer.set_border_width(10)
        footer.pack_start(self.status_bar, True, True, 0)
        
        # Theme Toggle Button
        self.theme_btn = Gtk.Button(label="🌙 Dark Mode")
        self.theme_btn.connect("clicked", self.on_theme_toggle)
        footer.pack_start(self.theme_btn, False, False, 0)
        
        ini_btn = Gtk.Button(label="INI Editor")
        ini_btn.connect("clicked", self.on_show_ini_editor)
        footer.pack_start(ini_btn, False, False, 10)
        
        version_label = Gtk.Label(label="v1.1")
        footer.pack_end(version_label, False, False, 0)
        
        self.content_vbox.pack_end(footer, False, False, 0)
        
        # Setup Theme-Aware Logo
        self.update_logo_for_theme()
        
        # Setup Auto-Refresh for USB
        self.refresh_drives()
        GLib.timeout_add_seconds(3, self.refresh_drives)
        
        self.dark_mode = False
        self.is_installing = False
        self.cancel_event = threading.Event()
        self.install_thread = None
        
        self.on_theme_toggle(None)
        
        # Auto-detect system language and apply
        try:
            import locale
            
            # Check LANGUAGE env variable first (most reliable on Linux)
            lang_env = os.environ.get("LANGUAGE", "")
            if lang_env:
                if "pt" in lang_env:
                    self.lang_combo.set_active(1)
                    self.apply_language("pt")
                elif "es" in lang_env:
                    self.lang_combo.set_active(2)
                    self.apply_language("es")
                else:
                    self.lang_combo.set_active(0)
                    self.apply_language("en")
            else:
                # Fallback to locale.getlocale()
                loc = locale.getlocale(locale.LC_MESSAGES)
                sys_lang = loc[0] or "en"
                if "pt" in sys_lang:
                    self.lang_combo.set_active(1)
                    self.apply_language("pt")
                elif "es" in sys_lang:
                    self.lang_combo.set_active(2)
                    self.apply_language("es")
                else:
                    self.lang_combo.set_active(0)
                    self.apply_language("en")
        except:
            pass
        
        # Show language selection dialog on first run
        self.show_first_run_dialog()
        
        self.show_all()
    
    def show_first_run_dialog(self):
        import os
        config_dir = os.path.expanduser("~/.config/x360-tools")
        config_file = os.path.join(config_dir, "first_run")
        
        if not os.path.exists(config_file):
            # First run - show language selection
            dialog = Gtk.Dialog(title="x360 Tools - Select Language", transient_for=self, modal=True)
            dialog.set_default_size(400, 250)
            
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
            vbox.set_border_width(30)
            vbox.set_halign(Gtk.Align.CENTER)
            
            # Logo
            logo_path = os.path.join(self.base_dir, "assets", "x360_tools_logo_dark.png")
            if os.path.exists(logo_path):
                img = Gtk.Image()
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 300, 80, True)
                img.set_from_pixbuf(pixbuf)
                vbox.pack_start(img, False, False, 0)
            
            lbl = Gtk.Label(label="<span size='large' weight='bold'>Select your language</span>\n\nSelecione seu idioma\nSeleccione su idioma", use_markup=True)
            vbox.pack_start(lbl, False, False, 0)
            
            # Language buttons
            lang_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            
            btn_en = Gtk.Button(label="English")
            btn_pt = Gtk.Button(label="Português")
            btn_es = Gtk.Button(label="Español")
            
            def on_lang_select(btn, lang_code):
                dialog.destroy()
                self.lang_combo.set_active({"en": 0, "pt": 1, "es": 2}[lang_code])
                self.apply_language(lang_code)
                # Save preference
                os.makedirs(config_dir, exist_ok=True)
                with open(config_file, "w") as f:
                    f.write(lang_code)
            
            btn_en.connect("clicked", on_lang_select, "en")
            btn_pt.connect("clicked", on_lang_select, "pt")
            btn_es.connect("clicked", on_lang_select, "es")
            
            lang_box.pack_start(btn_en, True, True, 0)
            lang_box.pack_start(btn_pt, True, True, 0)
            lang_box.pack_start(btn_es, True, True, 0)
            
            vbox.pack_start(lang_box, False, False, 0)
            
            dialog.get_content_area().pack_start(vbox, True, True, 0)
            dialog.show_all()
            dialog.run()
            
    def on_sidebar_navigate(self, btn, tab_id, tab_label):
        # Update stack
        self.stack.set_visible_child_name(tab_id)
        
        # Update title in header
        self.view_title_label.set_markup(f"<span size='x-large' weight='bold'>{tab_label}</span>")
        
        # Update active button style
        for b_id, b_widget in self.nav_buttons.items():
            ctx = b_widget.get_style_context()
            if b_id == tab_id:
                ctx.add_class("active")
            else:
                ctx.remove_class("active")

    def on_theme_toggle(self, button):
        self.dark_mode = not self.dark_mode
        if button:
            if self.dark_mode:
                button.set_label("🌙 Dark Mode")
            else:
                button.set_label("☀️ Light Mode")
        
        self.update_logo_for_theme()
        
        # Update CSS
        bg_color = "#121212" if self.dark_mode else "#F5F5F5"
        fg_color = "#FFFFFF" if self.dark_mode else "#333333"
        card_bg = "#1E1E1E" if self.dark_mode else "#FFFFFF"
        sidebar_bg = "#181818" if self.dark_mode else "#E0E0E0"
        sidebar_border = "#282828" if self.dark_mode else "#CCCCCC"
        
        # Robust CSS construction for PREMIUM UI
        new_css = f"window, .main-container {{ background: linear-gradient(180deg, {bg_color} 0%, #000000 100%); color: {fg_color}; }}\n"
        new_css += f".sidebar {{ background-color: {sidebar_bg}; border-style: solid; border-width: 0 1px 0 0; border-color: {sidebar_border}; }}\n"
        new_css += f".sidebar-item {{ color: alpha({fg_color}, 0.7); background-color: transparent; border-style: solid; border-width: 0 0 0 4px; border-color: transparent; padding: 16px 20px; font-weight: bold; }}\n"
        new_css += f".sidebar-item:hover {{ background-color: rgba(255,255,255,0.05); color: {fg_color}; }}\n"
        new_css += f".sidebar-item.active {{ color: #107C10; background-color: rgba(16,124,16,0.1); border-color: #107C10; }}\n"
        
        # Premium Card Styling
        new_css += ".premium-card { border-radius: 12px; background-color: #1E1E1E; }\n"
        new_css += ".premium-card.selected { border: 2px solid #107C10; }\n"
        new_css += ".card-label-box { background: linear-gradient(0deg, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0) 100%); padding: 10px; }\n"
        new_css += f".card-subtitle {{ color: alpha({fg_color}, 0.5); font-size: 11px; }}\n"
        new_css += ".card-indicator { border-radius: 12px; border: 2px solid rgba(255,255,255,0.2); background-color: rgba(0,0,0,0.3); }\n"
        new_css += ".card-indicator.checked { background-color: #107C10; border-color: #107C10; }\n"
        
        new_css += "button { background-color: #107C10; color: #FFFFFF; border-radius: 25px; padding: 10px 20px; font-weight: bold; border: none; }\n"
        new_css += "button:hover { background-color: #159C15; }\n"
        new_css += ".suggested-action { background: linear-gradient(90deg, #107C10 0%, #159C15 100%); box-shadow: 0 4px 15px rgba(16,124,16,0.4); }\n"
        
        new_css += f"entry {{ background-color: {card_bg}; color: {fg_color}; border-radius: 10px; padding: 12px; border: 1px solid {sidebar_border}; }}\n"
        new_css += "progressbar progress { background: linear-gradient(90deg, #107C10 0%, #159C15 100%); border-radius: 10px; }\n"
        
        self.style_provider.load_from_data(new_css.encode())

    def apply_language(self, lang_code):
        self.current_lang = lang_code
        
        def translate_widget(widget):
            # Normal widgets (Buttons, Labels, Checks)
            if hasattr(widget, "get_label") and hasattr(widget, "set_label"):
                orig = getattr(widget, "_orig_text", None)
                if orig is None:
                    orig = widget.get_label()
                    if orig is not None:
                        widget._orig_text = orig
                
                if orig:
                    translated = core.i18n.tr(orig, lang_code)
                    if hasattr(widget, "get_use_markup") and widget.get_use_markup():
                        widget.set_markup(translated)
                    else:
                        widget.set_label(translated)
            
            # Handle buttons with _orig_label attribute
            if hasattr(widget, "_orig_label"):
                translated = core.i18n.tr(widget._orig_label, lang_code)
                widget.set_label(translated)
                        
            if isinstance(widget, Gtk.Container):
                widget.foreach(translate_widget)
        
        if hasattr(self, "root_hbox"):
            translate_widget(self.root_hbox)
            
        # Also handle special stack titles if any are left
        if hasattr(self, "stack"):
            for child in self.stack.get_children():
                try:
                    name = self.stack.child_get_property(child, 'title')
                    if name:
                        orig = getattr(child, "_orig_title", None)
                        if orig is None:
                            orig = name
                            child._orig_title = orig
                        self.stack.child_set_property(child, 'title', core.i18n.tr(orig, lang_code))
                except:
                    pass

    def safe_set_image(self, widget, path, w, h):
        if not os.path.exists(path):
            print(f"Warning: Asset not found: {path}")
            return
        try:
            # use new_from_file_at_scale for better performance and robustness
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, w, h, True)
            widget.set_from_pixbuf(pixbuf)
        except Exception as e:
            print(f"Error loading image {path}: {e}")

    def update_logo_for_theme(self):
        # We now use the manual self.dark_mode instead of system setting for full control
        logo_file = "x360_tools_logo_dark.png" if self.dark_mode else "x360_tools_logo_light.png"
        logo_path = os.path.join(self.base_dir, "assets", logo_file)
        
        # Load main logo
        if hasattr(self, 'settings_logo'):
            self.safe_set_image(self.settings_logo, logo_path, 720, 200)
        if hasattr(self, 'install_logo'):
            self.safe_set_image(self.install_logo, logo_path, 720, 200)
        if hasattr(self, 'plugins_logo'):
            self.safe_set_image(self.plugins_logo, logo_path, 320, 90)

        # Stealth Logo switching (Black for Light, White for Dark)
        stealth_file = "xlive_logo_dark.png" if self.dark_mode else "xlive_logo_light.png"
        stealth_path = os.path.join(self.base_dir, "assets", stealth_file)
        if hasattr(self, 'stealth_logo'):
            self.safe_set_image(self.stealth_logo, stealth_path, 400, 150)
                
        return logo_file

    def refresh_drives(self):
        if self.is_installing:
            return True
            
        new_drives = detect_removable_drives()
        if len(new_drives) != len(self.drives):
            self.drives = new_drives
            self.update_drive_combo()
        return True

    def update_drive_combo(self):
        # Update both drive combos to stay in sync
        combos = []
        if hasattr(self, 'drive_combo'): combos.append(self.drive_combo)
        if hasattr(self, 'content_drive_combo'): combos.append(self.content_drive_combo)
        
        for combo in combos:
            combo.get_model().clear()
            if not self.drives:
                combo.append_text("No removable drives detected")
            else:
                for d in self.drives:
                    fs_info = f" [{d.fstype}]" if d.fstype else ""
                    combo.append_text(f"{d.device} ({d.label}{fs_info}, {d.size_gb:.1f}GB)")
                combo.set_active(0)

    def create_card(self, title, subtitle, image_file, key, category_icon="🎮", is_checked=False):
        # Premium Card using Overlay
        card_box = Gtk.EventBox()
        card_box.get_style_context().add_class("premium-card")
        
        overlay = Gtk.Overlay()
        card_box.add(overlay)
        
        # 1. Background Image
        img = Gtk.Image()
        img_path = os.path.join(self.base_dir, "assets", image_file)
        self.safe_set_image(img, img_path, 200, 120)
        overlay.add(img)
        
        # 2. Selection Indicator (Top Left)
        self.selections[key] = is_checked
        indicator = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        indicator.set_size_request(24, 24)
        indicator.set_halign(Gtk.Align.START)
        indicator.set_valign(Gtk.Align.START)
        indicator.set_margin_start(10)
        indicator.set_margin_top(10)
        indicator.get_style_context().add_class("card-indicator")
        if is_checked:
            indicator.get_style_context().add_class("checked")
        overlay.add_overlay(indicator)
        
        # 3. Label Bar (Bottom)
        label_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        label_vbox.set_valign(Gtk.Align.END)
        label_vbox.get_style_context().add_class("card-label-box")
        
        main_lbl = Gtk.Label(label=f"<b>{title}</b>")
        main_lbl.set_use_markup(True)
        main_lbl.set_xalign(0)
        main_lbl.set_margin_start(10)
        label_vbox.pack_start(main_lbl, False, False, 2)
        
        sub_lbl = Gtk.Label(label=subtitle)
        sub_lbl.set_xalign(0)
        sub_lbl.set_margin_start(10)
        sub_lbl.set_margin_bottom(5)
        sub_lbl.get_style_context().add_class("card-subtitle")
        label_vbox.pack_start(sub_lbl, False, False, 0)
        
        overlay.add_overlay(label_vbox)
        
        # Interaction Logic
        def on_card_click(eb, event):
            self.selections[key] = not self.selections[key]
            if self.selections[key]:
                indicator.get_style_context().add_class("checked")
                card_box.get_style_context().add_class("selected")
            else:
                indicator.get_style_context().remove_class("checked")
                card_box.get_style_context().remove_class("selected")
            return True
            
        card_box.connect("button-press-event", on_card_click)
        
        # Hover effect
        def on_enter(eb, event):
            card_box.get_style_context().add_class("hover")
        def on_leave(eb, event):
            card_box.get_style_context().remove_class("hover")
            
        card_box.connect("enter-notify-event", on_enter)
        card_box.connect("leave-notify-event", on_leave)
        
        return card_box

    def create_install_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        vbox.set_border_width(0)
        
        # 1. Hero Carousel (Libhandy)
        carousel_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        carousel_box.set_size_request(-1, 300)
        
        self.carousel = Handy.Carousel()
        self.carousel.set_animation_duration(500)
        
        # Hero Slide 1
        hero1 = Gtk.Box()
        hero_img = Gtk.Image()
        self.safe_set_image(hero_img, os.path.join(self.base_dir, "assets", "hero_banner.png"), 900, 300)
        hero1.add(hero_img)
        self.carousel.add(hero1)
        
        carousel_box.add(self.carousel)
        
        # dots indicator
        dots = Handy.CarouselIndicatorDots()
        dots.set_carousel(self.carousel)
        carousel_box.pack_start(dots, False, False, 10)
        
        vbox.pack_start(carousel_box, False, False, 0)
        
        # 2. Main Grid (Interactive Cards)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(scrolled, True, True, 0)
        
        grid_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=30)
        grid_vbox.set_margin_start(20)
        grid_vbox.set_margin_end(20)
        scrolled.add(grid_vbox)
        
        # Section: Recommended Setup
        rec_lbl = Gtk.Label(label="<b>Recommended Setup</b>")
        rec_lbl.set_use_markup(True)
        rec_lbl.set_xalign(0)
        grid_vbox.pack_start(rec_lbl, False, False, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(4)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(20)
        grid_vbox.pack_start(flowbox, False, False, 0)
        
        # Cards
        flowbox.add(self.create_card("BadUpdate", "System Exploit", "exploit_thumb.png", "method_badupdate", is_checked=True))
        flowbox.add(self.create_card("Aurora", "Modern Library", "aurora_thumb.png", "aurora_dash", is_checked=True))
        flowbox.add(self.create_card("FSD 3", "Classic Homebrew", "fsd_thumb.png", "fsd_dash"))
        flowbox.add(self.create_card("XeUnshackle", "Native Unlock", "exploit_thumb.png", "patch_xeunshackle"))
        
        # Bottom Action Bar (Integrated into page)
        action_bar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        action_bar.set_margin_top(20)
        grid_vbox.pack_start(action_bar, False, False, 20)
        
        # Drive Selector
        self.drive_combo = Gtk.ComboBoxText()
        self.drive_combo.set_size_request(-1, 50)
        self.update_drive_combo()
        action_bar.add(self.drive_combo)
        
        # Progress & Start
        bottom_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        action_bar.add(bottom_hbox)
        
        self.wizard_btn = Gtk.Button(label="🪄 Wizard")
        self.wizard_btn.set_size_request(120, 50)
        self.wizard_btn.connect("clicked", self.show_install_wizard)
        bottom_hbox.pack_start(self.wizard_btn, False, False, 0)
        
        self.start_btn = Gtk.Button(label="Start Installation")
        self.start_btn.set_size_request(-1, 50)
        self.start_btn.get_style_context().add_class("suggested-action")
        self.start_btn.connect("clicked", self.on_start_clicked)
        bottom_hbox.pack_start(self.start_btn, True, True, 0)
        
        self.progress_bar = Gtk.ProgressBar()
        action_bar.add(self.progress_bar)
        
        self.stack.add_titled(vbox, "install", "Home")

    def show_install_wizard(self, widget):
        def wiz_tr(text):
            return core.i18n.tr(text, self.current_lang)
        
        assistant = Gtk.Assistant()
        assistant.set_title(wiz_tr("Quick Wizard (Beginners)"))
        assistant.set_default_size(600, 450)
        assistant.set_transient_for(self)
        
        wizard_choices = {
            "drive_index": 0 if self.drives else -1,
            "device_type": "Pendrive",
            "console_type": "RGH",
            "dashboards": {"Aurora.zip": True, "Freestyle.zip": False, "Emerald.zip": False, "Viper360.zip": False, "XeXMenu.zip": True},
            "install_extras": True
        }
        
        # 1. Welcome
        box1 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box1.set_border_width(30)
        welcome_text = "<span size='x-large' weight='bold'>" + wiz_tr("Welcome to the Quick Wizard!") + "</span>\n\n" + wiz_tr("This wizard will guide you through formatting and preparing your USB drive for the Xbox 360 in a simplified way.") + "\n\n" + wiz_tr("Click 'Next' to continue.")
        lbl1 = Gtk.Label(label=welcome_text, use_markup=True, justify=Gtk.Justification.CENTER)
        box1.pack_start(lbl1, True, True, 0)
        assistant.append_page(box1)
        assistant.set_page_title(box1, wiz_tr("Welcome"))
        assistant.set_page_type(box1, Gtk.AssistantPageType.INTRO)
        assistant.set_page_complete(box1, True)
        
        # 2. Drive Selection
        box2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box2.set_border_width(30)
        drive_text = wiz_tr("Select the USB drive to format:") + "\n<span color='red' weight='bold'>" + wiz_tr("WARNING: ALL DATA WILL BE ERASED!") + "</span>"
        lbl2 = Gtk.Label(label=drive_text, use_markup=True)
        box2.pack_start(lbl2, False, False, 0)
        drive_combo = Gtk.ComboBoxText()
        if not self.drives:
            drive_combo.append_text(wiz_tr("No USB drive found"))
        else:
            for d in self.drives:
                drive_combo.append_text(f"{d.device} ({d.label}, {d.size_gb:.1f}GB)")
            drive_combo.set_active(0)
            
        def on_drive_changed(c):
            wizard_choices["drive_index"] = c.get_active()
        drive_combo.connect("changed", on_drive_changed)
        box2.pack_start(drive_combo, False, False, 0)
        assistant.append_page(box2)
        assistant.set_page_title(box2, wiz_tr("USB Device"))
        assistant.set_page_type(box2, Gtk.AssistantPageType.CONTENT)
        
        # Set page complete after appending
        has_drives = len(self.drives) > 0
        assistant.set_page_complete(box2, has_drives)

        # 3. Device Type (HDD vs USB)
        box_dev = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box_dev.set_border_width(30)
        lbl_dev = Gtk.Label(label=wiz_tr("Where are you installing the tools?"))
        box_dev.pack_start(lbl_dev, False, False, 0)
        rb_usb = Gtk.RadioButton(label=wiz_tr("Pendrive / External USB (Recommended)"))
        rb_hdd = Gtk.RadioButton(group=rb_usb, label=wiz_tr("Internal Xbox 360 HDD"))
        
        def on_dev_toggled(rb, dtype):
            if rb.get_active(): wizard_choices["device_type"] = dtype
                
        rb_usb.connect("toggled", on_dev_toggled, "Pendrive")
        rb_hdd.connect("toggled", on_dev_toggled, "HDD")
        box_dev.pack_start(rb_usb, False, False, 0)
        box_dev.pack_start(rb_hdd, False, False, 0)
        assistant.append_page(box_dev)
        assistant.set_page_title(box_dev, wiz_tr("Installation Target"))
        assistant.set_page_type(box_dev, Gtk.AssistantPageType.CONTENT)
        assistant.set_page_complete(box_dev, True)
        
        # 3. Console Type
        box3 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box3.set_border_width(30)
        lbl3 = Gtk.Label(label=wiz_tr("What is your console's modchip/exploit?"))
        box3.pack_start(lbl3, False, False, 0)
        rb1 = Gtk.RadioButton(label=wiz_tr("RGH / JTAG (Default, 99% of cases)"))
        rb2 = Gtk.RadioButton(group=rb1, label=wiz_tr("LT / Original / I don't know"))
        
        def on_rb_toggled(rb, ctype):
            if rb.get_active(): wizard_choices["console_type"] = ctype
                
        rb1.connect("toggled", on_rb_toggled, "RGH")
        rb2.connect("toggled", on_rb_toggled, "LT")
        box3.pack_start(rb1, False, False, 0)
        box3.pack_start(rb2, False, False, 0)
        assistant.append_page(box3)
        assistant.set_page_title(box3, wiz_tr("Console Type"))
        assistant.set_page_type(box3, Gtk.AssistantPageType.CONTENT)
        assistant.set_page_complete(box3, True)
        
        # 4. Software Choices
        box4 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box4.set_border_width(30)
        lbl4 = Gtk.Label(label=wiz_tr("Which Dashboards (main menu) do you want to include?"))
        lbl4.set_xalign(0)
        box4.pack_start(lbl4, False, False, 0)
        
        grid = Gtk.Grid(column_spacing=10, row_spacing=5)
        
        def on_dash_toggled(chk, pkg):
            wizard_choices["dashboards"][pkg] = chk.get_active()
            
        dashs = [(wiz_tr("Aurora (Modern / Recommended)"), "Aurora.zip", True),
                 (wiz_tr("Freestyle (Classic)"), "Freestyle.zip", False),
                 (wiz_tr("Emerald"), "Emerald.zip", False),
                 (wiz_tr("Viper360"), "Viper360.zip", False),
                 (wiz_tr("XeXMenu (Required / File Manager)"), "XeXMenu.zip", True)]
                  
        for i, (name, pkg, default) in enumerate(dashs):
            chk = Gtk.CheckButton(label=name)
            chk.set_active(default)
            chk.connect("toggled", on_dash_toggled, pkg)
            grid.attach(chk, 0, i, 1, 1)
            
        box4.pack_start(grid, False, False, 0)
        
        chk_extras = Gtk.CheckButton(label=wiz_tr("Install Essential Plugins (DashLaunch, Autogg, etc)"))
        chk_extras.set_active(True)
        chk_extras.set_margin_top(15)
        def on_extras_toggled(chk):
            wizard_choices["install_extras"] = chk.get_active()
        chk_extras.connect("toggled", on_extras_toggled)
        box4.pack_start(chk_extras, False, False, 0)
        
        assistant.append_page(box4)
        assistant.set_page_title(box4, wiz_tr("Dashboards & Software"))
        assistant.set_page_type(box4, Gtk.AssistantPageType.CONTENT)
        assistant.set_page_complete(box4, True)
        
        # 5. Confirm
        box5 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        box5.set_border_width(30)
        confirm_text = "<span size='large' weight='bold'>" + wiz_tr("All Ready!") + "</span>\n\n" + wiz_tr("When you click 'Apply', formatting will begin") + "\n\n<span color='red'>" + wiz_tr("Your administrator password will be requested") + "</span>"
        lbl5 = Gtk.Label(label=confirm_text, use_markup=True, justify=Gtk.Justification.CENTER)
        box5.pack_start(lbl5, True, True, 0)
        assistant.append_page(box5)
        assistant.set_page_title(box5, wiz_tr("Confirm Installation"))
        assistant.set_page_type(box5, Gtk.AssistantPageType.CONFIRM)
        assistant.set_page_complete(box5, True)
        
        def on_apply(ast):
            if wizard_choices["drive_index"] >= 0:
                self.drive_combo.set_active(wizard_choices["drive_index"])
                
            self.selections.clear()
            
            # ABadAvatar is the universal default and mandatory first step
            self.selections["method_badavatar"] = True
            self.selections["is_hdd"] = (wizard_choices["device_type"] == "HDD")
            
            if wizard_choices["console_type"] == "RGH":
                self.selections["patch_xeunshackle"] = True
            else:
                # Still install ABadAvatar even on LT/Original as requested
                pass
            
            for dash_pkg, state in wizard_choices["dashboards"].items():
                if dash_pkg == "XeXMenu.zip" and not state:
                    self.selections["skip_xexmenu"] = True
                else:
                    self.selections[dash_pkg] = state
            
            if wizard_choices["install_extras"]:
                self.selections["Plugins.zip"] = True
                self.selections["DashLaunch.zip"] = True # Fictional but safe if missing
                self.selections["RBB.zip"] = True
            else:
                self.selections["skip_rockband"] = True
            
            # Destroy assistant first using idle_add to avoid signal issues
            def start_install():
                assistant.destroy()
                self.on_start_clicked(None)
            GLib.idle_add(start_install)
            
        assistant.connect("apply", on_apply)
        
        def on_cancel(dialog):
            if dialog:
                GLib.idle_add(dialog.destroy)
        assistant.connect("cancel", on_cancel)
        assistant.connect("close", on_cancel)
        
        assistant.show_all()

    def create_dashboards_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        vbox.set_border_width(20)
        
        lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Dashboards</span>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        vbox.pack_start(lbl, False, False, 0)
        
        scrolled = Gtk.ScrolledWindow()
        vbox.pack_start(scrolled, True, True, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(4)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(20)
        scrolled.add(flowbox)
        
        # Dashboard Cards
        flowbox.add(self.create_card("Aurora", "Modern Dashboard", "aurora_thumb.png", "pkg_aurora", is_checked=True))
        flowbox.add(self.create_card("FSD 3", "Classic Dashboard", "fsd_thumb.png", "pkg_fsd3"))
        flowbox.add(self.create_card("Emerald", "Minimalist", "aurora_thumb.png", "pkg_emerald"))
        flowbox.add(self.create_card("Viper360", "Alternative", "fsd_thumb.png", "pkg_viper360"))
        
        self.stack.add_titled(vbox, "dashboards", "Dashboards")

    def create_homebrew_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        vbox.set_border_width(20)
        
        lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Homebrew</span>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        vbox.pack_start(lbl, False, False, 0)
        
        scrolled = Gtk.ScrolledWindow()
        vbox.pack_start(scrolled, True, True, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(4)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(20)
        scrolled.add(flowbox)
        
        # Homebrew Cards
        flowbox.add(self.create_card("XeXMenu 1.2", "File Manager", "exploit_thumb.png", "pkg_xexmenu", is_checked=True))
        flowbox.add(self.create_card("DashLaunch", "System Patches", "exploit_thumb.png", "pkg_dashlaunch", is_checked=True))
        
        self.stack.add_titled(vbox, "homebrew", "Homebrew")
        
    def create_stealth_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        vbox.set_border_width(20)
        
        lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Stealth Networks</span>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        vbox.pack_start(lbl, False, False, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(4)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(20)
        vbox.pack_start(flowbox, False, False, 0)
        
        # Stealth Cards
        flowbox.add(self.create_card("Proto", "Private stealth service", "stealth_thumb.png", "pkg_proto"))
        flowbox.add(self.create_card("XBLS", "Classic stealth", "stealth_thumb.png", "pkg_xbls"))
        flowbox.add(self.create_card("NiNJA", "Power user stealth", "stealth_thumb.png", "pkg_ninja"))
        
        self.stack.add_titled(vbox, "stealth", "Stealth")

    def create_plugins_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        vbox.set_border_width(20)
        
        lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Plugins &amp; Tools</span>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        vbox.pack_start(lbl, False, False, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(4)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(20)
        vbox.pack_start(flowbox, False, False, 0)
        
        # Professional Plugin Cards
        flowbox.add(self.create_card("DashLaunch", "System config", "exploit_thumb.png", "pkg_dashlaunch"))
        flowbox.add(self.create_card("Avatar Update", "System update", "exploit_thumb.png", "pkg_avatar"))
        flowbox.add(self.create_card("Avatar HDD", "Internal only", "exploit_thumb.png", "pkg_avatar_hdd"))
        
        self.stack.add_titled(vbox, "plugins", "Plugins")

    def create_settings_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        vbox.set_border_width(40)
        
        # Branding
        self.settings_logo = Gtk.Image()
        vbox.pack_start(self.settings_logo, False, False, 20)
        
        # Centered Options Container
        btn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        btn_box.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(btn_box, False, False, 0)
        
        # Professional Buttons
        self.btn_wizard = Gtk.Button(label="Open Installation Wizard")
        self.btn_wizard.get_style_context().add_class("suggested-action")
        self.btn_wizard.connect("clicked", self.show_install_wizard)
        btn_box.pack_start(self.btn_wizard, False, False, 0)
        
        self.btn_format = Gtk.Button(label="Format for Xbox 360 (FAT32)")
        self.btn_format.connect("clicked", self.on_format_clicked)
        btn_box.pack_start(self.btn_format, False, False, 0)
        
        # Language Selector
        lang_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        lang_hbox.set_halign(Gtk.Align.CENTER)
        lang_hbox.add(Gtk.Label(label="Language:"))
        self.lang_combo = Gtk.ComboBoxText()
        self.lang_combo.append("PT", "Português")
        self.lang_combo.append("EN", "English")
        self.lang_combo.append("ES", "Español")
        self.lang_combo.set_active_id(self.current_lang)
        self.lang_combo.connect("changed", lambda c: self.apply_language(c.get_active_id()))
        lang_hbox.add(self.lang_combo)
        btn_box.pack_start(lang_hbox, False, False, 10)
        
        self.stack.add_titled(vbox, "settings", "Settings")

    def on_format_clicked(self, btn):
        if not self.drives:
            self.status_bar.push(0, "Error: No target drive selected.")
            return
            
        active_idx = self.drive_combo.get_active()
        if active_idx < 0: return
        self.selected_drive = self.drives[active_idx]
        
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="Confirmar Formatação"
        )
        dialog.format_secondary_text(
            f"Deseja formatar o pendrive {self.selected_drive.device}?\n"
            "ISSO IRÁ APAGAR TODOS OS DADOS!"
        )
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.OK:
            if format_fat32(self.selected_drive.device):
                self.status_bar.push(0, "Drive formatado com sucesso!")
            else:
                self.status_bar.push(0, "Falha na formatação.")

    # Event Handlers
    def on_package_toggled(self, widget, package):
        self.selections[package.filename] = widget.get_active()

    def on_option_toggled(self, widget, key):
        self.selections[key] = widget.get_active()

    def on_wipe_temp(self, btn):
        import shutil
        temp_path = os.path.join(self.base_dir, "temp")
        if os.path.exists(temp_path):
            shutil.rmtree(temp_path)
            os.makedirs(temp_path)
            self.status_bar.push(0, "Temp data wiped successfully.")
        else:
            self.status_bar.push(0, "Temp folder not found.")

    def on_delete_app(self, btn):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Delete x360 Tools for Linux?",
        )
        dialog.format_secondary_text("This will remove all project files from this directory. This action is IRREVERSIBLE.")
        response = dialog.run()
        if response == Gtk.ResponseType.YES:
            # Dangerous logic: remove the current directory
            import shutil
            shutil.rmtree(self.base_dir)
            Gtk.main_quit()
        dialog.destroy()

    def on_start_clicked(self, btn):
        if self.is_installing:
            self.cancel_event.set()
            self.status_bar.push(0, "Cancelamento solicitado...")
            return

        if not self.drives:
            self.status_bar.push(0, "Error: No target drive selected.")
            return
            
        active_idx = self.drive_combo.get_active()
        if active_idx < 0: return
        self.selected_drive = self.drives[active_idx]

        # Password Warning Dialog
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="Autorização Necessária"
        )
        dialog.format_secondary_text(
            "O BadStick irá formatar o pendrive selecionado.\n\n"
            "Uma janela de senha do sistema será aberta para autorizar esta operação.\n"
            "Deseja prosseguir?"
        )
        response = dialog.run()
        dialog.destroy()

        if response != Gtk.ResponseType.OK:
            self.status_bar.push(0, "Operação cancelada.")
            return

        self.cancel_event.clear()
        self.is_installing = True
        self.start_btn.set_label("Cancelar Instalação")
        self.stack_switcher.set_sensitive(False)
        self.stack.set_sensitive(False)
        self.progress_bar.set_fraction(0.0)
        
        self.install_thread = threading.Thread(target=self.run_install_flow, daemon=True)
        self.install_thread.start()

    def reset_install_state(self):
        self.is_installing = False
        self.start_btn.set_label("Start Installation")
        self.stack_switcher.set_sensitive(True)
        self.stack.set_sensitive(True)

    def on_show_ini_editor(self, widget):
        if hasattr(self, 'ini_view'):
            self.main_vbox.remove(self.stack)
            self.stack_switcher.set_visible(False)
            self.main_vbox.pack_start(self.ini_view, True, True, 0)
            self.main_vbox.reorder_child(self.ini_view, 0)
            self.ini_view.show_all()
            return
            
        # Create INI View
        self.ini_view = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.ini_view.set_border_width(10)
        
        # Header Label (matches screenshot: x360 Tools INI Configuration)
        header = Gtk.Label(label="<span size='x-large' weight='bold'>x360 Tools INI Configuration</span>", use_markup=True)
        self.ini_view.pack_start(header, False, False, 5)
        
        main_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.ini_view.pack_start(main_hbox, True, True, 0)
        
        # Tabs on top left
        self.ini_nb = Gtk.Notebook()
        main_hbox.pack_start(self.ini_nb, True, True, 0)
        
        self.editors = {} # name -> TextView
        
        from core.ini_logic import get_ini_template, save_ini
        
        for name in ["Launch.ini", "JRPC.ini", "XBDM.ini"]:
            sw = Gtk.ScrolledWindow()
            tv = Gtk.TextView()
            tv.set_monospace(True)
            tv.set_left_margin(10)
            tv.get_buffer().set_text(get_ini_template(name))
            sw.add(tv)
            self.ini_nb.append_page(sw, Gtk.Label(label=name))
            self.editors[name] = tv
            
        # Sidebar Buttons
        btn_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_hbox.pack_end(btn_vbox, False, False, 0)
        
        btns = [
            ("Save", self.on_ini_save),
            ("Clear", self.on_ini_clear),
            ("Open", self.on_ini_open),
            ("New Launch.ini", self.on_ini_new_launch),
            ("Return", self.on_return_main)
        ]
        
        for label, callback in btns:
            btn = Gtk.Button(label=label)
            btn.set_size_request(120, 40)
            btn.connect("clicked", callback)
            if label == "Return":
                btn_vbox.pack_end(btn, False, False, 0)
            else:
                btn_vbox.pack_start(btn, False, False, 0)
                
        # Footer
        ini_footer = Gtk.Label(label="v1.0", xalign=0)
        self.ini_view.pack_end(ini_footer, False, False, 5)
        
        self.main_vbox.remove(self.stack)
        self.stack_switcher.set_visible(False)
        self.main_vbox.pack_start(self.ini_view, True, True, 0)
        self.main_vbox.reorder_child(self.ini_view, 0)
        self.ini_view.show_all()

    def on_return_main(self, widget):
        self.main_vbox.remove(self.ini_view)
        # Re-pack the stack at index 0 (top)
        self.main_vbox.pack_start(self.stack, True, True, 0)
        self.main_vbox.reorder_child(self.stack, 0)
        self.stack_switcher.set_visible(True)
        self.stack.show_all()

    def on_ini_save(self, widget):
        from core.ini_logic import save_ini
        page_idx = self.ini_nb.get_current_page()
        # Find active tab name
        tab_label = self.ini_nb.get_tab_label(self.ini_nb.get_nth_page(page_idx)).get_text()
        tv = self.editors.get(tab_label)
        if tv:
            buffer = tv.get_buffer()
            text = buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter(), True)
            if self.selected_drive and self.selected_drive.mount_point:
                path = os.path.join(self.selected_drive.mount_point, tab_label)
                if save_ini(path, text):
                    self.status_bar.push(0, f"Saved {tab_label} to USB.")
            else:
                path = os.path.join(self.base_dir, tab_label)
                save_ini(path, text)
                self.status_bar.push(0, f"Saved {tab_label} locally.")

    def on_ini_clear(self, widget):
        page_idx = self.ini_nb.get_current_page()
        tab_label = self.ini_nb.get_tab_label(self.ini_nb.get_nth_page(page_idx)).get_text()
        tv = self.editors.get(tab_label)
        if tv:
            tv.get_buffer().set_text("")
                
    def on_ini_open(self, widget):
        dialog = Gtk.FileChooserDialog(
            title="Open INI File", parent=self, action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        if dialog.run() == Gtk.ResponseType.OK:
            path = dialog.get_filename()
            with open(path, 'r') as f:
                content = f.read()
            page_idx = self.ini_nb.get_current_page()
            tab_label = self.ini_nb.get_tab_label(self.ini_nb.get_nth_page(page_idx)).get_text()
            tv = self.editors.get(tab_label)
            if tv:
                tv.get_buffer().set_text(content)
        dialog.destroy()

    def on_ini_new_launch(self, widget):
        from core.ini_logic import get_ini_template
        tv = self.editors.get("Launch.ini")
        if tv:
            tv.get_buffer().set_text(get_ini_template("Launch.ini"))
            self.ini_nb.set_current_page(0) 

    def _force_add_pkg(self, pkgs, filename):
        for p in self.ALL_PACKAGES_REF:
            if p.filename == filename and p not in pkgs:
                pkgs.append(p)
                break

    def run_install_flow(self):
        try:
            if not self.selected_drive:
                GLib.idle_add(self.status_bar.push, 0, "Error: No drive selected.")
                return

            GLib.idle_add(self.status_bar.push, 0, "Initializing installation...")
            GLib.idle_add(self.progress_bar.set_fraction, 0.05)
            
            # 1. Format if not skipped
            if not self.selections.get("skip_format"):
                GLib.idle_add(self.status_bar.push, 0, f"Formatting {self.selected_drive.device} to FAT32...")
                if format_fat32(self.selected_drive.device):
                    GLib.idle_add(self.status_bar.push, 0, "Format successful. Waiting for mount...")
                    time.sleep(3)
                    # Update mount point
                    new_drives = detect_removable_drives()
                    for d in new_drives:
                        if d.device == self.selected_drive.device:
                            self.selected_drive = d
                            break
                else:
                    GLib.idle_add(self.status_bar.push, 0, "Format failed. Proceeding...")

            if self.cancel_event.is_set():
                GLib.idle_add(self.status_bar.push, 0, "Instalação cancelada.")
                return

            if not self.selected_drive.mount_point:
                GLib.idle_add(self.status_bar.push, 0, "Mounting drive...")
                try:
                    subprocess.run(["udisksctl", "mount", "-b", self.selected_drive.device], check=False)
                    time.sleep(2)
                    new_drives = detect_removable_drives()
                    for d in new_drives:
                        if d.device == self.selected_drive.device:
                            self.selected_drive = d
                            break
                except:
                    pass
            
            if self.cancel_event.is_set():
                GLib.idle_add(self.status_bar.push, 0, "Instalação cancelada.")
                return

            if not self.selected_drive.mount_point:
                GLib.idle_add(self.status_bar.push, 0, "Error: Could not mount drive.")
                return

            GLib.idle_add(self.progress_bar.set_fraction, 0.15)
            
            # 2. Collect packages in priority order
            self.ALL_PACKAGES_REF = ALL_PACKAGES
            selected_pkgs = []
            
            # ABadAvatar (method_badavatar) is the priority #1
            exploit_pkg = None
            if self.selections.get("method_badavatar"):
                if self.selections.get("is_hdd"):
                    exploit_pkg = "ABadAvatarHDD.zip"
                else:
                    # ABadAvatar on Pendrive
                    exploit_pkg = "Payload-XeUnshackle.zip"
            elif self.selections.get("method_badavatarhdd"):
                exploit_pkg = "ABadAvatarHDD.zip"
            elif self.selections.get("method_abadmemunit"):
                exploit_pkg = "ABadMemUnit0.zip"
            elif self.selections.get("method_badupdate"):
                exploit_pkg = "BUPayload-FreeMyXe.zip" if self.selections.get("patch_freemyxe") else "BUPayload-XeUnshackle.zip"
            elif self.selections.get("patch_xeunshackle"):
                exploit_pkg = "Payload-XeUnshackle.zip"

            # Add Exploit FIRST if selected
            if exploit_pkg:
                self._force_add_pkg(selected_pkgs, exploit_pkg)
            
            # Add other selected/required packages
            if self.selections.get("install_all"):
                for p in ALL_PACKAGES:
                    if p.filename != exploit_pkg:
                        selected_pkgs.append(p)
            else:
                # Specific selections
                main_pkgs = [p for p in ALL_PACKAGES if self.selections.get(p.filename) and p.filename != exploit_pkg]
                for p in main_pkgs:
                    if p not in selected_pkgs:
                        selected_pkgs.append(p)

                # Implicit rules
                if not self.selections.get("skip_xexmenu"):
                    self._force_add_pkg(selected_pkgs, "XeXMenu.zip")
                
                if not self.selections.get("skip_rockband") and not self.selections.get("skip_main"):
                    self._force_add_pkg(selected_pkgs, "RBB.zip")
            
            total = len(selected_pkgs)
            if total == 0:
                GLib.idle_add(self.status_bar.push, 0, "Nenhum pacote selecionado.")
                GLib.idle_add(self.progress_bar.set_fraction, 1.0)
                return

            from core.packages import resolve_package_url

            for i, p in enumerate(selected_pkgs):
                if self.cancel_event.is_set():
                    GLib.idle_add(self.status_bar.push, 0, "Instalação interrompida.")
                    return

                # Calculate progress
                base_progress = 0.15 + (i / total) * 0.8
                GLib.idle_add(self.progress_bar.set_fraction, base_progress)
                GLib.idle_add(self.progress_bar.set_text, f"Instalando {i+1}/{total}: {p.name}")

                # 1. Resolve path (Check local assets or download to temp)
                asset_path = os.path.join(self.base_dir, "assets", p.filename)
                temp_path = os.path.join(self.base_dir, "temp", p.filename)
                
                final_path = ""
                if os.path.exists(asset_path):
                    final_path = asset_path
                elif os.path.exists(temp_path):
                    final_path = temp_path
                else:
                    # Download it
                    msg = f"Downloading {p.name}..."
                    GLib.idle_add(self.status_bar.push, 0, msg)
                    url = resolve_package_url(p.filename)
                    
                    try:
                        def dl_prog(percent):
                            if self.cancel_event.is_set(): raise Exception("CancelledByUser")
                            p_frac = base_progress + (0.8 * (1/total) * (percent/100.0) * 0.5)
                            GLib.idle_add(self.progress_bar.set_fraction, p_frac)
                        
                        final_path = download_file(url, p.filename, progress_callback=dl_prog, cancel_event=self.cancel_event)
                    except Exception as e:
                        if "CancelledByUser" in str(e): return
                        GLib.idle_add(self.status_bar.push, 0, f"Error downloading {p.name}: {e}")
                        continue

                if self.cancel_event.is_set(): return

                # 2. Extract it
                if final_path and os.path.exists(final_path):
                    if not self.selected_drive.mount_point:
                        new_drives = detect_removable_drives()
                        for d in new_drives:
                            if d.device == self.selected_drive.device:
                                self.selected_drive = d
                                break
                    
                    if not self.selected_drive.mount_point:
                        GLib.idle_add(self.status_bar.push, 0, f"Error: Sem ponto de montagem para {p.name}")
                        continue

                    msg = f"Extracting {p.name}..."
                    GLib.idle_add(self.status_bar.push, 0, msg)
                    try:
                        extract_zip(final_path, self.selected_drive.mount_point, cancel_event=self.cancel_event)
                    except Exception as e:
                        if "CancelledByUser" in str(e): return
                        GLib.idle_add(self.status_bar.push, 0, f"Error extracting {p.name}: {e}")
                
                if self.cancel_event.is_set():
                    GLib.idle_add(self.status_bar.push, 0, "Instalação interrompida.")
                    return
                
                time.sleep(0.1)
                
            GLib.idle_add(self.progress_bar.set_fraction, 1.0)
            GLib.idle_add(self.status_bar.push, 0, "x360 Tools: Installation Complete!")
            
            if self.selections.get("exit_on_finish"):
                time.sleep(2)
                GLib.idle_add(Gtk.main_quit)
            
        except Exception as e:
            GLib.idle_add(self.status_bar.push, 0, f"Error: {str(e)}")
        finally:
            GLib.idle_add(self.reset_install_state)

    def create_game_convert_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        vbox.set_border_width(40)
        
        lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Game Conversion</span>")
        lbl.set_use_markup(True)
        lbl.set_xalign(0)
        vbox.pack_start(lbl, False, False, 0)
        
        # Main Card
        card = Gtk.Frame()
        card_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        card_box.set_border_width(30)
        card.add(card_box)
        vbox.pack_start(card, False, False, 0)
        
        # Mode Toggle
        mode_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        self.radio_extract = Gtk.RadioButton(label="ISO to Extract (Classic)")
        self.radio_god = Gtk.RadioButton(group=self.radio_extract, label="ISO to GOD (360)")
        mode_hbox.pack_start(self.radio_extract, False, False, 0)
        mode_hbox.pack_start(self.radio_god, False, False, 0)
        card_box.pack_start(mode_hbox, False, False, 0)
        
        # Selection Grid
        grid = Gtk.Grid(column_spacing=15, row_spacing=15)
        self.entry_src = Gtk.Entry()
        self.entry_src.set_placeholder_text("Select source ISO...")
        self.entry_src.set_hexpand(True)
        btn_src = Gtk.Button(label="📁")
        btn_src.connect("clicked", self.on_select_iso_clicked)
        grid.attach(self.entry_src, 0, 0, 1, 1)
        grid.attach(btn_src, 1, 0, 1, 1)
        
        self.entry_dest = Gtk.Entry()
        self.entry_dest.set_placeholder_text("Select destination folder...")
        self.entry_dest.set_hexpand(True)
        btn_dest = Gtk.Button(label="📁")
        btn_dest.connect("clicked", self.on_select_folder_clicked)
        grid.attach(self.entry_dest, 0, 1, 1, 1)
        grid.attach(btn_dest, 1, 1, 1, 1)
        card_box.pack_start(grid, False, False, 0)
        
        # Action
        self.btn_convert = Gtk.Button(label="Start Conversion")
        self.btn_convert.get_style_context().add_class("suggested-action")
        self.btn_convert.set_size_request(-1, 50)
        self.btn_convert.connect("clicked", self.on_convert_clicked)
        card_box.pack_start(self.btn_convert, False, False, 10)
        
        # Progress
        self.convert_progress = Gtk.ProgressBar()
        vbox.pack_start(self.convert_progress, False, False, 10)
        
        self.lbl_convert_status = Gtk.Label(label="")
        vbox.pack_start(self.lbl_convert_status, False, False, 0)
        
        self.stack.add_titled(vbox, "game_convert", "Convert")
        self.create_freemarket_tab()

    def create_freemarket_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_border_width(0)
        
        # 1. Hero Carousel (Libhandy)
        carousel_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        carousel_box.set_size_request(-1, 350)
        
        market_carousel = Handy.Carousel()
        market_carousel.set_animation_duration(500)
        
        # Hero Slide 1 (Halo 3)
        hero1 = Gtk.Box()
        hero1_img = Gtk.Image()
        self.safe_set_image(hero1_img, os.path.join(self.base_dir, "assets", "hero_banner.png"), 900, 350)
        hero1.add(hero1_img)
        market_carousel.add(hero1)
        
        carousel_box.add(market_carousel)
        vbox.pack_start(carousel_box, False, False, 0)
        
        # 2. Scrolled Area for Games
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(scrolled, True, True, 0)
        
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        content_vbox.set_margin_start(40)
        content_vbox.set_margin_end(40)
        content_vbox.set_margin_top(20)
        scrolled.add(content_vbox)
        
        # Search Entry
        search_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.market_search = Gtk.SearchEntry()
        self.market_search.set_placeholder_text("Search game library...")
        self.market_search.set_size_request(400, -1)
        search_box.pack_start(self.market_search, False, False, 0)
        content_vbox.pack_start(search_box, False, False, 0)
        
        # Game Section: Top Downloads
        top_lbl = Gtk.Label(label="<span size='x-large' weight='bold'>Top Downloads</span>")
        top_lbl.set_use_markup(True)
        top_lbl.set_xalign(0)
        content_vbox.pack_start(top_lbl, False, False, 0)
        
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(5)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        flowbox.set_column_spacing(20)
        flowbox.set_row_spacing(25)
        content_vbox.pack_start(flowbox, False, False, 0)
        
        # Game Cards
        flowbox.add(self.create_card("Halo 3", "Bungie / High-Definition", "halo3_thumb.png", "game_halo3"))
        flowbox.add(self.create_card("Gears of War 2", "Epic Games / Tactical", "gears2_thumb.png", "game_gears2"))
        flowbox.add(self.create_card("Fable II", "Lionhead / Fantasy", "fable2_thumb.png", "game_fable2"))
        flowbox.add(self.create_card("Mass Effect", "BioWare / Sci-Fi", "hero_banner.png", "game_masseffect"))
        flowbox.add(self.create_card("Forza Horizon", "Playground / Racing", "hero_banner.png", "game_forza"))
        
        # --- Platform Expanders ---
        self.exp_360 = Gtk.Expander(label="Xbox 360")
        self.exp_360.set_expanded(True)
        self.market_flowbox_360 = Gtk.FlowBox()
        self.market_flowbox_360.set_valign(Gtk.Align.START)
        self.market_flowbox_360.set_max_children_per_line(5)
        self.market_flowbox_360.set_selection_mode(Gtk.SelectionMode.NONE)
        self.market_flowbox_360.set_column_spacing(20)
        self.market_flowbox_360.set_row_spacing(25)
        self.exp_360.add(self.market_flowbox_360)
        content_vbox.pack_start(self.exp_360, False, False, 0)
        
        self.exp_classic = Gtk.Expander(label="Xbox Clássico")
        self.exp_classic.set_expanded(True)
        self.market_flowbox_classic = Gtk.FlowBox()
        self.market_flowbox_classic.set_valign(Gtk.Align.START)
        self.market_flowbox_classic.set_max_children_per_line(5)
        self.market_flowbox_classic.set_selection_mode(Gtk.SelectionMode.NONE)
        self.market_flowbox_classic.set_column_spacing(20)
        self.market_flowbox_classic.set_row_spacing(25)
        self.exp_classic.add(self.market_flowbox_classic)
        content_vbox.pack_start(self.exp_classic, False, False, 0)
        
        # Start fetching games
        self.fetch_freemarket_games()
        
        self.stack.add_titled(vbox, "freemarket", "Freemarket")

    def fetch_freemarket_games(self, force=False):
        def run():
            GLib.idle_add(self.status_bar.push, 0, core.i18n.tr("Loading catalog...", self.current_lang))
            try:
                # Scrape both lists
                games_360 = self.freemarket.fetch_game_list("360", force_refresh=force)
                games_classic = self.freemarket.fetch_game_list("classic", force_refresh=force)
                
                GLib.idle_add(self.populate_freemarket_grid, games_360, "360")
                GLib.idle_add(self.populate_freemarket_grid, games_classic, "classic")
                GLib.idle_add(self.status_bar.push, 0, core.i18n.tr("Ready.", self.current_lang))
            except Exception as e:
                GLib.idle_add(self.status_bar.push, 0, f"Error: {e}")
        
        threading.Thread(target=run, daemon=True).start()

    def populate_freemarket_grid(self, games, platform):
        flowbox = self.market_flowbox_360 if platform == "360" else self.market_flowbox_classic
        # Clear existing
        for child in flowbox.get_children():
            flowbox.remove(child)
        
        # Limit to 50 per category for smooth performance on Linux
        for game in games[:50]:
            card = self.create_card(game["name"], game["platform"].upper(), "exploit_thumb.png", f"game_{game['id']}")
            # Wrap in EventBox if not already interactive in create_card
            flowbox.add(card)
            # Re-connect click events since create_card creates a generic checkbox logic
            # for now we'll just keep the create_card look and fix functional click in next pass if needed
        
        flowbox.show_all()

    def create_game_card(self, game):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        vbox.set_size_request(150, 220)
        vbox.get_style_context().add_class("game-card")
        
        # Cover Image Container
        img_bin = Gtk.Box()
        img_bin.set_size_request(140, 180)
        # Use a real cover-looking background (via CSS)
        img_bin.get_style_context().add_class("game-cover-placeholder")
        
        lbl_icon = Gtk.Label(label="🎮")
        img_bin.pack_start(lbl_icon, True, True, 0)
        
        vbox.pack_start(img_bin, False, False, 0)
        
        # Title
        lbl_title = Gtk.Label(label=game["name"])
        lbl_title.set_line_wrap(True)
        lbl_title.set_max_width_chars(20)
        lbl_title.set_ellipsize(Pango.EllipsizeMode.END)
        vbox.pack_start(lbl_title, False, False, 0)
        
        # Platform info
        plat_lbl = Gtk.Label(label=game["platform"].upper())
        plat_lbl.get_style_context().add_class("dim-label")
        vbox.pack_start(plat_lbl, False, False, 0)
        
        # Click event
        eb = Gtk.EventBox()
        eb.add(vbox)
        eb.connect("button-press-event", self.on_game_card_clicked, game)
        return eb

    def on_market_search_changed(self, search_entry):
        text = search_entry.get_text().lower().strip()
        def filter_func(child):
            if not text: return True
            eb = child.get_child()
            if not eb: return True
            vbox = eb.get_child()
            if not vbox: return True
            # Find the title label (usually the one that's wrap=True or longest)
            for widget in vbox.get_children():
                if isinstance(widget, Gtk.Label):
                    content = widget.get_text().lower()
                    if content not in ["🎮", "360", "classic"] and text in content:
                        return True
            return False
        
        self.market_flowbox_360.set_filter_func(filter_func)
        self.market_flowbox_classic.set_filter_func(filter_func)

    def on_game_card_clicked(self, eb, event, game):
        # Create a detail dialog
        dialog = Gtk.Dialog(title=game["name"], transient_for=self, flags=0)
        dialog.set_default_size(500, 400)
        
        content = dialog.get_content_area()
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        vbox.set_border_width(20)
        
        # Big Cover Placeholder
        big_cover = Gtk.Box()
        big_cover.set_size_request(-1, 250)
        big_cover.get_style_context().add_class("game-cover-placeholder")
        big_cover.pack_start(Gtk.Label(label="🎮 " + game["name"]), True, True, 0)
        vbox.pack_start(big_cover, False, False, 0)
        
        # Description
        meta = self.freemarket.search_metadata(game["name"])
        lbl_desc = Gtk.Label(label=meta["description"])
        lbl_desc.set_line_wrap(True)
        vbox.pack_start(lbl_desc, False, False, 0)
        
        # Device Selector with INFO message
        info_lbl = Gtk.Label()
        info_lbl.set_markup(f"<span color='#107C10'><b>{core.i18n.tr('Select the device and the app will handle all installation in the correct folders automatically.', self.current_lang)}</b></span>")
        vbox.pack_start(info_lbl, False, False, 0)
        
        device_combo = Gtk.ComboBoxText()
        for drive in self.drives:
            device_combo.append_text(f"{drive['name']} ({drive['mount_point']})")
        
        if self.drives:
            device_combo.set_active(0)
        vbox.pack_start(device_combo, False, False, 0)
        
        btn_download = Gtk.Button(label=core.i18n.tr("Download & Install", self.current_lang))
        btn_download.get_style_context().add_class("suggested-action")
        vbox.pack_start(btn_download, False, False, 10)
        
        def start_download(btn):
            idx = device_combo.get_active()
            if idx == -1: return
            dest_drive = self.drives[idx]
            dialog.destroy()
            self.start_freemarket_download(game, dest_drive)
            
        btn_download.connect("clicked", start_download)
        
        content.add(vbox)
        dialog.show_all()
        dialog.run()
        dialog.destroy()

    def start_freemarket_download(self, game, drive):
        self.status_bar.push(0, f"Downloading {game['name']}...")
        
        def run():
            tmp_dir = os.path.join(self.freemarket.cache_dir, "downloads")
            os.makedirs(tmp_dir, exist_ok=True)
            zip_path = os.path.join(tmp_dir, os.path.basename(game["url"]))
            
            def progress_cb(current, total):
                percent = current / total if total > 0 else 0
                GLib.idle_add(self.status_bar.push, 0, f"Downloading: {game['name']} ({percent:.1%})")
            
            if download_file(game["url"], zip_path, progress_cb):
                GLib.idle_add(self.status_bar.push, 0, f"Extracting {game['name']}...")
                extract_dir = os.path.join(tmp_dir, "extracted")
                os.makedirs(extract_dir, exist_ok=True)
                
                if extract_zip(zip_path, extract_dir):
                    # Logic to find ISO and convert
                    # This is a bit simplified for now
                    iso_files = [f for f in os.listdir(extract_dir) if f.lower().endswith(".iso")]
                    if iso_files:
                        iso_path = os.path.join(extract_dir, iso_files[0])
                        mode = "god" if game["platform"] == "360" else "extract"
                        
                        # Use the appropriate Content folder based on drive mount_point
                        dest_base = os.path.join(drive["mount_point"], "Content", "0000000000000000")
                        os.makedirs(dest_base, exist_ok=True)
                        
                        GLib.idle_add(self.status_bar.push, 0, f"Converting {game['name']}...")
                        
                        def conv_progress(msg):
                            GLib.idle_add(self.status_bar.push, 0, msg)
                        
                        try:
                            if mode == "god":
                                self.converter.iso_to_god(iso_path, dest_base, progress_cb=conv_progress)
                            else:
                                self.converter.extract_xiso(iso_path, dest_base, progress_cb=conv_progress)
                            
                            GLib.idle_add(self.status_bar.push, 0, f"SUCCESS: {game['name']} installed!")
                        except Exception as e:
                            GLib.idle_add(self.status_bar.push, 0, f"Conversion Error: {e}")
                
        threading.Thread(target=run, daemon=True).start()

    def on_select_iso_clicked(self, btn):
        dialog = Gtk.FileChooserDialog(
            title=core.i18n.tr("Select ISO", self.current_lang),
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        
        filter_iso = Gtk.FileFilter()
        filter_iso.set_name("ISO Images")
        filter_iso.add_pattern("*.iso")
        filter_iso.add_pattern("*.ISO")
        dialog.add_filter(filter_iso)
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self.entry_src.set_text(dialog.get_filename())
        dialog.destroy()

    def on_select_folder_clicked(self, btn):
        dialog = Gtk.FileChooserDialog(
            title=core.i18n.tr("Select Folder", self.current_lang),
            parent=self,
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self.entry_dest.set_text(dialog.get_filename())
        dialog.destroy()

    def on_convert_clicked(self, btn):
        src = self.entry_src.get_text()
        dest = self.entry_dest.get_text()
        
        if not src or not dest:
            self.lbl_convert_status.set_markup("<span color='red'>Error: Source and Destination required!</span>")
            return
            
        mode = "extract" if self.radio_extract.get_active() else "god"
        allow_errors = self.check_ignore_binary.get_active()
        
        self.btn_convert.set_sensitive(False)
        self.convert_progress.pulse()
        self.lbl_convert_status.set_text(core.i18n.tr("Wait, converting...", self.current_lang))
        
        thread = threading.Thread(target=self.run_conversion_thread, args=(mode, src, dest, allow_errors))
        thread.daemon = True
        thread.start()

    def run_conversion_thread(self, mode, src, dest, allow_errors=False):
        try:
            def progress_cb(msg):
                GLib.idle_add(self.lbl_convert_status.set_text, msg)
                GLib.idle_add(self.convert_progress.pulse)

            if mode == "extract":
                self.converter.extract_xiso(src, dest, progress_cb=progress_cb, allow_errors=allow_errors)
            else:
                self.converter.iso_to_god(src, dest, progress_cb=progress_cb, allow_errors=allow_errors)
                
            GLib.idle_add(self.lbl_convert_status.set_markup, f"<span color='#107C10'>{core.i18n.tr('Conversion successful!', self.current_lang)}</span>")
            GLib.idle_add(self.convert_progress.set_fraction, 1.0)
        except Exception as e:
            error_msg = str(e)
            if "binary not found" in error_msg.lower():
                msg = core.i18n.tr("Binary not found!", self.current_lang)
            else:
                msg = f"{core.i18n.tr('Conversion failed!', self.current_lang)}\n{error_msg}"
            GLib.idle_add(self.lbl_convert_status.set_markup, f"<span color='red'>{msg}</span>")
            GLib.idle_add(self.convert_progress.set_fraction, 0.0)
        finally:
            GLib.idle_add(self.btn_convert.set_sensitive, True)

    def create_content_manager_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        vbox.set_border_width(20)
        
        # File Selection
        file_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl_pkg = Gtk.Label(label=core.i18n.tr("Select Content (DLC/TU/Saves)", self.current_lang))
        file_box.pack_start(lbl_pkg, False, False, 0)
        
        self.entry_pkg = Gtk.Entry()
        self.entry_pkg.set_hexpand(True)
        file_box.pack_start(self.entry_pkg, True, True, 0)
        
        btn_browse = Gtk.Button(label="...")
        btn_browse.connect("clicked", self.on_select_content_clicked)
        file_box.pack_start(btn_browse, False, False, 0)
        vbox.pack_start(file_box, False, False, 5)

        # Drive Selection in this Tab
        drive_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl_drive = Gtk.Label(label=core.i18n.tr("USB Device:", self.current_lang))
        drive_box.pack_start(lbl_drive, False, False, 0)
        
        self.content_drive_combo = Gtk.ComboBoxText()
        self.content_drive_combo.set_hexpand(True)
        self.content_drive_combo.connect("changed", self.on_drive_changed)
        drive_box.pack_start(self.content_drive_combo, True, True, 0)
        vbox.pack_start(drive_box, False, False, 5)
        
        # Metadata Display Frame (Horizon Style)
        meta_frame = Gtk.Frame(label=core.i18n.tr("Package Metadata", self.current_lang))
        meta_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        meta_hbox.set_border_width(15)
        
        # Icon on the left
        self.img_icon = Gtk.Image()
        self.img_icon.set_from_icon_name("package-x-generic", Gtk.IconSize.DIALOG)
        self.img_icon.set_pixel_size(64)
        meta_hbox.pack_start(self.img_icon, False, False, 0)
        
        meta_grid = Gtk.Grid(column_spacing=10, row_spacing=5)
        
        lbl1 = Gtk.Label(label=core.i18n.tr("Display Name:", self.current_lang))
        lbl1.set_xalign(1)
        meta_grid.attach(lbl1, 0, 0, 1, 1)
        self.lbl_meta_name = Gtk.Label(label="-")
        self.lbl_meta_name.set_xalign(0)
        self.lbl_meta_name.set_line_wrap(True)
        meta_grid.attach(self.lbl_meta_name, 1, 0, 1, 1)
        
        lbl2 = Gtk.Label(label=core.i18n.tr("Title ID:", self.current_lang))
        lbl2.set_xalign(1)
        meta_grid.attach(lbl2, 0, 1, 1, 1)
        self.lbl_meta_id = Gtk.Label(label="-")
        self.lbl_meta_id.set_xalign(0)
        meta_grid.attach(self.lbl_meta_id, 1, 1, 1, 1)

        lbl_mid = Gtk.Label(label=core.i18n.tr("Media ID:", self.current_lang))
        lbl_mid.set_xalign(1)
        meta_grid.attach(lbl_mid, 0, 2, 1, 1)
        self.lbl_meta_media = Gtk.Label(label="-")
        self.lbl_meta_media.set_xalign(0)
        meta_grid.attach(self.lbl_meta_media, 1, 2, 1, 1)
        
        lbl3 = Gtk.Label(label=core.i18n.tr("Content Type:", self.current_lang))
        lbl3.set_xalign(1)
        meta_grid.attach(lbl3, 0, 3, 1, 1)
        self.lbl_meta_type = Gtk.Label(label="-")
        self.lbl_meta_type.set_xalign(0)
        meta_grid.attach(self.lbl_meta_type, 1, 3, 1, 1)

        meta_hbox.pack_start(meta_grid, True, True, 0)
        meta_frame.add(meta_hbox)
        vbox.pack_start(meta_frame, False, False, 0)
        
        # Action Button
        self.btn_install_pkg = Gtk.Button(label=core.i18n.tr("Install to USB", self.current_lang))
        self.btn_install_pkg.get_style_context().add_class("suggested-action")
        self.btn_install_pkg.connect("clicked", self.on_install_content_clicked)
        vbox.pack_start(self.btn_install_pkg, False, False, 0)
        
        self.lbl_stfs_status = Gtk.Label(label="")
        vbox.pack_start(self.lbl_stfs_status, False, False, 0)

        # Device Explorer Section
        exp_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        exp_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        lbl_exp = Gtk.Label(label="<b>" + core.i18n.tr("Device Explorer", self.current_lang) + "</b>")
        lbl_exp.set_use_markup(True)
        exp_header.pack_start(lbl_exp, False, False, 0)
        
        btn_refresh = Gtk.Button()
        btn_refresh.set_image(Gtk.Image.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON))
        btn_refresh.connect("clicked", self.on_refresh_device_clicked)
        exp_header.pack_end(btn_refresh, False, False, 0)
        exp_box.pack_start(exp_header, False, False, 5)

        # TreeView for Explorer (Grouped)
        # Model: [Icon (Pixbuf), Name (str), ID (str), Type (str), FullPath (str), IsHeader (bool)]
        self.store_explorer = Gtk.TreeStore(GdkPixbuf.Pixbuf, str, str, str, str, bool)
        self.tree_explorer = Gtk.TreeView(model=self.store_explorer)
        
        # Icon Column
        renderer_icon = Gtk.CellRendererPixbuf()
        col_icon = Gtk.TreeViewColumn("", renderer_icon, pixbuf=0)
        self.tree_explorer.append_column(col_icon)

        # Name Column
        renderer_text = Gtk.CellRendererText()
        col_name = Gtk.TreeViewColumn(core.i18n.tr("Display Name:", self.current_lang), renderer_text, text=1)
        col_name.set_resizable(True)
        col_name.set_expand(True)
        self.tree_explorer.append_column(col_name)

        # Title ID Column
        col_tid = Gtk.TreeViewColumn("Title ID", renderer_text, text=2)
        self.tree_explorer.append_column(col_tid)

        # Type Column
        col_type = Gtk.TreeViewColumn("Type", renderer_text, text=3)
        self.tree_explorer.append_column(col_type)
            
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(250)
        scroll.add(self.tree_explorer)
        exp_box.pack_start(scroll, True, True, 0)
        
        # Right-click menu for extraction
        self.tree_explorer.connect("button-press-event", self.on_tree_button_press)
        
        vbox.pack_start(exp_box, True, True, 0)
        
        # Sync combos on start
        self.update_drive_combo()
        
        self.stack.add_titled(vbox, "content_manager", core.i18n.tr("Content Manager", self.current_lang))

    def on_drive_changed(self, combo):
        # Prevent infinite recursion if we change the other combo
        if getattr(self, "_updating_combos", False):
            return
            
        idx = combo.get_active()
        if idx < 0 or not self.drives:
            self.selected_drive = None
            return
            
        self.selected_drive = self.drives[idx]
        
        # Sync other combo
        self._updating_combos = True
        if hasattr(self, 'drive_combo') and hasattr(self, 'content_drive_combo'):
            other = self.content_drive_combo if combo == self.drive_combo else self.drive_combo
            other.set_active(idx)
        self._updating_combos = False
        
        # Auto-refresh explorer when drive changes
        self.on_refresh_device_clicked(None)

    def on_select_content_clicked(self, btn):
        dialog = Gtk.FileChooserDialog(
            title=core.i18n.tr("Select Content (DLC/TU/Saves)", self.current_lang),
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            path = dialog.get_filename()
            self.entry_pkg.set_text(path)
            # Update Metadata display (With icon extraction)
            meta = get_stfs_metadata(path, extract_icon=True)
            if meta:
                self.lbl_meta_name.set_text(meta["display_name"])
                self.lbl_meta_id.set_text(meta["title_id"])
                self.lbl_meta_media.set_text(meta["media_id"])
                self.lbl_meta_type.set_text(meta["type_name"])
                if meta["icon_path"]:
                    self.img_icon.set_from_file(meta["icon_path"])
                else:
                    self.img_icon.set_from_icon_name("package-x-generic", Gtk.IconSize.DIALOG)
                
                self.lbl_stfs_status.set_text("")
                self.btn_install_pkg.set_sensitive(True)
            else:
                self.lbl_meta_name.set_text("-")
                self.lbl_meta_id.set_text("-")
                self.lbl_meta_media.set_text("-")
                self.lbl_meta_type.set_text("-")
                self.img_icon.set_from_icon_name("error", Gtk.IconSize.DIALOG)
                self.lbl_stfs_status.set_markup(f"<span color='red'>{core.i18n.tr('Not a valid Xbox 360 package!', self.current_lang)}</span>")
                self.btn_install_pkg.set_sensitive(False)
        dialog.destroy()

    def on_refresh_device_clicked(self, btn):
        if not self.selected_drive or not self.selected_drive.mount_point:
            return
            
        self.store_explorer.clear()
        
        def run_scan():
            games = list_usb_content(self.selected_drive.mount_point)
            
            for tid, data in games.items():
                # Load game icon
                pixbuf = None
                if data["icon"] and os.path.exists(data["icon"]):
                    try:
                        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(data["icon"], 32, 32, True)
                    except: pass
                
                # Update UI in main thread (Game + its items)
                def update_game_ui(t=tid, d=data, p=pixbuf):
                    parent = self.store_explorer.append(None, [p, d["name"], t, "Game", "", True])
                    for item in d["items"]:
                        self.store_explorer.append(parent, [None, item["display_name"], item["title_id"], item["type_name"], item["file_path"], False])
                    # Expand the game by default
                    # self.tree_explorer.expand_all()
                
                GLib.idle_add(update_game_ui)

        threading.Thread(target=run_scan, daemon=True).start()

    def on_tree_button_press(self, tree, event):
        if event.button == 3: # Right click
            path_info = tree.get_path_at_pos(int(event.x), int(event.y))
            if path_info:
                path, col, cellx, celly = path_info
                tree.get_selection().select_path(path)
                
                # Check if it's a file (not a header)
                model = tree.get_model()
                iter = model.get_iter(path)
                is_header = model.get_value(iter, 5)
                file_path = model.get_value(iter, 4)
                
                if not is_header and file_path:
                    menu = Gtk.Menu()
                    
                    item_extract = Gtk.MenuItem(label=core.i18n.tr("Extract to PC", self.current_lang))
                    item_extract.connect("activate", self.on_extract_clicked, file_path)
                    menu.append(item_extract)
                    
                    menu.show_all()
                    menu.popup_at_pointer(event)
            return True
        return False

    def on_extract_clicked(self, menu_item, pkg_path):
        dialog = Gtk.FileChooserDialog(
            title=core.i18n.tr("Select destination for extraction", self.current_lang),
            parent=self,
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_SAVE, Gtk.ResponseType.OK)
        
        if dialog.run() == Gtk.ResponseType.OK:
            dest = dialog.get_filename()
            try:
                 extract_package(pkg_path, dest)
                 self.status_bar.push(0, core.i18n.tr("Extraction successful!", self.current_lang))
            except Exception as e:
                 self.status_bar.push(0, f"Error: {str(e)}")
        dialog.destroy()

    def on_install_content_clicked(self, btn):
        pkg_path = self.entry_pkg.get_text()
        if not pkg_path or not os.path.exists(pkg_path):
            return
            
        # Get selected drive from the combo
        if not self.selected_drive or not self.selected_drive.mount_point:
             self.lbl_stfs_status.set_markup("<span color='red'>Error: No USB Drive selected in Install tab!</span>")
             return

        self.btn_install_pkg.set_sensitive(False)
        self.lbl_stfs_status.set_text(core.i18n.tr("Wait, installing...", self.current_lang))
        
        def run_install():
            try:
                dest_path = install_package(pkg_path, self.selected_drive.mount_point)
                
                # Verification Pass (Real verification + visual feedback)
                GLib.idle_add(self.lbl_stfs_status.set_text, core.i18n.tr("Verifying...", self.current_lang))
                time.sleep(0.8) # Small delay to ensure OS buffers are flushed and for user perception
                
                if os.path.exists(dest_path) and os.path.getsize(dest_path) == os.path.getsize(pkg_path):
                    GLib.idle_add(self.lbl_stfs_status.set_markup, f"<span color='#107C10'>{core.i18n.tr('Installation successful!', self.current_lang)}</span>")
                    # Auto refresh the explorer to show the new content
                    GLib.idle_add(self.on_refresh_device_clicked, None)
                else:
                    raise IOError("Verification failed: Integrity check mismatch.")
                    
            except Exception as e:
                GLib.idle_add(self.lbl_stfs_status.set_markup, f"<span color='red'>Error: {str(e)}</span>")
            finally:
                GLib.idle_add(self.btn_install_pkg.set_sensitive, True)

        thread = threading.Thread(target=run_install)
        thread.daemon = True
        thread.start()

if __name__ == "__main__":
    print("[*] Instantiating X360Tools...")
    try:
        app = X360Tools()
        print("[*] X360Tools initialized, showing window...")
        app.connect("destroy", Gtk.main_quit)
        app.show_all()
        print("[*] Entering Gtk.main loop. Interface should be visible.")
        Gtk.main()
    except Exception as e:
        print(f"[CRASH] {str(e)}")
        with open(LOG_FILE, "a") as f:
            f.write(f"CRASH: {str(e)}\n")
            import traceback
            traceback.print_exc(file=f)
