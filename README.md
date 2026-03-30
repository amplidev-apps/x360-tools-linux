# x360 Tools (Linux & Windows) — v2.0 🎮🟩

> **The Definitive Xbox 360 Management Ecosystem** | Flutter v2.0 Premium Interface × Asynchronous Python Engine

[🇧🇷 Português](#português) | [🇬🇧 English](#english) | [🇪🇸 Español](#español)

---

<a name="português"></a>
## 🇧🇷 Português

### A Nova Era do Modding: x360 Tools (Cross-Platform)
O **x360 Tools v2.0** é a materialização de um projeto de engenharia de software focado em performance, estética e usabilidade. Desenvolvido para usuários de Xbox 360 RGH/JTAG e LT, este ecossistema não é apenas um utilitário, mas uma central de comando completa que integra descoberta de jogos, gestão de biblioteca, configuração de sistema e manutenção de hardware em uma única interface fluida, agora disponível para **Linux e Windows**.

Construído sobre uma **arquitetura híbrida**, o projeto utiliza **Flutter v2.0** para garantir uma UI de nível "AAA" com suporte a temas Dinâmicos (Dark/Light) e **Python 3 Assíncrono** para lidar com operações pesadas de I/O em segundo plano, garantindo que a interface nunca trave, mesmo durante downloads de 32 threads ou conversões de ISO.

---

### 🌟 Pilares do Ecossistema

#### 🛒 Descoberta: x360 Freemarket
O portal definitivo para a preservação de jogos. Integrado com **14 bases de dados globais**, o Freemarket oferece:
- **Ingestão Inteligente:** Busca multi-threaded em catálogos do Internet Archive.
- **Deduplicação Pro:** Identificação automática de versões regionais (NTSC-U, PAL, NTSC-J).
- **Instalação em 3 Cliques:** Download → Extração → Conversão GOD → Instalação automática.

#### 📚 Gestão: Minha Biblioteca & Cloud Saves
Um scanner de alta precisão que lê os cabeçalhos **STFS** diretamente do seu dispositivo:
- **Metadados Nativos:** Extração de nomes oficiais, Title IDs e miniaturas diretamente do hardware.
- **Safe Backup:** Sistema de proteção de saves para garantir que seu progresso nunca se perca.

#### 🛡️ Sistema: Backup .x360b & Imaging
Segurança de nível industrial para seu console:
- **Imaging de Partição:** Criação de imagens de disco completas no formato proprietário `.x360b` com compressão LZMA.
- **Restauração de Baixo Nível:** Formatação FAT32 com cluster size otimizado para Xbox (4096b).

#### 📡 Conectividade: FTP Native Hub
Gerenciamento sem fios sem depender de ferramentas de terceiros:
- **Pure-Python FTP:** Cliente integrado para transferência bidirecional de alta velocidade entre Linux e Xbox.

---

### 📖 Manual do Usuário (Instruções Detalhadas)

#### 1. Início e Conexão de Hardware
Tudo começa com o seu dispositivo. O x360 Tools é inteligente o suficiente para saber onde ele está e o que ele é.
- **Seleção de Drive:** Na barra lateral superior, selecione o dispositivo montado. O sistema exibirá o espaço livre e o "Label" do drive.
- **Identificação Automática:** Se você conectar um HDD oficial de Xbox 360, o sistema habilitará payloads específicos para HDDs (`ABadMemUnit`). Se for um Pendrive, habilitará o `ABadAvatar`. **Sempre verifique se o drive correto está selecionado antes de instalar exploits.**

#### 2. Operando o x360 Freemarket
- **Buscando Jogos:** Use a barra de busca no topo para filtrar por nome ou TitleID. A busca é instantânea (SQLite FTS).
- **Versões e Regiões:** Dentro da ficha técnica de um jogo, procure pelo seletor "Região/Versão". Se um jogo tiver versões diferentes para EUA e Europa, você pode alternar entre elas antes de clicar em instalar.
- **DLCs e Updates:** Abaixo da descrição do jogo, você encontrará seções dedicadas para DLCs e Title Updates. Basta um clique para adicioná-los à fila de download.

#### 3. Gerenciador de Downloads (A Central de Fluxo)
Acompanhe o progresso em tempo real:
- **Fases:** O download passa por: *Baixando (Azul)* → *Extraindo (Amarelo)* → *Convertendo (Laranja)* → *Instalando (Verde)*.
- **Cancelamento:** Para cancelar um item, use o botão de contexto individual. Use "Limpar Concluídos" para manter sua lista organizada.

#### 4. Setup de Dashboards e Homebrews
- **Instalando Aurora/FSD:** Vá na aba **Dashboards**, veja a pré-visualização e clique em "Instalar". O sistema fará todo o trabalho de colocar os arquivos no diretório `Hdd1:\Content\0000000000000000\`.
- **XeX Menu:** Essencial para iniciantes. Localize-o na aba **Homebrews** para garantir que você possa lançar arquivos `.xex` logo de cara.

#### 5. Conversão ISO → GOD
Se você já possui seus próprios arquivos `.iso` no PC:
- Vá na aba **x360 Converter**.
- Selecione o arquivo ISO de origem e o destino no seu dispositivo.
- O sistema converterá para o formato GOD (que não requer drive de disco) e organizará na pasta correta do TitleID.

#### 6. DashLaunch Pro (Configurações de Especialista)
O editor de `launch.ini` permite controlar o coração do console:
- **Pingpatch:** Mantenha ativado para evitar banimentos.
- **Default Path:** Define qual dashboard abrirá quando o console ligar (ex: `Hdd1:\Aurora\Aurora.xex`).
- **Geração de Template:** Se seu console for virgem, clique em "Carregar INI" e ele também irá criar um arquivo `launch.ini` com as melhores práticas de 2026.

#### 7. Backup e Restauração (.x360b)
- **Criando Backup:** Selecione seu drive, vá em **x360 Recovery**, e gere um arquivo `.x360b`. Este arquivo contém TUDO do seu drive em estado bruto.
- **Restaurando:** Selecione um drive novo (deve ser igual ou maior que o original), escolha o arquivo `.x360b` e aguarde. O sistema formatará e recriará a estrutura de arquivos perfeitamente.

---

### 💻 Arquitetura Técnica

| Camada | Tecnologia | Responsabilidade |
|--------|------------|------------------|
| **Frontend** | Flutter 3.x | UI, Gestão de Estado (Provider), Animações |
| **Bridge** | Service Bridge | Comunicação via Stream Assíncrona |
| **Backend** | Python 3.10+ | Lógica de Negócio (Asynchronous), Threading, I/O |
| **Plataformas** | Linux & Windows | Suporte Nativo (AppImage/DEB & MSIX/Exe) |
| **Database** | SQLite 3 | Cache de Catálogo e Metadados (AppData/%APPDATA%) |
| **Payloads** | C++/Rust/Py | STFS Injection, ISO Conversion (.exe no Win) |

---

### 📦 Instalação no Windows
Para usuários Windows, o processo é simplificado:
1. Baixe o **Instalador Oficial (x360Tools_Setup.exe)** ou o pacote **MSIX**.
2. O sistema instalará automaticamente o backend Python necessário.
3. Certifique-se de ter os drivers de USB atualizados para o reconhecimento correto dos drives FAT32.

---

<a name="english"></a>
## 🇬🇧 English

### The New Era of Modding: x360 Tools for Linux
**x360 Tools for Linux v2.0** is the pinnacle of Xbox 360 management software. Built with a professional "AAA" aesthetic and high-performance asynchronous engine, it bridges the gap between classic hardware and modern Linux desktops.

---

### 🛡️ Feature Deep-Dive

#### 🛒 x360 Freemarket
- **Infinite Library:** Access to thousands of titles via multi-threaded automated scrapers.
- **Smart Resolution:** Automatic TitleID and Region matching.
- **One-Click Pipeline:** Download → Extract → GOD Convert → Deploy.

#### 🛡️ System Image (.x360b)
- **Low-Level Imaging:** Sector-by-sector backup with LZMA compression.
- **Format & Restore:** Native FAT32 cluster alignment (4096b) for maximum compatibility.

#### 📡 Pro Connectivity
- **Native FTP:** No external clients needed. Integrated dual-pane wireless management.

---

### 📖 User Manual & Instructions

#### 1. Device Selection
- **Crucial Step:** Select your USB/HDD from the sidebar dropdown.
- **RGH vs LT:** Ensure you know your console type. The system identifies drive types (Pendrive/HDD) to prevent payload corruption.

#### 2. The Freemarket Workflow
- **Search:** Instant SQLite filtering as you type.
- **Regions:** Switch between NTSC/PAL seamlessly using the detail sheet pill selector.
- **Installation:** Monitor the "Downloads" tab to see real-time speed and ETA.

#### 3. Homebrews & Dashboards
- **Aurora/FSD:** Deployment is fully automated. The system places files and writes boot paths for you.
- **Homebrew Library:** Pre-curated list of essentials (XeX Menu, DashLaunch, xm360).

---

<a name="español"></a>
## 🇪🇸 Español

### x360 Tools for Linux v2.0: El Ecosistema Definitivo
Una suite profesional diseñada para la comunidad de Xbox 360, combinando la elegancia de Flutter con la potencia de Python.

---

### 🌟 Características Principales
- **x360 Freemarket:** Descarga e instalación automática de juegos, DLCs y TUs.
- **Gestión STFS:** Extracción de metadados y portadas directamente del dispositivo.
- **Backup Industrial:** Imágenes `.x360b` para una supervivencia total del sistema.
- **FTP Integrado:** Gestión inalámbrica nativa.

---

### 🚀 Instalación / Installation / Instalação

```bash
# Clone
gh repo clone amplidev-apps/x360-tools-linux
cd x360-tools-linux/v1.1

# Dependencies
pip install requests deep-translator urllib3

# Run Premium UI
./run_flutter.sh
```

---

**x360 Tools for Linux** — *Powered by Linux, Designed for Xbox Legends.* 🎮🟩
> Version: **v2.0** | Updated: March 2026 | Developed by: **AmpliDev**
