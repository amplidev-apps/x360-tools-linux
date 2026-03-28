import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import '../services/python_bridge.dart';

// Removed redundant XboxUnityApi class. High-accuracy mapping is now handled by the Python backend.

class AsyncCoverImage extends StatefulWidget {
  final String gameName;
  final String platform;
  final String? initialCoverUrl;
  final String? initialLocalPath;
  final String? titleId;
  
  const AsyncCoverImage({
    super.key, 
    required this.gameName, 
    this.platform = "360",
    this.initialCoverUrl,
    this.initialLocalPath,
    this.titleId,
  });

  @override
  State<AsyncCoverImage> createState() => _AsyncCoverImageState();
}

class _AsyncCoverImageState extends State<AsyncCoverImage> {
  String? coverUrl;
  String? localPath;
  String? tid;
  String? localRes; // Helper for _load

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    // If we already have data from the batch load, use it immediately!
    if (widget.initialCoverUrl != null || widget.initialLocalPath != null || widget.titleId != null) {
      if (mounted) {
        setState(() {
          coverUrl = widget.initialCoverUrl;
          localPath = widget.initialLocalPath;
          tid = widget.titleId;
        });
      }
      return; 
    }

    // Fallback: If for some reason the batch metadata is missing, fetch it.
    // Stagger requests to avoid overwhelming the bridge
    await Future.delayed(Duration(milliseconds: 200 + (widget.gameName.length * 15) % 800));
    if (!mounted) return;

    final state = Provider.of<AppState>(context, listen: false);
    String? res;
    Map<String, dynamic>? details;
    try {
      details = await state.fetchGameDetails(widget.gameName, widget.platform);
      if (details['status'] == 'success' && details['data'] != null) {
        res = details['data']['CoverUrl'];
        localRes = details['data']['LocalPath'];
      }
    } catch (e) {
      debugPrint("Error loading core cover for ${widget.gameName}: $e");
    }

