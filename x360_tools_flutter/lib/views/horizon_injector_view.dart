import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'dart:io';

class HorizonInjectorView extends StatefulWidget {
  const HorizonInjectorView({super.key});

  @override
  State<HorizonInjectorView> createState() => _HorizonInjectorViewState();
}

class _HorizonInjectorViewState extends State<HorizonInjectorView> {
  bool _isExplorerMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshExplorerContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.tr("x360 Landscape"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      state.tr(_isExplorerMode 
                        ? "Explore e extraia conteúdo do seu dispositivo USB." 
                        : "Injete DLCs, TUs e Saves diretamente no seu Xbox 360."),
                      style: TextStyle(fontSize: 16, color: state.isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                decoration: BoxDecoration(
                  color: state.isDarkMode ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _buildModeButton(state, state.tr("INJETOR"), !_isExplorerMode),
                    _buildModeButton(state, state.tr("EXPLORADOR"), _isExplorerMode),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (_isExplorerMode)
                IconButton(
                  onPressed: () => state.refreshExplorerContent(), 
                  icon: const Icon(Icons.refresh, color: Color(0xFF107C10))
                ),
            ],
          ),
          
          const SizedBox(height: 40),

          Expanded(
            child: _isExplorerMode ? _buildExplorerTab(state) : _buildInjectorTab(state),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(AppState state, String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isExplorerMode = label == context.read<AppState>().tr("EXPLORADOR")),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF107C10) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : (state.isDarkMode ? Colors.white54 : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInjectorTab(AppState state) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => state.pickSTFSFile(),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 48, color: state.isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(state.tr("Clique para selecionar um arquivo STFS"), style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black87)),
                        if (state.currentSTFSPath != null)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(state.currentSTFSPath!, style: const TextStyle(fontSize: 12, color: Color(0xFF107C10))),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (state.stfsMetadata != null) _buildMetadataCard(state.stfsMetadata!, state),
              ],
            ),
          ),
          const SizedBox(width: 40),
          SizedBox(
            width: 350,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.tr("OPÇÕES DE INJEÇÃO"), style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 24),
                  Text(state.tr("Dispositivo Destino:"), style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black87, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: state.isDarkMode ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: state.selectedDrive?['device'],
                        dropdownColor: state.isDarkMode ? Colors.black : Colors.white,
                        items: state.drives.map((d) {
                          final drive = Map<String, dynamic>.from(d);
                          return DropdownMenuItem<String>(
                            value: drive['device'],
                            child: Text("${drive['label']} (${drive['size_gb']} GB)", style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final drive = state.drives.firstWhere((d) => d['device'] == val);
                          state.selectDrive(Map<String, dynamic>.from(drive));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (state.currentSTFSPath == null || state.isInstalling) ? null : () => state.installSTFSContent(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF107C10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: state.isInstalling 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(state.tr("INJETAR NO DISPOSITIVO"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(Map<String, dynamic> meta, AppState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF107C10).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state.tr("PACKAGE DETAILS"), style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: state.isDarkMode ? Colors.black : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
                ),
                child: meta['icon_path'] != null 
                  ? Image.file(File(meta['icon_path']))
                  : Icon(Icons.inventory_2_outlined, size: 40, color: state.isDarkMode ? Colors.white24 : Colors.black26),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta['display_name'] ?? "Unknown", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: state.isDarkMode ? Colors.white : Colors.black)),
                    Text(meta['type_name'] ?? "Unknown Type", style: const TextStyle(color: Color(0xFF107C10))),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildMetaInfo(state.tr("Title ID"), meta['title_id'] ?? "-", state),
                        const SizedBox(width: 40),
                        _buildMetaInfo(state.tr("Media ID"), meta['media_id'] ?? "-", state),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(String label, String value, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr(label), style: TextStyle(fontSize: 10, color: state.isDarkMode ? Colors.white38 : Colors.black87, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, color: state.isDarkMode ? Colors.white : Colors.black, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildExplorerTab(AppState state) {
    if (state.isLoadingExplorer) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)));
    }

    if (state.explorerContent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: state.isDarkMode ? Colors.white10 : Colors.black12),
            const SizedBox(height: 16),
            Text(state.tr("Nenhum conteúdo encontrado no dispositivo."), style: TextStyle(color: state.isDarkMode ? Colors.white24 : Colors.black54)),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemCount: state.explorerContent.length,
      itemBuilder: (context, index) {
        final tid = state.explorerContent.keys.elementAt(index);
        final game = state.explorerContent[tid];
        return _buildGameCard(tid, game, state);
      },
    );
  }

  Widget _buildGameCard(String tid, Map<String, dynamic> game, AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: state.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white70,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: state.isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: state.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: game['icon'] != null && File(game['icon']).existsSync()
                  ? Image.file(File(game['icon']), fit: BoxFit.contain)
                  : Icon(Icons.videogame_asset, size: 48, color: state.isDarkMode ? Colors.white10 : Colors.black12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(game['items'] as List).length} ${state.tr("itens no pacote")}",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF107C10)),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _showContentDetails(game, state),
                        icon: Icon(Icons.arrow_forward_ios, size: 14, color: state.isDarkMode ? Colors.white38 : Colors.black45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContentDetails(Map<String, dynamic> game, AppState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
        title: Text(game['name'], style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: (game['items'] as List).length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (context, index) {
              final item = game['items'][index];
              return ListTile(
                title: Text(item['display_name'], style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                subtitle: Text(item['type_name'], style: const TextStyle(color: Color(0xFF107C10), fontSize: 11)),
                trailing: IconButton(
                  icon: Icon(Icons.download, color: state.isDarkMode ? Colors.white54 : Colors.black54, size: 18),
                  onPressed: () {
                    Navigator.pop(context);
                    state.extractSTFSContent(item['file_path']);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(state.tr("FECHAR"), style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54))),
        ],
      ),
    );
  }
}
