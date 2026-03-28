import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/premium_card.dart';

class HomeView extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Section (Início)
          _buildHero(state),
          const SizedBox(height: 48),

          // 2. Navigation Banners
          Text(
            state.tr("Quick Access"), 
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)
          ),
          const SizedBox(height: 24),
          
          _buildBanner(
            title: state.tr("Instalação Completa"),
            subtitle: state.tr("Configure seu console do zero com o Wizard guiado."),
            icon: Icons.auto_awesome,
            color: const Color(0xFF107C10),
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildBanner(
                  title: state.tr("Dashboards"),
                  subtitle: state.tr("Aurora, Freestyle e mais."),
                  icon: Icons.dashboard_customize,
                  color: Colors.blueAccent,
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildBanner(
                  title: state.tr("Homebrews"),
                  subtitle: state.tr("Apps essenciais para seu 360."),
                  icon: Icons.apps,
                  color: Colors.deepPurpleAccent,
                  onTap: () => onNavigate(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildBanner(
                  title: state.tr("Stealth e Bypass"),
                  subtitle: state.tr("Serviços online e segurança."),
                  icon: Icons.security,
                  color: Colors.redAccent,
                  onTap: () => onNavigate(4),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildBanner(
                  title: state.tr("Plugins e Outros"),
                  subtitle: state.tr("Expanda as funções do seu console."),
                  icon: Icons.extension,
                  color: Colors.orangeAccent,
                  onTap: () => onNavigate(5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildBanner(
            title: state.tr("Injetor Horizon"),
            subtitle: state.tr("Gerencie DLCs, TUs e Saves com facilidade."),
            icon: Icons.send_to_mobile,
            color: const Color(0xFF107C10),
            onTap: () => onNavigate(6),
          ),
          const SizedBox(height: 20),

          _buildBanner(
            title: state.tr("Conversor de Jogos"),
            subtitle: state.tr("Transforme ISOs em GOD (360) ou Extraia (Clássico)."),
            icon: Icons.transform,
            color: Colors.blueGrey,
            onTap: () => onNavigate(7),
          ),
          const SizedBox(height: 20),

          _buildBanner(
            title: state.tr("Gamerpics e Perfil"),
            subtitle: state.tr("Personalize seu console com Gamer Pictures customizadas."),
            icon: Icons.photo_library,
            color: Colors.teal,
            onTap: () => onNavigate(8),
          ),
          const SizedBox(height: 20),

          _buildBanner(
            title: state.tr("Backup e Restauração"),
            subtitle: state.tr("Crie uma imagem completa (.x360b) do seu dispositivo."),
            icon: Icons.settings_backup_restore,
            color: const Color(0xFF107C10),
            onTap: () => onNavigate(9),
          ),
          
          const SizedBox(height: 48),
          
          // Selection Summary (if any)
          if (state.selectedPackages.isNotEmpty) _buildSelectionSummary(state),
        ],
      ),
    );
  }

  Widget _buildBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
            ),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(AppState state) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF0A0A0A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern or subtle image
          Positioned(
            right: -50,
            top: -50,
            child: Icon(Icons.blur_on, size: 300, color: const Color(0xFF107C10).withOpacity(0.1)),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.tr("BEM-VINDO AO"), 
                  style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 14)
                ),
                const Text("x360 Tools v2.0", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const SizedBox(height: 10),
                Text(
                  state.tr("A central definitiva para o seu Xbox 360 no Linux."), 
                  style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.6))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSummary(AppState state) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF107C10), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Itens Selecionados", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "${state.selectedPackages.length} pacotes prontos para instalação.",
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => onNavigate(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C10), 
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)
            ),
            child: const Text("IR PARA INSTALAÇÃO", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
