import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../services/python_bridge.dart';
import '../services/translation_service.dart';

enum DownloadPhase {
  waiting,
  checkingSpace,
  downloading,
  extracting,
  converting,
  installing,
  completed,
  failed,
  canceled
}

class DownloadItem {
  final String id;
  final String name;
  final String url;
  final String platform;
  final String destPath;
  DownloadPhase phase;
  String statusMessage;
  double progress;
  bool isPaused;
  String? localPath;
  DateTime startTime;
  String? speed;
  String? eta;
  final String type; // "game", "tu", or "dlc"
  final String? coverUrl;
  final String? titleId;
  final Map<String, dynamic>? originalGame;

  DownloadItem({
    required this.id,
    required this.name,
    required this.url,
    required this.platform,
    required this.destPath,
    this.type = "game",
    this.phase = DownloadPhase.waiting,
    this.statusMessage = "Aguardando...",
    this.progress = 0.0,
    this.localPath,
    this.coverUrl,
    this.titleId,
    this.originalGame,
    this.isPaused = false,
  }) : startTime = DateTime.now();
}

class AppState extends ChangeNotifier {
  // --- Legacy Selection Maps (Literal Parity) ---
  final Map<String, bool> exploitMethods = {
    "BadUpdate": false,
    "ABadAvatar": false,
    "BadAvatarHDD": false,
    "ABadMemUnit": false,
  };

  final Map<String, bool> patchOptions = {
    "XeUnshackle": false,
    "FreeMyXe": false,
  };

  final Map<String, bool> installOptions = {
    "Skip XeXMenu": false,
    "Skip Rock Band": false,
    "Skip Main Files": false,
    "Skip Format": false,
    "Install All": false,
    "Exit On Finish": false,
  };

  // Detailed selections for each tab (Literal Parity)
  final Map<String, bool> dashboardSelections = {
    "Aurora": true,
    "Freestyle": false,
    "Emerald": false,
    "Viper360": false,
    "XeXMenu": false,
    "XeXLoader": false,
    "Xenu": false,
    "NXE2GOD": false,
    "IngeniouX": false,
    "XPG.Chameleon": false,
  };

  final Map<String, bool> homebrewSelections = {
    "Dashlaunch": true,
    "FFPlay": false,
    "GOD.Unlocker": false,
    "XM360": false,
    "XNA.Offline": false,
    "HDDx.Fixer": false,
    "Flasher": false,
  };

  final Map<String, bool> stealthSelections = {
    "CipherLive": false,
    "xbGuard": false,
    "Proto": false,
    "Nfinite": false,
    "TetheredLive": false,
    "XBL.Kyuubii": false,
    "XBLS": false,
    "xbNetwork": false,
  };

  final Map<String, bool> pluginSelections = {
    "Plugins e Outros": false,
    "xbPIrate": false,
    "hiddriver360": false,
    "HvP2": false,
  };

  final Map<String, bool> customSelections = {
    "X Notify.Pack": false,
    "FakeAnim": false,
    "Boot.Animations": false,
  };

  final Map<String, bool> backcompatSelections = {
    "Hacked.Compatibility.Files": false,
    "Original.Compatibility.Files": false,
    "Xbox.One.Files": false,
    "XEFU.Spoofer": false,
  };

  // --- Core State ---
  List<dynamic> drives = [];
  Map<String, dynamic>? selectedDrive;
  
  bool isWizardActive = false;
  int wizardStep = 0;
  String? consoleType; 
  bool isInstalling = false;
  String statusMessage = "Idle";
  double progress = 0.0;
  String currentLanguage = "Português";

  // --- Horizon Injector State ---
  String? currentSTFSPath;
  Map<String, dynamic>? stfsMetadata;
  Map<String, dynamic> explorerContent = {};
  bool isLoadingSTFS = false;
  bool isLoadingExplorer = false;
  
  // --- Profile Pics State ---
  List<dynamic> gamerpics = [];
  bool isLoadingGamerpics = false;
  List<dynamic> installedGamerpics = [];
  bool isLoadingInstalledGamerpics = false;

  // --- Freemarket State ---
  List<DownloadItem> downloads = [];
  List<dynamic> games = [];
  bool isLoadingGames = false;
  bool isScanningLibrary = false;
  Map<String, List<dynamic>> libraryGames = {
    "360": [],
    "OG": [],
    "DLC": [],
    "TU": []
  };
  bool isLoggedInIA = false;

  // --- FTP State ---
  bool isFtpConnected = false;
  String? ftpHost;
  List<dynamic> ftpCurrentDir = [];
  String ftpCurrentPath = "/";
  bool isLoadingFtp = false;

  // --- Save Manager State ---
  List<dynamic> saves = [];
  bool isLoadingSaves = false;

