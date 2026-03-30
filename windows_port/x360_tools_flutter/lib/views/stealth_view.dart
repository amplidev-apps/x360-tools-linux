import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/partial_install_footer.dart';

class StealthView extends StatelessWidget {
  const StealthView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Large Xbox Live Logo (Literal Parity)
          Expanded(
            flex: 1,
            child: Image.asset(
              state.isDarkMode ? "assets/xlive_logo_dark.png" : "assets/xlive_logo_light.png",
              height: 250,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 40),

          // 2. Checklist Group
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.tr("Stealth Networks"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: state.stealthSelections.keys.map((key) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: CheckboxListTile(
                        title: Text(key, style: TextStyle(fontSize: 13, color: state.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
                        subtitle: Text(state.tr("${key}_desc"), style: TextStyle(fontSize: 10, color: state.isDarkMode ? Colors.white54 : Colors.black54)),
                        value: state.stealthSelections[key],
                        onChanged: (_) => state.toggleStealth(key),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: Colors.green,
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                const PartialInstallFooter(category: "Stealth"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
