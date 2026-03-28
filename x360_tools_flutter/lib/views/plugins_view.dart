import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/partial_install_footer.dart';

class PluginsView extends StatelessWidget {
  const PluginsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          // 1. Logo (Literal Parity)
          Image.asset("assets/x360_tools_logo_light.png", height: 120),
          const SizedBox(height: 40),

          // 2. Three Columns of Checkboxes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColumn(state.tr("Plugins (Extended)"), state.pluginSelections, state.togglePlugin, state),
              _buildColumn(state.tr("Customization"), state.customSelections, state.toggleCustom, state),
              _buildColumn(state.tr("Backwards Compatibility"), state.backcompatSelections, state.toggleBackcompat, state),
            ],
          ),
          const SizedBox(height: 48),
          const PartialInstallFooter(category: "Plugins"),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, Map<String, bool> items, Function(String) onToggle, AppState state) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...items.keys.map((key) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Text(state.tr(key), style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  state.tr("${key}_desc"), 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                Checkbox(
                  value: items[key],
                  onChanged: (_) => onToggle(key),
                  activeColor: Colors.green,
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
