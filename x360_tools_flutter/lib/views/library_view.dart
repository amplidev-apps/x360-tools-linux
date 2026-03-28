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
    Future.microtask(() => context.read<AppState>().scanLibrary());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_books_rounded, color: Color(0xFF107C10), size: 32),
              const SizedBox(width: 16),
              const Text("Minha Biblioteca", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (state.isScanningLibrary)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF107C10))),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: state.isScanningLibrary ? null : () => state.scanLibrary(),
                icon: const Icon(Icons.sync_rounded),
                label: const Text("SINCRONIZAR"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: "JOGOS (360/OG)"),
                      Tab(text: "CONTEÚDO (DLC)"),
                      Tab(text: "UPDATES (TU)"),
                    ],
                    indicatorColor: Color(0xFF107C10),
                    labelColor: Color(0xFF107C10),
                    unselectedLabelColor: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGamesGrid(state),
                        _buildContentList(state, "DLC"),
                        _buildContentList(state, "TU"),
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

  Widget _buildGamesGrid(AppState state) {
    final allGames = [...state.libraryGames["360"]!, ...state.libraryGames["OG"]!];
    
    if (allGames.isEmpty && !state.isScanningLibrary) {
      return const Center(child: Text("Nenhum jogo encontrado no dispositivo selecionado.", style: TextStyle(color: Colors.white24)));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: allGames.length,
      itemBuilder: (context, index) {
        final game = allGames[index];
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: game['icon'] != null && File(game['icon']).existsSync()
                        ? Image.file(File(game['icon']), fit: BoxFit.cover)
                        : Image.asset('assets/gamecovers/4B4D07E2.jpg', fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${game['type']} - ${game['titleId'] ?? 'N/A'}", style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentList(AppState state, String type) {
    final list = state.libraryGames[type]!;
    if (list.isEmpty) return Center(child: Text("Nenhuma $type encontrada.", style: const TextStyle(color: Colors.white24)));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return ListTile(
          leading: const Icon(Icons.folder_open, color: Colors.white24),
          title: Text(item['name'] ?? "Unknown Content"),
          subtitle: Text("ID: ${item['titleId']} | Arquivo: ${item['filename']}"),
          trailing: const Icon(Icons.check_circle, color: Color(0xFF107C10), size: 16),
        );
      },
    );
  }
}
