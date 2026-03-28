import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/partial_install_footer.dart';

class DashboardsView extends StatelessWidget {
  const DashboardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Preview Image (Literal Parity)
          Expanded(
            flex: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset("assets/Captura de tela de 2026-03-24 13-05-51.png", fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 40),

          // 2. Checklist Group
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.tr("Dashboards / Launchers"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ...state.dashboardSelections.keys.map((key) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: CheckboxListTile(
                    title: Text(key, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(state.tr("${key}_desc"), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    value: state.dashboardSelections[key],
                    onChanged: (_) => state.toggleDashboard(key),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: Colors.green,
                  ),
                )),
                const SizedBox(height: 20),
                Text(
                  state.tr("* XeXMenu 1.2 is installed by default"),
                  style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const PartialInstallFooter(category: "Dashboards"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
