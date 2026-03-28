class TranslationService {
  static const Map<String, Map<String, String>> strings = {
    "Instalação": {"pt": "Instalação", "es": "Instalación", "en": "Install"},
    "Dashboards": {"pt": "Dashboards", "es": "Dashboards", "en": "Dashboards"},
    "Homebrews": {"pt": "Homebrews", "es": "Homebrews", "en": "Homebrew"},
    "Stealth e Bypass": {"pt": "Stealth e Bypass", "es": "Stealth y Bypass", "en": "Stealth & Bypass"},
    "Plugins e Outros": {"pt": "Plugins e Outros", "es": "Plugins y Otros", "en": "Plugins / Other"},
    "Configurações": {"pt": "Configurações", "es": "Configuración", "en": "Settings"},
    "Início": {"en": "Home", "es": "Inicio", "pt": "Início"},
    "x360 Landscape": {"pt": "x360 Landscape", "en": "x360 Landscape", "es": "x360 Landscape"},
    "x360 Converter": {"pt": "x360 Converter", "en": "x360 Converter", "es": "x360 Converter"},
    "Profile Pics": {"pt": "Avatar Gamerpics", "en": "Gamerpics", "es": "Gamerpics"},
    "Backup e Restauro": {"pt": "Backup e Restauro", "en": "Backup & Restore", "es": "Copia de Seguridad"},
    "INICIAR CONVERSÃO": {"pt": "INICIAR CONVERSÃO", "en": "START CONVERSION", "es": "INICIAR CONVERSIÓN"},

    // Home Banners
    "Instalação Completa": {"pt": "Instalação Completa", "en": "Full Installation", "es": "Instalación Completa"},
    "Configure seu console do zero com o Wizard guiado.": {"pt": "Configure seu console do zero com o Wizard guiado.", "en": "Setup your console from scratch with a guided wizard.", "es": "Configura tu consola desde cero con un asistente guiado."},
    "Aurora, Freestyle e mais.": {"pt": "Aurora, Freestyle e mais.", "en": "Aurora, Freestyle and more.", "es": "Aurora, Freestyle y más."},
    "Apps essenciais para seu 360.": {"pt": "Apps essenciais para seu 360.", "en": "Essential apps for your 360.", "es": "Apps esenciales para tu 360."},
    "Serviços online e segurança.": {"pt": "Serviços online e segurança.", "en": "Online services and security.", "es": "Servicios online y seguridad."},
    "Expanda as funções do seu console.": {"pt": "Expanda as funções do seu console.", "en": "Expand your console functionalities.", "es": "Expande las funciones de tu consola."},
    "Gerencie DLCs, TUs e Saves com facilidade.": {"pt": "Gerencie DLCs, TUs e Saves com facilidade.", "en": "Manage DLCs, TUs, and Saves with ease.", "es": "Gestiona DLCs, TUs y Saves con facilidad."},
    "Quick Access": {"pt": "Acesso Rápido", "en": "Quick Access", "es": "Acceso Rápido"},
    "BEM-VINDO AO": {"pt": "BEM-VINDO AO", "en": "WELCOME TO", "es": "BIENVENIDO A"},
    "A central definitiva para o seu Xbox 360 no Linux.": {"pt": "A central definitiva para o seu Xbox 360 no Linux.", "en": "The ultimate hub for your Xbox 360 on Linux.", "es": "El centro definitivo para tu Xbox 360 en Linux."},

    // x360 Landscape
    "INJETOR": {"pt": "LANDSCAPE", "en": "LANDSCAPE", "es": "LANDSCAPE"},
    "EXPLORADOR": {"pt": "EXPLORADOR", "en": "EXPLORER", "es": "EXPLORADOR"},
    "Explore e extraia conteúdo do seu dispositivo USB.": {"pt": "Explore e extraia conteúdo do seu dispositivo USB.", "en": "Explore and extract content from your USB device.", "es": "Explora y extrae contenido de tu dispositivo USB."},
    "Injete DLCs, TUs e Saves diretamente no seu Xbox 360.": {"pt": "Gerencie DLCs, TUs e Saves diretamente no seu Xbox 360.", "en": "Manage DLCs, TUs, and Saves directly to your Xbox 360.", "es": "Gestiona DLCs, TUs y Saves directamente en tu Xbox 360."},
    "Clique para selecionar um arquivo STFS": {"pt": "Clique para selecionar um arquivo STFS", "en": "Click to select an STFS file", "es": "Haz clic para seleccionar un arquivo STFS"},
    "OPÇÕES DE INJEÇÃO": {"pt": "OPÇÕES DE GERENCIAMENTO", "en": "MANAGEMENT OPTIONS", "es": "OPCIONES DE GESTIÓN"},
    "Dispositivo Destino:": {"pt": "Dispositivo Destino:", "en": "Target Device:", "es": "Dispositivo de Destino:"},
    "INJETAR NO DISPOSITIVO": {"pt": "TRANSFERIR PARA O DISPOSITIVO", "en": "TRANSFER TO DEVICE", "es": "TRANSFERIR AL DISPOSITIVO"},
    "PACKAGE DETAILS": {"pt": "DETALHES DO PACOTE", "en": "PACKAGE DETAILS", "es": "DETALLES DEL PAQUETE"},
    "Nenhum conteúdo encontrado no dispositivo.": {"pt": "Nenhum conteúdo encontrado no dispositivo.", "en": "No content found on the device.", "es": "No se encontró contenido en el dispositivo."},
    "itens no pacote": {"pt": "itens no pacote", "en": "items in package", "es": "ítems en el paquete"},
    "FECHAR": {"pt": "FECHAR", "en": "CLOSE", "es": "CERRAR"},

    // Settings
    "Utilitários": {"pt": "Utilitários", "en": "Utilities", "es": "Utilidades"},
    "Aparência": {"pt": "Aparência", "en": "Appearance", "es": "Apariencia"},
    "Modo Escuro": {"pt": "Modo Escuro", "en": "Dark Mode", "es": "Modo Oscuro"},
    "Modo Claro": {"pt": "Modo Claro", "en": "Light Mode", "es": "Modo Claro"},
    "Limpar Cache Temporário": {"pt": "Limpar Cache Temporário", "en": "Clear Temporary Cache", "es": "Limpiar Caché Temporal"},
    "Desinstalar x360 Tools": {"pt": "Desinstalar x360 Tools", "en": "Uninstall x360 Tools", "es": "Desinstalar x360 Tools"},
    "Idioma": {"pt": "Idioma", "en": "Language", "es": "Idioma"},

    // Installation Keys
    "Skip XeXMenu": {"pt": "Pular XeXMenu", "en": "Skip XeXMenu", "es": "Omitir XeXMenu"},
    "Skip Rock Band": {"pt": "Pular Rock Band", "en": "Skip Rock Band", "es": "Omitir Rock Band"},
    "Skip Main Files": {"pt": "Pular Arquivos Principais", "en": "Skip Main Files", "es": "Omitir Archivos Principales"},
    "Skip Format": {"pt": "Pular Formatação", "en": "Skip Format", "es": "Omitir Formate"},
    "Install All": {"pt": "Instalar Tudo", "en": "Install All", "es": "Instalar Todo"},
    "Exit On Finish": {"pt": "Fechar ao concluir", "en": "Exit On Finish", "es": "Cerrar al terminar"},

    // Installation View Titles
    "Método de Exploit": {"pt": "Método de Exploit", "en": "Exploit Method", "es": "Método de Exploit"},
    "Patches": {"pt": "Patches", "en": "Patches", "es": "Parches"},
    "Opções de Instalação": {"pt": "Opções de Instalação", "en": "Installation Options", "es": "Opciones de Instalación"},
    "Assistente de Instalação (Iniciantes)": {"pt": "Assistente de Instalação (Iniciantes)", "en": "Installation Wizard (Beginners)", "es": "Asistente de Instalación (Principiantes)"},
    "Iniciar Instalação": {"pt": "Iniciar Instalação", "en": "Start Installation", "es": "Iniciar Instalación"},
    "Atualizar Dispositivos": {"pt": "Atualizar Dispositivos", "en": "Refresh Devices", "es": "Actualizar Dispositivos"},
    "Sair": {"pt": "Sair", "en": "Exit", "es": "Salir"},
    "Aviso: Nenhum dispositivo detectado": {"pt": "Aviso: Nenhum dispositivo detectado", "en": "Warning: No device detected", "es": "Aviso: No se detectó dispositivo"},
    "Status: ": {"pt": "Status: ", "en": "Status: ", "es": "Estado: "},

    // Wizard
    "Dispositivo USB": {"pt": "Dispositivo USB", "en": "USB Device", "es": "Dispositivo USB"},
    "Tipo de Console": {"pt": "Tipo de Console", "en": "Console Type", "es": "Tipo de Consola"},
    "Programas e Dashboards": {"pt": "Programas e Dashboards", "en": "Software & Dashboards", "es": "Software y Dashboards"},
    "Confirmar Instalação": {"pt": "Confirmar Instalação", "en": "Confirm Installation", "es": "Confirmar Instalación"},
    "PRÓXIMO": {"pt": "PRÓXIMO", "en": "NEXT", "es": "SIGUIENTE"},
    "VOLTAR": {"pt": "VOLTAR", "en": "BACK", "es": "ATRÁS"},
    "Onde as ferramentas serão instaladas?": {"pt": "Onde as ferramentas serão instaladas?", "en": "Where will the tools be installed?", "es": "¿Dónde se instalarán las herramientas?"},
    "Pendrive / USB Externo": {"pt": "Pendrive / USB Externo", "en": "USB Drive / External", "es": "USB / Pendrive Externo"},
    "HDD Interno do Xbox": {"pt": "HDD Interno do Xbox", "en": "Internal Xbox HDD", "es": "HDD Interno de Xbox"},
    "Qual o destrave do seu console?": {"pt": "Qual o destrave do seu console?", "en": "What is your console's exploit?", "es": "¿Cuál es el destrave de tu consola?"},
    "RGH / JTAG (Padrão)": {"pt": "RGH / JTAG (Padrão)", "en": "RGH / JTAG (Default)", "es": "RGH / JTAG (Predeterminado)"},
    "LT / Original / Não Sei": {"pt": "LT / Original / Não Sei", "en": "LT / Original / I don't know", "es": "LT / Original / No sé"},

    // Wizard Additional
    "INSTALL WIZARD": {"pt": "ASSISTENTE DE INSTALAÇÃO", "en": "INSTALL WIZARD", "es": "ASISTENTE DE INSTALACIÓN"},
    "Welcome to x360 Tools v2.0": {"pt": "Bem-vindo ao x360 Tools v2.0", "en": "Welcome to x360 Tools v2.0", "es": "Bienvenido a x360 Tools v2.0"},
    "This wizard will guide you through preparing your USB device for your Xbox 360.": {
      "pt": "Este assistente irá guiá-lo na preparação do seu dispositivo USB para o seu Xbox 360.",
      "en": "This wizard will guide you through preparing your USB device for your Xbox 360.",
      "es": "Este asistente le guiará en la preparación de su dispositivo USB para su Xbox 360."
    },
    "Select Target Device": {"pt": "Selecionar Dispositivo de Destino", "en": "Select Target Device", "es": "Seleccionar Dispositivo de Destino"},
    "Formatting will erase all data on the selected device. Make sure you have a backup.": {
      "pt": "A formatação apagará todos os dados no dispositivo selecionado. Certifique-se de ter um backup.",
      "en": "Formatting will erase all data on the selected device. Make sure you have a backup.",
      "es": "El formateo borrará todos los datos en el dispositivo seleccionado. Asegúrese de tener una copia de seguridad."
    },
    "FORMAT FAT32": {"pt": "FORMATAR FAT32", "en": "FORMAT FAT32", "es": "FORMATEAR FAT32"},
    "Console Hardware Type": {"pt": "Tipo de Hardware do Console", "en": "Console Hardware Type", "es": "Tipo de Hardware de la Consola"},
    "Modified hardware that runs unsigned code and homebrew.": {
      "pt": "Hardware modificado que executa código não assinado e homebrews.",
      "en": "Modified hardware that runs unsigned code and homebrew.",
      "es": "Hardware modificado que executa código no firmado y homebrew."
    },
    "Standard or Flash-only console for playing backups from disc.": {
      "pt": "Console original ou apenas com flash para jogar backups via disco.",
      "en": "Standard or Flash-only console for playing backups from disc.",
      "es": "Consola estándar o solo con flash para jugar copias de seguridad desde disco."
    },
    "Select Dashboard": {"pt": "Selecionar Dashboard", "en": "Select Dashboard", "es": "Seleccionar Dashboard"},
    "Dashboard Interface": {"pt": "Interface de Sistema", "en": "Dashboard Interface", "es": "Interfaz de Sistema"},
    "Additional Software": {"pt": "Softwares Adicionais", "en": "Additional Software", "es": "Software Adicional"},
    "Stealth Servers": {"pt": "Servidores Stealth", "en": "Stealth Servers", "es": "Servidores Stealth"},
    "System Plugins": {"pt": "Plugins de Sistema", "en": "System Plugins", "es": "Plugins de Sistema"},
    "Installation Summary": {"pt": "Resumo da Instalação", "en": "Installation Summary", "es": "Resumen de la Instalación"},
    "Packages to Install:": {"pt": "Pacotes para Instalar:", "en": "Packages to Install:", "es": "Paquetes a Instalar:"},
    "INSTALL NOW": {"pt": "INSTALAR AGORA", "en": "INSTALL NOW", "es": "INSTALAR AHORA"},
    "CONTINUE": {"pt": "CONTINUAR", "en": "CONTINUE", "es": "CONTINUAR"},
    "BACK": {"pt": "VOLTAR", "en": "BACK", "es": "ATRÁS"},
    "of": {"pt": "de", "en": "of", "es": "de"},
    "Step": {"pt": "Passo", "en": "Step", "es": "Paso"},

    // Dashboards
    "Dashboards / Launchers": {"pt": "Dashboards / Launchers", "en": "Dashboards / Launchers", "es": "Dashboards / Launchers"},
    "* XeXMenu 1.2 is installed by default": {"pt": "* XeXMenu 1.2 é instalado por padrão", "en": "* XeXMenu 1.2 is installed by default", "es": "* XeXMenu 1.2 se instala por defecto"},

    // Homebrew
    "Homebrew Applications": {"pt": "Aplicativos Homebrew", "en": "Homebrew Applications", "es": "Aplicaciones Homebrew"},

    // Stealth
    "Stealth Networks": {"pt": "Redes Stealth", "en": "Stealth Networks", "es": "Redes Stealth"},

    // Plugins
    "Plugins (Extended)": {"pt": "Plugins (Extras)", "en": "Plugins (Extended)", "es": "Plugins (Extras)"},
    "Console Specific Files": {"pt": "Arquivos da Memória Xbox", "en": "Console Specific Files", "es": "Archivos de la Consola"},
    "Customization": {"pt": "Personalização (Boot)", "en": "Customization", "es": "Personalización"},
    "Backwards Compatibility": {"pt": "Retrocompatibilidade", "en": "Backwards Compatibility", "es": "Retrocompatibilidad"},
    "x360 Tools Utilities": {"pt": "Utilitários do x360 Tools", "en": "x360 Tools Utilities", "es": "Utilidades de x360 Tools"},
    "Wipe Temp Data": {"pt": "Limpar Cache Temporário", "en": "Wipe Temp Data", "es": "Limpiar Cache Temporal"},
    "Delete x360 Tools": {"pt": "Desinstalar x360 Tools", "en": "Delete x360 Tools", "es": "Desinstalar x360 Tools"},
    "Appearance": {"pt": "Aparência", "en": "Appearance", "es": "Apariencia"},
    "🌙 Dark Mode": {"pt": "🌙 Modo Escuro", "en": "🌙 Dark Mode", "es": "🌙 Modo Oscuro"},
    "☀️ Light Mode": {"pt": "☀️ Modo Claro", "en": "☀️ Light Mode", "es": "☀️ Modo Claro"},
    "Nenhum item selecionado.": {"pt": "Nenhum item selecionado.", "en": "No items selected.", "es": "Ningún ítem seleccionado."},
    "Concluído.": {"pt": "Concluído.", "en": "Completed.", "es": "Completado."},

    // Descriptions - Dashboards
    "Aurora_desc": {"pt": "Dashboard moderna com capas e filtros.", "en": "Modern dashboard with covers and filters.", "es": "Dashboard moderna con carátulas y filtros."},
    "Freestyle_desc": {"pt": "A clássica FSD3, estável e funcional.", "en": "Classic FSD3, stable and functional.", "es": "La clásica FSD3, estable y funcional."},
    "Emerald_desc": {"pt": "Dashboard leve inspirada no Xbox original.", "en": "Lightweight dashboard inspired by original Xbox.", "es": "Dashboard ligera inspirada en el Xbox original."},
    "Viper360_desc": {"pt": "Interface alternativa com foco em velocidade.", "en": "Alternative interface focused on speed.", "es": "Interfaz alternativa centrada en la velocidad."},
    "XeXMenu_desc": {"pt": "Gerenciador de arquivos essencial.", "en": "Essential file manager.", "es": "Gestor de archivos esencial."},

    // Descriptions - Homebrew
    "Dashlauncher_desc": {"pt": "Configura inicialização e plugins.", "en": "Configure boot settings and plugins.", "es": "Configura el inicio y los plugins."},
    "FFPlay_desc": {"pt": "Player de vídeo para diversos formatos.", "en": "Video player for various formats.", "es": "Reproductor de video para varios formatos."},
    "XM360_desc": {"pt": "Gerencie DLCs e conteúdos XBLA.", "en": "Manage DLCs and XBLA content.", "es": "Gestiona DLCs y contenido XBLA."},
    "HDDx.Fixer_desc": {"pt": "Restaura a partição HDDx oficial.", "en": "Restores the official HDDx partition.", "es": "Restaura la partición HDDx oficial."},

    // Descriptions - Stealth
    "CipherLive_desc": {"pt": "Servidor Stealth premium e estável.", "en": "Premium and stable stealth server.", "es": "Servidor stealth premium y estable."},
    "xbGuard_desc": {"pt": "Proteção e funções online avançadas.", "en": "Advanced online protection and features.", "es": "Protección y funciones online avanzadas."},
    "Proto_desc": {"pt": "Servidor Stealth gratuito e eficiente.", "en": "Free and efficient stealth server.", "es": "Servidor stealth gratuito y eficiente."},

    // Descriptions - Plugins
    "Plugins e Outros_desc": {"pt": "Pacote base de plugins essenciais.", "en": "Base pack of essential plugins.", "es": "Paquete base de plugins esenciales."},
    "xbPIrate_desc": {"pt": "Melhorias de sistema e carregamento.", "en": "System enhancements and loading tweaks.", "es": "Mejoras de sistema y optimizaciones de carga."},
    "hiddriver360_desc": {"pt": "Suporte a controles USB genéricos.", "en": "Support for generic USB controllers.", "es": "Soporte para controles USB genéricos."},
    "HvP2_desc": {"pt": "Plugin de baixo nível para sistema.", "en": "Low-level system plugin.", "es": "Plugin de sistema de bajo nivel."},

    // Descriptions - Customization
    "X Notify.Pack_desc": {"pt": "Temas para avisos do sistema.", "en": "Themes for system notifications.", "es": "Temas para avisos del sistema."},
    "FakeAnim_desc": {"pt": "Animações de boot customizadas.", "en": "Custom boot animations.", "es": "Animaciones de inicio personalizadas."},
    "Boot.Animations_desc": {"pt": "Diversas animações de inicialização.", "en": "Various boot animations.", "es": "Diversas animaciones de inicio."},

    // Descriptions - Backcompat
    "Hacked.Compatibility.Files_desc": {"pt": "Roda mais jogos de Xbox Original.", "en": "Runs more Original Xbox games.", "es": "Ejecuta más juegos de Xbox Original."},
    "Original.Compatibility.Files_desc": {"pt": "Arquivos oficiais da Microsoft.", "en": "Official Microsoft files.", "es": "Archivos oficiales de Microsoft."},
    "Xbox.One.Files_desc": {"pt": "Suporte a controles de Xbox One.", "en": "Support for Xbox One controllers.", "es": "Soporte para controles de Xbox One."},
    "XEFU.Spoofer_desc": {"pt": "Emulador de hardware do console.", "en": "Console hardware emulator.", "es": "Emulador de hardware de consola."},
    "Procurar Herois": {"pt": "Procurar Heróis...", "en": "Search Heroes...", "es": "Buscar Héroes..."},
    "Injetando": {"pt": "Injetando", "en": "Injecting", "es": "Inyectando"},
    "Gamerpic injetada com sucesso!": {"pt": "Gamerpic injetada com sucesso!", "en": "Gamerpic injected successfully!", "es": "¡Gamerpic inyectada con éxito!"},
    "Selecione um heroi para injetar no seu dispositivo.": {"pt": "Selecione um herói para injetar no seu dispositivo.", "en": "Select a hero to inject into your device.", "es": "Selecciona un héroe para inyectar en tu dispositivo."},
    "Injetar": {"pt": "Injetar", "en": "Inject", "es": "Inyectar"},

    // Freemarket & Technical Sheet
    "FICHA TÉCNICA": {"pt": "FICHA TÉCNICA", "en": "TECHNICAL SHEET", "es": "FICHA TÉCNICA"},
    "DESENVOLVEDOR": {"pt": "DESENVOLVEDOR", "en": "DEVELOPER", "es": "DESARROLLADOR"},
    "DISTRIBUIDORA": {"pt": "DISTRIBUIDORA", "en": "PUBLISHER", "es": "DISTRIBUIDORA"},
    "GÊNERO": {"pt": "GÊNERO", "en": "GENRE", "es": "GÉNERO"},
    "LANÇAMENTO": {"pt": "LANÇAMENTO", "en": "RELEASE", "es": "LANZAMIENTO"},
    "TITLE ID": {"pt": "TITLE ID", "en": "TITLE ID", "es": "TITLE ID"},
    "TITLE UPDATES": {"pt": "TITLE UPDATES", "en": "TITLE UPDATES", "es": "TITLE UPDATES"},
    "BAIXAR": {"pt": "BAIXAR", "en": "DOWNLOAD", "es": "DESCARGAR"},
    "SINOPSE": {"pt": "SINOPSE", "en": "SYNOPSIS", "es": "SINOPSIS"},
    "Nenhuma sinopse disponível.": {"pt": "Nenhuma sinopse disponível.", "en": "No synopsis available.", "es": "No hay sinopsis disponible."},
    "Busca Profunda": {"pt": "Busca Profunda", "en": "Deep Search", "es": "Búsqueda Profunda"},
    "Atualizar Catálogo": {"pt": "Atualizar Catálogo", "en": "Update Catalog", "es": "Actualizar Catálogo"},
    "Filtrar por nome...": {"pt": "Filtrar por nome...", "en": "Filter by name...", "es": "Filtrar por nombre..."},
    "Arquivos": {"pt": "Arquivos", "en": "Files", "es": "Archivos"},
    "Tamanho": {"pt": "Tamanho", "en": "Size", "es": "Tamaño"},
    "Aguardando...": {"pt": "Aguardando...", "en": "Waiting...", "es": "Esperando..."},
    "Instalado": {"pt": "Instalado", "en": "Installed", "es": "Instalado"},
    "Falha": {"pt": "Falha", "en": "Failed", "es": "Fallo"},
    "Cancelado": {"pt": "Cancelado", "en": "Canceled", "es": "Cancelado"},
    "Extraindo...": {"pt": "Extraindo...", "en": "Extracting...", "es": "Extrayendo..."},
    "Convertendo...": {"pt": "Convertendo...", "en": "Converting...", "es": "Convirtiendo..."},
    "Instalando...": {"pt": "Instalando...", "en": "Installing...", "es": "Instalando..."},
    "Espaço insuficiente!": {"pt": "Espaço insuficiente!", "en": "Insufficient space!", "es": "¡Espacio insuficiente!"},
    "Modo Offline": {"pt": "Modo Offline", "en": "Offline Mode", "es": "Modo Offline"},
    "Vincular ao Dispositivo": {"pt": "Vincular ao Dispositivo", "en": "Bind to Device", "es": "Vincular al Dispositivo"},
    "Avaliação": {"pt": "Avaliação", "en": "Rating", "es": "Calificación"},
    "ORIGEM": {"pt": "ORIGEM", "en": "SOURCE", "es": "ORIGEN"},
    "Xbox 360 Library": {"pt": "Biblioteca Xbox 360", "en": "Xbox 360 Library", "es": "Biblioteca Xbox 360"},
    "Xbox Classic Library": {"pt": "Biblioteca Xbox Classic", "en": "Xbox Classic Library", "es": "Biblioteca Xbox Classic"},
    "Original Xbox": {"pt": "Xbox Original", "en": "Original Xbox", "es": "Xbox Original"},
    "Xbox 360": {"pt": "Xbox 360", "en": "Xbox 360", "es": "Xbox 360"},
  };

  static String tr(String key, String lang) {
    String code = "pt";
    if (lang == "English") code = "en";
    if (lang == "Español") code = "es";
    
    if (strings.containsKey(key)) {
      return strings[key]![code] ?? key;
    }
    return key;
  }
}
