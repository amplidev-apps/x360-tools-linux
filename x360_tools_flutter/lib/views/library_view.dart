import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'dart:io';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final state = context.read<AppState>();
      if (state.drives.isEmpty) {
        await state.refreshDrives();
      }
      if (state.selectedDrive != null) {
        await state.scanLibrary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: state.isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C10).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.library_books_rounded, color: Color(0xFF107C10), size: 32),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.tr("Minha Biblioteca"), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: state.isDarkMode ? Colors.white : Colors.black)),
                  Text(state.tr("Jogos e conteúdos instalados no dispositivo"), style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45, fontSize: 13)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: state.isScanningLibrary ? null : () => state.forcedSync(),
                icon: state.isScanningLibrary
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded),
                label: Text(state.tr("SINCRONIZAR")),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C10),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Device Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Icon(Icons.usb_rounded, color: const Color(0xFF107C10), size: 22),
                const SizedBox(width: 12),
                Text("${state.tr("Dispositivo")}:", style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 14)),
                const SizedBox(width: 16),
                Expanded(
                      child: state.drives.isEmpty
                      ? Text(state.tr("Nenhum dispositivo encontrado."), style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45))
                      : DropdownButton<String>(
                          value: state.selectedDrive?['device'],
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A1A),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: state.drives.map<DropdownMenuItem<String>>((d) {
                            final drive = d as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: drive['device'] as String,
                              child: Text("${drive['label']} (${drive['device']}) - ${drive['mount']}"),
                            );
                          }).toList(),
                          onChanged: (val) {
                            final drive = state.drives.firstWhere((d) => d['device'] == val);
                            state.selectDrive(drive as Map<String, dynamic>);
                            state.scanLibrary();
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Content Tabs
          Expanded(
            child: DefaultTabController(
              length: 4,
              initialIndex: state.currentLibraryTab,
              child: Column(
                children: [
                  TabBar(
                    dividerColor: Colors.transparent,
                    indicatorColor: const Color(0xFF107C10),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    onTap: (index) => state.setLibraryTab(index),
                    tabs: [
                      Tab(text: "Xbox 360", icon: Icon(Icons.gamepad, size: 20)),
                      Tab(text: "Classic/OG", icon: Icon(Icons.history, size: 20)),
                      Tab(text: "DLCs", icon: Icon(Icons.add_box, size: 20)),
                      Tab(text: "Updates/TU", icon: Icon(Icons.system_update_alt, size: 20)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTabContent(context, state, state.libraryGames["360"]!, "Jogos 360"),
                        _buildTabContent(context, state, state.libraryGames["OG"]!, "Jogos Classic"),
                        _buildTabContent(context, state, state.libraryGames["DLC"]!, "DLCs"),
                        _buildTabContent(context, state, state.libraryGames["TU"]!, "Updates"),
                      ],
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

  Widget _buildTabContent(BuildContext context, AppState state, List<dynamic> list, String type) {
    if (state.isScanningLibrary) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)));
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 64, color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text("${state.tr("Nenhum")} $type ${state.tr("encontrado")}.", style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return GestureDetector(
          onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, item, state),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: state.isDarkMode ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
            ),
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF107C10).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  image: item['icon'] != null && File(item['icon']).existsSync()
                      ? DecorationImage(image: FileImage(File(item['icon'])), fit: BoxFit.cover)
                      : null,
                ),
                child: item['icon'] == null || !File(item['icon']).existsSync()
                    ? const Icon(Icons.videogame_asset, color: Color(0xFF107C10), size: 20)
                    : null,
              ),
              title: Text(item['name'] ?? "Unknown Content", style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              subtitle: Text(
                "TitleID: ${item['titleId'] ?? 'XEX/XBE'} | Path: ${item['path']}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45, fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white24),
                onPressed: () {}, // Handled by gesture detector
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset position, dynamic item, AppState state) {
    bool isGame = item['type'] == 'GOD' || item['type'] == 'XEX' || item['type'] == 'XBE';
    
    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF1A1A1A),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem<dynamic>(
          onTap: () => state.exploreLibraryItem(item),
          child: Row(
            children: [
              const Icon(Icons.folder_open_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Text(state.tr("Abrir local do arquivo"), style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (isGame)
          PopupMenuItem<dynamic>(
            onTap: () => state.navigateToFtp(item['path']),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                Text(state.tr("Abrir no FTP (Console)"), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        if (item['titleId'] != null)
          PopupMenuItem<dynamic>(
            onTap: () => Future.microtask(() => _showMetadataDialog(context, item, state)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                Text(state.tr("Ver Metadados STFS"), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<dynamic>(
          onTap: () => Future.microtask(() => _exportToPc(context, item, state)),
          child: Row(
            children: [
              const Icon(Icons.file_download_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Text(state.tr("Exportar para o PC"), style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (isGame)
          PopupMenuItem<dynamic>(
            onTap: () => Future.microtask(() => _changeCover(context, item, state)),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                Text(state.tr("Alterar Capa (HQ)"), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
         PopupMenuItem<dynamic>(
          onTap: () => Future.microtask(() => _showRenameDialog(context, item, state)),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Text(state.tr("Renomear"), style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (!isGame && item['titleId'] != null) ...[
           const PopupMenuDivider(height: 1),
           PopupMenuItem<dynamic>(
            onTap: () => state.goToBaseGame(item['titleId']),
            child: Row(
              children: [
                const Icon(Icons.sports_esports_outlined, color: Color(0xFF107C10), size: 18),
                const SizedBox(width: 12),
                Text(state.tr("Ir para o Jogo Base"), style: const TextStyle(color: Color(0xFF107C10), fontSize: 13)),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(height: 1),
        PopupMenuItem<dynamic>(
          onTap: () => Future.microtask(() => _showDeleteDialog(context, item, state)),
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
              const SizedBox(width: 12),
              Text(state.tr("Excluir"), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  void _showMetadataDialog(BuildContext context, dynamic item, AppState state) async {
    final meta = await state.getSTFSMeta(item['path']);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(state.tr("Metadados STFS"), style: const TextStyle(color: Colors.white)),
        content: meta['status'] == 'success' 
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _metaRow("Title ID", meta['data']['title_id']),
                  _metaRow("Media ID", meta['data']['media_id']),
                  _metaRow("Console ID", meta['data']['console_id']),
                  _metaRow("Profile ID", meta['data']['profile_id']),
                  _metaRow("Type", meta['data']['type_name']),
                ],
              ),
            )
          : Text(state.tr("Erro ao ler metadados"), style: const TextStyle(color: Colors.redAccent)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(state.tr("FECHAR"), style: const TextStyle(color: Color(0xFF107C10)))),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value ?? "N/A", style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  void _exportToPc(BuildContext context, dynamic item, AppState state) async {
    String? selectedDirectory = await state.pickDirectory(
      title: state.tr("Selecione a pasta de destino no seu PC"),
    );
    
    if (selectedDirectory != null) {
      final res = await state.exportLibraryItem(item, selectedDirectory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['status'] == 'success' ? state.tr("Item exportado com sucesso!") : state.tr("Erro ao exportar item.")))
        );
      }
    }
  }

  void _changeCover(BuildContext context, dynamic item, AppState state) async {
    String? result = await state.pickFile(
      title: state.tr("Selecione uma imagem de capa (HQ)"),
      filter: "Imagens|*.jpg;*.png;*.jpeg",
    );

    if (result != null) {
      final res = await state.changeGameCover(item, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['status'] == 'success' ? state.tr("Capa atualizada!") : state.tr("Erro ao atualizar capa.")))
        );
      }
    }
  }

  void _showRenameDialog(BuildContext context, dynamic item, AppState state) {
    final controller = TextEditingController(text: item['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(state.tr("Renomear Item"), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: state.tr("Novo nome"),
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF107C10))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(state.tr("CANCELAR"), style: const TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              state.renameLibraryItem(item, controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
            child: Text(state.tr("SALVAR"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic item, AppState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(state.tr("Excluir Conteúdo"), style: const TextStyle(color: Colors.white)),
        content: Text("${state.tr("Tem certeza que deseja excluir")} '${item['name']}' ${state.tr("permanentemente do disco?")}", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(state.tr("CANCELAR"), style: const TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () {
              state.deleteLibraryItem(item);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(state.tr("EXCLUIR"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
