import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/app_state.dart';

class SavesView extends StatelessWidget {
  const SavesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: const Color(0xFF0A0A0A),
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
                child: const Icon(Icons.sd_storage, color: Color(0xFF107C10), size: 36),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Save Manager",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.tr("Gerencie seus saves e perfis de Xbox 360 localmente e exporte para outros dispositivos."),
                      style: const TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: state.isLoadingSaves ? null : () => state.saveScan(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(state.tr("Atualizar")),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: state.isLoadingSaves ? null : () async {
                  final path = await state.pickFile(title: state.tr("Selecione um Arquivo STFS (Save/Profile)"));
                  if (path != null) {
                    await state.saveImport(path);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C10),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.file_upload),
                label: Text(state.tr("Importar Save")),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Content
          Expanded(
            child: state.isLoadingSaves
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
                : state.saves.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
                            const SizedBox(height: 24),
                            Text(
                              state.tr("Nenhum save encontrado no cofre."),
                              style: const TextStyle(color: Colors.white38, fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: state.saves.length,
                        itemBuilder: (context, index) {
                          final save = state.saves[index];
                          return _buildSaveCard(context, state, save);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveCard(BuildContext context, AppState state, dynamic save) {
    final String titleId = save['title_id'] ?? 'Unknown';
    final String displayName = save['display_name'] ?? 'Save File';
    final String description = save['description'] ?? '';
    final String iconPath = save['icon_path'] ?? '';
    final String fileName = save['file_name'] ?? '';

    // Calculate generic relative sizes
    final double mb = (save['size'] ?? 0) / (1024 * 1024);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
              image: iconPath.isNotEmpty && File(iconPath).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(iconPath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: iconPath.isEmpty || !File(iconPath).existsSync()
                ? const Icon(Icons.videogame_asset, color: Colors.white38, size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isNotEmpty ? description : "Title ID: $titleId",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${mb.toStringAsFixed(2)} MB",
                      style: const TextStyle(color: Color(0xFF107C10), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // Tooltip & Export disabled for now as mocked, but visually present
                        IconButton(
                          icon: const Icon(Icons.cloud_upload, color: Colors.white38, size: 20),
                          tooltip: state.tr("Backup em Nuvem (Em Breve)"),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.tr("Cloud Sync chegará em uma atualização futura."))));
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: state.tr("Apagar Arquivo"),
                          onPressed: () {
                            state.saveDelete(fileName);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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
}
