import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/python_bridge.dart';

class ContentManagerView extends StatefulWidget {
  const ContentManagerView({super.key});

  @override
  State<ContentManagerView> createState() => _ContentManagerViewState();
}

class _ContentManagerViewState extends State<ContentManagerView> {
  Map<String, dynamic> _content = {};
  bool _isLoading = false;
  Map<String, dynamic>? _selectedItem;

  @override
  void initState() {
    super.initState();
    _refreshContent();
  }

  Future<void> _refreshContent() async {
    final state = context.read<AppState>();
    if (state.selectedDrive == null) return;

    setState(() => _isLoading = true);
    final res = await PythonBridge.listContent(state.selectedDrive!['device']);
    setState(() {
      _isLoading = false;
      if (res["status"] == "success") {
        _content = res["data"] as Map<String, dynamic>;
      }
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
              const Text("Content Manager", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: _refreshContent, icon: const Icon(Icons.refresh, color: Color(0xFF107C10))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Manage DLCs, Title Updates, and Saves on your USB device.",
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Device Tree
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
                      : ListView.builder(
                          itemCount: _content.length,
                          itemBuilder: (context, index) {
                            final tid = _content.keys.elementAt(index);
                            final game = _content[tid];
                            return _buildGameNode(tid, game);
                          },
                        ),
                  ),
                ),
                const SizedBox(width: 24),

                // 2. Metadata Panel
                Expanded(
                  flex: 2,
                  child: _buildDetailsPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameNode(String tid, Map<String, dynamic> game) {
    return ExpansionTile(
      leading: const Icon(Icons.videogame_asset, color: Color(0xFF107C10)),
      title: Text(game["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(tid, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      children: (game["items"] as List).map((item) {
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 32),
          leading: const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
          title: Text(item["display_name"]),
          subtitle: Text(item["type_name"]),
          onTap: () => setState(() => _selectedItem = item),
        );
      }).toList(),
    );
  }

  Widget _buildDetailsPanel() {
    if (_selectedItem == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text("Select a package to view details", style: TextStyle(color: Colors.white24)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF107C10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PACKAGE DETAILS", style: TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 20),
          Text(_selectedItem!["display_name"], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_selectedItem!["type_name"], style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          _buildMetaRow("Title ID", _selectedItem!["title_id"]),
          _buildMetaRow("Media ID", _selectedItem!["media_id"]),
          _buildMetaRow("Content Type", _selectedItem!["type_hex"]),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download),
              label: const Text("EXTRACT TO PC"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF252525)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text("DELETE FROM USB", style: TextStyle(color: Colors.red)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
