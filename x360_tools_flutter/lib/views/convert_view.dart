import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/python_bridge.dart';

class ConvertView extends StatefulWidget {
  const ConvertView({super.key});

  @override
  State<ConvertView> createState() => _ConvertViewState();
}

class _ConvertViewState extends State<ConvertView> {
  final TextEditingController _srcController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  String _mode = "god"; // "god" for 360, "extract" for Classic
  bool _isConverting = false;
  bool _autoInstall = false;
  String _status = "Selecione os arquivos para começar.";

  Future<void> _startConversion() async {
    if (_srcController.text.isEmpty) {
      setState(() => _status = "Erro: Selecione a ISO de origem.");
      return;
    }

    if (!_autoInstall && _destController.text.isEmpty) {
      setState(() => _status = "Erro: Selecione a pasta de destino.");
      return;
    }

    // Default to /tmp for auto-install if no dest selected
    String destDir = _destController.text.isEmpty ? "/tmp/x306tools_conv" : _destController.text;

    setState(() {
      _isConverting = true;
      _status = "Convertendo... Por favor, aguarde.";
    });

    final state = context.read<AppState>();
    String? drivePath;
    if (_autoInstall) {
      drivePath = state.selectedDrive?['device'];
    }

    try {
      final res = await PythonBridge.convertIso(
        _srcController.text,
        destDir,
        _mode,
        device: drivePath,
        cleanup: _destController.text.isEmpty,
      );

      setState(() {
        _isConverting = false;
        if (res["status"] == "success") {
          _status = "Sucesso: Conversão concluída!";
        } else {
          _status = "Erro: ${res["message"]}";
        }
      });
    } catch (e) {
      setState(() {
        _isConverting = false;
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
              const Icon(Icons.transform, color: Color(0xFF107C10), size: 48),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.tr("x360 Converter"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(
                    state.tr("Prepare seus jogos para rodar no console."),
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Selection Cards
          Row(
            children: [
              Expanded(child: _buildModeCard("Xbox 360", "Converter ISO para GOD", Icons.album, "god")),
              const SizedBox(width: 24),
              Expanded(child: _buildModeCard("Xbox Clássico", "Extrair ISO para Pasta (.xbe)", Icons.disc_full, "extract")),
            ],
          ),

          const SizedBox(height: 48),

          // File Section
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilePickerField(
                  state.tr("Arquivo ISO de Origem"), 
                  _srcController, 
                  Icons.file_present,
                  () async {
                    final path = await state.pickFile(title: "Selecionar ISO", filter: "ISO | *.iso *.ISO");
                    if (path != null) setState(() => _srcController.text = path);
                  }
                ),
                const SizedBox(height: 24),
                _buildFilePickerField(
                  state.tr("Pasta de Destino"), 
                  _destController, 
                  Icons.folder,
                  () async {
                    final path = await state.pickDirectory(title: "Selecionar Destino");
                    if (path != null) setState(() => _destController.text = path);
                  }
                ),
                const SizedBox(height: 24),
                
                // Auto-install Option
                CheckboxListTile(
                  title: Text(state.tr("Instalar no dispositivo após converter")),
                  subtitle: Text(state.tr("O jogo será copiado automaticamente para o pen drive.")),
                  value: _autoInstall,
                  activeColor: const Color(0xFF107C10),
                  onChanged: (v) => setState(() => _autoInstall = v!),
                  contentPadding: EdgeInsets.zero,
                ),

                if (_autoInstall) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26, 
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.selectedDrive?['device'],
                        isExpanded: true,
                        hint: const Text("Selecione o dispositivo"),
                        items: state.drives.map((d) {
                          return DropdownMenuItem<String>(
                            value: d['device'],
                            child: Text("${d['label']} (${d['size_gb']} GB)"),
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

                const SizedBox(height: 48),
                
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isConverting ? null : _startConversion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C10),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                    ),
                    child: _isConverting 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 16),
                            Text("CONVERTENDO...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                          ],
                        )
                      : Text(state.tr("INICIAR CONVERSÃO").toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                  ),
                ),
                
                if (_status.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _status.contains("Erro") ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _status, 
                      style: TextStyle(
                        color: _status.contains("Erro") ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(String title, String subtitle, IconData icon, String mode) {
    bool isSelected = _mode == mode;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF107C10).withOpacity(0.1) : Colors.black26,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF107C10) : Colors.white12,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white24, size: 32),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white54)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: isSelected ? Colors.white70 : Colors.white24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerField(String label, TextEditingController controller, IconData icon, VoidCallback onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, color: Colors.white30),
                  hintText: "Caminho do arquivo...",
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onPick,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.all(18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.folder_open, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}
