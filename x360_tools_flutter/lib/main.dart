import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'views/library_view.dart';
import 'views/dashlaunch_view.dart';
import 'views/ftp_view.dart';
import 'views/saves_view.dart';
import 'services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    title: 'x360 Tools',
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setIcon('/home/amplimusic/Documentos/BadStickLinux/v1.1/x360_tools_flutter/assets/x360_tools_icon.png');
  });

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
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'x360 Tools',
      debugShowCheckedModeBanner: false,
      theme: state.isDarkMode ? ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme.dark(
          primary: Colors.green,
          surface: Color(0xFF151515),
        ),
      ) : ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F2),
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF107C10),
          onPrimary: Colors.white,
          surface: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
          ),
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
      const LibraryView(),
      const DashboardsView(),
      const HomebrewView(),
      const StealthView(),
      const PluginsView(),
      const HorizonInjectorView(),
      const ConvertView(),
      const ProfilePicsView(),
      const BackupView(),
      const DashLaunchView(),
      const FtpView(),
      const SavesView(),
      const SettingsView(),
    ];
  }

  final List<Map<String, dynamic>> _tabs = [
    {"name": "Início", "icon": Icons.home_rounded, "key": "Início"},
    {"name": "Instalação", "icon": Icons.install_desktop_rounded, "key": "Instalação"},
    {"name": "x360 Freemarket", "icon": Icons.shopping_bag_rounded, "key": "x360 Freemarket"},
    {"name": "Minha Biblioteca", "icon": Icons.library_books_rounded, "key": "Minha Biblioteca"},
    {"name": "Dashboards", "icon": Icons.dashboard_rounded, "key": "Dashboards"},
    {"name": "Homebrews", "icon": Icons.apps_rounded, "key": "Homebrews"},
    {"name": "Stealth e Bypass", "icon": Icons.security_rounded, "key": "Stealth e Bypass"},
    {"name": "Plugins e Outros", "icon": Icons.extension_rounded, "key": "Plugins e Outros"},
    {"name": "x360 Landscape", "icon": Icons.send_to_mobile_rounded, "key": "x360 Landscape"},
    {"name": "x360 Converter", "icon": Icons.transform_rounded, "key": "x360 Converter"},
    {"name": "Profile Pics", "icon": Icons.photo_library_rounded, "key": "Profile Pics"},
    {"name": "Backup e Restauro", "icon": Icons.settings_backup_restore, "key": "Backup e Restauro"},
    {"name": "DashLaunch Pro", "icon": Icons.tune_rounded, "key": "DashLaunch Pro"},
    {"name": "FTP Manager", "icon": Icons.wifi_tethering, "key": "FTP Manager"},
    {"name": "Save Manager", "icon": Icons.sd_storage, "key": "Save Manager"},
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
                    color: state.isDarkMode ? Colors.black : const Color(0xFFE6E6E6),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Logo/Header (Modern Vector Identity)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SvgPicture.asset(
                              state.isDarkMode ? 'assets/x360_new_logo_white.svg' : 'assets/x360_new_logo_black.svg',
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Nav Items
                        Expanded(
                          child: ListView.builder(
                            itemCount: _tabs.length,
                            itemBuilder: (context, index) => _buildSidebarItem(index, state),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // 2. Content Column
                Expanded(
                  child: Column(
                    children: [
                      // 1. Custom Title Bar / Window Draggable Area
                      GestureDetector(
                        onPanStart: (details) {
                          windowManager.startDragging();
                        },
                        child: Container(
                          height: 50,
                        color: state.isDarkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Spacer(),
                              _buildWindowControl(Colors.yellow, Icons.remove, () => windowManager.minimize()),
                              _buildWindowControl(Colors.green, Icons.crop_square, () async {
                                if (await windowManager.isMaximized()) {
                                  windowManager.unmaximize();
                                } else {
                                  windowManager.maximize();
                                }
                              }),
                              _buildWindowControl(Colors.red, Icons.close, () => windowManager.close()),
                            ],
                          ),
                        ),
                      ),

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
                        color: state.isDarkMode ? Colors.black : const Color(0xFFE6E6E6),
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
                                  color: state.isDarkMode ? Colors.black : Colors.white,
                                  border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text("${state.tr("Status: ")}${state.statusMessage}", style: TextStyle(fontSize: 12, color: state.isDarkMode ? Colors.white70 : Colors.black87)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildFooterButton(
                                state.isDarkMode ? state.tr("Modo Escuro") : state.tr("Modo Claro"), 
                                state.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny, 
                                state.isDarkMode ? Colors.yellow.shade800 : Colors.blue.shade700, 
                                state.toggleTheme),
                            const SizedBox(width: 10),
                            const Text("v1.1", style: TextStyle(color: Colors.white38, fontSize: 12)),
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
                color: isSelected ? const Color(0xFF107C10) : (state.isDarkMode ? Colors.white60 : Colors.black87),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  state.tr(tab['key']),
                  style: TextStyle(
                    color: isSelected ? (state.isDarkMode ? Colors.white : Colors.black) : (state.isDarkMode ? Colors.white60 : Colors.black),
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

  Widget _buildWindowControl(Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 14, color: Colors.black),
      ),
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
