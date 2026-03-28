import 'package:flutter/material.dart';
import 'dart:io';
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
  String? localPath;
  DateTime startTime;
  String? speed;
  String? eta;

  DownloadItem({
    required this.id,
    required this.name,
    required this.url,
    required this.platform,
    required this.destPath,
    this.phase = DownloadPhase.waiting,
    this.statusMessage = "Aguardando...",
    this.progress = 0.0,
    this.localPath,
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

  AppState() {
    _init();
  }

  Future<void> _init() async {
    await refreshDrives();
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

  void cancelDownload(String id) {
    PythonBridge.cancelDownload(id);
    final item = downloads.firstWhere((d) => d.id == id, orElse: () => DownloadItem(id: "", name: "", url: "", platform: "", destPath: ""));
    if (item.id.isNotEmpty) {
      item.phase = DownloadPhase.canceled;
      item.statusMessage = "Cancelado pelo usuário";
      item.progress = 0;
      notifyListeners();
    }
  }

  Future<void> installFromFreemarket(Map<String, dynamic> game, String destPath, bool onDevice) async {
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: downloadId,
      name: game['name'] ?? "Unknown",
      url: game['url'] ?? "",
      platform: game['platform'] ?? "360",
      destPath: destPath,
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
            final pStr = line.replaceFirst("Progress:", "").replaceAll("%", "").trim();
            final p = double.tryParse(pStr);
            if (p != null) item.progress = p / 100.0;
          } else if (line.startsWith("PHASE:")) {
            item.statusMessage = line.replaceFirst("PHASE:", "").trim();
            final status = item.statusMessage.toLowerCase();
            if (status.contains("espaço")) item.phase = DownloadPhase.checkingSpace;
            else if (status.contains("baixando")) item.phase = DownloadPhase.downloading;
            else if (status.contains("extraindo")) item.phase = DownloadPhase.extracting;
            else if (status.contains("convertendo")) item.phase = DownloadPhase.converting;
            else if (status.contains("processando")) item.phase = DownloadPhase.installing;
            else if (status.contains("concluída")) {
               item.phase = DownloadPhase.completed;
               item.progress = 1.0;
            }
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
        // Determine installation folder
        if (item.platform == "360") {
           item.localPath = "$destPath/Content/0000000000000000";
        } else {
           item.localPath = "$destPath/Games/${item.name}";
        }
      } else {
        item.phase = DownloadPhase.failed;
        item.statusMessage = "Falha: ${res["message"]}";
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

    isInstalling = true;
    statusMessage = "Baixando Title Update...";
    progress = 0.0;
    notifyListeners();

    try {
      final stream = PythonBridge.installTU(
        url: tu['DownloadUrl'] ?? "",
        name: "TU_Update.bin", 
        titleId: titleId,
        dest: selectedDrive!['device'],
      );

      await for (final line in stream) {
        if (line.startsWith("Progress:")) {
          final pStr = line.replaceFirst("Progress:", "").replaceAll("%", "").trim();
          final p = double.tryParse(pStr);
          if (p != null) progress = p / 100.0;
        } else if (line.startsWith("Status:")) {
          statusMessage = line.replaceFirst("Status:", "").trim();
        }
        notifyListeners();
      }

      statusMessage = "TU Instalada com sucesso!";
      progress = 1.0;
    } catch (e) {
      statusMessage = "Erro ao instalar TU: $e";
    }

    isInstalling = false;
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
    
    statusMessage = res["message"] ?? "Concluído.";
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

    statusMessage = res["message"] ?? tr("Concluído.");
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
    return await PythonBridge.getGameDetails(gameName, platform: platform);
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
}

