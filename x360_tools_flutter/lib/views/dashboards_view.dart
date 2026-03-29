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
        crossAxisAlignment: CrossAxisAlignment.stretch, // Fill entire height
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
                      "assets/aurora_preview.png", 
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
                      "assets/fsd3_preview.jpg", 
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),

          // 2. Checklist Group (Scrollable to fix pixel overflow)
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.tr("Dashboards / Launchers"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 24),
                  ...state.dashboardSelections.keys.map((key) => Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: CheckboxListTile(
                      title: Text(key, style: TextStyle(fontSize: 13, color: state.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
                      subtitle: Text(state.tr("${key}_desc"), style: TextStyle(fontSize: 10, color: state.isDarkMode ? Colors.white54 : Colors.black54)),
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
                    state.tr("* XeXMenu 1.2 is installed by default (via X330 Tools)"),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  const PartialInstallFooter(category: "Dashboards"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
