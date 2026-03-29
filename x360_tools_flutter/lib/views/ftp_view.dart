import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class FtpView extends StatefulWidget {
  const FtpView({super.key});

  @override
  State<FtpView> createState() => _FtpViewState();
}

class _FtpViewState extends State<FtpView> {
  final TextEditingController _ipController = TextEditingController();

  void _connect(AppState state) async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Digite o IP do Xbox.")));
      return;
    }
    await state.ftpConnect(ip);
  }

  void _uploadFile(AppState state) async {
    final file = await state.pickFile(title: state.tr("Selecione um arquivo para enviar ao Xbox"));
    if (file != null) {
      await state.ftpUpload(file, state.ftpCurrentPath);
    }
  }

  void _createFolder(AppState state) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: state.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text(state.tr("Nova Pasta"), style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: state.tr("Nome da pasta"),
            hintStyle: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF107C10))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.tr("Cancelar"), style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.isNotEmpty) {
                String newPath = state.ftpCurrentPath;
                if (!newPath.endsWith("/")) newPath += "/";
                newPath += ctrl.text;
                state.ftpMkdir(newPath);
              }
            },
            child: Text(state.tr("Criar")),
          ),
        ],
      ),
    );
  }

  void _deleteItem(AppState state, String name, bool isDir) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: state.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text(state.tr("Confirmar Exclusão"), style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black)),
        content: Text(
          "${state.tr("Deseja deletar")} '$name'?", 
          style: TextStyle(color: state.isDarkMode ? Colors.white70 : Colors.black87)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.tr("Cancelar"), style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              String targetPath = state.ftpCurrentPath;
              if (!targetPath.endsWith("/")) targetPath += "/";
              targetPath += name;
              state.ftpDelete(targetPath, isDir);
            },
            child: Text(state.tr("Deletar")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: state.isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C10).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.wifi_tethering, color: Color(0xFF107C10), size: 36),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "FTP Wireless Manager",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: state.isDarkMode ? Colors.white : Colors.black, letterSpacing: -1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.tr("Gerencie e instale arquivos no Xbox 360 pelo ar (Requer Aurora/FSD3)."),
                      style: TextStyle(fontSize: 14, color: state.isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Connection Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    enabled: !state.isFtpConnected,
                    style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: "192.168.0.X",
                      hintStyle: TextStyle(color: state.isDarkMode ? Colors.white24 : Colors.black26),
                      labelText: state.tr("Endereço IP do Xbox 360"),
                      labelStyle: const TextStyle(color: Color(0xFF107C10)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF107C10), width: 2),
                      ),
                      prefixIcon: Icon(Icons.router, color: state.isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  height: 60,
                  width: 200,
                  child: ElevatedButton(
                    onPressed: state.isLoadingFtp ? null : () {
                      if (state.isFtpConnected) {
                        state.ftpDisconnect();
                      } else {
                        _connect(state);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isFtpConnected ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF107C10),
                      foregroundColor: state.isFtpConnected ? Colors.redAccent : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: state.isLoadingFtp
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            state.isFtpConnected ? state.tr("DESCONECTAR") : state.tr("CONECTAR"),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // File Explorer Panel
          Expanded(
            child: state.isFtpConnected
                ? _buildFileExplorer(state)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.satellite_alt, size: 80, color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                        const SizedBox(height: 24),
                        Text(
                          state.tr("Nenhuma conexão ativa."),
                          style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.tr("Certifique-se de que a Aurora ou Freestyle estão abertas no console e o FTP ativado."),
                          style: TextStyle(color: state.isDarkMode ? Colors.white24 : Colors.black38, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer(AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: state.isDarkMode ? const Color(0xFF121212) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: state.isDarkMode ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_upward, color: state.isDarkMode ? Colors.white70 : Colors.black87),
                  tooltip: "Acima",
                  onPressed: () {
                    if (state.ftpCurrentPath != "/") {
                      final parts = state.ftpCurrentPath.split('/').where((p) => p.isNotEmpty).toList();
                      if (parts.isNotEmpty) parts.removeLast();
                      final newPath = "/" + parts.join('/');
                      state.ftpList(newPath == "/" ? "" : newPath);
                    }
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    state.ftpCurrentPath.isEmpty ? "/" : state.ftpCurrentPath,
                    style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF107C10)),
                  tooltip: state.tr("Atualizar"),
                  onPressed: () => state.ftpList(state.ftpCurrentPath),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _createFolder(state),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                  icon: const Icon(Icons.create_new_folder),
                  label: Text(state.tr("Nova Pasta")),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _uploadFile(state),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10), foregroundColor: Colors.white),
                  icon: const Icon(Icons.upload_file),
                  label: Text(state.tr("Enviar Arquivo")),
                ),
              ],
            ),
          ),
          
          // File List
          Expanded(
            child: state.isLoadingFtp
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
                : ListView.builder(
                    itemCount: state.ftpCurrentDir.length,
                    itemBuilder: (context, index) {
                      final item = state.ftpCurrentDir[index];
                      final isDir = item['is_dir'] == true;
                      return ListTile(
                        leading: Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          color: isDir ? const Color(0xFF107C10) : (state.isDarkMode ? Colors.white54 : Colors.black54),
                          size: 32,
                        ),
                        title: Text(item['name'], style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black)),
                        subtitle: Text(item['size'].toString(), style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: state.isDarkMode ? Colors.white38 : Colors.black45),
                          onPressed: () => _deleteItem(state, item['name'], isDir),
                        ),
                        onTap: () {
                          if (isDir) {
                            String target = state.ftpCurrentPath;
                            if (target != "/") target += "/";
                            target += item['name'];
                            state.ftpList(target);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
