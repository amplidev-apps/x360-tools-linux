import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/app_state.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Centered Logo
          SvgPicture.asset(state.isDarkMode ? "assets/x360_new_logo_white.svg" : "assets/x360_new_logo_black.svg", height: 160),
          const SizedBox(height: 48),

          // 2. Sections
          _buildSectionHeader(state, state.tr("Geral")),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Idioma"),
            description: state.tr("Altere o idioma global da interface."),
            trailing: _buildLanguageDropdown(state),
          ),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Auto-Scan de Dispositivos"),
            description: state.tr("auto_scan_desc"),
            trailing: Switch(
              value: state.autoScanDrives,
              activeColor: const Color(0xFF107C10),
              onChanged: (val) => state.updateSettings(scan: val),
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(state, state.tr("Caminhos e Rede")),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Pasta de Downloads"),
            description: state.tr("download_path_desc"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.downloadPath.isEmpty ? "Padrão (Downloads)" : state.downloadPath,
                  style: TextStyle(color: state.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open, color: Color(0xFF107C10)),
                  onPressed: () async {
                    // Simple path selection simulation/input
                    final path = await state.pickDirectory();
                    if (path != null) state.updateSettings(dlPath: path);
                  },
                ),
              ],
            ),
          ),
          _buildSettingCard(
            context,
            state,
            isExpandable: true,
            title: state.tr("Configurações de Rede (FTP)"),
            description: state.tr("ftp_settings_desc"),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      state,
                      label: "IP Console",
                      initialValue: state.ftpIp,
                      onChanged: (val) => state.updateSettings(fIp: val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      state,
                      label: "Usuário",
                      initialValue: state.ftpUser,
                      onChanged: (val) => state.updateSettings(fUser: val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      state,
                      label: "Senha",
                      initialValue: state.ftpPass,
                      onChanged: (val) => state.updateSettings(fPass: val),
                      isPassword: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildSettingCard(
            context,
            state,
            isExpandable: true,
            title: state.tr("Archive.org Account"),
            description: state.tr("Insira suas credenciais para acessar o acervo completo."),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      state,
                      label: state.tr("E-mail"),
                      initialValue: state.archiveEmail,
                      onChanged: (val) => state.updateSettings(aEmail: val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      state,
                      label: state.tr("Senha"),
                      initialValue: state.archivePassword,
                      onChanged: (val) => state.updateSettings(aPass: val),
                      isPassword: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Login Button and Status
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4, bottom: 24),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: state.isArchiveLoggingIn ? null : state.loginToArchive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C10),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: state.isArchiveLoggingIn 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(state.tr("ENTRAR"), style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                if (state.archiveLoginMessage.isNotEmpty)
                  Expanded(
                    child: Text(
                      state.archiveLoginMessage,
                      style: TextStyle(
                        color: state.isLoggedInIA ? Colors.green : Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          _buildSectionHeader(state, state.tr("Biblioteca")),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Resolução de Capas"),
            description: state.tr("cover_res_desc"),
            trailing: _buildDropdown(
              state,
              value: state.coverResolution,
              items: ["Baixa", "Média", "Alta"],
              onChanged: (val) => state.updateSettings(res: val),
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(state, state.tr("Sistema")),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Limpar Cache Temporário"),
            description: state.tr("Remove arquivos temporários de extração e ícones antigos."),
            trailing: ElevatedButton(
              onPressed: state.clearTemporaryCache,
              style: ElevatedButton.styleFrom(backgroundColor: state.isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
              child: Text(state.tr("LIMPAR"), style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black87)),
            ),
          ),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Logs e Diagnóstico"),
            description: state.tr("logs_desc"),
            trailing: ElevatedButton(
              onPressed: () {
                // Future: implementation of log viewer
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Visualizador de Logs em breve!")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C10),
                foregroundColor: Colors.white,
              ),
              child: Text(state.tr("VER LOGS"), style: const TextStyle(color: Colors.white)),
            ),
          ),
          _buildSettingCard(
            context,
            state,
            title: state.tr("Desinstalar x360 Tools"),
            description: state.tr("Remove o aplicativo e todos os arquivos de configuração."),
            trailing: ElevatedButton(
              onPressed: state.uninstallX360Tools,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
              child: Text(state.tr("DESINSTALAR"), style: const TextStyle(color: Colors.redAccent)),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppState state, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: Color(0xFF107C10), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
          ),
          Divider(color: state.isDarkMode ? Colors.white10 : Colors.black12),
        ],
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, AppState state, {
    required String title,
    required String description,
    Widget? trailing,
    Widget? content,
    bool isExpandable = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: state.isDarkMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: state.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: state.isDarkMode ? Colors.white : Colors.black)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 13, color: state.isDarkMode ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (content != null) content,
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown(AppState state) {
    return _buildDropdown(
      state,
      value: state.currentLanguage,
      items: ["Português", "English", "Español"],
      onChanged: (val) {
        if (val != null) state.setLanguage(val);
      },
    );
  }

  Widget _buildDropdown(AppState state, {required String value, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: state.isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state.isDarkMode ? Colors.white10 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: state.isDarkMode ? Colors.black : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF107C10)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) => onChanged(val),
        ),
      ),
    );
  }

  Widget _buildTextField(AppState state, {required String label, required String initialValue, required Function(String) onChanged, bool isPassword = false}) {
    return TextField(
      controller: TextEditingController(text: initialValue),
      obscureText: isPassword,
      onChanged: onChanged,
      style: TextStyle(color: state.isDarkMode ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: state.isDarkMode ? Colors.white38 : Colors.black45),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: state.isDarkMode ? Colors.white10 : Colors.black12), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF107C10)), borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: state.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.05),
      ),
    );
  }
}
