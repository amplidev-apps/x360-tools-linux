import os
import sys

# ANSI Escape Codes for styling
class Style:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    DIM = '\033[2m'
    NC = '\033[0m' # No Color
    
    # Selection effects
    SELECTED = '\033[7m' # Inverted

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def draw_header(title, current_tab):
    tabs = ["STARTUP", "INSTALL", "DASH", "HOMEBREW", "STEALTH", "PLUGINS", "SETTINGS", "INI"]
    
    print(f"{Style.BOLD}{Style.CYAN}== x360 Tools (beta) (Python Port) =={Style.NC}")
    print(f"{Style.DIM}Status: Alpha 1.0{Style.NC}\n")
    
    tab_line = ""
    for i, t in enumerate(tabs):
        if i == current_tab:
            tab_line += f"{Style.SELECTED} {t} {Style.NC}  "
        else:
            tab_line += f" {t}   "
    print(tab_line)
    print("─" * 60)
    print(f"\n{Style.BOLD}{title}{Style.NC}\n")

def draw_footer():
    print("\n" + "─" * 60)
    print(f"{Style.DIM}[Tab/Shift-Tab] Navegar Abas | [Setas] Selecionar | [Esc/Q] Sair{Style.NC}")
