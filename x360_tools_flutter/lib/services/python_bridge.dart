import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PythonBridge {
  static const String bridgeScript = '../service_bridge.py';
  static final Map<String, Process> _activeProcesses = {};

  static void cancelDownload(String id) {
    _activeProcesses[id]?.kill();
    _activeProcesses.remove(id);
  }

  static void cancelCurrentInstall() {
    // Legacy alias to kill the last active process if any
    if (_activeProcesses.isNotEmpty) {
       final lastId = _activeProcesses.keys.last;
       _activeProcesses[lastId]?.kill();
       _activeProcesses.remove(lastId);
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
  }) async {
    final List<String> args = ['python3', bridgeScript, '--cmd', cmd];
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
    if (gallery) args.add('--gallery');

    try {
      final ProcessResult result = await Process.run(args[0], args.sublist(1));
      if (result.exitCode == 0) {
        // Parse large JSON in a background isolate
        final String output = result.stdout as String;
        if (output.length > 5000) {
          return await compute(_decodeJson, output);
        } else {
          return json.decode(output) as Map<String, dynamic>;
        }
      } else {
        return {
          "status": "error",
          "message": "Process failed: ${result.stderr}"
        };
      }
    } catch (e) {
      return {"status": "error", "message": "Failed to run bridge: $e"};
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

  static Future<Map<String, dynamic>> installSTFS(String src, String device) async {
    return await _runCommand("install_stfs", src: src, device: device);
  }

  static Future<Map<String, dynamic>> extractSTFS(String src, String dest) async {
    return await _runCommand("extract_stfs", src: src, dest: dest);
  }

  static Future<Map<String, dynamic>> createBackup(String device, String destPath, {String? label, Function(String)? onProgress}) async {
    final List<String> args = ['python3', bridgeScript, '--cmd', 'create_backup', '--device', device, '--dest', destPath];
    if (label != null && label.isNotEmpty) {
      args.addAll(['--label', label]);
    }
    final process = await Process.start(args[0], args.sublist(1));
    
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
    final List<String> args = ['python3', bridgeScript, '--cmd', 'restore_backup', '--src', backupPath, '--device', device];
    if (label != null && label.isNotEmpty) {
      args.addAll(['--label', label]);
    }
    final process = await Process.start(args[0], args.sublist(1));
    
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

  static Future<Map<String, dynamic>> getGameDetails(String name, {String platform = "360"}) async {
    return await _runCommand("get_game_details", name: name, platform: platform);
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
      'python3', 
      bridgeScript, 
      '--cmd', 'install_game', 
      '--url', url, 
      '--name', name, 
      '--platform', platform, 
      '--device', device, 
      '--on-device', onDevice.toString()
    ];

    final process = await Process.start(args[0], args.sublist(1));
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
    final process = await Process.start('python3', [
      'service_bridge.py',
      '--cmd', 'install_tu',
      '--url', url,
      '--name', name,
      '--title_id', titleId,
      '--dest', dest,
    ]);

    await for (final line in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) {
        yield line;
      }
    }
  }

  static Future<Map<String, dynamic>> openFolder(String path) async {
    return await _runCommand("open_folder", dest: path);
  }
}

