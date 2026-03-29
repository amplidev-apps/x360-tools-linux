import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PythonBridge {
  static String get _bridgeScript {
    if (Platform.isWindows) {
      // When bundled in MSIX/Exe, assets are in data/flutter_assets/assets/python_backend/
      final String exePath = Platform.resolvedExecutable;
      final Directory exeDir = File(exePath).parent;
      final String assetPath = "${exeDir.path}\\data\\flutter_assets\\assets\\python_backend\\service_bridge.py";
      
      if (File(assetPath).existsSync()) {
        return assetPath;
      }
      
      // Fallback for debug/development
      return 'assets/python_backend/service_bridge.py';
    }
    return '../service_bridge.py';
  }
  
  static String? get _bridgeDir {
    if (Platform.isWindows) {
      final String script = _bridgeScript;
      if (script.contains('\\')) {
        return script.substring(0, script.lastIndexOf('\\'));
      }
    }
    return null; // Current dir for Linux
  }

  static String get _pythonCmd => Platform.isWindows ? 'python' : 'python3';
  static final Map<String, Process> _activeProcesses = {};

  static Future<void> cancelDownload(String id) async {
    // 1. Send signal through bridge (kills subprocesses)
    await _runCommand("cancel_download", id: id);
    // 2. Kill the bridge process itself if still running
    _activeProcesses[id]?.kill();
    _activeProcesses.remove(id);
  }

  static Future<void> pauseDownload(String id) async {
    await _runCommand("pause_download", id: id);
  }

  static Future<void> resumeDownload(String id) async {
    await _runCommand("resume_download", id: id);
  }

  static void cancelCurrentInstall() {
    // Legacy alias to kill the last active process if any
    if (_activeProcesses.isNotEmpty) {
       final lastId = _activeProcesses.keys.last;
       cancelDownload(lastId);
    }
  }

  static Future<Map<String, dynamic>> _runCommand(
      String cmd, {
      String? arg, 
      String? platform, 
      String? category, 
      List<String>? packages, 
      String? device,
      String? src,
      String? dest,
      String? mode,
      String? id,
      String? name,
      String? crop,
      bool gallery = false,
      bool cleanup = false,
      bool refresh = false,
      bool isDir = false,
      String? lang,
      String? host,
      String? remotePath,
      String? localPath,
      String? type,
      String? cookie,
      String? user,
      String? password,
      String? iaUser,
      String? iaPass,
  }) async {
    final List<String> args = [_bridgeScript, '--cmd', cmd];
    if (arg != null) args.addAll(['--arg', arg]);
    if (platform != null) args.addAll(['--platform', platform]);
    if (category != null) args.addAll(['--category', category]);
    if (packages != null) args.addAll(['--packages', json.encode(packages)]);
    if (device != null) args.addAll(['--device', device]);
    if (src != null) args.addAll(['--src', src]);
    if (dest != null) args.addAll(['--dest', dest]);
    if (mode != null) args.addAll(['--mode', mode]);
    if (cleanup) args.add('--cleanup');
    if (refresh) args.add('--refresh');
    if (id != null) args.addAll(['--id', id]);
    if (name != null) args.addAll(['--name', name]);
    if (crop != null) args.addAll(['--crop', crop]);
    if (user != null) args.addAll(['--user', user]); // FTP User
    if (password != null) args.addAll(['--passwd', password]); // FTP Pass
    if (iaUser != null) args.addAll(['--ia-user', iaUser]); // IA User
    if (iaPass != null) args.addAll(['--ia-pass', iaPass]); // IA Pass
    if (gallery) args.add('--gallery');
    if (lang != null) args.addAll(['--lang', lang]);
    if (host != null) args.addAll(['--host', host]);
    if (remotePath != null) args.addAll(['--remote-path', remotePath]);
    if (localPath != null) args.addAll(['--local-path', localPath]);
    if (isDir) args.add('--is-dir');
    if (type != null) args.addAll(['--type', type]);
    if (cookie != null) args.addAll(['--cookie', cookie]);

    try {
      final Process process = await Process.start(_pythonCmd, args, workingDirectory: _bridgeDir);
      
      final StringBuffer stdoutBuffer = StringBuffer();
      final StringBuffer stderrBuffer = StringBuffer();
      
      // Collect stdout and stderr concurrently
      final stdoutCollector = process.stdout.transform(utf8.decoder).forEach(stdoutBuffer.write);
      final stderrCollector = process.stderr.transform(utf8.decoder).forEach(stderrBuffer.write);
          
      final int exitCode = await process.exitCode.timeout(const Duration(seconds: 45));
      await Future.wait([stdoutCollector, stderrCollector]);

      if (exitCode == 0) {
        final String output = stdoutBuffer.toString().trim();
        // The bridge may output warnings before the actual JSON result.
        // We find the first '{' to extract the JSON payload.
        int firstBrace = output.indexOf('{');
        if (firstBrace == -1) {
             return {"status": "error", "message": "No valid JSON response from bridge. Raw output was: $output"};
        }
        String cleanJson = output.substring(firstBrace).trim();
        
        // Final sanity check: find the last '}'
        int lastBrace = cleanJson.lastIndexOf('}');
        if (lastBrace != -1) {
          cleanJson = cleanJson.substring(0, lastBrace + 1);
        }

        if (cleanJson.length > 10000) {
          return await compute(_decodeJson, cleanJson);
        } else {
          return json.decode(cleanJson) as Map<String, dynamic>;
        }
      } else {
        return {
          "status": "error",
          "message": "Process failed (Code $exitCode): ${stderrBuffer.toString()}"
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Failed to run bridge or timeout: $e"};
    }
  }

  static Map<String, dynamic> _decodeJson(String source) {
    return json.decode(source) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> listDrives() async {
    final res = await _runCommand("list_drives");
    if (res["status"] == "success") return res["data"] as List;
    return [];
  }

  static Future<List<dynamic>> getPackages({String? category}) async {
    final res = await _runCommand("get_packages", category: category);
    if (res["status"] == "success") return res["data"] as List;
    return [];
  }

  static Future<List<dynamic>> fetchGames(String platform, {bool refresh = false}) async {
    final res = await _runCommand("fetch_games", platform: platform, refresh: refresh);
    if (res["status"] == "success") return res["data"] as List;
    return [];
  }

  static Future<bool> formatDrive(String device) async {
    final res = await _runCommand("format_drive", arg: device);
    return res["status"] == "success";
  }

  static Future<Map<String, dynamic>> installPackages(String device, List<String> packages) async {
    return await _runCommand("install", device: device, packages: packages);
  }

  static Future<Map<String, dynamic>> getSTFSMeta(String path) async {
    return await _runCommand("get_stfs_meta", src: path);
  }

  static Future<Map<String, dynamic>> listContent(String device) async {
    return await _runCommand("list_content", device: device);
  }

  static Future<Map<String, dynamic>> convertIso(String src, String dest, String mode, {String? device, bool cleanup = false}) async {
    return await _runCommand("convert_iso", src: src, dest: dest, mode: mode, device: device, cleanup: cleanup);
  }

  static Future<Map<String, dynamic>> setDashLaunchConfig(String option, dynamic value, {String? device}) async {
    return await _runCommand("dashlaunch_set", arg: option, device: device, src: value.toString());
  }

  // --- Added Generic & FTP Commands ---
  static Future<Map<String, dynamic>> executeCommand(String cmd, {
    String? arg, 
    String? src, 
    String? type, 
    String? device, 
    String? dest, 
    String? cookie, 
    String? user, 
    String? password,
    String? iaUser,
    String? iaPass,
  }) async {
    return await _runCommand(
      cmd, 
      arg: arg, 
      src: src, 
      type: type, 
      device: device, 
      dest: dest, 
      cookie: cookie, 
      user: user, 
      password: password,
      iaUser: iaUser,
      iaPass: iaPass,
    );
  }

  static Future<Map<String, dynamic>> ftpCommand(String cmd, {
    String? host, 
    String? remotePath, 
    String? localPath, 
    String? user,
    String? password,
    bool isDir = false,
  }) async {
    return await _runCommand(
      cmd, 
      host: host, 
      remotePath: remotePath, 
      localPath: localPath, 
      user: user,
      password: password,
      isDir: isDir
    );
  }

  static Future<Map<String, dynamic>> installSTFS(String src, String device) async {
    return await _runCommand("install_stfs", src: src, device: device);
  }

  static Future<Map<String, dynamic>> extractSTFS(String src, String dest) async {
    return await _runCommand("extract_stfs", src: src, dest: dest);
  }

  static Future<Map<String, dynamic>> createBackup(String device, String destPath, {String? label, Function(String)? onProgress}) async {
    final List<String> args = [_bridgeScript, '--cmd', 'create_backup', '--device', device, '--dest', destPath];
    if (label != null && label.isNotEmpty) {
      args.addAll(['--label', label]);
    }
    final process = await Process.start(_pythonCmd, args, workingDirectory: _bridgeDir);
    
    String? lastLine;
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      if (trimmed.startsWith('{')) {
        lastLine = trimmed;
      } else {
        onProgress?.call(trimmed);
      }
    }
    
    if (lastLine != null) return json.decode(lastLine);
    final err = await process.stderr.transform(utf8.decoder).join();
    return {"status": "error", "message": err.isNotEmpty ? err : "No response from bridge"};
  }

  static Future<Map<String, dynamic>> restoreBackup(String backupPath, String device, {String? label, Function(String)? onProgress}) async {
    final List<String> args = [_bridgeScript, '--cmd', 'restore_backup', '--src', backupPath, '--device', device];
    if (label != null && label.isNotEmpty) {
      args.addAll(['--label', label]);
    }
    final process = await Process.start(_pythonCmd, args, workingDirectory: _bridgeDir);
    
    String? lastLine;
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('{')) {
        lastLine = trimmed;
      } else {
        onProgress?.call(trimmed);
      }
    }
    
    if (lastLine != null) return json.decode(lastLine);
    final err = await process.stderr.transform(utf8.decoder).join();
    return {"status": "error", "message": err.isNotEmpty ? err : "No response from bridge"};
  }

  static Future<Map<String, dynamic>> getDeviceSummary(String device) async {
    return await _runCommand("get_device_summary", device: device);
  }

  static Future<Map<String, dynamic>> getGameDetails(String name, {String platform = "360", String lang = "pt"}) async {
    return await _runCommand("get_game_details", name: name, platform: platform, lang: lang);
  }

  static Future<Map<String, dynamic>> installGame(
    String id,
    String url, 
    String name, 
    String platform, 
    String device, 
    {bool onDevice = true, Function(String)? onProgress}
  ) async {
    final List<String> args = [
      _bridgeScript, 
      '--cmd', 'install_game', 
      '--url', url, 
      '--name', name, 
      '--platform', platform, 
      '--device', device, 
      '--on-device', onDevice.toString()
    ];

    final process = await Process.start(_pythonCmd, args, workingDirectory: _bridgeDir);
    _activeProcesses[id] = process;
    
    String? lastLine;
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      if (trimmed.startsWith('{')) {
        lastLine = trimmed;
      } else {
        onProgress?.call(trimmed);
      }
    }
    
    _activeProcesses.remove(id);
    
    if (lastLine != null) return json.decode(lastLine);
    final err = await process.stderr.transform(utf8.decoder).join();
    return {"status": "error", "message": err.isNotEmpty ? err : "No response from bridge"};
  }

  static Future<Map<String, dynamic>> installDLC(
    String id,
    String url, 
    String name, 
    String titleId, 
    String device, 
    {Function(String)? onProgress}
  ) async {
    final List<String> args = [
      _bridgeScript, 
      '--cmd', 'install_dlc', 
      '--url', url, 
      '--name', name, 
      '--title-id', titleId, 
      '--device', device
    ];

    final process = await Process.start(_pythonCmd, args, workingDirectory: _bridgeDir);
    _activeProcesses[id] = process;
    
    String? lastLine;
    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      if (trimmed.startsWith('{')) {
        lastLine = trimmed;
      } else {
        onProgress?.call(trimmed);
      }
    }
    
    _activeProcesses.remove(id);
    
    if (lastLine != null) return json.decode(lastLine);
    final err = await process.stderr.transform(utf8.decoder).join();
    return {"status": "error", "message": err.isNotEmpty ? err : "No response from bridge"};
  }

  static Future<Map<String, dynamic>> getBackupSummary(String srcPath) async {
    return await _runCommand("get_backup_summary", src: srcPath);
  }

  static Future<List<dynamic>> getGamerpics() async {
    final res = await _runCommand("get_gamerpics");
    if (res["status"] == "success") return res["data"] as List;
    return [];
  }

  static Future<Map<String, dynamic>> injectGamerpic(String device, String id) async {
    return await _runCommand("inject_gamerpic", device: device, id: id);
  }

  static Future<Map<String, dynamic>> createCustomGamerpic({
    required String src,
    String name = "Custom Gamerpic",
    String? device,
    String? cropJson,
    bool saveToGallery = false,
  }) async {
    return await _runCommand(
      "create_custom_gamerpic",
      src: src,
      name: name,
      device: device,
      crop: cropJson,
      gallery: saveToGallery,
    );
  }

  static Future<List<dynamic>> getInstalledGamerpics(String device) async {
    final res = await _runCommand("get_installed_gamerpics", device: device);
    if (res["status"] == "success") return res["data"] as List;
    return [];
  }

  static Future<Map<String, dynamic>> deleteDeviceGamerpic(String filePath) async {
    return await _runCommand("delete_device_gamerpic", src: filePath);
  }

  static Future<Map<String, dynamic>> exportDeviceGamerpic(String filePath, String destDir) async {
    return await _runCommand("export_device_gamerpic", src: filePath, dest: destDir);
  }

  static Stream<String> installTU({
    required String url,
    required String name,
    required String titleId,
    required String dest,
  }) async* {
    final process = await Process.start(_pythonCmd, [
      _bridgeScript,
      '--cmd', 'install_tu',
      '--url', url,
      '--name', name,
      '--title-id', titleId,
      '--device', dest,
    ]);

    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) {
        yield line;
      }
    }
  }

  static Future<Map<String, dynamic>> scanLibrary(String device) async {
    return await _runCommand("scan_library", device: device);
  }

  static Future<Map<String, dynamic>> getDashLaunch(String path) async {
    return await _runCommand("get_dashlaunch", src: path);
  }

  static Future<Map<String, dynamic>> updateDashLaunch(String path, Map<String, dynamic> data) async {
    return await _runCommand("update_dashlaunch", dest: path, arg: jsonEncode(data));
  }

  static Future<Map<String, dynamic>> openFolder(String path) async {
    return await _runCommand("open_folder", dest: path);
  }
}

