import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'dart:io';

class DashLaunchView extends StatefulWidget {
  const DashLaunchView({super.key});

  @override
  State<DashLaunchView> createState() => _DashLaunchViewState();
}

class _DashLaunchViewState extends State<DashLaunchView> {
  Map<String, dynamic>? _iniData;
  bool _isLoading = false;
  String? _currentPath;

  Future<void> _loadIni() async {
    final state = context.read<AppState>();
    if (state.selectedDrive == null) return;
    
    final path = "${state.selectedDrive!['device']}/launch.ini";
    setState(() => _isLoading = true);
    
    try {
      final res = await state.getDashLaunch(path);
      if (res["status"] == "success") {
        setState(() {
          _iniData = Map<String, dynamic>.from(res["data"]);
          _currentPath = path;
        });
      } else {
        // Provide a default RGH template if file doesn't exist
        setState(() {
          _iniData = {
            "paths": {"default": "Usb:\\Aurora\\Aurora.xex"},
            "settings": {
              "pingpatch": "true",
              "contpatch": "true",
              "livestrong": "false",
              "liveblock": "true",
              "noontp": "true",
              "xhttp": "true"
            },
            "plugins": {}
          };
          _currentPath = path;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveIni() async {
    if (_currentPath == null || _iniData == null) return;
    final state = context.read<AppState>();
    
    setState(() => _isLoading = true);
    await state.updateDashLaunch(_currentPath!, _iniData!);
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Arquivo launch.ini salvo com sucesso!")),
    );
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
              const Icon(Icons.tune_rounded, color: Color(0xFF107C10), size: 32),
              const SizedBox(width: 16),
              const Text("DashLaunch Pro Editor", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadIni,
                icon: const Icon(Icons.file_open_rounded),
                label: const Text("CARREGAR .INI"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading || _iniData == null ? null : _saveIni,
                icon: const Icon(Icons.save_rounded),
                label: const Text("SALVAR NO USB"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentPath ?? "Selecione um dispositivo e carregue o arquivo launch.ini",
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (_iniData == null && !_isLoading)
            const Expanded(child: Center(child: Text("Carregue o arquivo do seu pendrive para começar a editar.", style: TextStyle(color: Colors.white24))))
          else if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF107C10))))
          else
            Expanded(child: _buildEditorForm()),
        ],
      ),
    );
  }

  Widget _buildEditorForm() {
    return ListView(
      children: [
        _buildSectionHeader("Caminhos de Inicialização (Paths)"),
        _buildPathField("default", "Boot Principal"),
        const SizedBox(height: 24),
        
        _buildSectionHeader("Configurações de Rede e Sistema (Settings)"),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildToggle("pingpatch", "Remover limite de Ping (System Link)"),
            _buildToggle("contpatch", "Remover limite de Conteúdo (DLC Patch)"),
            _buildToggle("liveblock", "Bloquear conexão com Xbox Live"),
            _buildToggle("livestrong", "Bloquear servidores DNS da Microsoft"),
            _buildToggle("noontp", "Não sincronizar hora via NTP"),
            _buildToggle("xhttp", "Habilitar comandos HTTP"),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionHeader("Plugins Adicionais"),
        _buildPathField("plugin1", "Plugin 1", section: "plugins"),
        _buildPathField("plugin2", "Plugin 2", section: "plugins"),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(title, style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildToggle(String key, String label) {
    final section = _iniData!["settings"] ?? {};
    final bool value = section[key]?.toString().toLowerCase() == "true";

    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Switch(
            value: value,
            activeColor: const Color(0xFF107C10),
            onChanged: (val) {
              setState(() {
                _iniData!["settings"][key] = val.toString();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPathField(String key, String label, {String section = "paths"}) {
    final data = _iniData![section] ?? {};
    final String value = data[key]?.toString() ?? "";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
        onChanged: (val) => _iniData![section][key] = val,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.folder, size: 20, color: Colors.white24),
          hintText: "Ex: Usb:\\Aurora\\Aurora.xex",
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
