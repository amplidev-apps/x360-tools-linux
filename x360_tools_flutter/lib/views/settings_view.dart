import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Centered Logo
            Image.asset("assets/x360_tools_logo_light.png", height: 200),
            const SizedBox(height: 48),

            // 2. Utility Section
            Text(
              state.tr("x360 Tools Utilities"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildUtilityButton(
                  context,
                  state.tr("Limpar Cache Temporário"),
                  state.clearTemporaryCache,
                ),
                const SizedBox(width: 16),
                _buildUtilityButton(
                  context,
                  state.tr("Desinstalar x360 Tools"),
                  state.uninstallX360Tools,
                ),
              ],
            ),

            const SizedBox(height: 48),

            // 3. Language Section
            Text(
              state.tr("Idioma"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF107C10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.currentLanguage,
                  icon: const Icon(Icons.unfold_more, color: Colors.white),
                  dropdownColor: const Color(0xFF107C10),
                  items: ["Português", "English", "Español"].map((String lang) {
                    return DropdownMenuItem<String>(
                      value: lang,
                      child: Text(lang, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) state.setLanguage(newValue);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityButton(BuildContext context, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF107C10),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
