# 🎮 x360 Tools for Linux v2.0 - Gaming Modernity

![x360 Tools Header](https://raw.githubusercontent.com/amplimusic/x360_tools_flutter/main/assets/readme_banner.png)

Welcome to **x360 Tools for Linux v2.0**, the definitive open-source suite for Xbox 360 and Classic Xbox management on Linux. Rebuilt from the ground up with **Flutter** and **Python**, this version delivers a premium AAA experience with high-performance multi-threading and a stunning, theme-aware interface.

---

## 🌎 Idiomas / Languages / Idiomas
*   [Português Brasileiro (Original)](#-português-brasileiro)
*   [English Version](#-english)
*   [Versión en Español](#-español)

---

## 🇧🇷 Português Brasileiro

### 💡 O que é o x360 Tools?
O x360 Tools é uma ferramenta "tudo-em-um" projetada para simplificar a vida do usuário de Xbox 360 RGH/JTAG no Linux. Desde a conversão de ISOs até a injeção de DLCs e gerenciamento de saves, tudo é feito através de uma interface intuitiva e profissional.

### 🚀 Funcionalidades Principais
*   **Freemarket Archive.org:** Navegue e baixe milhares de títulos diretamente de repositórios oficiais com alta velocidade.
*   **Conversor Universal:** Transforme ISOs em pacotes GOD (Games on Demand) ou extraia ISOs de Xbox Clássico.
*   **Gerenciador FTP:** Conexão nativa sem fio para transferir jogos e arquivos diretamente para o HD do seu console.
*   **Horizon & Content Injector:** Injeção direta de Title Updates (TU), DLCs e Saves em dispositivos USB.
*   **DashLaunch Pro Editor:** Edite o seu `launch.ini` visualmente, sem precisar abrir arquivos de texto.
*   **Profile Pics (Gamerpics):** Biblioteca com milhares de heróis e suporte para criação de Gamerpics personalizadas a partir de qualquer imagem.
*   **Safe Recovery:** Sistema de Backup e Restauração completo (.x360b) para o seu pendrive de jogos.

### 📘 Manual de Instruções (Quick Start)

#### 1. Preparação do Dispositivo
Sempre conecte o seu pendrive ou HD externo formatado em **FAT32** antes de iniciar as operações. Use o seletor de dispositivos no topo de cada módulo para garantir que os arquivos vão para o lugar certo.

#### 2. Usando o Freemarket
*   Vá na aba **Freemarket**.
*   Faça login com sua conta do **Archive.org** nas configurações para evitar limites de download.
*   Pesquise o jogo desejado, veja os detalhes e clique em **DOWNLOAD**.
*   O progresso será exibido na barra inferior. Assim que concluído, o jogo estará na sua Biblioteca.

#### 3. Injetando DLCs e TUs
*   Acesse o módulo **Horizon Landscape**.
*   Clique na área de "Drop" para selecionar o seu arquivo STFS (DLC/TU/Save).
*   Verifique os metadados (TitleID/MediaID) para confirmar se é compatível com seu jogo.
*   Selecione o pendrive e clique em **INJETAR**.

---

## 🇺🇸 English

### 💡 What is x360 Tools?
x360 Tools is an all-in-one management suite for Xbox 360 RGH/JTAG users on Linux. It bridges the gap between complex terminal scripts and a premium, user-friendly desktop experience.

### 🚀 Key Features
*   **Archive.org Freemarket:** Native integration for downloading content from high-speed metadata-aware repositories.
*   **ISO Converter:** Convert local ISOs to GOD format or extract Classic Xbox ISOs to XEX folders.
*   **FTP Manager:** Seamless wireless management of your Xbox console's internal storage.
*   **STFS Injector:** Inject Save games, DLCs, and Title Updates with automated pathing for USB devices.
*   **Gamerpic Studio:** Thousands of library avatars plus custom Gamerpic creation from local images.

---

## 🇪🇸 Español

### 🚀 Funciones Principales
*   **Tienda Freemarket:** Descarga directa de miles de juegos y DLCs desde Internet Archive.
*   **Conversor de ISOs:** Pasa tus ISOs a formato GOD o extrae contenido de Xbox Clásico fácilmente.
*   **Inyector de Contenido:** Instala TUs y DLCs en tu pendrive con solo un clic.

---

## ⚙️ Arquitetura Técnica
O x360 Tools utiliza uma arquitetura híbrida de alto desempenho:
*   **Frontend:** Flutter 3.x para uma UI fluida, responsiva e com suporte total a temas **Light/Dark**.
*   **Backend:** Python 3.10+ agindo como o motor central (`service_bridge.py`), gerenciando extrações, rede e I/O de disco.
*   **Comunicação:** JSON-RPC Bridge proprietário para latência zero entre a interface e os comandos do sistema.

## 🤝 Contribuição & Suporte
Desenvolvido por **Amplimusic** com foco na comunidade Xbox de código aberto. 

*   **Reporte Bugs:** Abra uma Issue no repositório.
*   **Suporte:** Documentação técnica detalhada no arquivo [WIKI](wiki.md).

---
*Powered by x360 Tools Team — Modernizing Retro-Gaming.*
