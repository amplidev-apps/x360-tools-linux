import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import '../services/python_bridge.dart';

class XboxUnityApi {
  static final Map<String, String> _cache = {};

  // DLC keywords to strip so we look up the base game cover
  static const _dlcKeywords = [
    ' - dlc', ' dlc', ' - season pass', ' season pass',
    ' - bundle', ' bundle pack', ' - pack', ' - expansion',
    ' - add-on', ' add-on', ' - addon', ' addon',
    ' - content pack', ' content pack', ' - map pack',
  ];

  // Edition tags to strip
  static const _editionTags = [
    'game of the year edition', 'goty edition', 'goty',
    'complete edition', 'ultimate edition', 'platinum hits',
    'greatest hits', 'classic edition', 'special edition',
    'definitive edition', 'enhanced edition', 'gold edition',
    'premium edition', 'anniversary edition', 'remastered',
  ];

  static const _romanMap = {
    'v': '5',
    'ii': '2', 'iii': '3', 'iv': '4', 'vi': '6',
    'vii': '7', 'viii': '8', 'ix': '9', 'xi': '11',
    'xii': '12',
  };

  static const _numWordMap = {
    'zero': '0', 'one': '1', 'two': '2', 'three': '3',
    'four': '4', 'five': '5', 'six': '6', 'seven': '7',
    'eight': '8', 'nine': '9', 'ten': '10',
  };