    if (mounted) {
      setState(() {
        coverUrl = res;
        localPath = localRes;
        tid = details?['data']?['TitleID'] ?? details?['data']?['title_id'];
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // 1. Try BUNDLED ASSET (Highest priority, ultra-fast)
    if (tid != null && tid != "Desconhecido") {
      return Image.asset(
        'assets/gamecovers/$tid.jpg',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        errorBuilder: (context, error, stackTrace) {
           // 2. Try LOCAL CACHE (If asset is missing for new games)
           if (localPath != null && localPath!.isNotEmpty && File(localPath!).existsSync()) {
              return Image.file(
                File(localPath!),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stackTrace) => _buildNetworkFallback(),
              );
           }
           return _buildNetworkFallback();
        },
      );
    }

    return _buildNetworkFallback();
  }

  Widget _buildNetworkFallback() {
    final cvr = (coverUrl != null && coverUrl!.isNotEmpty)
        ? coverUrl!
        : "https://xboxunity.net/Resources/Lib/Images/Covers/4D5707E1.jpg";
    
    return Image.network(
      cvr,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    // Attempt to load the user's preferred placeholder locally first (V41)
    final fallbackPath = "../applib/cache/covers/4D5707E1.jpg";
    if (File(fallbackPath).existsSync()) {
      return Image.file(
        File(fallbackPath),
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
      );
    }

    return Container(
      color: Colors.black26,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32),
            SizedBox(height: 8),
            Text("NO COVER", style: TextStyle(color: Colors.white10, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class FreemarketView extends StatefulWidget {
  const FreemarketView({super.key});

  @override
  State<FreemarketView> createState() => _FreemarketViewState();
}

enum FreemarketTab { catalog, downloads }

class _FreemarketViewState extends State<FreemarketView> {
  FreemarketTab _currentTab = FreemarketTab.catalog;
  String _selectedPlatform = "360";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  Map<String, dynamic>? _selectedGame;
  Map<String, dynamic>? _selectedVersion;
  Map<String, dynamic>? _selectedGameDetails;
  bool _isLoadingDetails = false;

  void _selectGame(Map<String, dynamic> game) async {
    final state = Provider.of<AppState>(context, listen: false);
    setState(() {
      _selectedGame = game;
      _selectedVersion = game['versions'] != null && (game['versions'] as List).isNotEmpty 
          ? (game['versions'] as List)[0] 
          : game;
      _isLoadingDetails = true;
      _selectedGameDetails = null;
    });

    try {
      final detailsRes = await state.fetchGameDetails(game['name'], game['platform'] ?? "360");
      if (detailsRes['status'] == 'success') {
        setState(() => _selectedGameDetails = detailsRes['data']);
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchGames(platform: _selectedPlatform);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _changePlatform(String platform) {
    if (_selectedPlatform == platform) return;
    setState(() => _selectedPlatform = platform);
    context.read<AppState>().fetchGames(platform: platform);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: _selectedGame == null ? _buildMainGallery(state) : _buildGameDetailView(state),
        ),
        
        // Installation Overlay (Global)
        if (state.isInstalling)
          Positioned.fill(
            child: Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  width: 450,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.downloading_rounded, color: Color(0xFF107C10), size: 64),
                      const SizedBox(height: 24),
                      Text(
                        state.statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 40),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF107C10)),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text("${(state.progress * 100).toInt()}% Concluído", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => state.cancelInstallation(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                            ),
                          ),
                          child: const Text("CANCELAR INSTALAÇÃO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainGallery(AppState state) {
    final filteredGames = state.games.where((g) {
      // 1. Filter out DLCs/Addons from the main grid
      if (g['is_dlc'] == true) return false;
      
      // Reinforce with name-based check to catch uncaught items before refresh
      final name = (g['name'] as String).toLowerCase();
      if (name.contains(' dlc') || name.contains(' - dlc') || 
          name.contains('season pass') || name.contains('downloadable content')) {
        return false;
      }
      
      // 2. Apply search query
      if (_searchQuery.isEmpty) return true;
      return (g['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        children: [
          // 1. Premium Header with Glassmorphism
          _buildHeader(state),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentTab == FreemarketTab.catalog 
                  ? _buildCatalogView(state)
                  : _buildDownloadsTab(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogView(AppState state) {
    final filteredGames = state.games.where((g) {
      if (g['is_dlc'] == true) return false;
      final name = (g['name'] as String).toLowerCase();
      if (name.contains(' dlc') || name.contains(' - dlc') || 
          name.contains('season pass') || name.contains('downloadable content')) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return (g['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return CustomScrollView(
      primary: false,
      slivers: [
        // 2. Hero Section
        if (_searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: _buildHeroSection(state),
            ),
          ),
        
        // 3. Section Title & Category Tabs
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Row(
              children: [
                Text(
                  _selectedPlatform == "360" ? state.tr("Xbox 360 Library") : state.tr("Xbox Classic Library"),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildPlatformChip("360", state.tr("Xbox 360")),
                const SizedBox(width: 12),
                _buildPlatformChip("classic", state.tr("Original Xbox")),
              ],
            ),
          ),
        ),
        
        // 4. Game Grid (Virtualized)
        state.isLoadingGames 
          ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF107C10)),
              ),
            )
          : filteredGames.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState(state))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 32,
                      crossAxisSpacing: 32,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildGameCard(filteredGames[index]),
                      childCount: filteredGames.length,
                    ),
                  ),
                ),
        
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmptyState(AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 24),
          const Text("Nenhuma sinopse disponível.", style: TextStyle(color: Colors.white38, fontSize: 18)),
          const SizedBox(height: 8),
          const Text("Try changing the search query or platform category.", style: TextStyle(color: Colors.white12, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGameDetailView(AppState state) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        children: [
          // Sub-header with Back Button
          _buildDetailHeader(state),

          Expanded(
            child: _isLoadingDetails 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(60),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Large Cover & Technical Info
                      _buildDetailSidebar(state),

                      const SizedBox(width: 60),

                      // Right: Description & Installation
                      Expanded(child: _buildDetailMain(state)),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _selectedGame = null),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF107C10)),
            tooltip: state.tr("Back to Catalog"),
          ),
          const SizedBox(width: 12),
          Text(
            _selectedGame!['name'].toString().toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSidebar(AppState state) {
    // Priority: 1. Detail Search (Highest) 2. Pre-loaded Game List (Medium) 3. Generic Placeholder (Low)
    final coverUrl = _selectedGameDetails?['CoverUrl'] ?? 
                     _selectedGame?['coverUrl'] ??
                     "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg";
    
    final localPath = _selectedGameDetails?['LocalPath'] ?? _selectedGame?['localPath'];

    return SizedBox(
      width: 300,
      child: Column(
        children: [
          // Large Premium Cover
          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: (localPath != null && File(localPath).existsSync())
                ? Image.file(
                    File(localPath),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => AsyncCoverImage(
                      gameName: _selectedGame!['name'],
                      platform: _selectedPlatform,
                      titleId: _selectedGameDetails?['TitleID'] ?? _selectedGame?['titleId'],
                    ),
                  )
                : AsyncCoverImage(
                    gameName: _selectedGame!['name'],
                    platform: _selectedPlatform,
                    titleId: _selectedGameDetails?['TitleID'] ?? _selectedGame?['titleId'],
                  ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Ficha Técnica Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("FICHA TÉCNICA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C10))),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.laptop, state.tr("Sistema"), _selectedPlatform == "360" ? "Xbox 360" : "Xbox Classic"),
                _buildInfoRow(Icons.public, state.tr("Região"), _selectedGameDetails?['Region'] ?? "Region-Free"),
                _buildInfoRow(Icons.code, state.tr("GÊNERO"), _selectedGameDetails?['Genre'] ?? "Ação e Aventura"),
                _buildInfoRow(Icons.calendar_today, state.tr("LANÇAMENTO"), _selectedGameDetails?['ReleaseDate'] ?? "2010"),
                _buildInfoRow(Icons.business, state.tr("DESENVOLVEDOR"), _selectedGameDetails?['Developer'] ?? "Microsoft Studios"),
                _buildInfoRow(Icons.store, state.tr("DISTRIBUIDORA"), _selectedGameDetails?['Publisher'] ?? "Microsoft"),
                _buildInfoRow(Icons.numbers, state.tr("TITLE ID"), _selectedGameDetails?['TitleID'] ?? _selectedGame?['titleId'] ?? "Detectando..."),
                _buildInfoRow(Icons.storage, state.tr("Tamanho"), _selectedGameDetails?['SizeFormatted'] ?? state.tr("Sob-Demanda")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 12),
          Text("$label:", style: const TextStyle(fontSize: 13, color: Colors.white38)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMain(AppState state) {
    final tus = (_selectedGameDetails?['TitleUpdates'] as List?) ?? (_selectedGameDetails?['title_updates'] as List?) ?? [];
    final desc = _selectedGameDetails?['Description'] ?? _selectedGameDetails?['description'] ?? "Este título está disponível para transferência direta via x360 Tools Library...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedGame!['name'],
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_selectedGameDetails?['Genre'] != null)
              Container(
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C10).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF107C10).withOpacity(0.3)),
                ),
                child: Text(
                  _selectedGameDetails!['Genre'].toString().toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF107C10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.orange, size: 16),
            const Icon(Icons.star, color: Colors.orange, size: 16),
            const Icon(Icons.star, color: Colors.orange, size: 16),
            const Icon(Icons.star, color: Colors.orange, size: 16),
            const Icon(Icons.star_half, color: Colors.orange, size: 16),
            const SizedBox(width: 12),
            Text("${state.tr("Avaliação")}: ${_selectedGameDetails?['Rating'] ?? '4.8'}/5.0", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            const SizedBox(width: 16),
            if (_selectedGameDetails?['Source'] != null)
              Text("${state.tr("ORIGEM")}: ${_selectedGameDetails!['Source']}", style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 40),

        if (tus.isNotEmpty) ...[
          Text(
            state.tr("TITLE UPDATES (TU) DISPONÍVEIS"),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: tus.map((tu) => _buildTURow(state, tu)).toList(),
            ),
          ),
          const SizedBox(height: 40),
        ],

        // DLCs & Add-ons Section
        _buildDLCSection(state),

        // Region / Version Selector
        if (_selectedGame != null && _selectedGame!['versions'] != null && (_selectedGame!['versions'] as List).length > 1) ...[
          Text(
            state.tr("REGIÃO / VERSÃO"),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedVersion,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: (_selectedGame!['versions'] as List).map((v) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: v as Map<String, dynamic>,
                    child: Text(
                      v['name'],
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedVersion = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],

        Text(
          state.tr("DESCRIÇÃO DO JOGO"),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF107C10)),
        ),
        const SizedBox(height: 16),
        Text(
          desc,
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), height: 1.6),
        ),
        
        const SizedBox(height: 60),

        // Installation Options Card
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF107C10).withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF107C10).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.tr("AÇÕES DE INSTALAÇÃO"), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailActionButton(
                      state.tr("INSTALAR NO DISPOSITIVO"),
                      state.tr("Converter e enviar para USB"),
                      Icons.usb,
                      () => _handleGameInstall(state, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailActionButton(
                      state.tr("BAIXAR E CONVERTER"),
                      state.tr("Salvar em uma pasta local"),
                      Icons.folder_open,
                      () => _handleGameInstall(state, false),
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDLCSection(AppState state) {
    List dlcs = (_selectedGameDetails?['DLCs'] as List?) ?? [];
    
    // Fallback to legacy filtering if no persistent DLCs found yet
    if (dlcs.isEmpty) {
      dlcs = state.games.where((g) {
        if (g['is_dlc'] != true) return false;
        
        final base = g['base_game_name'].toString().toLowerCase().trim();
        final current = _selectedGame!['name'].toString().toLowerCase().trim();
        
        // Attempt exact or partial match
        return base == current || current.contains(base) || base.contains(current);
      }).toList();
    }

    if (dlcs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.tr("DLCS & CONTEÚDOS ADICIONAIS"),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF107C10)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: dlcs.map((dlc) => _buildDLCRow(state, dlc as Map<String, dynamic>)).toList(),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDLCRow(AppState state, Map<String, dynamic> dlc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_box_outlined, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dlc['Name'] ?? dlc['name'] ?? "Unknown DLC",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  dlc['DownloadUrl'] != null ? "Download via Internet Archive" : (dlc['description'] ?? "Conteúdo Adicional"),
                  style: const TextStyle(fontSize: 12, color: Colors.white30),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final version = (dlc['versions'] as List).isNotEmpty ? dlc['versions'][0] : dlc;
              state.installFromFreemarket(
                version, 
                state.selectedDrive?['path'] ?? "", 
                true
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C10).withOpacity(0.1),
              foregroundColor: const Color(0xFF107C10),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF107C10), width: 1),
              ),
            ),
            child: Text(state.tr("INSTALAR DLC"), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTURow(AppState state, Map<String, dynamic> tu) {
    final version = tu['Version'] ?? "N/A";
    final mediaId = tu['MediaID'] ?? "Qualquer";
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update, size: 16, color: Colors.white38),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TU Version $version", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Media ID: $mediaId", style: const TextStyle(fontSize: 11, color: Colors.white24)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => state.installTitleUpdate(tu, _selectedGameDetails!['title_id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C10),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.download, size: 14),
            label: Text(state.tr("BAIXAR E INSTALAR")),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActionButton(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isSecondary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSecondary ? Colors.white.withOpacity(0.03) : const Color(0xFF107C10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSecondary ? Colors.white10 : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSecondary ? Colors.white54 : Colors.white),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isSecondary ? Colors.white38 : Colors.white70)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGameInstall(AppState state, bool onDevice) async {
    String? destPath;
    if (onDevice) {
      if (state.selectedDrive == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Nenhum dispositivo selecionado.")));
        return;
      }
      destPath = state.selectedDrive!['device'];
    } else {
      destPath = await state.pickDirectory(title: "Selecione onde salvar o jogo");
    }

    if (destPath != null) {
       final gameToInstall = _selectedVersion ?? _selectedGame!;
       await state.installFromFreemarket(gameToInstall, destPath, onDevice);
    }
  }

  Widget _buildHeader(AppState state) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.tr("x360 FREEMARKET"), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF107C10))),
                  Text(state.tr("The ultimate Xbox marketplace"), style: const TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
              const Spacer(),
              
              // Tabs navigation
              _buildTabButton(state.tr("CATÁLOGO"), FreemarketTab.catalog),
              const SizedBox(width: 8),
              _buildTabButton(state.tr("DOWNLOADS"), FreemarketTab.downloads, badge: state.downloads.where((d) => d.phase != DownloadPhase.completed && d.phase != DownloadPhase.failed && d.phase != DownloadPhase.canceled).length),
              
              const SizedBox(width: 32),

              // Animated Search Bar
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  height: 40,
                  decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      setState(() => _searchQuery = v);
                    });
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: state.tr("Search Games, DLCs & Apps..."),
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
              
              // Refresh button
              IconButton(
                onPressed: () => state.fetchGames(platform: _selectedPlatform, refresh: true),
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: state.tr("Refresh Catalog (Force)"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(AppState state) {
    return Container(
      height: 420,
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
            color: const Color(0xFF107C10).withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background "Art" (Placeholder for featured game)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Opacity(
                opacity: 0.3,
                child: Image.network(
                  "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070&auto=format&fit=crop", // Generic gaming background
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF107C10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(state.tr("FEATURED"), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "AETHERBOUND\nLEGACY OF THE VOID",
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1.5),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 400,
                  child: Text(
                    "Explore the forgotten sectors of the galaxy in this stunning RPG masterpiece. Now available for download in various regions.",
                    style: TextStyle(fontSize: 16, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C10),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download, size: 20),
                      const SizedBox(width: 12),
                      Text(state.tr("INSTALL NOW"), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(String platform, String label) {
    bool isSelected = _selectedPlatform == platform;
    return InkWell(
      onTap: () => _changePlatform(platform),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF107C10) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    return InkWell(
      onTap: () => _selectGame(game),
      borderRadius: BorderRadius.circular(12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AsyncCoverImage(
                          gameName: game['name'] ?? "",
                          platform: game['platform'] ?? "360",
                          initialCoverUrl: game['coverUrl'],
                          initialLocalPath: game['localPath'],
                          titleId: game['titleId'],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              game['name'] ?? "Unknown Title",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(game['platform'] == '360' ? "Xbox 360" : "Original Xbox", style: const TextStyle(fontSize: 11, color: Colors.white38)),
                const Spacer(),
                const Icon(Icons.cloud_download, size: 12, color: Color(0xFF107C10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, FreemarketTab tab, {int badge = 0}) {
    final isSelected = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF107C10) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : Colors.white70)),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                child: Text(badge.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsTab(AppState state) {
    if (state.downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_for_offline_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 24),
            Text("Nenhum download ativo ou concluído", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(40),
      itemCount: state.downloads.length,
      itemBuilder: (context, index) {
        final item = state.downloads[state.downloads.length - 1 - index]; // Newest first
        return _buildDownloadCard(state, item);
      },
    );
  }

  Widget _buildDownloadCard(AppState state, DownloadItem item) {
    final bool isFinished = item.phase == DownloadPhase.completed;
    final bool isFailed = item.phase == DownloadPhase.failed;
    final bool isActive = !isFinished && !isFailed && item.phase != DownloadPhase.canceled;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: const Color(0xFF107C10).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.videogame_asset_outlined, color: Color(0xFF107C10), size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(item.statusMessage, style: TextStyle(color: isFailed ? Colors.redAccent : Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
              if (isFinished && item.localPath != null)
                ElevatedButton.icon(
                  onPressed: () => state.openInstallationFolder(item.localPath!),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text("ABRIR PASTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C10).withOpacity(0.2),
                    foregroundColor: const Color(0xFF107C10),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (isActive)
                 IconButton(
                   onPressed: () => state.cancelDownload(item.id),
                   icon: const Icon(Icons.close_rounded, color: Colors.white24),
                   tooltip: "Cancelar Instalação",
                 ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(isFailed ? Colors.redAccent : const Color(0xFF107C10)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(item.progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white24)),
              if (isActive)
                Text(item.platform == "360" ? "XBOX 360 GOD" : "XBOX CLASSIC", style: const TextStyle(fontSize: 11, color: Colors.white12, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
