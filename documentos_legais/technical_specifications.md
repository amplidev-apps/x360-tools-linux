# x360 Tools for Linux - Especificações Técnicas (v1.0 - v2.0)

## 1. Visão Geral da Arquitetura
O **x360 Tools** evoluiu de um script monolítico em Python (**v1.0**) para uma aplicação de alta fidelidade baseada em **Flutter** com um backend desacoplado em Python (**v2.0 Elite**).

### Componentes Principais:
- **Frontend (Flutter)**: Interface de usuário premium baseada no design "Fluent Dark" do Xbox. Gerencia o estado global, navegação e interações do usuário.
- **Backend (Python 3)**: Núcleo de processamento de baixo nível para manipulação de sistemas de arquivos, extração de pacotes e comunicação com o hardware.
- **Service Bridge (Capa de Comunicação)**: Um protocolo leve de JSON-RPC via CLI (`service_bridge.py`) que permite que o Flutter execute comandos do sistema com segurança e receba dados estruturados.

## 2. Tecnologias e Dependências
- **Linguagem**: Dart (Flutter) & Python 3.10+.
- **Interface**: Flutter SDK v3.29.0+ para Linux (GTK base).
- **Backend Core**: 
  - `pyparted`: Detecção de hardware e análise de partições.
  - `requests`: Comunicação com o catálogo do Xbox Freemarket.
  - `shutil/os`: Manipulação de arquivos e extração ZIP.
- **Binários Nativos (Engine de Conversão)**:
  - `extract-xiso`: Para extração de jogos do Xbox Clássico.
  - `iso2god-rs`: Conversão de ISOs modernas para pacotes GOD (Game On Demand).

## 3. Módulos do Sistema de Arquivos

### 3.1 USB Manager (`core/usb.py`)
Responsável por identificar dispositivos removíveis, filtrar discos internos do sistema e realizar a formatação em FAT32 (padrão obrigatório do Xbox 360). 
- **Funcionalidade**: Varredura `/dev/sd*` e montagem automática via `udisks2` ou montagem direta.

### 3.2 STFS Engine (`core/stfs.py`)
Implementação nativa do parser de pacotes Xbox 360 (**CON/LIVE/PIRS**). 
- **Capitulação de Metadados**: Lê `Title ID`, `Media ID`, `Content Type` e extrai ícones embutidos diretamente dos cabeçalhos binários.
- **Instalação Inteligente**: Resolve automaticamente o caminho de destino no USB: `/Content/0000000000000000/[TitleID]/[TypeID]/`.

### 3.3 Game Converter (`core/converter.py`)
Orquestrador de subprocessos para conversão de jogos.
- **ISO2GOD**: Transforma imagens de disco em pacotes instaláveis que aparecem nativamente na dashboard oficial ou Aurora/FSD.
- **Extract-XISO**: Extrai o conteúdo bruto de jogos para execução direta via XEX.

## 4. Biblioteca de Software (packages.py)
Contém a definição de mais de 45 pacotes pré-configurados, categorizados como:
- **Dashboards**: Aurora, Freestyle Dashboard, XeXMenu.
- **Homebrew**: Dashlaunch, XM360, FFPlay.
- **Stealth**: Servidores de conexão segura para Xbox Live.
- **Customization**: Boot animations e notificações personalizadas (X-Notify).

## 5. Fluxo de Instalação (Exclusive Wizard)
O **Install Wizard** (presente desde a v1.0 e aprimorado na v2.0) utiliza um fluxo de estado linear:
1. **Verificação de Hardware**: Drive USB e espaço em disco.
2. **Identificação de Versão**: Console RGH/JTAG ou LT+ 3.0.
3. **Seleção de UI**: Dashboards e exploradores de arquivos.
4. **Otimização de Sistema**: Plugins de performance e servidores stealth.
5. **Batch Processing**: Download paralelo e extração atômica para garantir integridade.

## 6. Website Oficial e Distribuição
A aplicação é distribuída via pacotes **.deb** e **AppImage** (em desenvolvimento para v2.0) hospedados localmente para garantir independência de repositórios externos.
- **Endereço**: [www.x360tools.gamer.gd](http://www.x360tools.gamer.gd)
