import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class InstallationView extends StatelessWidget {
  const InstallationView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Column(
      children: [
        // Top content (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Column(
              children: [
                // 1. Branding Section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Image.asset("assets/x360_tools_logo_light.png", height: 200),
                      const SizedBox(height: 10),
                      if (state.selectedDrive == null)
                        Text(
                          state.tr("Aviso: Nenhum dispositivo detectado"),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),

                // 2. Selection Groups (Horizontal Row)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroup(state.tr("Método de Exploit"), state.exploitMethods, state.toggleExploit, state),
                    _buildGroup(state.tr("Patches"), state.patchOptions, state.togglePatch, state),
                    _buildGroup(state.tr("Opções de Instalação"), state.installOptions, state.toggleInstallOption, state),
                  ],
                ),

                const SizedBox(height: 40),

                // 3. Drive Selector (Matches blue dropdown in screenshot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedDrive?['device'],
                      isExpanded: true,
                      dropdownColor: Colors.black,
                      icon: const Icon(Icons.unfold_more, color: Colors.blueAccent),
                      items: state.drives.map((d) => DropdownMenuItem<String>(
                        value: d['device'] as String,
                        child: Text("${d['device']} - ${d['label']}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                      )).toList(),
                      onChanged: (val) {
                        final drive = state.drives.firstWhere((d) => d['device'] == val);
                        state.selectDrive(Map<String, dynamic>.from(drive));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar (Fixed/Docked)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildMainButton(state.tr("Assistente de Instalação (Iniciantes)"), Icons.auto_awesome, state.startWizard),
                  const SizedBox(width: 8),
                  _buildMainButton(state.tr("Iniciar Instalação"), Icons.play_arrow, state.installSelected),
                  const SizedBox(width: 8),
                  _buildMainButton(state.tr("Atualizar Dispositivos"), Icons.refresh, state.refreshDrives),
                  const SizedBox(width: 8),
                  _buildMainButton(state.tr("Sair"), Icons.exit_to_app, () => exit(0)),
                ],
              ),
              if (state.isInstalling)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(value: state.progress, color: Colors.green),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroup(String title, Map<String, bool> items, Function(String) onToggle, AppState state) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
            const Divider(color: Colors.white10),
            ...items.keys.map((key) => SizedBox(
              height: 32,
              child: CheckboxListTile(
                title: Text(state.tr(key), style: const TextStyle(fontSize: 12)),
                value: items[key],
                onChanged: (_) => onToggle(key),
                controlAffinity: ListTileControlAffinity.trailing,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.green,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
