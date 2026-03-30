import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/python_bridge.dart';

/// Shown after the user picks an image. Provides interactive
/// 1:1 crop, a name field, device selector, and gallery toggle.
class GamerpicEditorDialog extends StatefulWidget {
  final String imagePath;

  const GamerpicEditorDialog({super.key, required this.imagePath});

  @override
  State<GamerpicEditorDialog> createState() => _GamerpicEditorDialogState();
}

class _GamerpicEditorDialogState extends State<GamerpicEditorDialog> {
  // ── Crop state ────────────────────────────────────────────────────────────
  // Crop box in relative [0..1] coords over the displayed image
  double _cropX = 0.0;
  double _cropY = 0.0;
  double _cropSize = 1.0; // square side as fraction of min(displayW, displayH)

  // Drag offset for moving the crop box
  Offset? _dragStart;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;

  // Actual decoded image dimensions (to pass crop box in pixels to backend)
  double _imgW = 1;
  double _imgH = 1;

  // ── Form state ────────────────────────────────────────────────────────────
  late TextEditingController _nameCtrl;
  String? _selectedDevice;
  bool _saveToGallery = true;
  bool _installToDevice = false;

  bool _isCreating = false;
  String? _resultMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    final filename = widget.imagePath.split('/').last.split('.').first;
    _nameCtrl = TextEditingController(text: filename);

    // Load the image to get its dimensions
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(Uint8List.fromList(bytes), (img) {
        completer.complete(img);
      });
      final img = await completer.future;
      setState(() {
        _imgW = img.width.toDouble();
        _imgH = img.height.toDouble();
        // Start with a centered square crop
        final side = min(_imgW, _imgH);
        _cropSize = side / max(_imgW, _imgH);
        if (_imgW > _imgH) {
          _cropX = (_imgW - side) / 2 / _imgW;
          _cropY = 0.0;
        } else if (_imgH > _imgW) {
          _cropX = 0.0;
          _cropY = (_imgH - side) / 2 / _imgH;
        }
      });
      img.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Convert relative [0..1] crop coords to pixel crop box (Pillow format)
  List<int> _toCropBox(double displayW, double displayH) {
    final sideRelative = _cropSize; // fraction of display short-side
    final displayShort = min(displayW, displayH);
    final cropDisplayPx = sideRelative * displayShort;

    // Map display coords back to image pixel coords
    final scaleX = _imgW / displayW;
    final scaleY = _imgH / displayH;

    final left = (_cropX * displayW * scaleX).round();
    final top = (_cropY * displayH * scaleY).round();
    final side = (cropDisplayPx * min(scaleX, scaleY)).round();
    final right = (left + side).clamp(0, _imgW.toInt());
    final bottom = (top + side).clamp(0, _imgH.toInt());
    return [left, top, right, bottom];
  }