  /// Build an ordered, deduplicated list of search query variations from a raw name.
  static List<String> _buildVariations(String raw) {
    // Normalise: strip parens/brackets, disc tags, lower-case
    String name = raw
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'\s+Disc\s+\d+', caseSensitive: false), '')
        .toLowerCase()
        .trim();
    if (name.startsWith('- ')) name = name.substring(2).trim();

    final seen = <String>[];
    void add(String v) {
      v = v.trim();
      if (v.isNotEmpty && !seen.contains(v)) seen.add(v);
    }

    // 1. Colon substitution
    final colon = name.replaceAll(' - ', ': ');
    add(colon);

    // 2. No dash
    add(name.replaceAll(' - ', ' '));

    // 3. Segments around first ' - '
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      add(parts[0]);
      if (parts.length > 1) add(parts.sublist(1).join(' - '));
      add(parts[0].replaceAll(' - ', ': '));
    }

    // 4. DLC suffix stripping → base game name
    String baseDlc = name;
    for (final kw in _dlcKeywords) {
      final idx = baseDlc.toLowerCase().indexOf(kw);
      if (idx > 0) {
        baseDlc = baseDlc.substring(0, idx).replaceAll(RegExp(r'[ \-:]+$'), '').trim();
        break;
      }
    }
    if (baseDlc != name) {
      add(baseDlc);
      add(baseDlc.replaceAll(' - ', ': '));
      add(baseDlc.replaceAll(' - ', ' '));
      if (baseDlc.contains(' - ')) add(baseDlc.split(' - ')[0].trim());
    }

    // 5. Edition tag stripping
    String edStripped = name;
    for (final tag in _editionTags) {
      edStripped = edStripped
          .replaceAll(RegExp(',?\\s*${RegExp.escape(tag)}', caseSensitive: false), '')
          .trim();
    }
    if (edStripped != name) {
      add(edStripped);
      add(edStripped.replaceAll(' - ', ': '));
    }

    // 6. Roman numeral ↔ digit
    _romanMap.forEach((roman, digit) {
      final vr = colon.replaceAll(RegExp('\\b$roman\\b', caseSensitive: false), digit);
      if (vr != colon) add(vr);
      final vd = colon.replaceAll(RegExp('\\b${RegExp.escape(digit)}\\b'), roman);
      if (vd != colon) add(vd);
    });

    // 7. Written numbers ↔ digit
    _numWordMap.forEach((word, digit) {
      final vw = colon.replaceAll(RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false), digit);
      if (vw != colon) add(vw);
      final vd = colon.replaceAll(RegExp('\\b${RegExp.escape(digit)}\\b'), word);
      if (vd != colon) add(vd);
    });

    // 8. Strip leading numeric year/number (e.g. "2006 FIFA World Cup" → "FIFA World Cup")
    final strippedPrefix = colon.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
    if (strippedPrefix != colon) add(strippedPrefix);

    // 9. Bare subtitle after colon
    if (colon.contains(': ')) add(colon.split(': ').sublist(1).join(': ').trim());

    // 10. & ↔ and
    if (colon.contains(' & ')) {
      add(colon.replaceAll(' & ', ' and '));
    } else if (colon.contains(' and ')) {
      add(colon.replaceAll(' and ', ' & '));
    }

    return seen;
  }

  static Future<String?> getCoverUrl(String name) async {
    final variations = _buildVariations(name);

    for (final searchName in variations) {
      // Only return a cached positive hit; skip negative sentinels
      if (_cache.containsKey(searchName) && _cache[searchName]!.isNotEmpty) {
        return _cache[searchName];
      }
      if (_cache.containsKey(searchName) && _cache[searchName]!.isEmpty) {
        continue; // known miss for this variation — try next
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final uri = Uri.parse(
          "https://xboxunity.net/Resources/Lib/TitleList.php"
          "?page=0&count=10&search=${Uri.encodeComponent(searchName)}"
          "&sort=0&direction=1&category=0&filter=0",
        );
        final request = await client.getUrl(uri);
        request.headers.set("X-Requested-With", "XMLHttpRequest");
        request.headers.set("Referer", "https://xboxunity.net/");
        final response = await request.close();
        if (response.statusCode == 200) {
          final respBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(respBody);
          final items = data['Items'] as List?;
          if (items != null && items.isNotEmpty) {
            // Find the best match among results
            var bestItem = items[0];
            final cleanSearch = searchName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            
            for (var item in items) {
              final itemName = item['Name'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
              if (itemName == cleanSearch) {
                bestItem = item;
                break;
              }
              // Fallback to "contains" if it starts with the name
              if (itemName.startsWith(cleanSearch)) {
                bestItem = item;
              }
            }

            final titleId = bestItem['TitleID'];
            final coversCount = int.tryParse(bestItem['Covers'].toString()) ?? 0;
            if (coversCount > 0) {
              final cUri = Uri.parse(
                  "https://xboxunity.net/Resources/Lib/CoverInfo.php?titleid=$titleId");
              final cReq = await client.getUrl(cUri);
              cReq.headers.set("X-Requested-With", "XMLHttpRequest");
              final cResp = await cReq.close();
              if (cResp.statusCode == 200) {
                final cBody = await cResp.transform(utf8.decoder).join();
                final cData = jsonDecode(cBody);
                final covers = cData['Covers'] as List?;
                if (covers != null && covers.isNotEmpty) {
                  final cid = covers[0]['CoverID'];
                  final url = "https://xboxunity.net/Resources/Lib/Cover.php?size=large&cid=$cid";
                  // Cache the canonical name and all variations tried so far
                  _cache[searchName] = url;
                  return url;
                }
              }
            }
          }
        }
        // Mark this specific variation as a known miss
        _cache[searchName] = '';
      } catch (_) {
        // Network error — don't cache, may succeed later
      } finally {
        client.close();
      }
    }

    return null;
  }
}

class AsyncCoverImage extends StatefulWidget {
  final String gameName;
  const AsyncCoverImage({super.key, required this.gameName});

  @override
  State<AsyncCoverImage> createState() => _AsyncCoverImageState();
}

class _AsyncCoverImageState extends State<AsyncCoverImage> {
  String? coverUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    // Add a random delay to stagger requests and avoid overwhelming the API
    await Future.delayed(Duration(milliseconds: 100 + (widget.gameName.length * 10) % 1000));
    
