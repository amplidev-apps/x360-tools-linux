import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/python_bridge.dart';

class BackupView extends StatefulWidget {
  const BackupView({super.key});

  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  bool _isProcessing = false;
  double _progress = 0.0;
  String _status = "Selecione uma ação para começar.";
  final TextEditingController _labelController = TextEditingController(text: "X360USB");

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onProgress(String message) {
    if (message.contains("Progress:")) {
      final regExp = RegExp(r"Progress: (\d+)%");
      final match = regExp.firstMatch(message);
      if (match != null) {
        setState(() {
          _progress = int.parse(match.group(1)!) / 100.0;
        });
      }
    }
    setState(() => _status = message);
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'sports_esports': return Icons.sports_esports;
      case 'dashboard': return Icons.dashboard;
      case 'apps': return Icons.apps;
      case 'settings': return Icons.settings;
      case 'system_update': return Icons.system_update;
      default: return Icons.folder;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  Future<bool> _showSummaryDialog(AppState state, String title, List<dynamic> summary, {bool isRestore = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: state.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: Row(
          children: [
            Icon(isRestore ? Icons.cloud_download : Icons.cloud_upload, color: const Color(0xFF107C10)),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRestore 
                  ? "Os seguintes itens serão instalados no seu dispositivo. O dispositivo será TOTALMENTE LIMPO antes da instalação."
                  : "Os seguintes itens foram identificados para o backup:",
                style: TextStyle(color: state.isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: state.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: summary.length,
                      separatorBuilder: (context, index) => Divider(color: state.isDarkMode ? Colors.white10 : Colors.black12, height: 1),
                      itemBuilder: (context, index) {
                        final item = summary[index];
                        return ListTile(
                          leading: Icon(_getIconData(item['icon']), color: const Color(0xFF107C10)),
                          title: Text(item['name'], style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['category']} • ${_formatSize(item['size_bytes'])}", style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (isRestore) const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text("ESSENCIAL: O dispositivo será formatado para garantir reconhecimento total no Xbox 360.", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("CANCELAR", style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
            child: Text(isRestore ? "LIMPAR E RESTAURAR" : "INICIAR BACKUP"),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleBackup() async {
    final state = context.read<AppState>();
    if (state.selectedDrive == null) {
      setState(() => _status = "Erro: Selecione um dispositivo para o backup.");
      return;
    }

    setState(() => _status = "Escaneando conteúdo do dispositivo...");
    final summaryRes = await PythonBridge.getDeviceSummary(state.selectedDrive!['device']);
    if (summaryRes['status'] != 'success') {
      setState(() => _status = "Erro ao escanear: ${summaryRes['message']}");
      return;
    }

    final confirmed = await _showSummaryDialog(state, "Resumo do Backup", summaryRes['summary']);
    if (!confirmed) {
      setState(() => _status = "Backup cancelado pelo usuário.");
      return;
    }

    final destPath = await state.pickDirectory(title: "Onde salvar o backup?");
    if (destPath == null) return;

    final label = _labelController.text.isNotEmpty ? _labelController.text : "X360USB";
    final date = DateTime.now().toString().split(' ')[0].replaceAll(':', '-');
    final fullDest = "$destPath/${label}_$date.x360b";

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = "Criando backup... Comprimindo arquivos.";
    });

    try {
      final res = await PythonBridge.createBackup(
        state.selectedDrive!['device'], 
        fullDest,
        label: _labelController.text,
        onProgress: _onProgress,
      );
      setState(() {
        _isProcessing = false;
        if (res["status"] == "success") {
          _status = "Backup concluído com sucesso!";
          _progress = 1.0;
        } else {
          _status = "Erro: ${res["message"]}";
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = "Erro: $e";
      });
    }
  }

  Future<void> _handleRestore() async {
    final state = context.read<AppState>();
    if (state.selectedDrive == null) {
      setState(() => _status = "Erro: Selecione um dispositivo de destino para a restauração.");
      return;
    }

    final backupPath = await state.pickFile(
      title: "Selecionar Arquivo de Backup",
      filter: "Backup x360 | *.x360b",
    );
    if (backupPath == null) return;

    setState(() => _status = "Analisando arquivo de backup...");
    final summaryRes = await PythonBridge.getBackupSummary(backupPath);
    if (summaryRes['status'] != 'success') {
      setState(() => _status = "Erro ao analisar backup: ${summaryRes['message']}");
      return;
    }

    String? finalLabel = summaryRes['label'];
    
    if (finalLabel != null && finalLabel.isNotEmpty) {
      bool? wantRename = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Nome do Backup Detectado", style: TextStyle(color: Colors.white)),
          content: Text("Este backup possui o nome \"$finalLabel\". O nome do seu dispositivo terá esse mesmo nome, deseja renomear?", style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("MANTER NOME", style: TextStyle(color: Colors.green))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("RENOMEAR", style: TextStyle(color: Colors.white70))),
          ],
        )
      );

      if (wantRename == true) {
        final TextEditingController renameCtrl = TextEditingController(text: finalLabel);
        final String? newName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text("Novo nome para o dispositivo", style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: renameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Máximo 11 caracteres",
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF107C10))),
              ),
              maxLength: 11,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, renameCtrl.text), 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
                child: const Text("DEFINIR NOME"),
              ),
            ],
          )
        );
        if (newName != null && newName.isNotEmpty) {
          finalLabel = newName;
        }
      }
    }

    final confirmed = await _showSummaryDialog(state, "Resumo da Restauração", summaryRes['summary'], isRestore: true);
    if (!confirmed) {
      setState(() => _status = "Restauração cancelada.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _status = "Restaurando backup... Extraindo arquivos.";
    });

    try {
      final res = await PythonBridge.restoreBackup(
        backupPath, 
        state.selectedDrive!['device'],
        label: finalLabel,
        onProgress: _onProgress,
      );
      setState(() {
        _isProcessing = false;
        if (res["status"] == "success") {
          _status = "Restauração concluída com sucesso!";
          _progress = 1.0;
        } else {
          _status = "Erro: ${res["message"]}";
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = "Erro: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_backup_restore, color: Color(0xFF107C10), size: 48),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.tr("Backup e Restauração"), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: state.isDarkMode ? Colors.white : Colors.black)),
                  Text(
                    state.tr("Salve ou restaure a configuração completa do seu dispositivo."),
                    style: TextStyle(fontSize: 16, color: state.isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Device Selector Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Icon(Icons.usb, color: state.isDarkMode ? Colors.white54 : Colors.black54),
                const SizedBox(width: 16),
                Text("Dispositivo:", style: TextStyle(fontWeight: FontWeight.bold, color: state.isDarkMode ? Colors.white : Colors.black)),
                const SizedBox(width: 24),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedDrive?['device'],
                      dropdownColor: state.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                      items: state.drives.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['device'],
                          child: Text("${d['label']} (${d['size_gb']} GB)", style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        final drive = state.drives.firstWhere((d) => d['device'] == v);
                        state.selectDrive(drive);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Backup Naming Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.black12 : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.label_important_outline, color: Color(0xFF107C10), size: 20),
                const SizedBox(width: 16),
                Text("Nome para o Backup:", style: TextStyle(color: state.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13)),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Máximo 11 caracteres",
                      hintStyle: TextStyle(color: state.isDarkMode ? Colors.white24 : Colors.black26),
                      border: InputBorder.none,
                      counterText: "",
                    ),
                    maxLength: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  state,
                  "CRIA BACKUP",
                  "Comprime todo o conteúdo em um arquivo .x360b",
                  Icons.cloud_upload,
                  _isProcessing ? null : _handleBackup,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildActionCard(
                  state,
                  "RESTAURAR",
                  "Extrai um arquivo .x360b para o dispositivo",
                  Icons.cloud_download,
                  _isProcessing ? null : _handleRestore,
                  isSecondary: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          if (_isProcessing) 
            Column(
              children: [
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: const Color(0xFF107C10),
                  backgroundColor: Colors.white10,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                if (_progress > 0)
                  Text(
                    "${(_progress * 100).toInt()}%",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF107C10)),
                  ),
              ],
            ),

          if (_status.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _status.contains("Erro") ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _status, 
                style: TextStyle(
                  color: _status.contains("Erro") ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(AppState state, String title, String subtitle, IconData icon, VoidCallback? onTap, {bool isSecondary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isSecondary ? (state.isDarkMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.05)) : const Color(0xFF107C10).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSecondary ? (state.isDarkMode ? Colors.white10 : Colors.black12) : const Color(0xFF107C10).withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 48, color: isSecondary ? (state.isDarkMode ? Colors.white : Colors.black) : const Color(0xFF107C10)),
              const SizedBox(height: 24),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: state.isDarkMode ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: state.isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
