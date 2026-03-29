# x360 Tools for Linux — v2.0 🎮🟩

> **The Ultimate Xbox 360 Ecosystem for Linux** | Interface Flutter v2.0 × Motor Python Assíncrono

[🇬🇧 English](#english) | [🇧🇷 Português](#português) | [🇪🇸 Español](#español)

---

<a name="english"></a>
## 🇬🇧 English

### What is x360 Tools for Linux?

**x360 Tools for Linux** is a fully-featured, professional-grade desktop application built specifically for Linux users who own a softmodded (RGH/JTAG/LT) Xbox 360. It is not a single-purpose utility — it is a **complete management ecosystem** covering everything from game discovery, downloading, and installation, to dashboard configuration, game cover management, FTP wireless access, save file handling, and system backup.

The application is built with a **Flutter v2.0** frontend that communicates with a high-performance, asynchronous **Python 3** backend via a structured CLI bridge (`service_bridge.py`). This architecture guarantees maximum UI responsiveness — the interface never freezes, even during large downloads or intensive I/O operations.

---

### 🌟 Complete Feature Reference

---

#### 🛒 x360 Freemarket — The World's Biggest Xbox 360 Store

The **x360 Freemarket** is the flagship feature of the application. It provides a fully automated, legal game download and installation pipeline backed by the Internet Archive's vast public library.

**Catalog Engine:**
- Aggregates metadata from **14 dedicated Internet Archive databases**, covering Xbox 360 full games, Xbox Classic games, DLCs, and Add-ons.
- All catalog metadata is ingested via a high-performance, multi-threaded **SQLite ingestion engine** that stores data in local `.sqlite` databases. Browsing the catalog requires zero internet — the catalog is pre-loaded.
- The installed SQLite databases total thousands of entries covering the complete PAL, NTSC-U, NTSC-J, and Region-Free release libraries.
- First-launch ingestion is performed automatically via the `FreemarketEngine` class in `core/freemarket.py`, which queries each database and builds an optimized, deduplicated game list.

**Catalog UI — The Store Front:**
- The default view presents a **mosaic-style hero section** with featured games followed by a **5-column responsive grid** of the entire catalog.
- Each game card shows the official box art cover (local asset or async URL fetch), title, platform badge, and star rating.
- A **real-time search bar** filters the entire catalog instantly using SQLite FTS (Full Text Search) — results update as you type without any lag.
- A **refresh button** allows the user to force re-ingestion of the catalog databases at any time.

**Game Detail Page — `FICHA TÉCNICA`:**
Clicking any game opens a full-detail view displaying:
- **High-resolution box art** from the local assets directory (`assets/gamecovers/`) or fallback URL.
- **Star rating** (sourced from the metadata database).
- **Technical Sheet** including: System (Xbox 360 / Xbox Classic), Region (NTSC-U / PAL / NTSC-J / Region-Free), Genre, Release Date, Developer, Publisher, and **Title ID** (the 8-character hex identifier used by the Xbox 360 filesystem).
- **Synopsys / Description** (translated dynamically to the user's language).
- **Region/Version Selector**: If multiple regional builds exist (e.g., NTSC-U, PAL, NTSC-J), they appear as selectable pills — choosing a region updates the download URL to the matching regional file.

**Title Updates (TU) Browser:**
- All known Title Updates for a game are listed inside its detail page.
- Each TU entry shows its version number and a direct **download button**.
- Downloaded TUs are placed automatically in the correct Xbox 360 path: `Content/0000000000000000/<TitleID>/000B0000/`.

**DLC Manager:**
- All known DLCs associated with a game are listed inside its detail page under "DLCs & Conteúdos Adicionais".
- Each DLC entry has an **"INSTALAR DLC"** button.
- DLCs from the Internet Archive catalog are matched to their parent game using the `base_game_name` field derived from the filename (e.g., `Naughty Bear - Panic in Paradise - BatBear Costume (World) (Addon)` → base: `Naughty Bear`).
- Installed DLCs are written to the correct Xbox 360 path: `Content/0000000000000000/<TitleID>/00000002/`.
- **Title ID Resolution**: The system uses a multi-level TitleID resolver: first checks the parent game's detail (`search_unity_by_name`), then falls back to `fast_batch_lookup` for games where the primary resolver returns "Desconhecido", ensuring correct installation even for games with incomplete metadata coverage.

**Game Download & Installation Flow:**
1. User clicks **"INSTALAR"** on a game.
2. The app switches automatically to the **Downloads tab**.
3. A **SnackBar notification** confirms the download has started.
4. The `FreemarketEngine` downloads the file (multi-threaded, up to 32 parallel connections) from the Internet Archive.
5. **Login Detection**: After download, the engine scans the first 1KB of the file — if it detects an HTML/login page redirect (common when the IA session expires), it alerts the user and deletes the corrupted file.
6. The downloaded archive (`.zip`, `.rar`, `.7z`, `.iso`) is automatically extracted.
7. The extracted content is converted to **GOD (Games on Demand)** format via `god_utils`.
8. The GOD package is moved to the correct device path: `<mount>/Content/0000000000000000/<TitleID>/00007000/`.
9. The UI transitions to `DownloadPhase.completed` and the game appears in **Minha Biblioteca**.

---

#### ⬇️ Download Manager — Advanced Multi-Phase Engine

The Download Manager (`GERENCIADOR DE DOWNLOADS`) is a persistent panel that tracks all active and completed operations.

**Download Phases:**
Each download item progresses through clearly labeled phases, each with a distinct color indicator:
- 🔵 `Baixando` — HTTP multi-threaded download in progress.
- 🟡 `Extraindo` — Archive extraction (zip/rar/7z).
- 🟠 `Convertendo` — GOD conversion (iso → GOD package).
- 🟢 `Instalando` — Moving files to the target device directory.
- ✅ `Concluído` — Installation complete, local path is stored.
- ❌ `Falha` — An error occurred; the exact failure reason is displayed in the UI (e.g., "Falha: 503 Server Error: Service Unavailable").

**Progress Bar & Stats:**
- Real-time progress percentage (0–100%).
- Current download speed in MB/s.
- ETA (estimated time remaining) in `MM:SS` format.

**Controls:**
- **"Limpar Concluídos"** button removes all completed entries from the list.
- Individual items can be **canceled** via a long-press or context action.

**Notification on Start:**
When a new download is initiated (game, DLC, or TU), a styled green **SnackBar** notification appears instantly, confirming the download name and auto-switching the view to the Downloads tab.

---

#### 📚 Minha Biblioteca — Local Library Scanner

The **Minha Biblioteca** tab provides a real-time local library of everything installed on the connected device.

- **Automatic Drive Scanner**: When a USB drive/HDD is selected, the library scanner traverses the device's `Content/` directory tree and detects Xbox 360 GOD packages, Xbox Classic titles, Title Updates, and DLCs.
- **STFS Metadata Extraction**: For each detected GOD package, the engine reads the STFS container header to extract the official game name, title ID, and embedded thumbnail icon.
- **Smart Categorization**: Detected items are organized into separate visual tabs: **Jogos**, **DLCs**, and **Updates**.
- **Cover Display**: Icons extracted from STFS headers are displayed as cover art. If no icon is present, a graceful default cover (`4B4D07E2.jpg`) is used.
- **Open Folder**: Each game entry has an "Abrir Pasta" button that opens the system file manager at the game's install directory.

---

#### 🎛️ Dashboards — Aurora & FSD3 Preview & Setup

The **Dashboards** tab is the command center for configuring the console's custom dashboard software.

- **Visual Preview**: Two large preview images are displayed — one for **Aurora** (the most popular modern RGH dashboard) and one for **FSD3 (Freestyle Dash 3)** — giving the user a visual reference before choosing.
- **Automated Dashboard Installation**: Both Aurora and FSD3 can be downloaded and installed directly to the connected device. The engine places the dashboard in the correct path (`Hdd1/Content/...`) and writes the required boot path.
- **Configuration Options**: Checkboxes for enabling/disabling LiNK (system-link online), content mounting paths, and scan behavior.
- **One-Click Deploy**: A single button triggers the full download → extract → deploy pipeline.

---

#### 🧩 Homebrews — Embedded Homebrew App Library

The **Homebrews** tab provides a curated catalogue of essential Xbox 360 homebrew applications with dual-image preview panels and detailed descriptions.

**Available Software:**
- **XeX Menu** — The standard file manager for RGH/JTAG consoles. Browse and launch any XEX executable from any storage device. Essential for first-time setup.
- **DashLaunch** — The kernel-level launch configuration plugin that defines the default boot dashboard, network patches, and system behavior. Current version: 3.06.
- **xm360** — The most powerful DRM removal and game mounting tool for Xbox 360, allowing you to play STFS-packaged games without license restrictions.
- **XeXLoader** — A lightweight XEX launcher that can load executables directly from FAT32 USB drives, useful for unsigned code development.
- **Xenu** — A specialized tool for managing Xbox LIVE entitlements and re-licensing content to local profiles.
- **nxe2god** — Batch converter that converts NXE (disc image rips) packages to GOD (Games on Demand) format in bulk, directly on the console.
- **IngeniouX** — Advanced system utility for reading, patching, and managing NAND flash memory contents directly.
- **XPG Chameleon** — A profile editing and achievement unlocker that allows modifying gamer profiles and achievement data in offline environments.

---

#### 🛡️ Stealth & Bypass

The **Stealth e Bypass** tab provides tools to configure the console's network stealth profile, protecting it from Xbox LIVE detection bans.

- **KV (KeyVault) Management**: Select, backup, and activate CPU key vaults. The KV is the console's unique cryptographic identity — a burned KV unlocks the ability to access certain content but also triggers LIVE bans.
- **Stealth Server Config**: Configure the console to route LIVE traffic through known stealth servers (e.g., Neighborhood Stealth, gg.xbox360stealth.net).
- **XDK Dashboard Mode**: Toggle the console between Retail and XDK (development kit) display profiles.

---

#### 🧩 Plugins e Outros

The **Plugins e Outros** tab manages additional DashLaunch plugins and XEX-format utilities:

- **Plugin Library Browser**: Lists known plugins (`.xex` format) compatible with the connected dashboard version.
- **Auto-Install to Device**: Plugins can be downloaded and installed directly to the `Hdd1/DashLaunch/` path.
- **Version Awareness**: The engine checks the currently deployed DashLaunch version before installing plugins to warn of incompatibility.

---

#### 🏞️ x360 Landscape — STFS, Gamerpics & Identity

**x360 Landscape** is the identity management hub for Xbox 360 profiles and content.

**Avatar Gamerpics:**
- Browse a curated library of thousands of **official Xbox 360 gamerpics** across multiple categories.
- Also supports **custom/modded gamerpics** (any PNG/JPG image resized to 64×64 and packaged as an STFS container).
- Gamerpics are injected directly into the profile on the connected device using the `GamerpicsEngine`.
- Preview of the gamerpic is shown before injection.

**STFS Manager:**
- Inspect the contents of any STFS container (game, DLC, profile, avatar item) without a console.
- Extract raw files from STFS packages.
- Rebuild and re-sign STFS packages with custom content.

---

#### 🔄 x360 Converter

The **x360 Converter** tab handles raw image file transformations.

- **ISO → GOD (Games on Demand)**: Converts raw Xbox 360 ISO disc images into GOD packages compatible with Aurora, FSD3, and XeX Menu. GOD packages do not require a disc drive.
- **Xbox Classic ISO → GOD**: Handles original Xbox game ISOs, extracting and converting them into the correct legacy GOD folder structure for backwards-compatible play on RGH consoles.
- **Batch Conversion**: Queue multiple ISOs for sequential or parallel conversion.
- **Progress Tracking**: Each conversion job shows real-time progress and ETA in the Downloads Manager.

---

#### ⚙️ DashLaunch Pro Editor

The **DashLaunch Pro** editor provides a visual, form-based editor for the `launch.ini` configuration file — the most important configuration file on any RGH/JTAG console.

- **Visual Toggle Interface**: Every DashLaunch option is presented as a labeled toggle, dropdown, or text field — no manual text editing required.
- **Critical Network Patches**: 
  - `pingpatch` — Disables LIVE ping checks (essential for stealth).
  - `liveblock` — Blocks all Xbox LIVE connectivity at kernel level.
  - `livestrong` — Forces LIVE connection even without a valid KV (for development use).
  - `nohealth` — Disables health/anti-cheat checks.
- **Boot Path Management**: Set the default launch XEX path (e.g., `Hdd1:\Aurora\Aurora.xex`).
- **Auto-Template Generation**: If the connected USB does not contain a `launch.ini`, the editor auto-generates a safe starter template with sensible defaults for RGH systems.
- **Live Reload**: Changes are written and applied to the device immediately without requiring a reboot on supported DashLaunch versions.

---

#### 📡 FTP Manager — Wireless Console Access

The **FTP Manager** provides native, integrated FTP client functionality for wireless file management between the Linux PC and the Xbox 360 console.

- **Native Pure-Python FTP Client**: Implemented in `core/ftp_client.py` using only the Python standard library — no external FTP tools required.
- **Connection Panel**: Enter the console's IP address, port (default: 21), username, and password (standard: xbox/xbox for FreeStyle Dash).
- **Dual Pane File Browser**: Left panel shows the Linux filesystem; right panel shows the Xbox 360 filesystem (as exposed by the FTP server running on the console).
- **File Transfer (Upload/Download)**: Transfer files in both directions with real-time progress.
- **Directory Operations**: Create, rename, and delete directories on the console remotely.
- **Connection State Persistence**: The app remembers the last used IP/port between sessions.

---

#### 💾 Save Manager

The **Save Manager** provides a local save file backup and restoration system for Xbox 360 game save data.

- **Automatic Save Discovery**: Scans the connected device's `Content/<Profile XUID>/` paths and detects all STFS-formatted save containers.
- **Metadata Extraction**: Reads the STFS header of each save to display the game title, save slot name, and last-modified date.
- **Backup to PC**: Copies save containers to a local backup directory (`~/x360_saves/`).
- **Restore from PC**: Restores a saved backup to the device.

---

#### 🛡️ Backup e Restauro — Exclusive `.x360b` Format

The **Backup & Restore** module provides complete device imaging in the proprietary `.x360b` format.

- **Full Partition Imaging**: Unlike simple folder copy, the `.x360b` engine reads the raw partition sectors of the FAT32 filesystem on the Xbox 360 device, capturing the entire Content tree, hidden system files, and filesystem metadata.
- **Compressed Archive**: The raw image is compressed using LZMA (the highest-ratio algorithm) inside a `.x360b` container (which is a standard ZIP under the hood with a custom extension).
- **Smart Metadata Embedding**: The `.x360b` file header includes the original device label, creation date, and a manifest of all Title IDs found on the device, allowing rapid inspection without full extraction.
- **Restoration Flow**: 
  1. Select the target device (must be ≥ original device size).
  2. The engine formats the device as **FAT32 with the Xbox 360-native cluster size** (4096 bytes) using `mkfs.fat`.
  3. The `.x360b` image is decompressed and the raw partition data is restored sector-by-sector.
  4. Optionally rename the device label during restore.
- **Safety Checks**: Before any destructive operation, the user is presented with a confirmation dialog showing the target device path and size.

---

#### 🌍 100% Localization System

- **3 Interface Languages**: Portuguese 🇧🇷, English 🇬🇧, and Spanish 🇪🇸.
- **Static UI Translation**: All interface strings are managed by `TranslationService` — a compile-time lookup table. No runtime internet fetch required.
- **Dynamic Synopsis Translation**: Game descriptions fetched from the metadata service are automatically translated to the user's selected language using `deep-translator` (Google Translate API, free tier).
- **Source Language Detection**: The system auto-detects the source language of game descriptions (including Japanese 🇯🇵 editions) before translating.
- **Backend Propagation**: The Flutter app passes the language preference to the Python backend via the `--lang pt/en/es` CLI argument. All metadata returned by the bridge is pre-translated.

---

#### 🏧 Instalação (Install Wizard)

The **Instalação** section provides a full, guided installation pipeline for setting up a softmodded console from scratch.

- **Device Selection**: Detects all connected USB drives and HDDs. The user selects the target device from a dropdown list that shows the device label, mount point, block path, and available storage.
- **Drive Type Detection**: Identifies whether the selected device is a Pendrive/Flash Drive or an Xbox 360 official HDD, and adjusts the exploit payload accordingly.
- **Console Type Selection**: RGH (Reset Glitch Hack) or LT (Disc Drive Firmware flash) — each workflow follows different installation paths.
- **Dashboard Selection**: Choose which dashboard to install — Aurora, FSD3 (Freestyle Dash 3), or XeX Menu.
- **Plugin Selection**: Select optional DashLaunch plugins and Homebrews to install alongside the dashboard.
- **ABadAvatar / ABadMemUnit Payloads**: 
  - `ABadAvatar` — The Avatar exploit payload, installed on **Pendrives only** (flash storage). Used to trigger the initial RGH kernel exploit chain from a USB device.
  - `ABadMemUnit` — The Memory Unit exploit variant, installed exclusively on **Xbox 360 official HDDs**. Installing on a Flash Drive would corrupt the payload due to sector alignment differences.
- **Gamerpics Package**: Optionally install the full Gamerpics library to the console's profile storage.
- **Guided Wizard (Initiation)**: A step-by-step `Gtk.Assistant`-style wizard guides users with no technical knowledge through the entire process, explaining each step clearly.
- **Progress Reporting**: Each installation step reports its status in real-time to the UI via `service_bridge.py`.

---

### 🛠️ Technical Architecture

```
Flutter v2.0 (UI Layer)
    │
    ├─ AppState (Provider) ──────────────────────────────────────
    │       Manages: selectedDrive, downloads, isInstalling,
    │       games, statusMessage, language preference.
    │       Uses MOUNT POINTS (not block paths) for all file ops.
    │
    ├─ PythonBridge (service) ────────────────────────── Async Process Stream
    │       Spawns: python3 service_bridge.py --cmd <command> [args]
    │       Streams: Progress lines (PHASE:..., Progress:XX%|...|...)
    │       Returns: JSON result on final line.
    │
Python Backend (service_bridge.py)
    │
    ├─ FreemarketEngine  (core/freemarket.py)
    │       fetch_game_list, search_metadata, install_dlc,
    │       install_tu, install_game, _download_threaded (32-thread)
    │
    ├─ MetadataService   (core/metadata_service.py)  
    │       fast_batch_lookup, search_unity_by_name
    │       Local SQLite DB + x360db GitHub + scraper fallbacks
    │
    ├─ GameConverter     (core/converter.py)
    │       ISO→GOD, NXE→GOD, Archive extraction (zip/rar/7z)
    │
    ├─ GamerpicsEngine   (core/gamerpics.py)
    │       STFS packaging, gamerpic injection
    │
    ├─ FTPClient         (core/ftp_client.py)
    │       Pure-Python FTP (no ftplib external deps)
    │
    ├─ BackupManager     (core/backup.py)
    │       .x360b imaging, LZMA compression, FAT32 restore
    │
    ├─ SaveManager       (core/save_manager.py)
    │       STFS save discovery, backup, restore
    │
    └─ DashLaunchManager (core/dashlaunch.py)
            launch.ini read/write, plugin install
```

**Key Design Decisions:**
- All filesystem paths use **mount points** (e.g., `/media/user/Xbox`) not raw block devices (e.g., `/dev/sdb1`), ensuring write access on Linux without root.
- The download streamer uses `concurrent.futures.ThreadPoolExecutor` with up to 32 workers for maximum throughput on Archive.org's CDN.
- Error messages from the Python backend use the `PHASE:Erro:` prefix to enable the Flutter UI to distinguish them from progress messages and display them prominently.
- The metadata resolver uses a **cascade fallback strategy**: local asset → SQLite DB → x360db GitHub → Unity Scraper → `fast_batch_lookup` → default placeholder.

---

### 🚀 Installation & Running

#### Prerequisites
- **Linux** (Ubuntu 20.04+ / Debian 11+ / Arch recommended)
- **Python 3.10+** with pip
- **Flutter SDK** (3.x stable, installed at `~/flutter_sdk`)
- **System packages**: `p7zip-full`, `unrar`, `mkdosfs` (for `.x360b` restore)

#### Setup
```bash
# Clone the repository
gh repo clone amplidev-apps/x360-tools-linux
cd x360-tools-linux/v1.1

# Install Python dependencies
pip install requests deep-translator urllib3

# Run the Flutter Premium UI
./run_flutter.sh

# (Optional) Run the legacy GTK3 interface
./run.sh
```

#### Required Python packages
| Package | Usage |
|---------|-------|
| `requests` | HTTP downloads from Internet Archive |
| `urllib3` | Connection pooling & retry logic |
| `deep-translator` | Dynamic synopsis translation |
| `sqlite3` | Built-in — catalog & metadata DBs |
| `concurrent.futures` | Built-in — multi-threaded downloads |

---

<a name="português"></a>
## 🇧🇷 Português

### O que é o x360 Tools for Linux?

**x360 Tools for Linux** é um aplicativo desktop profissional e completo, criado especificamente para usuários Linux que possuem um Xbox 360 modificado (RGH/JTAG/LT). Não é uma ferramenta de uso único — é um **ecossistema completo de gerenciamento** cobrindo desde a descoberta, download e instalação de jogos, até configuração de dashboards, gerenciamento de capas, acesso FTP sem fio, gerenciamento de saves e backup do sistema.

---

### 🌟 Referência Completa de Funcionalidades

---

#### 🛒 x360 Freemarket — A Maior Loja de Xbox 360 do Mundo

O **x360 Freemarket** é a funcionalidade principal do aplicativo. Oferece um pipeline automatizado e legal de download e instalação de jogos, alimentado pela vasta biblioteca pública do Internet Archive.

**Motor do Catálogo:**
- Agrega metadados de **14 bancos de dados dedicados do Internet Archive**, cobrindo jogos completos de Xbox 360, Xbox Clássico, DLCs e Add-ons.
- Todos os metadados do catálogo são ingeridos por um **motor de ingestão SQLite multi-threaded de alta performance**, que armazena os dados em bancos de dados `.sqlite` locais. Navegar pelo catálogo não requer internet — o catálogo é pré-carregado.
- Os bancos de dados SQLite instalados contêm milhares de entradas cobrindo as bibliotecas PAL, NTSC-U, NTSC-J e Region-Free completas.
- A ingestão no primeiro uso é feita automaticamente pela classe `FreemarketEngine` em `core/freemarket.py`, que consulta cada banco de dados e constrói uma lista de jogos otimizada e sem duplicatas.

**UI do Catálogo — A Vitrine da Loja:**
- A visão padrão apresenta uma **seção hero estilo mosaico** com jogos em destaque seguida por uma **grade responsiva de 5 colunas** de todo o catálogo.
- Cada card de jogo exibe a capa oficial do box art (asset local ou busca assíncrona por URL), título, badge de plataforma e avaliação em estrelas.
- Uma **barra de pesquisa em tempo real** filtra todo o catálogo instantaneamente usando SQLite FTS — os resultados se atualizam enquanto o usuário digita, sem nenhum lag.
- Um **botão de atualização** permite ao usuário forçar a re-ingestão dos bancos de dados do catálogo a qualquer momento.

**Página de Detalhe do Jogo — `FICHA TÉCNICA`:**
Clicar em qualquer jogo abre uma visão de detalhe completo exibindo:
- **Box art em alta resolução** do diretório de assets local (`assets/gamecovers/`) ou URL de fallback.
- **Avaliação em estrelas** (obtida do banco de dados de metadados).
- **Ficha Técnica** incluindo: Sistema (Xbox 360 / Xbox Clássico), Região (NTSC-U / PAL / NTSC-J / Region-Free), Gênero, Data de Lançamento, Desenvolvedor, Distribuidora e **Title ID** (o identificador hexadecimal de 8 caracteres usado pelo filesystem do Xbox 360).
- **Sinopse / Descrição** (traduzida dinamicamente para o idioma do usuário).
- **Seletor de Região/Versão**: Se existirem múltiplas versões regionais (ex.: NTSC-U, PAL, NTSC-J), elas aparecem como pills selecionáveis — escolher uma região atualiza a URL de download para o arquivo regional correspondente.

**Navegador de Title Updates (TU):**
- Todos os Title Updates conhecidos de um jogo são listados dentro da sua página de detalhe.
- Cada entrada de TU mostra o número de versão e um botão de **download direto**.
- Os TUs baixados são colocados automaticamente no caminho correto do Xbox 360: `Content/0000000000000000/<TitleID>/000B0000/`.

**Gerenciador de DLCs:**
- Todos as DLCs conhecidas associadas a um jogo são listadas dentro da sua página de detalhe em "DLCs & Conteúdos Adicionais".
- Cada entrada de DLC tem um botão **"INSTALAR DLC"**.
- DLCs do catálogo do Internet Archive são associadas ao jogo pai usando o campo `base_game_name` derivado do nome de arquivo.
- DLCs instaladas são escritas no caminho correto: `Content/0000000000000000/<TitleID>/00000002/`.
- **Resolução de Title ID em cascata**: O sistema usa três níveis de fallback — TitleID do jogo pai, `fast_batch_lookup`, e por último o `titleId` do próprio objeto DLC. Isso garante instalação correta mesmo para jogos com cobertura incompleta de metadados.

**Fluxo de Download e Instalação:**
1. Usuário clica em **"INSTALAR"** em um jogo.
2. O app muda automaticamente para a **aba de Downloads**.
3. Uma **notificação SnackBar** verde confirma que o download iniciou.
4. O `FreemarketEngine` baixa o arquivo (multi-threaded, até 32 conexões paralelas) do Internet Archive.
5. **Detecção de Login**: Após o download, o motor escaneia os primeiros 1KB do arquivo — se detectar um redirecionamento HTML/login (comum quando a sessão do IA expira), alerta o usuário e apaga o arquivo corrompido.
6. O arquivo baixado (`.zip`, `.rar`, `.7z`, `.iso`) é extraído automaticamente.
7. O conteúdo extraído é convertido para o formato **GOD (Games on Demand)** via `god_utils`.
8. O pacote GOD é movido para o caminho correto no dispositivo: `<mount>/Content/0000000000000000/<TitleID>/00007000/`.
9. A UI transiciona para `DownloadPhase.completed` e o jogo aparece na **Minha Biblioteca**.

---

#### ⬇️ Gerenciador de Downloads — Motor Multi-Fase Avançado

O Gerenciador de Downloads (`GERENCIADOR DE DOWNLOADS`) é um painel persistente que rastreia todas as operações ativas e concluídas.

**Fases de Download:**
Cada item de download progride por fases claramente rotuladas com indicadores de cor distintos:
- 🔵 `Baixando` — Download HTTP multi-threaded em andamento.
- 🟡 `Extraindo` — Extração de arquivo (zip/rar/7z).
- 🟠 `Convertendo` — Conversão GOD (iso → pacote GOD).
- 🟢 `Instalando` — Movendo arquivos para o diretório-alvo do dispositivo.
- ✅ `Concluído` — Instalação completa, caminho local armazenado.
- ❌ `Falha` — Ocorreu um erro; o motivo exato da falha é exibido na UI (ex.: "Falha: 503 Server Error: Service Unavailable").

**Barra de Progresso e Estatísticas:**
- Porcentagem de progresso em tempo real (0–100%).
- Velocidade atual de download em MB/s.
- ETA (tempo estimado restante) no formato `MM:SS`.

**Controles:**
- Botão **"Limpar Concluídos"** remove todas as entradas concluídas da lista.
- Itens individuais podem ser **cancelados** via ação de contexto.

**Notificação no Início:**
Quando um novo download é iniciado (jogo, DLC ou TU), uma **notificação SnackBar** verde estilizada aparece instantaneamente, confirmando o nome do download e mudando a visualização automaticamente para a aba de Downloads.

---

#### 📚 Minha Biblioteca — Scanner de Biblioteca Local

A aba **Minha Biblioteca** fornece uma biblioteca local em tempo real de tudo instalado no dispositivo conectado.

- **Scanner Automático de Drive**: Quando um pen drive/HD é selecionado, o scanner percorre a árvore de diretórios `Content/` do dispositivo e detecta pacotes GOD Xbox 360, títulos Xbox Clássico, Title Updates e DLCs.
- **Extração de Metadados STFS**: Para cada pacote GOD detectado, o motor lê o cabeçalho do container STFS para extrair o nome oficial do jogo, Title ID e ícone em miniatura embutido.
- **Categorização Inteligente**: Itens detectados são organizados em abas visuais separadas: **Jogos**, **DLCs** e **Updates**.
- **Exibição de Capas**: Ícones extraídos de cabeçalhos STFS são exibidos como arte de capa. Se nenhum ícone estiver presente, uma capa padrão elegante (`4B4D07E2.jpg`) é usada.
- **Abrir Pasta**: Cada entrada de jogo tem um botão "Abrir Pasta" que abre o gerenciador de arquivos do sistema no diretório de instalação do jogo.

---

#### 🎛️ Dashboards — Pré-Visualização e Configuração de Aurora & FSD3

A aba **Dashboards** é a central de comando para configurar o software de dashboard customizado do console.

- **Pré-Visualização Visual**: Duas imagens de pré-visualização são exibidas — uma para o **Aurora** (o dashboard RGH moderno mais popular) e outra para o **FSD3 (Freestyle Dash 3)**.
- **Instalação Automatizada**: Tanto Aurora quanto FSD3 podem ser baixados e instalados diretamente no dispositivo conectado.
- **Opções de Configuração**: Checkboxes para habilitar/desabilitar LiNK (online via system-link), caminhos de montagem de conteúdo e comportamento de varredura.
- **Deploy com Um Clique**: Um único botão aciona o pipeline completo de download → extração → deploy.

---

#### 🧩 Homebrews — Biblioteca de Apps Homebrew

A aba **Homebrews** fornece um catálogo curado de aplicativos homebrew essenciais para Xbox 360 com painéis de pré-visualização de imagem dupla e descrições detalhadas:

- **XeX Menu** — Gerenciador de arquivos padrão para consoles RGH/JTAG. Navegue e execute qualquer executável XEX de qualquer dispositivo de armazenamento.
- **DashLaunch 3.06** — Plugin de configuração de boot no nível do kernel que define o dashboard padrão, patches de rede e comportamento do sistema.
- **xm360** — A ferramenta mais poderosa de remoção de DRM e montagem de jogos para Xbox 360, permitindo jogar pacotes STFS sem restrições de licença.
- **XeXLoader** — Launcher XEX leve que pode carregar executáveis diretamente de pen drives FAT32.
- **Xenu** — Ferramenta especializada em gerenciamento de direitos Xbox LIVE e re-licenciamento de conteúdo para perfis locais.
- **nxe2god** — Conversor em lote que converte pacotes NXE para o formato GOD em massa, diretamente no console.
- **IngeniouX** — Utilitário avançado do sistema para ler, corrigir e gerenciar o conteúdo da memória flash NAND diretamente.
- **XPG Chameleon** — Editor de perfil e desbloqueador de conquistas que permite modificar perfis de jogador e dados de achievement em ambientes offline.

---

#### ⚙️ DashLaunch Pro Editor

O editor **DashLaunch Pro** fornece um editor visual baseado em formulário para o arquivo de configuração `launch.ini`.

- **Interface de Alternância Visual**: Cada opção do DashLaunch é apresentada como um toggle, dropdown ou campo de texto rotulado.
- **Patches de Rede Críticos**: `pingpatch`, `liveblock`, `livestrong`, `nohealth`.
- **Gerenciamento de Boot Path**: Defina o caminho XEX padrão de lançamento.
- **Geração Automática de Template**: Gera um template seguro de `launch.ini` caso o dispositivo não possua um.

---

#### 📡 FTP Manager — Acesso Sem Fio ao Console

O **FTP Manager** oferece funcionalidade nativa de cliente FTP integrado para gerenciamento de arquivos sem fio entre o PC Linux e o Xbox 360.

- **Cliente FTP Python puro**: Implementado em `core/ftp_client.py` usando apenas a biblioteca padrão do Python — sem ferramentas FTP externas.
- **Painel de Conexão**: Informe IP, porta (padrão: 21), usuário e senha do console.
- **Navegador de Arquivos Duplo**: Painel esquerdo = sistema de arquivos Linux; painel direito = sistema de arquivos do Xbox 360.
- **Transferência de Arquivos**: Upload e download em ambas as direções com progresso em tempo real.
- **Operações de Diretório**: Criar, renomear e excluir diretórios remotamente.

---

#### 💾 Save Manager

O **Save Manager** fornece backup local e restauração de saves de jogos Xbox 360.

- **Descoberta Automática**: Varre `Content/<XUID>/` do dispositivo e detecta todos os containers STFS de save.
- **Extração de Metadados**: Lê o cabeçalho STFS para exibir título do jogo, nome do slot e data de modificação.
- **Backup para PC**: Copia os containers para `~/x360_saves/`.
- **Restaurar do PC**: Restaura um backup para o dispositivo.

---

#### 🛡️ Backup e Restauro — Formato Exclusivo `.x360b`

O módulo de **Backup & Restauro** fornece imagem completa do dispositivo no formato proprietário `.x360b`.

- **Imagem de Partição Completa**: Captura setores brutos da partição FAT32 do dispositivo Xbox 360.
- **Compressão LZMA**: Algoritmo de maior taxa de compressão para backups portáteis.
- **Metadados Inteligentes**: O cabeçalho `.x360b` inclui rótulo do dispositivo, data de criação e manifesto de Title IDs.
- **Fluxo de Restauração**: Formata o dispositivo-alvo como FAT32 com o tamanho de cluster nativo (4096 bytes) e restaura setor por setor.
- **Verificações de Segurança**: Diálogo de confirmação antes de qualquer operação destrutiva.

---

#### 🌍 Sistema de Localização 100%

- **3 Idiomas de Interface**: Português 🇧🇷, Inglês 🇬🇧 e Espanhol 🇪🇸.
- **Tradução Estática de UI**: Strings gerenciadas pelo `TranslationService` — tabela de lookup em tempo de compilação.
- **Tradução Dinâmica de Sinopses**: Descrições dos jogos traduzidas com `deep-translator`.
- **Detecção de Idioma Fonte**: Detecta automaticamente o idioma original (incluindo japonês 🇯🇵).
- **Propagação pelo Backend**: Preferência de idioma enviada via `--lang pt/en/es` ao Python.

---

### 🚀 Instalação e Execução

#### Pré-requisitos
- **Linux** (Ubuntu 20.04+ / Debian 11+ / Arch recomendado)
- **Python 3.10+** com pip
- **Flutter SDK** (3.x stable, instalado em `~/flutter_sdk`)
- **Pacotes de sistema**: `p7zip-full`, `unrar`, `mkdosfs`

#### Setup
```bash
# Clonar o repositório
gh repo clone amplidev-apps/x360-tools-linux
cd x360-tools-linux/v1.1

# Instalar dependências Python
pip install requests deep-translator urllib3

# Iniciar a Interface Flutter Premium
./run_flutter.sh

# (Opcional) Interface legada GTK3
./run.sh
```

---

<a name="español"></a>
## 🇪🇸 Español

### ¿Qué es x360 Tools for Linux?

**x360 Tools for Linux** es una aplicación de escritorio profesional y completa, diseñada específicamente para usuarios de Linux que poseen una Xbox 360 modificada (RGH/JTAG/LT). No es una herramienta de propósito único — es un **ecosistema completo de gestión** que cubre desde el descubrimiento, descarga e instalación de juegos, hasta la configuración del dashboard, gestión de carátulas, acceso FTP inalámbrico, gestión de partidas guardadas y backup del sistema.

---

### 🌟 Referencia Completa de Funcionalidades

#### 🛒 x360 Freemarket
- Agrega metadatos de **14 bases de datos del Internet Archive**.
- Catálogo SQLite de alta velocidad con búsqueda en tiempo real.
- Página de detalle con Ficha Técnica completa (Sistema, Región, Género, Title ID, Desarrollador, Distribuidora).
- Selector de versiones regionales (NTSC-U / PAL / NTSC-J).
- Navegador de Title Updates con descarga directa.
- Gestión e instalación de DLCs con resolución inteligente de Title ID en cascada.

#### ⬇️ Gestor de Descargas
- Fases: `Baixando → Extraindo → Convertendo → Instalando → Concluído / Falha`.
- Velocidad en MB/s y ETA en tiempo real.
- Notificación SnackBar verde al iniciar cada descarga.

#### 📚 Mi Biblioteca
- Escáner automático de dispositivos conectados.
- Extracción de metadatos STFS (nombre, Title ID, icono).
- Pestañas: Juegos / DLCs / Updates.

#### 🎛️ Dashboards
- Previsualización de Aurora y FSD3.
- Instalación automatizada de dashboards al dispositivo.

#### 🧩 Homebrews
- XeX Menu, DashLaunch 3.06, xm360, XeXLoader, Xenu, nxe2god, IngeniouX, XPG Chameleon.
- Descripciones completas y previsualizaciones de imagen doble.

#### ⚙️ DashLaunch Pro Editor
- Editor visual de `launch.ini` con toggles y campos etiquetados.
- Patches de red: `pingpatch`, `liveblock`, `livestrong`, `nohealth`.
- Generación automática de plantilla segura para nuevos dispositivos.

#### 📡 FTP Manager
- Cliente FTP Python puro integrado.
- Navegador de archivos dual (PC ↔ Xbox 360).
- Transferencia con progreso en tiempo real.

#### 💾 Save Manager
- Descubrimiento automático de saves en el dispositivo.
- Backup a PC y restauración desde PC.

#### 🛡️ Backup y Restauración (`.x360b`)
- Imagen completa de partición con compresión LZMA.
- Metadatos inteligentes embebidos en el contenedor.
- Restauración con formateo FAT32 nativo (cluster 4096 bytes).

#### 🌍 Localización
- 3 idiomas: Portugués 🇧🇷, Inglés 🇬🇧, Español 🇪🇸.
- Traducción dinámica de sinopsis con `deep-translator`.
- Detección automática del idioma fuente (incluido japonés 🇯🇵).

---

### 🚀 Instalación y Ejecución

```bash
# Clonar el repositorio
gh repo clone amplidev-apps/x360-tools-linux
cd x360-tools-linux/v1.1

# Instalar dependencias Python
pip install requests deep-translator urllib3

# Iniciar la interfaz Flutter Premium
./run_flutter.sh
```

---

**x360 Tools for Linux** — *Powered by Linux, Designed for Xbox Legends.* 🎮🟩

> Versão atual: **v2.0** | Última atualização: Março 2026
