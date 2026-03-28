import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/premium_card.dart';

class WizardView extends StatelessWidget {
  const WizardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text(state.tr("INSTALL WIZARD"), style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Spacer(),
              IconButton(
                onPressed: () => state.setWizardActive = false, 
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (state.wizardStep + 1) / 6,
            color: const Color(0xFF107C10),
            backgroundColor: Colors.white10,
          ),
          const SizedBox(height: 48),

          // Content
          Expanded(
            child: _buildStepContent(state),
          ),

          // Footer
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (state.wizardStep > 0)
                TextButton.icon(
                  onPressed: state.prevWizardStep,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(state.tr("BACK")),
                )
              else
                const SizedBox(),
              
              Row(
                children: [
                  Text("${state.tr("Step")} ${state.wizardStep + 1} ${state.tr("of")} 6", style: const TextStyle(color: Colors.white30)),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: (state.wizardStep == 1 && state.selectedDrive == null)
                        ? null 
                        : (state.wizardStep == 2 && state.consoleType == null)
                            ? null
                            : (state.wizardStep == 5)
                                ? state.installSelected
                                : state.nextWizardStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF107C10),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    ),
                    child: Text(state.wizardStep == 5 ? state.tr("INSTALL NOW") : state.tr("CONTINUE")),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AppState state) {
    switch (state.wizardStep) {
      case 0: return _buildWelcomeStep(state);
      case 1: return _buildDeviceStep(state);
      case 2: return _buildConsoleStep(state);
      case 3: return _buildDashboardStep(state);
      case 4: return _buildPluginsStep(state);
      case 5: return _buildSummaryStep(state);
      default: return const Text("Unknown Step");
    }
  }

  Widget _buildWelcomeStep(AppState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF107C10)),
        const SizedBox(height: 24),
        Text(state.tr("Welcome to x360 Tools v2.0"), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Text(
          state.tr("This wizard will guide you through preparing your USB device for your Xbox 360."),
          style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.5)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDeviceStep(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr("Select Target Device"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        DropdownButton<String>(
          value: state.selectedDrive?['device'],
          isExpanded: true,
          dropdownColor: Colors.black,
          items: state.drives.map((d) => DropdownMenuItem<String>(
            value: d['device'],
            child: Text("${d['device']} - ${d['label']} (${d['size_gb']} GB)"),
          )).toList(),
          onChanged: (val) {
             final drive = state.drives.firstWhere((d) => d['device'] == val);
             state.selectDrive(Map<String, dynamic>.from(drive));
          },
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 20),
              Expanded(child: Text(state.tr("Formatting will erase all data on the selected device. Make sure you have a backup."))),
              ElevatedButton(
                onPressed: state.formatCurrentDrive,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(state.tr("FORMAT FAT32")),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleStep(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr("Console Hardware Type"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildOptionCard(
              state.tr("RGH / JTAG"), 
              state.tr("Modified hardware that runs unsigned code and homebrew."),
              state.consoleType == "RGH",
              () => state.setConsoleType("RGH"),
            ),
            const SizedBox(width: 24),
            _buildOptionCard(
              state.tr("LT / Original / Não Sei"), 
              state.tr("Standard or Flash-only console for playing backups from disc."),
              state.consoleType == "LT",
              () => state.setConsoleType("LT"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardStep(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr("Select Dashboard"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 20),
          itemCount: state.dashboards.length,
          itemBuilder: (context, index) {
            final pkg = state.dashboards[index];
            return PremiumCard(
              title: pkg['name']!,
              subtitle: state.tr("Dashboard Interface"),
              imagePath: "generic_cover.png",
              isSelected: state.selectedPackages.contains(pkg['file']!),
              onTap: () => state.togglePackage(pkg['file']!),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPluginsStep(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr("Additional Software"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              _buildCategoryGroup(state, state.tr("Stealth Servers"), state.stealth),
              const SizedBox(height: 32),
              _buildCategoryGroup(state, state.tr("System Plugins"), state.plugins),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStep(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.tr("Installation Summary"), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Text("${state.tr("Dispositivo USB")}: ${state.selectedDrive?['device']} (${state.selectedDrive?['label']})"),
        Text("${state.tr("Tipo de Console")}: ${state.consoleType == 'RGH' ? 'RGH/JTAG' : 'LT / Original'}"),
        const SizedBox(height: 32),
        Text(state.tr("Packages to Install:"), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: state.selectedPackages.map((p) => ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF107C10)),
              title: Text(p),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(String title, String desc, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF107C10).withOpacity(0.1) : Colors.white12,
            border: Border.all(color: isActive ? const Color(0xFF107C10) : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGroup(AppState state, String title, List pkgs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF107C10))),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: pkgs.map((p) => FilterChip(
            label: Text(p['name']!),
            selected: state.selectedPackages.contains(p['file']!),
            onSelected: (_) => state.togglePackage(p['file']!),
            selectedColor: const Color(0xFF107C10),
          )).toList(),
        ),
      ],
    );
  }
}