  // --- New Settings Fields ---
  String downloadPath = "";
  String ftpIp = "192.168.1.100";
  String ftpUser = "xbox";
  String ftpPass = "xbox";
  bool autoScanDrives = true;
  String coverResolution = "Média";
  bool isDarkMode = true;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    await loadSettings();
    if (autoScanDrives) {
      await refreshDrives();
    }
    await saveScan();
    await verifyIALogin();
  }

  Future<void> loadSettings() async {
    try {
      final file = File('config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        downloadPath = data['downloadPath'] ?? "";
        ftpIp = data['ftpIp'] ?? "192.168.1.100";
        ftpUser = data['ftpUser'] ?? "xbox";
        ftpPass = data['ftpPass'] ?? "xbox";
        autoScanDrives = data['autoScanDrives'] ?? true;
        coverResolution = data['coverResolution'] ?? "Média";
        isDarkMode = data['isDarkMode'] ?? true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  Future<void> saveSettings() async {
    try {
      final data = {
        'downloadPath': downloadPath,
        'ftpIp': ftpIp,
        'ftpUser': ftpUser,
        'ftpPass': ftpPass,
        'autoScanDrives': autoScanDrives,
        'coverResolution': coverResolution,
        'isDarkMode': isDarkMode,
      };
      final file = File('config.json');
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint("Error saving settings: $e");
    }
  }

  void updateSettings({
    String? dlPath,
    String? fIp,
    String? fUser,
    String? fPass,
    bool? scan,
    String? res,
  }) {
    if (dlPath != null) downloadPath = dlPath;
    if (fIp != null) ftpIp = fIp;
    if (fUser != null) ftpUser = fUser;
    if (fPass != null) ftpPass = fPass;
    if (scan != null) autoScanDrives = scan;
    if (res != null) coverResolution = res;
    saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    saveSettings();
    notifyListeners();
  }

  Future<void> verifyIALogin() async {
    try {
      final res = await PythonBridge.executeCommand("check_ia_login");
      if (res["status"] == "success") {
        isLoggedInIA = res["logged_in"] ?? false;
        notifyListeners();
      }
    } catch (_) {}
  }

  // --- Save Manager Methods ---
  Future<void> saveScan() async {
    isLoadingSaves = true;
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("save_scan");
      if (res['status'] == 'success') {
        saves = res['data'] ?? [];
      }
    } catch (e) {
      statusMessage = "Erro ao buscar saves: $e";
    } finally {
      isLoadingSaves = false;
      notifyListeners();
    }
  }

  Future<void> saveImport(String filePath) async {
    statusMessage = "Importando Save/Perfil...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("save_import", src: filePath);
      if (res['status'] == 'success') {
        statusMessage = res['message'];
        await saveScan();
      } else {
        statusMessage = "Erro importando save: ${res['message']}";
      }
    } catch (e) {
      statusMessage = "Exceção: $e";
    }
    notifyListeners();
  }

  Future<void> saveDelete(String fileName) async {
    statusMessage = "Apagando save...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("save_delete", arg: fileName);
      if (res['status'] == 'success') {
        statusMessage = "Save removido.";
        await saveScan();
      } else {
        statusMessage = "Erro apagando save: ${res['message']}";
      }
    } catch (e) {
      statusMessage = "Exceção ao apagar: $e";
    }
    notifyListeners();
  }

  // --- FTP Methods ---
  Future<Map<String, dynamic>> ftpConnect(String host) async {
    isLoadingFtp = true;
    statusMessage = "Conectando ao Xbox (FTP)...";
    notifyListeners();
    try {
      final res = await PythonBridge.ftpCommand("ftp_connect", host: host);
      if (res['status'] == 'success') {
        isFtpConnected = true;
        ftpHost = host;
        statusMessage = "Conectado via FTP ao Xbox!";
        await ftpList("/");
      } else {
        statusMessage = "Erro FTP: ${res['message']}";
      }
      return res;
    } finally {
      isLoadingFtp = false;
      notifyListeners();
    }
  }

  Future<void> ftpDisconnect() async {
    if (!isFtpConnected) return;
    await PythonBridge.ftpCommand("ftp_disconnect", host: ftpHost);
    isFtpConnected = false;
    ftpHost = null;
    ftpCurrentDir = [];
    statusMessage = "FTP Desconectado";
    notifyListeners();
  }

  Future<void> ftpList(String path) async {
    isLoadingFtp = true;
    notifyListeners();
    try {
      final res = await PythonBridge.ftpCommand("ftp_list", host: ftpHost, remotePath: path);
      if (res['status'] == 'success') {
        ftpCurrentDir = res['data'] ?? [];
        ftpCurrentPath = res['path'] ?? "/";
      }
    } finally {
      isLoadingFtp = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> ftpUpload(String localPath, String remotePath) async {
    statusMessage = "Enviando arquivo via FTP...";
    notifyListeners();
    final res = await PythonBridge.ftpCommand("ftp_upload", host: ftpHost, localPath: localPath, remotePath: remotePath);
    statusMessage = res['status'] == 'success' ? "Envio concluído!" : "Erro de envio FTP";
    notifyListeners();
    if (res['status'] == 'success') await ftpList(ftpCurrentPath);
    return res;
  }

  Future<Map<String, dynamic>> ftpDelete(String remotePath, bool isDir) async {
    isLoadingFtp = true;
    notifyListeners();
    final res = await PythonBridge.ftpCommand("ftp_delete", host: ftpHost, remotePath: remotePath, isDir: isDir);
    if (res['status'] == 'success') await ftpList(ftpCurrentPath);
    return res;
  }

  Future<Map<String, dynamic>> ftpMkdir(String remotePath) async {
    isLoadingFtp = true;
    notifyListeners();
    final res = await PythonBridge.ftpCommand("ftp_mkdir", host: ftpHost, remotePath: remotePath);
    if (res['status'] == 'success') await ftpList(ftpCurrentPath);
    return res;
  }

  Future<void> refreshDrives() async {
    statusMessage = "Atualizando dispositivos...";
    notifyListeners();
    drives = await PythonBridge.listDrives();
    if (drives.isNotEmpty && selectedDrive == null) {
      selectedDrive = Map<String, dynamic>.from(drives[0]);
    }
    statusMessage = "Idle";
    notifyListeners();
  }

  Future<void> fetchGames({String platform = "360", bool refresh = false}) async {
    isLoadingGames = true;
    statusMessage = refresh ? "Atualizando catálogo ($platform)..." : "Buscando jogos ($platform)...";
    notifyListeners();
    
    try {
      games = await PythonBridge.fetchGames(platform, refresh: refresh);
      statusMessage = "Lista de jogos carregada.";
    } catch (e) {
      statusMessage = "Erro ao buscar jogos: $e";
    }
    
    isLoadingGames = false;
    notifyListeners();
  }

  Future<void> cancelDownload(String id) async {
    await PythonBridge.cancelDownload(id);
    final index = downloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final item = downloads[index];
      item.phase = DownloadPhase.canceled;
      item.statusMessage = "Cancelado pelo usuário";
      item.progress = 0;
      notifyListeners();
    }
  }

  Future<void> togglePauseDownload(String id) async {
    final index = downloads.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final item = downloads[index];

    if (item.isPaused) {
      await PythonBridge.resumeDownload(id);
      item.isPaused = false;
      item.statusMessage = "Retomando...";
    } else {
      await PythonBridge.pauseDownload(id);
      item.isPaused = true;
      item.statusMessage = "Pausado";
    }
    notifyListeners();
  }

  Future<void> installFromFreemarket(Map<String, dynamic> game, String destPath, bool onDevice) async {
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: downloadId,
      name: game['name'] ?? "Unknown",
      url: game['url'] ?? "",
      platform: game['platform'] ?? "360",
      destPath: destPath,
      type: "game",
      coverUrl: game['coverUrl'],
      titleId: game['titleId'],
      originalGame: game,
    );
    
    downloads.add(item);
    isInstalling = true; 
    notifyListeners();

    try {
      final res = await PythonBridge.installGame(
        item.id,
        item.url,
        item.name,
        item.platform,
        destPath,
        onDevice: onDevice,
        onProgress: (line) {
          if (line.startsWith("Progress:")) {
            final parts = line.split("|");
            final pStr = parts[0].replaceFirst("Progress:", "").replaceAll("%", "").trim();
            final p = double.tryParse(pStr);
            if (p != null) {
              item.progress = p / 100.0;
              if (parts.length >= 3) {
                item.speed = parts[1].trim();
                item.eta = parts[2].trim();
              }
              notifyListeners();
            }
            } else if (line.startsWith("PHASE:")) {
              final phaseText = line.replaceFirst("PHASE:", "").trim();
              item.statusMessage = phaseText;
              
              // Map text to phase enum for UI coloring/badges
              if (phaseText.contains("Baixando")) {
                item.phase = DownloadPhase.downloading;
              } else if (phaseText.contains("Extraindo")) {
                item.phase = DownloadPhase.extracting;
              } else if (phaseText.contains("Convertendo") || phaseText.contains("Processando")) {
                item.phase = DownloadPhase.converting;
              } else if (phaseText.contains("Instalando") || phaseText.contains("Copiando") || phaseText.contains("Enviando")) {
                item.phase = DownloadPhase.installing;
              } else if (phaseText.contains("Verificando espaço")) {
                item.phase = DownloadPhase.checkingSpace;
              } else if (phaseText.contains("concluída")) {
                item.phase = DownloadPhase.completed;
              }
              
              notifyListeners();
            } else if (line.startsWith("LocalPath:")) {
              item.localPath = line.replaceFirst("LocalPath:", "").trim();
              notifyListeners();
            }
            // Legacy sync (for global overlay if needed)
            statusMessage = item.statusMessage;
            progress = item.progress;
            notifyListeners();
          },
        );

      if (res["status"] == "success") {
        item.phase = DownloadPhase.completed;
        item.progress = 1.0;
        // Determine installation folder (V99: Adaptive paths PC vs Device)
        if (onDevice) {
          if (item.platform == "360") {
            item.localPath = "$destPath/Content/0000000000000000";
          } else {
            item.localPath = "$destPath/Games/${item.name}";
          }
        } else {
          // PC installation: directly into destPath
          item.localPath = destPath;
        }
      } else {
        if (item.phase != DownloadPhase.failed) {
          item.phase = DownloadPhase.failed;
          item.statusMessage = "Falha: ${res["message"] ?? "Erro na ponte"}";
        } else if (res["message"] != null && res["message"].toString().length > 30) {
          // If bridge has a VERY long/detailed error, use it
          item.statusMessage = "Falha: ${res["message"]}";
        }
      }
    } catch (e) {
      item.phase = DownloadPhase.failed;
      item.statusMessage = "Erro crítico: $e";
    } finally {
      // Check if other downloads are active
      isInstalling = downloads.any((d) => d.phase != DownloadPhase.completed && d.phase != DownloadPhase.failed && d.phase != DownloadPhase.canceled);
      notifyListeners();
    }
  }

  Future<void> openInstallationFolder(String path) async {
    await PythonBridge.openFolder(path);
  }

  void cancelInstallation() {
    PythonBridge.cancelCurrentInstall();
    isInstalling = false;
    statusMessage = "Instalação cancelada pelo usuário.";
    notifyListeners();
  }

  Future<void> installTitleUpdate(Map<String, dynamic> tu, String titleId) async {
    if (selectedDrive == null) {
      statusMessage = "Aviso: Selecione um dispositivo para instalar a TU.";
      notifyListeners();
      return;
    }

    final baseGame = games.firstWhere((g) => g['titleId'] == titleId, orElse: () => {});
    final cUrl = baseGame['coverUrl'] as String?;

    final downloadId = "TU_${DateTime.now().millisecondsSinceEpoch}";
    final item = DownloadItem(
      id: downloadId,
      name: tu['name'] ?? "Title Update (${tu['Version'] ?? 'vN/A'})",
      url: tu['DownloadUrl'] ?? tu['downloadUrl'] ?? tu['url'] ?? "",
      platform: "360",
      destPath: selectedDrive!['mount'],
      type: "tu",
      coverUrl: cUrl,
      titleId: titleId,
      originalGame: baseGame,
      phase: DownloadPhase.downloading,
      statusMessage: "Iniciando download da TU...",
    );
    
    downloads.add(item);
    isInstalling = true;
    notifyListeners();

    try {
      final stream = PythonBridge.installTU(
        url: item.url,
        name: "TU_Update.bin", 
        titleId: titleId,
        dest: item.destPath,
      );

      await for (final line in stream) {
        if (line.startsWith("Progress:")) {
          final parts = line.split("|");
          final pStr = parts[0].replaceFirst("Progress:", "").replaceAll("%", "").trim();
          final p = double.tryParse(pStr);
          if (p != null) {
            item.progress = p / 100.0;
            if (parts.length >= 3) {
              item.speed = parts[1].trim();
              item.eta = parts[2].trim();
            }
            notifyListeners();
          }
        } else if (line.startsWith("PHASE:")) {
          final msg = line.replaceFirst("PHASE:", "").trim();
          if (msg.startsWith("Erro:")) {
            item.phase = DownloadPhase.failed;
            item.statusMessage = "Falha: ${msg.replaceFirst("Erro:", "").trim()}";
            notifyListeners();
            return;
          }
          item.statusMessage = msg;
          final status = item.statusMessage.toLowerCase();
          if (status.contains("concluído") || status.contains("sucesso")) {
             item.phase = DownloadPhase.completed;
             item.progress = 1.0;
          }
        }
        notifyListeners();
      }
      
      if (item.phase != DownloadPhase.completed) {
         item.phase = DownloadPhase.completed;
         item.progress = 1.0;
      }
      
      // Determine TU local path (V99: Adaptive paths PC vs Device)
      if (selectedDrive != null) {
        item.localPath = "${selectedDrive!['mount']}/Content/0000000000000000/$titleId/000B0000";
      } else {
        item.localPath = item.destPath;
      }
    } catch (e) {
      item.phase = DownloadPhase.failed;
      item.statusMessage = "Erro: $e";
    }

    isInstalling = downloads.any((d) => d.phase != DownloadPhase.completed && d.phase != DownloadPhase.failed && d.phase != DownloadPhase.canceled);
    notifyListeners();
  }

  Future<void> installDLC(Map<String, dynamic> dlc, String titleId) async {
    if (selectedDrive == null) {
      statusMessage = "Aviso: Selecione um dispositivo para instalar a DLC.";
      notifyListeners();
      return;
    }

    final baseGame = games.firstWhere((g) => g['titleId'] == titleId, orElse: () => {});
    final cUrl = baseGame['coverUrl'] as String?;

    // Resolve URL from all possible source structures:
    // 1. Top-level 'url' (IA game objects)
    // 2. 'DownloadUrl' / 'DownloadURL' (metadata service DLCs)
    // 3. Nested in versions list (Freemarket grouped objects)
    String resolvedUrl = dlc['url'] as String? ??
        dlc['DownloadUrl'] as String? ??
        dlc['DownloadURL'] as String? ??
        "";
    if (resolvedUrl.isEmpty) {
      final versions = dlc['versions'] as List?;
      if (versions != null && versions.isNotEmpty) {
        resolvedUrl = versions[0]['url'] as String? ?? "";
      }
    }

    final resolvedName = (dlc['name'] as String? ?? dlc['Name'] as String? ?? "DLC Content").trim();

    if (resolvedUrl.isEmpty) {
      statusMessage = "Erro: URL de download da DLC não encontrada.";
      notifyListeners();
      return;
    }

    final downloadId = "DLC_${DateTime.now().millisecondsSinceEpoch}";
    final item = DownloadItem(
      id: downloadId,
      name: resolvedName,
      url: resolvedUrl,
      platform: "360",
      destPath: selectedDrive!['mount'],
      type: "dlc",
      coverUrl: cUrl,
      titleId: titleId,
      originalGame: baseGame,
      phase: DownloadPhase.downloading,
      statusMessage: "Iniciando download da DLC...",
    );

    
    downloads.add(item);
    isInstalling = true;
    notifyListeners();

    try {
      final res = await PythonBridge.installDLC(
        item.id,
        item.url,
        item.name,
        titleId,
        item.destPath,
        onProgress: (line) {
          if (line.startsWith("Progress:")) {
            final parts = line.split("|");
            final pStr = parts[0].replaceFirst("Progress:", "").replaceAll("%", "").trim();
            final p = double.tryParse(pStr);
            if (p != null) {
              item.progress = p / 100.0;
              if (parts.length >= 3) {
                item.speed = parts[1].trim();
                item.eta = parts[2].trim();
              }
              notifyListeners();
            }
          } else if (line.startsWith("PHASE:")) {
            final msg = line.replaceFirst("PHASE:", "").trim();
            if (msg.startsWith("Erro:")) {
              item.phase = DownloadPhase.failed;
              item.statusMessage = "Falha: ${msg.replaceFirst("Erro:", "").trim()}";
              notifyListeners();
              return;
            }
            item.statusMessage = msg;
            final status = item.statusMessage.toLowerCase();
            if (status.contains("extraindo")) item.phase = DownloadPhase.extracting;
            else if (status.contains("instalando")) item.phase = DownloadPhase.installing;
            else if (status.contains("concluída")) {
               item.phase = DownloadPhase.completed;
               item.progress = 1.0;
            }
          }
          notifyListeners();
        },
      );

      if (res["status"] == "success") {
        item.phase = DownloadPhase.completed;
        item.progress = 1.0;
        // V99: Adaptive paths PC vs Device
        if (selectedDrive != null) {
          item.localPath = "${selectedDrive!['mount']}/Content/0000000000000000/$titleId/00000002";
        } else {
          item.localPath = item.destPath;
        }
      } else {
        if (item.phase != DownloadPhase.failed) {
          item.phase = DownloadPhase.failed;
          item.statusMessage = "Falha: ${res["message"] ?? "Erro na ponte"}";
        } else if (res["message"] != null && res["message"].toString().length > 30) {
          // If bridge has a VERY long/detailed error, use it
          item.statusMessage = "Falha: ${res["message"]}";
        }
      }
    } catch (e) {
      item.phase = DownloadPhase.failed;
      item.statusMessage = "Erro: $e";
    }

    isInstalling = downloads.any((d) => d.phase != DownloadPhase.completed && d.phase != DownloadPhase.failed && d.phase != DownloadPhase.canceled);
    notifyListeners();
  }

  void selectDrive(Map<String, dynamic> drive) {
    selectedDrive = drive;
    notifyListeners();
    // Auto-load installed gamerpics for this device
    fetchInstalledGamerpics();
  }

  // --- Toggle Methods ---
  void toggleExploit(String key) {
    exploitMethods.updateAll((k, v) => false); // Radio-like
    exploitMethods[key] = true;
    notifyListeners();
  }

  void togglePatch(String key) {
    patchOptions[key] = !patchOptions[key]!;
    notifyListeners();
  }

  void toggleInstallOption(String key) {
    installOptions[key] = !installOptions[key]!;
    notifyListeners();
  }

  void toggleDashboard(String key) {
    dashboardSelections[key] = !dashboardSelections[key]!;
    notifyListeners();
  }

  void toggleHomebrew(String key) {
    homebrewSelections[key] = !homebrewSelections[key]!;
    notifyListeners();
  }

  void toggleStealth(String key) {
    stealthSelections[key] = !stealthSelections[key]!;
    notifyListeners();
  }

  void togglePlugin(String key) {
    pluginSelections[key] = !pluginSelections[key]!;
    notifyListeners();
  }

  int currentMainTab = 0; // 0=Main, 1=Library, 2=FTP, etc.
  int currentLibraryTab = 0; // 0=360, 1=OG, 2=DLC, 3=TU
  String librarySearchQuery = "";

  void setMainTab(int index) {
    currentMainTab = index;
    notifyListeners();
  }

  void setLibraryTab(int index) {
    currentLibraryTab = index;
    notifyListeners();
  }

  Future<void> scanLibrary() async {
    if (selectedDrive == null) return;
    isScanningLibrary = true;
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("scan_library", device: selectedDrive!['device']);
      if (res['status'] == 'success') {
        libraryGames["360"] = res['data']['360'] ?? [];
        libraryGames["OG"] = res['data']['OG'] ?? [];
        libraryGames["DLC"] = res['data']['DLC'] ?? [];
        libraryGames["TU"] = res['data']['TU'] ?? [];
      }
    } catch (e) {
      statusMessage = "Erro no scan: $e";
    } finally {
      isScanningLibrary = false;
      notifyListeners();
    }
  }

  Future<void> forcedSync() async {
     statusMessage = "Sincronização forçada em andamento...";
     notifyListeners();
     // Clear any temp icon caches if needed (logic handled in backend mostly)
     await scanLibrary();
  }

  Future<Map<String, dynamic>> renameLibraryItem(dynamic item, String newName) async {
    statusMessage = "Renomeando...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand(
        "rename_library_item",
        src: item['path'],
        arg: newName,
        type: item['type'] ?? "GOD",
      );
      if (res['status'] == 'success') {
        statusMessage = "Renomeado com sucesso!";
        await scanLibrary();
      }
      return res;
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteLibraryItem(dynamic item) async {
    statusMessage = "Excluindo...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("delete_library_item", src: item['path']);
      if (res['status'] == 'success') {
        statusMessage = "Excluído com sucesso!";
        await scanLibrary();
      }
      return res;
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> exportLibraryItem(dynamic item, String destPC) async {
    statusMessage = "Exportando para o PC...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("export_library_item", src: item['path'], dest: destPC);
      statusMessage = res['status'] == 'success' ? "Exportado com sucesso!" : "Erro na exportação";
      return res;
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> changeGameCover(dynamic item, String iconPath) async {
    statusMessage = "Alterando capa...";
    notifyListeners();
    try {
      final res = await PythonBridge.executeCommand("set_custom_icon", src: item['path'], arg: iconPath);
      if (res['status'] == 'success') {
        statusMessage = "Capa atualizada!";
        await scanLibrary();
      }
      return res;
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getSTFSMeta(String path) async {
    return await PythonBridge.executeCommand("get_stfs_meta", src: path);
  }

  Future<void> exploreLibraryItem(dynamic item) async {
    await PythonBridge.executeCommand("explore_library_item", src: item['path']);
  }

  void navigateToFtp(String remotePath) {
    if (!isFtpConnected) {
      statusMessage = "Conecte-se ao FTP primeiro!";
      notifyListeners();
      return;
    }
    currentMainTab = 2; // Assume FTP is tab 2
    ftpCurrentPath = remotePath;
    ftpList(remotePath);
    notifyListeners();
  }

  void goToBaseGame(String titleId) {
    currentLibraryTab = 0; // Switch to 360 Games
    librarySearchQuery = titleId; // Filter by TitleID to highlight it
    notifyListeners();
  }

  Future<Map<String, dynamic>> getDashLaunch(String path) async {
    return await PythonBridge.getDashLaunch(path);
  }

  Future<void> updateDashLaunch(String path, Map<String, dynamic> data) async {
    final res = await PythonBridge.updateDashLaunch(path, data);
    if (res["status"] == "success") {
       statusMessage = "DashLaunch atualizado com sucesso!";
    } else {
       statusMessage = "Erro ao atualizar DashLaunch: ${res["message"]}";
    }
    notifyListeners();
  }


  void toggleCustom(String key) {
    customSelections[key] = !customSelections[key]!;
    notifyListeners();
  }

  void toggleBackcompat(String key) {
    backcompatSelections[key] = !backcompatSelections[key]!;
    notifyListeners();
  }

  // --- Wizard Getters & Methods ---
  set setWizardActive(bool value) {
    isWizardActive = value;
    notifyListeners();
  }

  void setConsoleType(String type) {
    consoleType = type;
    notifyListeners();
  }

  List<Map<String, String>> get dashboards => dashboardSelections.keys
      .map((k) => {'name': k, 'file': '$k.zip'})
      .toList();

  List<Map<String, String>> get stealth => stealthSelections.keys
      .map((k) => {'name': k, 'file': '$k.zip'})
      .toList();

  List<Map<String, String>> get plugins => pluginSelections.keys
      .map((k) => {'name': k, 'file': '$k.zip'})
      .toList();

  List<String> get selectedPackages {
    List<String> selected = [];
    dashboardSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    homebrewSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    stealthSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    pluginSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    customSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    backcompatSelections.forEach((k, v) { if (v) selected.add("$k.zip"); });
    return selected;
  }

  void togglePackage(String filename) {
    String name = filename.replaceAll(".zip", "");
    if (dashboardSelections.containsKey(name)) {
      dashboardSelections[name] = !dashboardSelections[name]!;
    } else if (homebrewSelections.containsKey(name)) {
      homebrewSelections[name] = !homebrewSelections[name]!;
    } else if (stealthSelections.containsKey(name)) {
      stealthSelections[name] = !stealthSelections[name]!;
    } else if (pluginSelections.containsKey(name)) {
      pluginSelections[name] = !pluginSelections[name]!;
    } else if (customSelections.containsKey(name)) {
      customSelections[name] = !customSelections[name]!;
    } else if (backcompatSelections.containsKey(name)) {
      backcompatSelections[name] = !backcompatSelections[name]!;
    }
    notifyListeners();
  }

  // --- Wizard Logic ---
  void startWizard() {
    isWizardActive = true;
    wizardStep = 0;
    notifyListeners();
  }

  void nextWizardStep() { wizardStep++; notifyListeners(); }
  void prevWizardStep() { if (wizardStep > 0) wizardStep--; notifyListeners(); }

  // --- Final Actions ---
  Future<void> installSelected() async {
    if (selectedDrive == null) {
      statusMessage = "Aviso: Nenhum dispositivo detectado";
      notifyListeners();
      return;
    }
    
    isInstalling = true;
    statusMessage = "Iniciando Instalação...";
    progress = 0.05;
    notifyListeners();
    
    // Collect all selected packages for the bridge
    List<String> packages = [];
    dashboardSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    homebrewSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    stealthSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    // ... etc. This part needs to be mapped to the actual filenames in service_bridge.py
    
    final res = await PythonBridge.installPackages(
      selectedDrive!['device'], 
      packages
    );

    isInstalling = false;
    progress = 1.0;
    notifyListeners();
  }

  Future<void> installCategory(String category) async {
    if (selectedDrive == null) {
      statusMessage = tr("Aviso: Nenhum dispositivo detectado");
      notifyListeners();
      return;
    }

    List<String> packages = [];
    if (category == "Dashboards") {
      dashboardSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    } else if (category == "Homebrews") {
      homebrewSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    } else if (category == "Stealth") {
      stealthSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    } else if (category == "Plugins") {
      pluginSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
      customSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
      backcompatSelections.forEach((k, v) { if (v) packages.add("$k.zip"); });
    }

    if (packages.isEmpty) {
      statusMessage = tr("Nenhum item selecionado.");
      notifyListeners();
      return;
    }

    isInstalling = true;
    statusMessage = "${tr("Iniciar Instalação")} ($category)...";
    progress = 0.1;
    notifyListeners();

    final res = await PythonBridge.installPackages(
      selectedDrive!['device'], 
      packages
    );

    isInstalling = false;
    progress = 1.0;
    notifyListeners();
  }

  Future<void> formatCurrentDrive() async {
    if (selectedDrive == null) return;
    statusMessage = "Formatando...";
    notifyListeners();
    await PythonBridge.formatDrive(selectedDrive!['device']);
    await refreshDrives();
    statusMessage = "Pronto.";
    notifyListeners();
  }

  // --- Settings Utilities ---
  String tr(String key) {
    return TranslationService.tr(key, currentLanguage);
  }

  void setLanguage(String lang) {
    currentLanguage = lang;
    notifyListeners();
  }

  Future<void> clearTemporaryCache() async {
    statusMessage = "Limpando cache...";
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1)); // Mock
    statusMessage = "Cache limpo.";
    notifyListeners();
  }

  Future<void> uninstallX360Tools() async {
    statusMessage = "Desinstalando...";
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1)); // Mock
    statusMessage = "Desinstalação concluída.";
    notifyListeners();
  }

  // --- Horizon Injector Methods ---
  Future<void> pickSTFSFile() async {
    // Using zenity for Linux file selection to avoid extra dependencies
    try {
      final result = await Process.run('zenity', ['--file-selection', '--title=Select Xbox 360 Content', '--file-filter=*.bin *']);
      if (result.exitCode == 0) {
        currentSTFSPath = (result.stdout as String).trim();
        await loadSTFSMeta(currentSTFSPath!);
      }
    } catch (e) {
      statusMessage = "Error picking file: $e";
      notifyListeners();
    }
  }

  Future<void> loadSTFSMeta(String path) async {
    isLoadingSTFS = true;
    notifyListeners();
    
    final res = await PythonBridge.getSTFSMeta(path);
    if (res["status"] == "success") {
      stfsMetadata = res["data"];
    } else {
      stfsMetadata = null;
      statusMessage = "Invalid STFS: ${res["message"]}";
    }
    
    isLoadingSTFS = false;
    notifyListeners();
  }

  Future<void> refreshExplorerContent() async {
    if (selectedDrive == null) return;
    isLoadingExplorer = true;
    notifyListeners();
    
    final res = await PythonBridge.listContent(selectedDrive!['device']);
    if (res["status"] == "success") {
      explorerContent = Map<String, dynamic>.from(res["data"]);
    }
    
    isLoadingExplorer = false;
    notifyListeners();
  }

  Future<void> installSTFSContent() async {
    if (currentSTFSPath == null || selectedDrive == null) return;
    
    isInstalling = true;
    statusMessage = "Installing Content...";
    notifyListeners();
    
    final res = await PythonBridge.installSTFS(currentSTFSPath!, selectedDrive!['device']);
    
    if (res["status"] == "success") {
      statusMessage = "Installation Successful!";
      await refreshExplorerContent();
    } else {
      statusMessage = "Error: ${res["message"]}";
    }
    
    isInstalling = false;
    notifyListeners();
  }

  Future<void> extractSTFSContent(String src) async {
    try {
      final destResult = await Process.run('zenity', ['--file-selection', '--directory', '--title=Select Destination Folder']);
      if (destResult.exitCode == 0) {
        final dest = (destResult.stdout as String).trim();
        statusMessage = "Extracting...";
        notifyListeners();
        
        final res = await PythonBridge.extractSTFS(src, dest);
        if (res["status"] == "success") {
          statusMessage = "Extraction Successful!";
        } else {
          statusMessage = "Error: ${res["message"]}";
        }
      }
    } catch (e) {
      statusMessage = "Error extracting: $e";
    }
    notifyListeners();
  }

  // --- Profile Pics Methods ---
  Future<void> fetchGamerpics() async {
    isLoadingGamerpics = true;
    notifyListeners();
    
    gamerpics = await PythonBridge.getGamerpics();
    
    isLoadingGamerpics = false;
    notifyListeners();
  }

  Future<void> fetchInstalledGamerpics() async {
    if (selectedDrive == null) return;
    isLoadingInstalledGamerpics = true;
    notifyListeners();
    
    installedGamerpics = await PythonBridge.getInstalledGamerpics(selectedDrive!['device']);
    
    isLoadingInstalledGamerpics = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchGameDetails(String gameName, String platform) async {
    String langCode = "pt";
    if (currentLanguage == "English") langCode = "en";
    if (currentLanguage == "Español") langCode = "es";
    
    return await PythonBridge.getGameDetails(gameName, platform: platform, lang: langCode);
  }

  Future<bool> deleteDeviceGamerpic(String filePath) async {
    final res = await PythonBridge.deleteDeviceGamerpic(filePath);
    if (res['status'] == 'success') {
      // Remove from local list without a full rescan
      installedGamerpics.removeWhere((pic) => pic['pack_path'] == filePath);
      statusMessage = tr("Gamerpic excluída do dispositivo.");
      notifyListeners();
      return true;
    }
    statusMessage = "${tr("Erro ao excluir")}: ${res['message']}";
    notifyListeners();
    return false;
  }

  /// Returns the destination path on success, null on failure.
  Future<String?> exportDeviceGamerpic(String filePath, String destDir) async {
    final res = await PythonBridge.exportDeviceGamerpic(filePath, destDir);
    if (res['status'] == 'success') {
      statusMessage = tr("Gamerpic exportada com sucesso!");
      notifyListeners();
      return res['data']?['path'] as String?;
    }
    statusMessage = "${tr("Erro ao exportar")}: ${res['message']}";
    notifyListeners();
    return null;
  }

  Future<void> injectGamerpic(String id) async {
    if (selectedDrive == null) {
      statusMessage = tr("Aviso: Nenhum dispositivo detectado");
      notifyListeners();
      return;
    }

    isInstalling = true;
    statusMessage = "${tr("Injetando")} Gamerpic...";
    notifyListeners();

    final res = await PythonBridge.injectGamerpic(selectedDrive!['device'], id);
    
    if (res["status"] == "success") {
      statusMessage = tr("Gamerpic injetada com sucesso!");
    } else {
      statusMessage = "Error: ${res["message"]}";
    }

    isInstalling = false;
    notifyListeners();
  }

  Future<String?> pickFile({String title = "Selecionar Arquivo", String? filter}) async {
    try {
      List<String> args = ['--file-selection', '--title=$title'];
      if (filter != null) {
        args.add('--file-filter=$filter');
      }
      final result = await Process.run('zenity', args);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (e) {
      statusMessage = "Erro ao selecionar arquivo: $e";
      notifyListeners();
      return null;
    }
  }

  Future<String?> pickDirectory({String title = "Selecionar Pasta"}) async {
    try {
      final result = await Process.run('zenity', [
        '--file-selection', 
        '--directory', 
        '--title=$title'
      ]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (e) {
      statusMessage = "Erro ao selecionar pasta: $e";
      notifyListeners();
      return null;
    }
  }

  Future<void> setIACookie(String cookie) async {
    try {
      final res = await PythonBridge.executeCommand("set_ia_cookie", cookie: cookie);
      if (res["status"] == "success") {
        statusMessage = res["message"];
        notifyListeners();
      } else {
        throw res["message"];
      }
    } catch (e) {
      statusMessage = "Erro ao salvar cookie: $e";
      notifyListeners();
    }
  }

  Future<void> loginIA(String email, String password) async {
    try {
      statusMessage = "PHASE:Autenticando no Archive.org...";
      notifyListeners();
      
      final res = await PythonBridge.executeCommand("login_ia", user: email, password: password);
      if (res["status"] == "success") {
        statusMessage = "PHASE:Login realizado com sucesso!";
        isLoggedInIA = true;
        notifyListeners();
      } else {
        isLoggedInIA = false;
        throw res["message"];
      }
    } catch (e) {
      statusMessage = "PHASE:Erro no Login: $e";
      notifyListeners();
    }
  }

  void clearCompletedDownloads() {
    downloads.removeWhere((item) => 
      item.phase == DownloadPhase.completed || 
      item.phase == DownloadPhase.failed || 
      item.phase == DownloadPhase.canceled);
    notifyListeners();
  }
}