  Future<void> _create(AppState state, double displayW, double displayH) async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _resultMessage = "Por favor, insira um nome para a Gamerpic.");
      return;
    }

    setState(() {
      _isCreating = true;
      _resultMessage = null;
    });

    final cropBox = _toCropBox(displayW, displayH);
    final cropJson = jsonEncode(cropBox);

    String? device;
    if (_installToDevice && _selectedDevice != null) {
      device = _selectedDevice;
    }

    final res = await PythonBridge.createCustomGamerpic(
      src: widget.imagePath,
      name: _nameCtrl.text.trim(),
      device: device,
      cropJson: cropJson,
      saveToGallery: _saveToGallery,
    );

    if (!mounted) return;

    setState(() {
      _isCreating = false;
      _success = res['status'] == 'success';
      _resultMessage = _success
          ? "Gamerpic \"${_nameCtrl.text.trim()}\" criada com sucesso!"
          : "Erro: ${res['message'] ?? 'Falha desconhecida'}";
    });

    if (_success) {
      // Refresh installed + gallery lists
      if (_installToDevice) state.fetchInstalledGamerpics();
      if (_saveToGallery) state.fetchGamerpics();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 880,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 32),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title bar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.crop, color: Color(0xFF107C10), size: 22),
                  const SizedBox(width: 12),
                  Text(
                    state.tr("Criar Gamer Picture"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  )
                ],
              ),
            ),

            // ── Body: Crop | Settings ─────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── LEFT: Image + Crop overlay ────────────────────────
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final displayW = constraints.maxWidth;
                          final displayH = constraints.maxHeight;
                          final displayShort = min(displayW, displayH);
                          final cropPx = _cropSize * displayShort;
                          final cropLeft = _cropX * displayW;
                          final cropTop = _cropY * displayH;

                          return Stack(
                            children: [
                              // Full image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox.expand(
                                  child: Image.file(
                                    File(widget.imagePath),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              // Dark overlay outside crop
                              ClipPath(
                                clipper: _CropHoleClipper(
                                  left: cropLeft,
                                  top: cropTop,
                                  size: cropPx,
                                ),
                                child: Container(
                                  color: Colors.black.withOpacity(0.55),
                                ),
                              ),

                              // Crop border rectangle
                              Positioned(
                                left: cropLeft,
                                top: cropTop,
                                width: cropPx,
                                height: cropPx,
                                child: GestureDetector(
                                  onPanStart: (d) {
                                    _dragStart = d.localPosition;
                                    _dragStartX = _cropX;
                                    _dragStartY = _cropY;
                                  },
                                  onPanUpdate: (d) {
                                    if (_dragStart == null) return;
                                    final dx = (d.localPosition.dx - _dragStart!.dx) / displayW;
                                    final dy = (d.localPosition.dy - _dragStart!.dy) / displayH;
                                    setState(() {
                                      _cropX = (_dragStartX + dx).clamp(0.0, 1.0 - _cropSize);
                                      _cropY = (_dragStartY + dy).clamp(0.0, 1.0 - _cropSize);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFF107C10), width: 2.5),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Resize handle: bottom-right corner
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: GestureDetector(
                                            onPanUpdate: (d) {
                                              setState(() {
                                                final delta = (d.delta.dx + d.delta.dy) / 2 / displayShort;
                                                _cropSize = (_cropSize + delta).clamp(0.1, 1.0);
                                                // Clamp position so box doesn't go outside image
                                                _cropX = _cropX.clamp(0.0, 1.0 - _cropSize);
                                                _cropY = _cropY.clamp(0.0, 1.0 - _cropSize);
                                              });
                                            },
                                            child: Container(
                                              width: 20,
                                              height: 20,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF107C10),
                                              ),
                                              child: const Icon(Icons.open_in_full_rounded, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        // Rule-of-thirds grid lines
                                        ..._buildGridLines(cropPx),
                                        // Corner helpers
                                        ..._buildCornerMarkers(cropPx),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Move cursor hint
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      state.tr("Arraste para mover • Canto inferior direito para redimensionar"),
                                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Divider ───────────────────────────────────────────
                  VerticalDivider(color: Colors.white.withOpacity(0.05), width: 1),

                  // ── RIGHT: Settings panel ─────────────────────────────
                  SizedBox(
                    width: 280,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        // Store display size for crop box calc
                        final displayW = constraints.maxWidth;
                        final displayH = constraints.maxHeight;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Preview 64x64
                              Center(child: _buildPreview()),
                              const SizedBox(height: 20),

                              _sectionLabel(state.tr("Nome da Gamer Picture")),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLength: 32,
                                decoration: InputDecoration(
                                  counterStyle: const TextStyle(color: Colors.white30, fontSize: 10),
                                  hintText: state.tr("Ex: Meu Avatar"),
                                  hintStyle: const TextStyle(color: Colors.white30),
                                  filled: true,
                                  fillColor: const Color(0xFF1A1A1A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF107C10)),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                              _sectionLabel(state.tr("Opções")),
                              const SizedBox(height: 10),

                              // Save to gallery toggle
                              _buildToggleRow(
                                icon: Icons.photo_library_outlined,
                                label: state.tr("Salvar na Galeria do App"),
                                value: _saveToGallery,
                                onChanged: (v) => setState(() => _saveToGallery = v),
                              ),

                              const SizedBox(height: 12),
                              // Install to device toggle
                              _buildToggleRow(
                                icon: Icons.usb,
                                label: state.tr("Instalar no Dispositivo"),
                                value: _installToDevice,
                                onChanged: (v) => setState(() => _installToDevice = v),
                              ),

                              // Device selector (only if install is checked)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                child: _installToDevice
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _sectionLabel(state.tr("Dispositivo de Destino")),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1A1A1A),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _selectedDevice,
                                                  hint: Text(state.tr("Selecionar..."),
                                                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                                  dropdownColor: const Color(0xFF1A1A1A),
                                                  isExpanded: true,
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                                  items: state.drives.map((d) {
                                                    final label = d['label'] ?? d['device'];
                                                    return DropdownMenuItem<String>(
                                                      value: d['device'].toString(),
                                                      child: Text(label.toString()),
                                                    );
                                                  }).toList(),
                                                  onChanged: (v) => setState(() => _selectedDevice = v),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(),
                              ),

                              const SizedBox(height: 24),

                              // Result message
                              if (_resultMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: _success
                                        ? const Color(0xFF107C10).withOpacity(0.15)
                                        : Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _success
                                          ? const Color(0xFF107C10).withOpacity(0.4)
                                          : Colors.red.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    _resultMessage!,
                                    style: TextStyle(
                                      color: _success ? const Color(0xFF4CAF50) : Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              // Confirm button
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _isCreating
                                      ? null
                                      : () => _create(
                                            state,
                                            // We pass 1,1 here; actual size computed inside _toCropBox using image native size
                                            _imgW,
                                            _imgH,
                                          ),
                                  icon: _isCreating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, size: 18),
                                  label: Text(
                                    _isCreating
                                        ? state.tr("Processando...")
                                        : state.tr("Criar Gamerpic"),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF107C10),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Text(
          "Preview 64×64",
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
        ),
        const SizedBox(height: 6),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(color: const Color(0xFF107C10), width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white54,
          letterSpacing: 0.8,
        ),
      );

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: value ? const Color(0xFF107C10) : Colors.white30),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF107C10),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  List<Widget> _buildGridLines(double size) => [
        // Vertical thirds
        Positioned(left: size / 3, top: 0, child: Container(width: 1, height: size, color: Colors.white.withOpacity(0.2))),
        Positioned(left: 2 * size / 3, top: 0, child: Container(width: 1, height: size, color: Colors.white.withOpacity(0.2))),
        // Horizontal thirds
        Positioned(top: size / 3, left: 0, child: Container(height: 1, width: size, color: Colors.white.withOpacity(0.2))),
        Positioned(top: 2 * size / 3, left: 0, child: Container(height: 1, width: size, color: Colors.white.withOpacity(0.2))),
      ];

  List<Widget> _buildCornerMarkers(double size) {
    const cSize = 10.0;
    const cThick = 2.5;
    final cColor = const Color(0xFF107C10);

    Widget corner(AlignmentGeometry alignment, double rotAngle) => Positioned(
          left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 0 : null,
          right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 0 : null,
          top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 0 : null,
          bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 0 : null,
          child: Transform.rotate(
            angle: rotAngle,
            child: SizedBox(
              width: cSize,
              height: cSize,
              child: Stack(children: [
                Positioned(top: 0, left: 0, child: Container(width: cSize, height: cThick, color: cColor)),
                Positioned(top: 0, left: 0, child: Container(width: cThick, height: cSize, color: cColor)),
              ]),
            ),
          ),
        );

    return [
      corner(Alignment.topLeft, 0),
      corner(Alignment.topRight, pi / 2),
      corner(Alignment.bottomRight, pi),
      corner(Alignment.bottomLeft, -pi / 2),
    ];
  }
}

// ─── Clip path that cuts a square "hole" for the crop box ────────────────────
class _CropHoleClipper extends CustomClipper<Path> {
  final double left, top, size;
  _CropHoleClipper({required this.left, required this.top, required this.size});

  @override
  Path getClip(Size s) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, s.width, s.height));
    final hole = Path()..addRect(Rect.fromLTWH(left, top, size, size));
    return Path.combine(PathOperation.difference, outer, hole);
  }

  @override
  bool shouldReclip(_CropHoleClipper old) =>
      old.left != left || old.top != top || old.size != size;
}