    int retries = 2;
    String? res;
    while (retries > 0) {
      if (!mounted) return;
      res = await XboxUnityApi.getCoverUrl(widget.gameName);
      if (res != null && res.isNotEmpty) break;
      retries--;
      if (retries > 0) await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      setState(() {
        coverUrl = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cvr = (coverUrl != null && coverUrl!.isNotEmpty)
        ? coverUrl!
        : "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg";
    return Image.network(
      cvr,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white12, size: 32),
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
              child: _buildHeroSection(),
            ),
          ),
        
        // 3. Section Title & Category Tabs
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Row(
              children: [
                Text(
                  _selectedPlatform == "360" ? "Xbox 360 Library" : "Xbox Classic Library",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildPlatformChip("360", "Xbox 360"),
                const SizedBox(width: 12),
                _buildPlatformChip("classic", "Original Xbox"),
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
              ? SliverFillRemaining(child: _buildEmptyState())
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 24),
          const Text("No games found for this platform.", style: TextStyle(color: Colors.white38, fontSize: 18)),
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
          _buildDetailHeader(),

          Expanded(
            child: _isLoadingDetails 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF107C10)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(60),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Large Cover & Technical Info
                      _buildDetailSidebar(),

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

  Widget _buildDetailHeader() {
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
            tooltip: "Back to Catalog",
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

  Widget _buildDetailSidebar() {
    final coverUrl = _selectedGameDetails?['cover_url'] ?? "https://raw.githubusercontent.com/antigravity-org/assets/main/covers/generic_360.jpg";
    
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
              child: Image.network(
                coverUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1A1A1A),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported, color: Colors.white10, size: 60),
                        const SizedBox(height: 16),
                        Text("Capa Indisponível", style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
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
                _buildInfoRow(Icons.laptop, "Sistema", _selectedPlatform == "360" ? "Xbox 360" : "Xbox Classic"),
                _buildInfoRow(Icons.public, "Região", _selectedGameDetails?['region'] ?? "Region-Free"),
                _buildInfoRow(Icons.storage, "Tamanho", _selectedGameDetails?['size_formatted'] ?? "Sob-Demanda"),
                _buildInfoRow(Icons.numbers, "Title ID", _selectedGameDetails?['title_id'] ?? "Detectando..."),
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
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildDetailMain(AppState state) {
    final tus = (_selectedGameDetails?['title_updates'] as List?) ?? [];
    final desc = _selectedGameDetails?['description'] ?? "Este título está disponível para transferência direta via x360 Tools Library...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedGame!['name'],
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
            Text("Avaliação: ${_selectedGameDetails?['rating'] ?? '4.8'}/5.0", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 40),

        if (tus.isNotEmpty) ...[
          const Text(
            "TITLE UPDATES (TU) DISPONÍVEIS",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
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
          const Text(
            "REGIÃO / VERSÃO",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54),
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

        const Text(
          "DESCRIÇÃO DO JOGO",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF107C10)),
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
              const Text("AÇÕES DE INSTALAÇÃO", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailActionButton(
                      "INSTALAR NO DISPOSITIVO",
                      "Converter e enviar para USB",
                      Icons.usb,
                      () => _handleGameInstall(state, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailActionButton(
                      "BAIXAR E CONVERTER",
                      "Salvar em uma pasta local",
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
    final dlcs = state.games.where((g) {
      if (g['is_dlc'] != true) return false;
      
      final base = g['base_game_name'].toString().toLowerCase().trim();
      final current = _selectedGame!['name'].toString().toLowerCase().trim();
      
      // Attempt exact or partial match
      return base == current || current.contains(base) || base.contains(current);
    }).toList();

    if (dlcs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DLCS & CONTEÚDOS ADICIONAIS",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF107C10)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: dlcs.map((dlc) => _buildDLCRow(state, dlc)).toList(),
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
                  dlc['name'],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Text(
                  "Download via Internet Archive",
                  style: TextStyle(fontSize: 12, color: Colors.white30),
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
            child: const Text("INSTALAR DLC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
            label: const Text("BAIXAR E INSTALAR"),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("x360 FREEMARKET", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF107C10))),
                  Text("The ultimate Xbox marketplace", style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
              const Spacer(),
              
              // Tabs navigation
              _buildTabButton("CATÁLOGO", FreemarketTab.catalog),
              const SizedBox(width: 8),
              _buildTabButton("DOWNLOADS", FreemarketTab.downloads, badge: state.downloads.where((d) => d.phase != DownloadPhase.completed && d.phase != DownloadPhase.failed && d.phase != DownloadPhase.canceled).length),
              
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
                  decoration: const InputDecoration(
                    hintText: "Search Games, DLCs & Apps...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
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
                tooltip: "Refresh Catalog (Force)",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
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
                  child: const Text("FEATURED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 12),
                      Text("INSTALL NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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
                        child: AsyncCoverImage(gameName: game['name'] ?? ""),
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
