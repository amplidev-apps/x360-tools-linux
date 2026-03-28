# x360 Tools for Linux v2.0 🎮

[English](#english) | [Português](#português) | [Español](#español)

---

<a name="english"></a>
## 🇬🇧 English: The Ultimate Xbox 360 Ecosystem for Linux

**x360 Tools for Linux** is not just a tool — it's a complete ecosystem for the modern Xbox 360 and Xbox Classic enthusiast. Built with a stunning **Flutter v2.0** interface and a high-performance **Python asynchronous engine**, it delivers the most professional console management experience available on Linux.

---

### 🌟 Exclusive Features & Highlights

#### 🛒 x360 Freemarket (The World's Biggest Xbox Catalog)
*   **10,000+ Items Available**: A unified catalog aggregating over 14 Internet Archive metadata databases.
*   **Hype-Level Library**: Thousands of Full Games, DLCs, and Title Updates ready for instant, automated deployment.
*   **Smart Ingestion**: High-speed SQLite indexing ensures zero-lag searching even within the massive catalog.
*   **Offline-First Game Metadata**: A pre-loaded local database containing synopses, genres, release dates, developers, publishers, ratings, and Title IDs — fetched without any internet connection.
*   **Offline Game Covers**: Over **1,000+ game cover images** bundled directly in the app's `assets/gamecovers/` directory, sourced from the open-source x360db (Xenia) project.
*   **Full Technical Sheet (`FICHA TÉCNICA`)**: Every game shows a detailed panel with System, Region, Genre, Release Date, Developer, Publisher, and Title ID.
*   **Title Updates (TU) Browser**: All available TUs for each game are listed inside the game page for direct download.
*   **DLC Manager**: Integrated DLC listing and installation within each game's detail page.
*   **Region/Version Selector**: Multi-region builds (NTSC-U, PAL, NTSC-J) are selectable directly from the game detail view.

#### 🌍 100% Localization System (NEW)
*   **3 Languages**: Full UI localization in **Portuguese 🇧🇷**, **English 🇬🇧**, and **Spanish 🇪🇸**.
*   **Dynamic Synopsis Translation**: Game descriptions are automatically translated to the user's preferred language using an AI-powered translation engine (`deep-translator`).
*   **Automatic Language Detection**: The system detects the source language (including Japanese 🇯🇵) and translates on-the-fly.
*   **Offline-First Translations**: UI strings are stored in a static lookup table (`TranslationService`) — no internet required.
*   **Backend Propagation**: The Flutter frontend sends the language preference via CLI argument to the Python backend (`--lang pt/en/es`), which returns pre-translated metadata.

#### 🛡️ Advanced Backup System (Exclusive `.x360b` Format)
*   **Complete Device Imaging**: Unlike simple file copying, the `.x360b` engine captures the entire device structure (Content, Games, Profiles).
*   **High-Ratio Compression**: Uses advanced algorithms to shrink partition images.
*   **Smart Metadata Embedding**: Includes original device label, date, and Title IDs inside a single portable package.
*   **Automated Recovery Flow**: Handles low-level FAT32 formatting with Xbox 360-native cluster size precision.
*   **Label Management**: Rename your device during restore for easy organization.

#### 🏞️ x360 Landscape (STFS & Identity)
*   **Gamerpic Injection**: Access thousands of Original and Custom Gamerpics for your profile.
*   **STFS Powerhouse**: Manage DLCs, Arcade Games, and Title Updates with simple drag-and-drop.
*   **Saves Management**: Backup and transfer your save files.

#### ⚡ Advanced Download Manager
*   **Multi-Phase Engine**: `Downloading` → `Extracting` → `Converting` → `Installing`
*   **Concurrent Operations**: Fast, stable, multi-threaded operations.

#### 🔄 x360 Converter & Wizard
*   **ISO to GOD (Games on Demand)**: The gold standard for RGH/JTAG users.
*   **Xbox Classic Legacy**: Automated extraction and conversion for original Xbox games.
*   **The Wizard**: Guided setup from FAT32 formatting to Aurora/FSD dashboard deploy in minutes.

#### 📚 Local Library Manager (Scanner & Grid)
*   **Automatic Drive Scanning**: Instantly identifies Xbox 360 GOD games, Xbox Classic titles, Title Updates, and DLCs installed on your external drives.
*   **STFS Identity Extraction**: Automatically extracts official game names and high-quality icons directly from the STFS metadata.
*   **Smart Categorization**: Organizes your local library into separate tabs for Games, DLCs, and Updates.
*   **Missing Cover Fallback**: Uses a default high-quality cover for games without embedded icons to maintain visual consistency.

#### ⚙️ DashLaunch Pro Editor
*   **Visual INI Configuration**: Edit `launch.ini` without any text editors via a premium, responsive interface.
*   **Network Patches**: Toggle `pingpatch`, `liveblock`, `livestrong`, and other DashLaunch options with simple switches.
*   **Boot Path Management**: Easily configure your default dashboard boot path (e.g., Aurora).
*   **RGH Templates**: Automatically generates an optimized `launch.ini` template if a USB drive does not have one.

---

### 🚀 Installation & Running

#### Prerequisites
- **Git**
- **Python 3.10+** with pip packages: `requests`, `deep-translator`
- **Flutter SDK** (must be installed in `~/flutter_sdk`)

#### Setup
```bash
# Clone the repository
gh repo clone amplidev-apps/x360-tools-linux
cd "x360 Tools"

# Install Python dependencies
pip install deep-translator requests

# Run the Flutter Premium UI
./run_flutter.sh

# Or run the legacy GTK3 Interface
./run.sh
```

### 🛠️ Technical Architecture
*   **UI/UX**: Premium **Segoe UI** typography with a bespoke Xbox-inspired dark theme and micro-animations.
*   **Architecture**: Decoupled Python/Flutter bridge (`service_bridge.py`) for maximum stability.
*   **Database**: SQLite WAL mode for zero-conflict concurrent reads during catalog browsing.
*   **Cover System**: Local asset lookup with async URL fallback (`AsyncCoverImage`).
*   **Translation Pipeline**: `AppState (lang) → PythonBridge (--lang) → MetadataService → deep-translator → Flutter UI`

---

<a name="português"></a>
## 🇧🇷 Português: O Ecossistema Definitivo para Xbox 360 no Linux

O **x360 Tools for Linux** não é apenas uma ferramenta — é um ecossistema completo para o entusiasta moderno de Xbox 360 e Xbox Clássico. Desenvolvido com uma interface **Flutter v2.0** deslumbrante e um motor **Python assíncrono**, é a solução mais profissional para gestão de console disponível no Linux.

---

### 🌟 Funcionalidades Exclusivas e Novidades

#### 🛒 x360 Freemarket (O Maior Catálogo do Mundo)
*   **Mais de 10.000 Itens**: Catálogo unificado com metadados de 14 bases de dados do Internet Archive.
*   **Biblioteca Gigante**: Jogos Completos, DLCs e Title Updates prontos para instalação automática.
*   **Busca SQLite**: Indexação de alta velocidade com pesquisa instantânea.
*   **Fichas Técnicas Offline**: Banco de dados local pré-carregado com sinopses, gêneros, datas, desenvolvedoras, publicadoras, avaliações e Title IDs — sem precisar de internet.
*   **Capas Offline**: Mais de **1.000 capas de jogos** embutidas diretamente nos assets do app (`assets/gamecovers/`), obtidas do projeto open-source x360db.
*   **Ficha Técnica Completa**: Painel com Sistema, Região, Gênero, Lançamento, Desenvolvedor, Distribuidora e Title ID.
*   **Navegador de Title Updates (TU)**: Todos os TUs disponíveis de cada jogo listados para download direto.
*   **Gerenciador de DLCs**: Listagem e instalação de DLCs integradas na página de cada jogo.
*   **Seletor de Região/Versão**: Múltiplas versões regionais (NTSC-U, PAL, NTSC-J) selecionáveis diretamente na ficha do jogo.

#### 🌍 Sistema de Localização 100% (NOVO)
*   **3 Idiomas**: Localização completa em **Português 🇧🇷**, **Inglês 🇬🇧** e **Espanhol 🇪🇸**.
*   **Tradução Dinâmica de Sinopses**: As descrições dos jogos são traduzidas automaticamente para o idioma preferido do usuário usando o motor `deep-translator`.
*   **Detecção Automática de Idioma**: O sistema detecta o idioma original (inclusive japonês 🇯🇵) e traduz em tempo real.
*   **Traduções Offline-First**: Strings de interface armazenadas em tabela estática (`TranslationService`) — sem internet necessária.
*   **Propagação pelo Backend**: O frontend Flutter envia a preferência de idioma via argumento CLI (`--lang pt/en/es`) ao backend Python.

#### 🛡️ Sistema de Backup Avançado (Formato Exclusivo `.x360b`)
*   **Imagem Completa do Dispositivo**: Captura toda a estrutura (Content, Games, Perfis).
*   **Alta Compressão**: Algoritmos avançados para backups portáteis e gerenciáveis.
*   **Metadados Inteligentes**: Inclui rótulo, data e Title IDs em um único pacote.
*   **Recuperação Automatizada**: Formatação FAT32 com precisão de cluster nativo do Xbox 360.
*   **Gestão de Rótulos**: Renomeie o dispositivo durante a restauração.

#### 🏞️ x360 Landscape (STFS & Identidade)
*   **Injeção de Gamerpics**: Acesse milhares de fotos de perfil originais e customizadas.
*   **Poder STFS**: Gerencie DLCs, Jogos Arcade e TUs com facilidade.
*   **Gestão de Saves**: Faça backup e transfira seu progresso.

#### ⚡ Gerenciador de Downloads Avançado
*   **Motor Multi-Fase**: `Baixando` → `Extraindo` → `Convertendo` → `Instalando`
*   **Operações Simultâneas**: Rápido e multi-threaded.

#### 🔄 x360 Converter & Assistente (Wizard)
*   **ISO para GOD**: Padrão ouro para usuários de RGH/JTAG.
*   **Legado Xbox Clássico**: Conversão automatizada para jogos do Xbox original.
*   **O Wizard**: Configuração guiada do zero ao play.


#### 📚 Gestor de Biblioteca Local (Scanner & Grid)
*   **Varredura Automática**: Identifica instantaneamente jogos Xbox 360 GOD, Xbox Clássico, Title Updates e DLCs instalados no seu pen drive/HD.
*   **Extração STFS**: Recupera automaticamente os nomes oficiais e ícones de alta qualidade diretamente dos metadados STFS.
*   **Categorização Inteligente**: Organiza sua biblioteca local em abas separadas para Jogos, DLCs e Updates.
*   **Capas Padrão**: Utiliza uma capa padrão de alta qualidade para jogos sem ícone interno, mantendo a consistência visual.

#### ⚙️ DashLaunch Pro Editor
*   **Configuração Visual de INI**: Edite o `launch.ini` sem editores de texto, usando uma interface premium e responsiva.
*   **Patches de Rede**: Ligue e desligue `pingpatch`, `liveblock`, `livestrong` e outros com um simples clique.
*   **Gestão de Boot**: Configure facilmente o caminho de inicialização padrão (ex: Aurora).
*   **Templates RGH**: Gera um template otimizado de `launch.ini` automaticamente caso o dispositivo não possua um.

---

### 🚀 Instalação e Execução

#### Pré-requisitos
- **Git**
- **Python 3.10+** com pacotes pip: `requests`, `deep-translator`
- **Flutter SDK** (instalado em `~/flutter_sdk`)

#### Setup
```bash
# Clonar o repositório
gh repo clone amplidev-apps/x360-tools-linux
cd "x360 Tools"

# Instalar dependências Python
pip install deep-translator requests

# Iniciar a Interface Premium em Flutter
./run_flutter.sh

# Ou iniciar a Interface Nativa em GTK3
./run.sh
```

### 🛠️ Arquitetura Técnica
*   **UI/UX**: Tipografia **Segoe UI** premium com tema escuro inspirado no Xbox e micro-animações.
*   **Arquitetura**: Bridge Python/Flutter desacoplada (`service_bridge.py`) para máxima estabilidade.
*   **Banco de Dados**: SQLite no modo WAL para leituras concorrentes sem conflito.
*   **Sistema de Capas**: Busca local em assets com fallback assíncrono de URL (`AsyncCoverImage`).
*   **Pipeline de Tradução**: `AppState (idioma) → PythonBridge (--lang) → MetadataService → deep-translator → UI Flutter`

---

<a name="español"></a>
## 🇪🇸 Español: El Ecosistema Definitivo para Xbox 360 en Linux

**x360 Tools for Linux** no es solo una herramienta — es un ecosistema completo para el entusiasta moderno de Xbox 360 y Xbox Clásico. Construido con una impresionante interfaz **Flutter v2.0** y un motor **Python asíncrono**, ofrece la experiencia de gestión de consolas más profesional en Linux.

---

### 🌟 Características Exclusivas y Destacadas

#### 🛒 x360 Freemarket (El Mayor Catálogo del Mundo)
*   **Más de 10,000 ítems disponibles**: Catálogo unificado con metadatos de 14 bases de datos de Internet Archive.
*   **Biblioteca Masiva**: Juegos completos, DLC y Title Updates listos para implementación automatizada.
*   **Búsqueda SQLite**: Indexación ultrarrápida sin lag incluso en catálogos gigantes.
*   **Fichas Técnicas Offline**: Base de datos local con sinopsis, géneros, fechas de lanzamiento, desarrolladores, editores, calificaciones y Title IDs — sin conexión a internet.
*   **Portadas Offline**: Más de **1,000 portadas de juegos** incluidas en los assets (`assets/gamecovers/`), del proyecto open-source x360db.
*   **Ficha Técnica Completa**: Panel con Sistema, Región, Género, Lanzamiento, Desarrollador, Distribuidora y Title ID.
*   **Explorador de Title Updates (TU)**: Todos los TU disponibles se listan para descarga directa.
*   **Gestor de DLCs**: Listado e instalación de DLC integrados en la página de cada juego.
*   **Selector de Región/Versión**: Múltiples versiones regionales (NTSC-U, PAL, NTSC-J) disponibles desde la ficha del juego.

#### 🌍 Sistema de Localización 100% (NUEVO)
*   **3 Idiomas**: Localización completa en **Portugués 🇧🇷**, **Inglés 🇬🇧** y **Español 🇪🇸**.
*   **Traducción Dinámica de Sinopsis**: Las descripciones de los juegos se traducen automáticamente al idioma preferido del usuario usando `deep-translator`.
*   **Detección Automática de Idioma**: El sistema detecta el idioma fuente (incluso japonés 🇯🇵) y traduce en tiempo real.
*   **Traducciones Offline-First**: Cadenas de interfaz almacenadas en tabla estática (`TranslationService`) — sin internet requerido.
*   **Propagación por Backend**: El frontend Flutter envía la preferencia de idioma vía argumento CLI (`--lang pt/en/es`) al backend Python.

#### 🛡️ Sistema de Backup Avanzado (Formato Exclusivo `.x360b`)
*   **Imagen Completa del Dispositivo**: Captura toda la estructura (Content, Games, Perfiles).
*   **Alta Compresión**: Algoritmos avanzados para backups portátiles.
*   **Metadatos Inteligentes**: Incluye etiqueta, fecha y Title IDs en un solo paquete.
*   **Recuperación Automatizada**: Formato FAT32 con precisión de cluster nativo del Xbox 360.
*   **Gestión de Etiquetas**: Renombra el dispositivo durante la restauración.

#### 🏞️ x360 Landscape (STFS & Identidad)
*   **Inyección de Gamerpics**: Accede a miles de imágenes de jugador originales y personalizadas.
*   **Potencia STFS**: Gestiona DLC, Arcade y TU con facilidad.
*   **Gestor de Partidas**: Respalda y transfiere tu progreso.

#### 📚 Gestor de Biblioteca Local (Escáner y Cuadrícula)
*   **Escaneo Automático**: Identifica instantáneamente juegos Xbox 360 GOD, Xbox Clásico, Title Updates y DLCs instalados en tus unidades.
*   **Extracción STFS**: Recupera nombres oficiales e íconos de alta calidad directamente de los metadatos STFS.
*   **Categorización Inteligente**: Organiza tu biblioteca local en pestañas separadas para Juegos, DLCs y Actualizaciones.
*   **Portadas Predeterminadas**: Utiliza una portada predeterminada de alta calidad para juegos sin ícono, manteniendo la consistencia visual.

#### ⚙️ DashLaunch Pro Editor
*   **Configuración Visual de INI**: Edita el `launch.ini` sin editores de texto, usando una interfaz premium y receptiva.
*   **Parches de Red**: Activa `pingpatch`, `liveblock`, `livestrong` y otras configuraciones con interruptores simples.
*   **Gestión de Arranque**: Configura fácilmente tu ruta de inicio predeterminada (ej. Aurora).
*   **Plantillas RGH**: Genera automáticamente una plantilla `launch.ini` optimizada si la unidad USB no tiene una.

### 🚀 Instalación y Ejecución

#### Requisitos
- **Git**
- **Python 3.10+** con paquetes pip: `requests`, `deep-translator`
- **Flutter SDK** (instalado en `~/flutter_sdk`)

#### Setup
```bash
# Clonar el repositorio
gh repo clone amplidev-apps/x360-tools-linux
cd "x360 Tools"

# Instalar dependencias Python
pip install deep-translator requests

# Iniciar la interfaz Premium en Flutter
./run_flutter.sh

# O iniciar la interfaz original GTK3
./run.sh
```

---
**x360 Tools** - *Powered by Linux, Designed for Xbox Legends.* 🎮🟩
