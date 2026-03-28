import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class PartialInstallFooter extends StatelessWidget {
  final String category;
  const PartialInstallFooter({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.usb, color: Color(0xFF107C10), size: 16),
              const SizedBox(width: 8),
              Text(
                state.tr("Select Target Device"),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedDrive?['device'],
                      isExpanded: true,
                      dropdownColor: Colors.black,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: state.drives.map((d) => DropdownMenuItem<String>(
                        value: d['device'],
                        child: Text("${d['device']} - ${d['label']} (${d['size_gb']} GB)"),
                      )).toList(),
                      onChanged: (val) {
                         final drive = state.drives.firstWhere((d) => d['device'] == val);
                         state.selectDrive(Map<String, dynamic>.from(drive));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: state.isInstalling ? null : () => state.installCategory(category),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C10),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 2,
                ),
                icon: state.isInstalling 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.install_desktop, size: 16),
                label: Text(
                  state.tr("INJETAR NO DISPOSITIVO"),
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
