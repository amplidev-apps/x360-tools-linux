import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/gamerpic_editor_dialog.dart';

class ProfilePicsView extends StatefulWidget {
  const ProfilePicsView({super.key});

  @override
  State<ProfilePicsView> createState() => _ProfilePicsViewState();
}

class _ProfilePicsViewState extends State<ProfilePicsView> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedGenre = "Todos";
  late TabController _tabController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _tabController.index == 1) {
        context.read<AppState>().fetchInstalledGamerpics();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.fetchGamerpics();
      state.refreshDrives();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Extract unique genres from the Library
    final List<String> genres = ["Todos"];
    for (var pic in state.gamerpics) {
      final g = pic['genre'] ?? "Outros";
      if (!genres.contains(g)) genres.add(g);
    }

    final filteredPics = state.gamerpics.where((pic) {
      final name = pic['name']?.toString().toLowerCase() ?? "";
      final genre = pic['genre'] ?? "Outros";
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      final matchesGenre = _selectedGenre == "Todos" || genre == _selectedGenre;
      return matchesSearch && matchesGenre;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(state),
          const SizedBox(height: 16),
          // ── TabBar ──────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: state.isDarkMode ? const Color(0xFF151515) : Colors.white70,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF107C10),
              unselectedLabelColor: state.isDarkMode ? Colors.white54 : Colors.black87,
              indicatorColor: const Color(0xFF107C10),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.library_books, size: 16),
                      const SizedBox(width: 8),
                      Text(state.tr("Biblioteca")),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.usb, size: 16),
                      const SizedBox(width: 8),
                      Text(state.tr("No Dispositivo")),
                      if (state.isLoadingInstalledGamerpics) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF107C10)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── TabBarView ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Library ──────────────────────────────────────
                state.isLoadingGamerpics
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
                    : state.gamerpics.isEmpty
                        ? _buildEmptyState(state, "Nenhum herói encontrado.")
                        : _buildGrid(state.gamerpics, state, showInject: true),
                // ── Tab 2: Installed on Device ──────────────────────────
                Column(
                  children: [
                    _buildDeviceHeader(state),
                    const SizedBox(height: 16),
                    Expanded(
                      child: state.isLoadingInstalledGamerpics
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
                          : state.installedGamerpics.isEmpty
                              ? _buildEmptyState(state, "Nenhum Gamer Picture encontrado no dispositivo.")
                              : _buildGrid(state.installedGamerpics, state, showInject: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState state) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.tr("Profile Pics"),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: state.isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              state.tr("Selecione um heroi para injetar no seu dispositivo."),
              style: TextStyle(fontSize: 14, color: state.isDarkMode ? Colors.white.withOpacity(0.6) : Colors.black87),
            ),
          ],
        ),
        const Spacer(),
        // ── Global Device Selector ──────────────────────────────────────
        Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: state.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.drives.isEmpty 
                  ? null 
                  : state.drives.any((d) => d['device'] == state.selectedDrive?['device']) 
                      ? state.selectedDrive!['device'] 
                      : state.drives.first['device'],
              dropdownColor: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
              isExpanded: true,
              style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 13),
              icon: const Icon(Icons.usb, size: 18, color: Color(0xFF107C10)),
              onChanged: (val) {
                if (val != null) {
                  final drive = state.drives.firstWhere((d) => d['device'] == val);
                  state.selectDrive(drive);
                }
              },
              items: state.drives.map((d) {
                final label = d['label'] ?? d['device'];
                final size = d['size_gb'] != null ? "${d['size_gb']}GB" : (d['size'] ?? "");
                return DropdownMenuItem<String>(
                  value: d['device'].toString(),
                  child: Text("$label ($size)", overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final path = await state.pickFile(
              title: state.tr("Selecionar Imagem (PNG, JPG, BMP)"),
              filter: "${state.tr("Imagens")} | *.png *.jpg *.jpeg *.bmp *.PNG *.JPG *.JPEG *.BMP",
            );
            if (path != null && mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => GamerpicEditorDialog(imagePath: path),
              );
            }
          },
          icon: const Icon(Icons.add_photo_alternate, size: 18),
          label: Text(state.tr("Criar Custom")),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF107C10),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceHeader(AppState state) {
    return Row(
      children: [
        const Icon(Icons.storage, size: 18, color: Color(0xFF107C10)),
        const SizedBox(width: 12),
        Text(
          state.selectedDrive != null 
              ? "${state.selectedDrive!['label'] ?? state.selectedDrive!['device']} (${state.selectedDrive!['size_gb'] ?? state.selectedDrive!['size'] ?? "?"} GB)"
              : state.tr("Nenhum dispositivo selecionado"),
          style: TextStyle(color: state.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: state.selectedDrive != null ? () => state.fetchInstalledGamerpics() : null,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(state.tr("Atualizar")),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF107C10),
            side: const BorderSide(color: Color(0xFF107C10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(AppState state, List<String> genres) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = value);
                });
              },
              style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: state.tr("Procurar Herois"),
                hintStyle: TextStyle(color: state.isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black45),
                prefixIcon: Icon(Icons.search, color: state.isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black45),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGenre,
                dropdownColor: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
                isExpanded: true,
                style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                icon: Icon(Icons.filter_list, color: state.isDarkMode ? Colors.white54 : Colors.black54),
                items: genres.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _selectedGenre = val!),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.drives.isEmpty ? null : state.drives.any((d) => d['device'] == state.selectedDrive?['device']) ? state.selectedDrive!['device'] : state.drives.first['device'],
                dropdownColor: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
                isExpanded: true,
                style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                icon: Icon(Icons.usb, size: 16, color: state.isDarkMode ? Colors.white54 : Colors.black87),
                onChanged: (val) {
                  if (val != null) {
                    final drive = state.drives.firstWhere((d) => d['device'] == val);
                    state.selectDrive(drive);
                  }
                },
                items: state.drives.map((d) {
                  final label = d['label'] ?? d['device'];
                  return DropdownMenuItem<String>(
                    value: d['device'].toString(),
                    child: Text(label.toString(), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<dynamic> pics, AppState state, {required bool showInject}) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: pics.length,
      itemBuilder: (context, index) {
        final pic = pics[index];
        final bool isInjecting = state.isInstalling;
        return _buildPicCard(pic, state, isInjecting, showInject: showInject);
      },
    );
  }

  Widget _buildPicCard(dynamic pic, AppState state, bool isInjecting, {required bool showInject}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(pic['path']),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Icon(Icons.image_not_supported, color: state.isDarkMode ? Colors.white10 : Colors.black12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  if (showInject)
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: isInjecting ? null : () => state.injectGamerpic(pic['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF107C10),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          state.tr("Injetar"),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    // ── Device actions: Export + Delete ──────────────────
                    Row(
                      children: [
                        // Export button
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: Tooltip(
                              message: state.tr("Exportar"),
                              child: OutlinedButton(
                                onPressed: () async {
                                  final packPath = pic['pack_path']?.toString();
                                  if (packPath == null) return;
                                  // Let user pick destination folder
                                  final result = await Process.run('zenity', [
                                    '--file-selection',
                                    '--directory',
                                    '--title=${state.tr("Selecionar Pasta de Destino")}',
                                  ]);
                                  if (result.exitCode == 0) {
                                    final destDir = (result.stdout as String).trim();
                                    await state.exportDeviceGamerpic(packPath, destDir);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF107C10),
                                  side: BorderSide(color: const Color(0xFF107C10).withOpacity(0.5)),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Icon(Icons.upload, size: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Delete button
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: Tooltip(
                              message: state.tr("Excluir do Dispositivo"),
                              child: OutlinedButton(
                                onPressed: () async {
                                  final packPath = pic['pack_path']?.toString();
                                  if (packPath == null) return;
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: state.isDarkMode ? const Color(0xFF151515) : Colors.white,
                                      title: Text(state.tr("Confirmar Exclusão"),
                                          style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 16)),
                                      content: Text(
                                        '${state.tr("Deseja excluir")} "${pic['name']}" ${state.tr("do dispositivo?")}',
                                        style: TextStyle(color: state.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: Text(state.tr("Cancelar"),
                                              style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[700]),
                                          child: Text(state.tr("Excluir"),
                                              style: const TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await state.deleteDeviceGamerpic(packPath);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Icon(Icons.delete_outline, size: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppState state, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: state.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black26),
          const SizedBox(height: 16),
          Text(
            state.tr(message),
            style: TextStyle(color: state.isDarkMode ? Colors.white.withOpacity(0.3) : Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
