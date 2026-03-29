import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/partial_install_footer.dart';

class HomebrewView extends StatelessWidget {
  const HomebrewView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Preview Images Column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/dashlaunch-3.06.jpg", 
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/xm360_preview.jpg", 
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),

          // 2. Checklist Group
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.tr("Homebrew Applications"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 24),
                  ...state.homebrewSelections.keys.map((key) => Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: CheckboxListTile(
                      title: Text(key, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(state.tr("${key}_desc"), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      value: state.homebrewSelections[key],
                      onChanged: (_) => state.toggleHomebrew(key),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Colors.green,
                    ),
                  )),
                  const SizedBox(height: 40),
                  const PartialInstallFooter(category: "Homebrews"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
