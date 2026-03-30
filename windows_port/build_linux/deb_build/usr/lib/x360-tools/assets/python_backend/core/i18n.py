import os
import re

STRINGS = {
    "Install": {"pt": "Instalação", "es": "Instalación", "en": "Install"},
    "Dashboards": {"pt": "Dashboards", "es": "Dashboards", "en": "Dashboards"},
    "Homebrew": {"pt": "Homebrews", "es": "Homebrews", "en": "Homebrew"},
    "Stealth Servers": {"pt": "Stealth e Bypass", "es": "Stealth y Bypass", "en": "Stealth & Bypass"},
    "Plugins": {"pt": "Plugins e Outros", "es": "Plugins y Otros", "en": "Plugins / Other"},
    "System Settings": {"pt": "Configurações", "es": "Configuración", "en": "System Settings"},

    "Exploit Method": {"pt": "Método de Exploit", "es": "Método de Exploit"},
    "Patches": {"pt": "Patches", "es": "Parches"},
    "Installation Options": {"pt": "Opções de Instalação", "es": "Opciones de Instalación"},
    
    "🪄 Assistente Rápido (Iniciantes)": {"en": "🪄 Quick Wizard (Beginners)", "es": "🪄 Asistente Rápido (Principiantes)"},
    "🪄 Quick Wizard (Beginners)": {"pt": "🪄 Assistente de Instalação (Iniciantes)", "es": "🪄 Asistente de Instalación (Principiantes)"},
    "Start Installation (Avançado)": {"en": "Start Installation (Advanced)", "es": "Iniciar Instalación (Avanzado)"},
    "Reset Drives": {"pt": "Atualizar Dispositivos", "es": "Actualizar Dispositivos"},
    "Exit": {"pt": "Sair", "es": "Salir"},
    "Cancelar Instalação": {"en": "Cancel Installation", "es": "Cancelar Instalación"},
    
    "Device Ready": {"pt": "Dispositivo Pronto", "es": "Dispositivo Listo"},
    "No removable drives detected": {"pt": "Nenhum pendrive detectado", "es": "No se detectó ningún USB"},
    
    "Dashboards / Launchers": {"pt": "Dashboards / Launchers", "es": "Dashboards / Launchers"},
    "Homebrew Applications": {"pt": "Aplicativos Homebrew", "es": "Aplicaciones Homebrew"},
    "Stealth Networks": {"pt": "Redes Stealth", "es": "Redes Stealth"},
    "Plugins (Extended)": {"pt": "Plugins (Extras)", "es": "Plugins (Extras)"},
    "Console Specific Files": {"pt": "Arquivos da Memória Xbox", "es": "Archivos del Consola"},
    "Customization": {"pt": "Personalização (Boot)", "es": "Personalización (Boot)"},
    "Backwards Compatibility": {"pt": "Retrocompatibilidade", "es": "Retrocompatibilidad Xbox Original"},
    "x360 Tools Utilities": {"pt": "Utilitários do x360 Tools", "es": "Utilidades de x360 Tools"},
    "Wipe Temp Data": {"pt": "Limpar Cache Temporário", "es": "Borrar Caché Temporal"},
    "Delete x360 Tools": {"pt": "Desinstalar x360 Tools", "es": "Desinstalar x360 Tools"},
    
    "Appearance": {"pt": "Aparência", "es": "Apariencia"},
    "Language": {"pt": "Idioma", "es": "Idioma"},
    "🌙 Dark Mode": {"pt": "🌙 Modo Escuro", "es": "🌙 Modo Oscuro"},
    "☀️ Light Mode": {"pt": "☀️ Modo Claro", "es": "☀️ Modo Claro"},
    
    "x360 Tools INI Configuration": {"pt": "Gerador de Launch.INI", "es": "Generador de Launch.INI"},
    "Generate/Save .INI File": {"pt": "Gerar / Salvar no USB", "es": "Generar / Guardar en USB"},
    "Load Local .INI": {"pt": "Carregar .INI do PC", "es": "Cargar .INI del PC"},
    "Load from USB": {"pt": "Carregar do USB", "es": "Cargar del USB"},
    
    "Assistente de Instalação (x360 Tools)": {"en": "x360 Tools - Install Wizard", "es": "Asistente de x360 Tools"},
    "Início": {"en": "Welcome", "es": "Inicio"},
    "Dispositivo USB": {"en": "USB Device", "es": "Dispositivo USB"},
    "Tipo de Console": {"en": "Console Type", "es": "Tipo de Consola"},
    "Programas e Dashboards": {"en": "Dashboards & Software", "es": "Software y Dashboards"},
    "Confirmar Instalação": {"en": "Confirm & Install", "es": "Confirmar Instalación"},
    
    # Additional UI strings
    "Welcome": {"pt": "Bem-vindo", "es": "Bienvenido"},
    "USB Device": {"pt": "Dispositivo USB", "es": "Dispositivo USB"},
    "Console Type": {"pt": "Tipo de Console", "es": "Tipo de Consola"},
    "Dashboards & Software": {"pt": "Programas e Dashboards", "es": "Software y Dashboards"},
    "Confirm & Install": {"pt": "Confirmar Instalação", "es": "Confirmar Instalación"},
    
    # Buttons and labels
    "Start Installation": {"pt": "Iniciar Instalação", "es": "Iniciar Instalación"},
    "Start Installation (Advanced)": {"pt": "Iniciar Instalação (Avançado)", "es": "Iniciar Instalación (Avanzado)"},
    "Cancel Installation": {"pt": "Cancelar Instalação", "es": "Cancelar Instalación"},
    "Quick Wizard (Beginner)": {"pt": "Assistente de Instalação (Iniciantes)", "es": "Asistente de Instalación (Principiantes)"},
    "Quick Wizard": {"pt": "Assistente de Instalação", "es": "Asistente de Instalación"},
    "Quick Wizard (Beginners)": {"pt": "Assistente de Instalação (Iniciantes)", "es": "Asistente de Instalación (Principiantes)"},
    "Update Devices": {"pt": "Atualizar Dispositivos", "es": "Actualizar Dispositivos"},
    
    # Status messages
    "Warning: No Device Detected": {"pt": "Aviso: Nenhum dispositivo detectado", "es": "Aviso: Ningún dispositivo detectado"},
    "Device Ready": {"pt": "Dispositivo Pronto", "es": "Dispositivo Listo"},
    "Initializing installation...": {"pt": "Iniciando instalação...", "es": "Iniciando instalación..."},
    "Nenhum pacote selecionado.": {"pt": "Nenhum pacote selecionado.", "es": "Ningún paquete seleccionado."},
    "Installation Complete!": {"pt": "Instalação concluída!", "es": "Instalación completada!"},
    
    # Installation Options
    "Skip XeXMenu": {"pt": "Pular XeXMenu", "es": "Omitir XeXMenu"},
    "Skip Rock Band": {"pt": "Pular Rock Band", "es": "Omitir Rock Band"},
    "Skip Main Files": {"pt": "Pular Arquivos Principais", "es": "Omitir Archivos Principales"},
    "Skip Format": {"pt": "Pular Formatação", "es": "Omitir Formate"},
    "Install All Files": {"pt": "Instalar Tudo", "es": "Instalar Todo"},
    "Exit On Finish": {"pt": "Fechar ao concluir", "es": "Cerrar al terminar"},
    
    # Quick Wizard Button
    "Quick Wizard (Beginners)": {"pt": "Assistente de Instalação (Iniciantes)", "es": "Asistente de Instalación (Principiantes)"},
    
    # Wizard texts
    "Welcome to the Quick Wizard!": {"pt": "Bem-vindo ao Assistente Rápido!", "es": "¡Bienvenido al Asistente Rápido!"},
    "Select the USB drive to format:": {"pt": "Selecione o Pendrive que deseja formatar:", "es": "Seleccione la unidad USB a formatear:"},
    "WARNING: ALL DATA WILL BE ERASED!": {"pt": "ATENÇÃO: TODOS OS DADOS SERÃO APAGADOS!", "es": "¡ADVERTENCIA: TODOS LOS DATOS SERÁN BORRADOS!"},
    "What is your console's modchip/exploit?": {"pt": "Qual o destrave do seu console?", "es": "¿Cuál es el destrave de tu consola?"},
    "RGH / JTAG (Default, 99% of cases)": {"pt": "RGH / JTAG (Padrão, 99% dos casos)", "es": "RGH / JTAG (Predeterminado, 99% de los casos)"},
    "LT / Original / I don't know": {"pt": "LT / Original / Não sei", "es": "LT / Original / No sé"},
    "All Ready!": {"pt": "Tudo Pronto!", "es": "¡Todo Listo!"},
    "When you click 'Apply', formatting will begin": {"pt": "Ao clicar em 'Aplicar', a formatação será iniciada", "es": "Al hacer clic en 'Aplicar', se iniziará el formateo"},
    "Your administrator password will be requested": {"pt": "Será solicitada sua senha de administrador", "es": "Se solicitará su contraseña de administrador"},
    "Click 'Next' to continue.": {"pt": "Clique em 'Avançar' para continuar.", "es": "Haga clic en 'Siguiente' para continuar."},
    
    # Wizard page titles
    "Welcome": {"pt": "Início", "es": "Inicio"},
    "USB Device": {"pt": "Dispositivo USB", "es": "Dispositivo USB"},
    "Console Type": {"pt": "Tipo de Console", "es": "Tipo de Consola"},
    "Dashboards & Software": {"pt": "Programas e Dashboards", "es": "Software y Dashboards"},
    "Confirm Installation": {"pt": "Confirmar Instalação", "es": "Confirmar Instalación"},
    
    # Additional wizard strings
    "Which Dashboards (main menu) do you want to include?": {"pt": "Quais Dashboards (menu principal) você deseja incluir?", "es": "¿Qué Dashboards (menú principal) desea incluir?"},
    "Emerald": {"pt": "Emerald", "es": "Emerald"},
    "Viper360": {"pt": "Viper360", "es": "Viper360"},
    "Install Essential Plugins": {"pt": "Instalar Plugins Essenciais", "es": "Instalar Plugins Esenciales"},
    "No USB drive found": {"pt": "Nenhum pendrive encontrado", "es": "No se encontró unidad USB"},
    
    # Wizard - Dashboards options
    "Aurora (Modern / Recommended)": {"pt": "Aurora (Moderno / Recomendado)", "es": "Aurora (Moderno / Recomendado)"},
    "Freestyle (Classic)": {"pt": "Freestyle (Clássico)", "es": "Freestyle (Clásico)"},
    "XeXMenu (Required / File Manager)": {"pt": "XeXMenu (Obrigatório / Gerenciador de Arquivos)", "es": "XeXMenu (Requerido / Gestor de Archivos)"},
    "This wizard will guide you through formatting and preparing your USB drive for the Xbox 360 in a simplified way.": {"pt": "Este assistente irá guiá-lo na formatação e preparação do seu pendrive para o Xbox 360 de forma simplificada.", "es": "Este asistente le guiará en el formateo y preparación de su USB para el Xbox 360 de forma simplificada."},
    "Install Essential Plugins (DashLaunch, Autogg, etc)": {"pt": "Instalar Plugins Essenciais (DashLaunch, Autogg, etc)", "es": "Instalar Plugins Esenciales (DashLaunch, Autogg, etc)"},
    "When you click 'Apply', formatting will begin": {"pt": "Ao clicar em 'Aplicar', a formatação será iniciada", "es": "Al hacer clic en 'Aplicar', se iniciarán el formateo"},
    
    # New Device Type strings
    "Where are you installing the tools?": {"pt": "Onde você deseja instalar as ferramentas?", "es": "¿Dónde desea instalar las herramientas?"},
    "Pendrive / External USB (Recommended)": {"pt": "Pendrive / USB Externo (Recomendado)", "es": "USB / Pendrive Externo (Recomendado)"},
    "Internal Xbox 360 HDD": {"pt": "HDD Interno do Xbox 360", "es": "Disco Duro (HDD) Interno de Xbox 360"},
    "Installation Target": {"pt": "Destino da Instalação", "es": "Destino de la Instalación"},
    
    # Game Convert tab
    "Game Convert": {"pt": "Converter Jogos", "es": "Convertir Juegos", "en": "Game Convert"},
    "Conversion Mode": {"pt": "Modo de Conversão", "es": "Modo de Conversión"},
    "ISO to Extract (Classic Xbox)": {"pt": "ISO para Extração (Xbox Clássico)", "es": "ISO para Extracción (Xbox Clásico)"},
    "ISO to GOD (Xbox 360)": {"pt": "ISO para GOD (Xbox 360)", "es": "ISO para GOD (Xbox 360)"},
    "Source ISO File:": {"pt": "Arquivo ISO de Origem:", "es": "Archivo ISO de Origen:"},
    "Destination Folder:": {"pt": "Pasta de Destino:", "es": "Carpeta de Destino:"},
    "Select ISO": {"pt": "Selecionar ISO", "es": "Seleccionar ISO"},
    "Select Folder": {"pt": "Selecionar Pasta", "es": "Seleccionar Carpeta"},
    "Convert Game": {"pt": "Converter Jogo", "es": "Convertir Juego"},
    "Wait, converting...": {"pt": "Aguarde, convertendo...", "es": "Espere, convirtiendo..."},
    "Conversion successful!": {"pt": "Conversão concluída com sucesso!", "es": "¡Conversión exitosa!"},
    "Conversion failed!": {"pt": "Falha na conversão!", "es": "¡Conversión fallida!"},
    "Binary not found!": {"pt": "Binário não encontrado!", "es": "¡Binario no encontrado!"},
    
    # v1.1 Content Manager
    "Content Manager": {"pt": "Injetor Horizon", "es": "Inyector Horizon", "en": "Content Manager"},
    "Select Content (DLC/TU/Saves)": {"pt": "Selecionar Conteúdo (DLC/TU/Saves)", "es": "Seleccionar Contenido (DLC/TU/Saves)"},
    "Package Metadata": {"pt": "Metadados do Pacote", "es": "Metadatos del Paquete"},
    "Title ID:": {"pt": "ID do Jogo:", "es": "ID del Juego:"},
    "Media ID:": {"pt": "ID de Mídia:", "es": "ID de Mídia:"},
    "Content Type:": {"pt": "Tipo:", "es": "Tipo:"},
    "Display Name:": {"pt": "Nome:", "es": "Nombre:"},
    "Description:": {"pt": "Descrição:", "es": "Descripción:"},
    "Device Explorer": {"pt": "Explorador de Dispositivo", "es": "Explorador de Dispositivo"},
    "Refresh Content": {"pt": "Atualizar Conteúdo", "es": "Actualizar Contenido"},
    "Install to USB": {"pt": "Injetar no Pendrive", "es": "Inyectar en USB"},
    "Wait, installing...": {"pt": "Aguarde, injetando...", "es": "Espere, inyectando..."},
    "Installation successful!": {"pt": "Conteúdo injetado com sucesso!", "es": "¡Inyección exitosa!"},
    "USB Device:": {"pt": "Dispositivo USB:", "es": "Dispositivo USB:", "en": "USB Device:"},
    "Extract to PC": {"pt": "Extrair para o PC", "es": "Extraer al PC", "en": "Extract to PC"},
    "Select destination for extraction": {"pt": "Selecione o destino para extração", "es": "Seleccione el destino para la extracción", "en": "Select destination for extraction"},
    "Extraction successful!": {"pt": "Extração concluída!", "es": "¡Extracción completada!", "en": "Extraction successful!"},
    "Verifying...": {"pt": "Verificando...", "es": "Verificando...", "en": "Verifying..."},
    "Ignore missing game binary": {"pt": "Ignorar binário ausente no jogo", "es": "Ignorar binario ausente en el juego", "en": "Ignore missing game binary"},
    "Freemarket": {"pt": "Freemarket", "es": "Freemarket", "en": "Freemarket"},
    "Search games...": {"pt": "Pesquisar jogos...", "es": "Buscar juegos...", "en": "Search games..."},
    "Select the device and the app will handle all installation in the correct folders automatically.": {
        "pt": "Selecione o dispositivo e o app cuidará de toda a instalação nas pastas corretas automaticamente.",
        "es": "Seleccione el dispositivo e o app cuidará de toda a instalação nas pastas corretas automaticamente.",
        "en": "Select the device and the app will handle all installation in the correct folders automatically."
    },
    "Download & Install": {"pt": "Baixar e Instalar", "es": "Descargar e Instalar", "en": "Download & Install"},
    "Wait, converting...": {"pt": "Aguarde, convertendo...", "es": "Espere, convirtiendo...", "en": "Wait, converting..."},
    "Conversion successful!": {"pt": "Conversão concluída com sucesso!", "es": "¡Conversión exitosa!", "en": "Conversion successful!"},
    "Loading catalog...": {"pt": "Carregando catálogo...", "es": "Cargando catálogo...", "en": "Loading catalog..."},
    "Ready.": {"pt": "Pronto.", "es": "Listo.", "en": "Ready."},
    "Xbox 360 Games": {"pt": "Jogos de Xbox 360", "es": "Juegos de Xbox 360", "en": "Xbox 360 Games"},
    "Xbox Classic Games": {"pt": "Jogos de Xbox Clássico", "es": "Juegos de Xbox Clásico", "en": "Xbox Classic Games"},
}

