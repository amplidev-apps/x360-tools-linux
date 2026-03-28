import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'views/home_view.dart';
import 'views/installation_view.dart';
import 'views/freemarket_view.dart';
import 'views/dashboards_view.dart';
import 'views/homebrew_view.dart';
import 'views/stealth_view.dart';
import 'views/plugins_view.dart';
import 'views/settings_view.dart';
import 'views/wizard_view.dart';
import 'views/horizon_injector_view.dart';
import 'views/profile_pics_view.dart';
import 'views/convert_view.dart';
import 'views/backup_view.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const X360ToolsApp(),
    ),
  );
}

class X360ToolsApp extends StatelessWidget {
  const X360ToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'x360 Tools for Linux',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme.dark(
          primary: Colors.green,
          surface: Color(0xFF151515),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late final List<Widget> _viewList;

  @override
  void initState() {
    super.initState();
    _viewList = [
      HomeView(onNavigate: _onNavigate),
      const InstallationView(),
      const FreemarketView(),
      const DashboardsView(),
      const HomebrewView(),
      const StealthView(),
      const PluginsView(),
      const HorizonInjectorView(),
      const ConvertView(),
      const ProfilePicsView(),
      const BackupView(),
      const SettingsView(),
    ];
  }

  final List<Map<String, dynamic>> _tabs = [
    {"name": "Início", "icon": Icons.home_rounded, "key": "Início"},
    {"name": "Instalação", "icon": Icons.install_desktop_rounded, "key": "Instalação"},
    {"name": "x360 Freemarket", "icon": Icons.shopping_bag_rounded, "key": "x360 Freemarket"},
    {"name": "Dashboards", "icon": Icons.dashboard_rounded, "key": "Dashboards"},
    {"name": "Homebrews", "icon": Icons.apps_rounded, "key": "Homebrews"},
    {"name": "Stealth e Bypass", "icon": Icons.security_rounded, "key": "Stealth e Bypass"},
    {"name": "Plugins e Outros", "icon": Icons.extension_rounded, "key": "Plugins e Outros"},
    {"name": "Injetor Horizon", "icon": Icons.send_to_mobile_rounded, "key": "Injetor Horizon"},
    {"name": "Conversor ISO", "icon": Icons.transform_rounded, "key": "Conversor ISO"},
    {"name": "Profile Pics", "icon": Icons.photo_library_rounded, "key": "Profile Pics"},
    {"name": "Backup e Restauro", "icon": Icons.settings_backup_restore, "key": "Backup e Restauro"},
    {"name": "Configurações", "icon": Icons.settings_rounded, "key": "Configurações"},
  ];

  void _onNavigate(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Vertical Sidebar
                SizedBox(
                  width: 260,
                  child: Container(
                    color: Colors.black,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Logo/Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF107C10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.videogame_asset, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "x360 Tools",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Nav Items
                        Expanded(
                          child: ListView.builder(
                            itemCount: _tabs.length,
                            itemBuilder: (context, index) => _buildSidebarItem(index, state),
                          ),
                        ),
                        
                        // Window Controls at bottom of sidebar
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildWindowControl(Colors.yellow, Icons.minimize),
                              _buildWindowControl(Colors.green, Icons.crop_square),
                              _buildWindowControl(Colors.red, Icons.close),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Content Column
                Expanded(
                  child: Column(
                    children: [
                      // Main Content
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _viewList,
                        ),
                      ),

                      // 3. Footer Bar
                      Container(
                        height: 50,
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                height: 35,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(color: Colors.white10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text("${state.tr("Status: ")}${state.statusMessage}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildFooterButton(state.tr("Modo Escuro"), Icons.nightlight_round, Colors.yellow.shade800, () {}),
                            const SizedBox(width: 10),
                            _buildFooterButton("INI Configuration", Icons.settings_applications, Colors.green.shade800, () {}),
                            const SizedBox(width: 10),
                            const Text("v1.0", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Wizard Overlay
          if (state.isWizardActive)
            const Positioned.fill(child: WizardView()),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, AppState state) {
    bool isSelected = _selectedIndex == index;
    var tab = _tabs[index];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => _onNavigate(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF107C10).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                tab['icon'],
                size: 20,
                color: isSelected ? const Color(0xFF107C10) : Colors.white60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  state.tr(tab['key']),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowControl(Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 14, color: Colors.black),
    );
  }

  Widget _buildFooterButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