def tr(english_or_base_text, lang_code="en"):
    """
    Translates strings. Supports:
    - English -> PT/ES (default behavior)
    - PT/ES -> English (when user changes language back)
    - Handles strings with GTK markup
    """
    if not english_or_base_text:
        return ""
        
    clean_key = english_or_base_text.strip()
    
    # 1. Try direct match with the key as-is
    if clean_key in STRINGS:
        if lang_code in STRINGS[clean_key]:
            return STRINGS[clean_key][lang_code]
        # Fallback to English if available
        if "en" in STRINGS[clean_key]:
            return STRINGS[clean_key]["en"]
    
    # 2. If not found and target is English, try reverse lookup
    # Search for any language that matches the input text, then translate to target
    if lang_code == "en":
        for key, translations in STRINGS.items():
            for src_lang, src_text in translations.items():
                if src_text == clean_key:
                    # Found the source, return English version
                    if "en" in translations:
                        return translations["en"]
                    return key  # Return the original key as fallback
    
    # 3. Try to handle markup strings
    no_markup = re.sub(r"<[^>]+>", "", clean_key).strip()
    if no_markup != clean_key:
        # Try exact match without markup
        if no_markup in STRINGS:
            if lang_code in STRINGS[no_markup]:
                # Re-wrap in original markup
                match = re.search(r"(<span[^>]*>)(.*?)(</span>)", clean_key, re.IGNORECASE | re.DOTALL)
                if match:
                    translated_inner = STRINGS[no_markup].get(lang_code, STRINGS[no_markup].get("en", no_markup))
                    return match.group(1) + translated_inner + match.group(3)
                return STRINGS[no_markup].get(lang_code, STRINGS[no_markup].get("en", no_markup))
        
        # Try reverse lookup for markup
        if lang_code == "en":
            for key, translations in STRINGS.items():
                if no_markup in translations.values():
                    if "en" in translations:
                        match = re.search(r"(<span[^>]*>)(.*?)(</span>)", clean_key, re.IGNORECASE | re.DOTALL)
                        if match:
                            return match.group(1) + translations["en"] + match.group(3)
                        return translations["en"]
                
    return english_or_base_text
