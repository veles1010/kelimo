import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/models/mosaic_progress.dart';
import 'package:kelimo/services/mosaic_service.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class MosaicScreen extends StatefulWidget {
  const MosaicScreen({required this.service, super.key});

  final MosaicService service;

  @override
  State<MosaicScreen> createState() => _MosaicScreenState();
}

class _MosaicScreenState extends State<MosaicScreen> {
  late MosaicProgress _progress;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _progress = widget.service.load();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_progress.progress * 100).round();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Gizli Mozaik'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showIntro) ...[
                      GlassSurface(
                        enableBlur: false,
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Her öğrendiğin kelime yeni bir parçayı ortaya çıkarır.',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Açıklamayı kapat',
                              onPressed: () =>
                                  setState(() => _showIntro = false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    GlassSurface(
                      enableBlur: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_progress.discoveredCount} / 1080 parça keşfedildi',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '%$percentage · ${_progress.remainingCount} kelime kaldı',
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _progress.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      label:
                          '${_progress.discoveredCount} / 1080 mozaik parçası keşfedildi',
                      child: AspectRatio(
                        aspectRatio: MosaicService.columns / MosaicService.rows,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            key: const ValueKey('knowledge-garden-mosaic'),
                            painter: _KnowledgeGardenPainter(
                              discovered: _progress.discoveredCellIndices,
                              brightness: Theme.of(context).brightness,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_progress.isComplete) ...[
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .96, end: 1),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: GlassSurface(
                          child: Text(
                            'Kelimo Ustası — 1080 kelimenin tamamını öğrendin!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeGardenPainter extends CustomPainter {
  const _KnowledgeGardenPainter({
    required this.discovered,
    required this.brightness,
  });

  final Set<int> discovered;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / MosaicService.columns;
    final cellHeight = size.height / MosaicService.rows;
    final paint = Paint();
    for (var row = 0; row < MosaicService.rows; row++) {
      for (var column = 0; column < MosaicService.columns; column++) {
        final index = row * MosaicService.columns + column;
        paint.color = discovered.contains(index)
            ? _artColor(column, row)
            : _coveredColor(column, row);
        canvas.drawRect(
          Rect.fromLTWH(
            column * cellWidth,
            row * cellHeight,
            cellWidth + .35,
            cellHeight + .35,
          ),
          paint,
        );
      }
    }
  }

  Color _coveredColor(int x, int y) {
    final checker = (x + y).isEven;
    if (brightness == Brightness.dark) {
      return checker ? const Color(0xff253744) : const Color(0xff2b414c);
    }
    return checker ? const Color(0xffc8d7d3) : const Color(0xffd4dfdc);
  }

  Color _artColor(int x, int y) {
    final sunDistance = math.sqrt(math.pow(x - 29, 2) + math.pow(y - 6, 2));
    if (sunDistance < 4) return const Color(0xffffa24c);
    if (y < 17) {
      if (y < 6) return const Color(0xff48558f);
      if (y < 12) return const Color(0xff6776ad);
      return const Color(0xfff0a36f);
    }
    final bookLeft = y >= 21 && x >= 5 && x <= 17 && y <= 27;
    final bookRight = y >= 21 && x >= 18 && x <= 30 && y <= 27;
    if (bookLeft) {
      return x + y % 2 < 22 ? const Color(0xffffe5bd) : const Color(0xfff7c979);
    }
    if (bookRight) {
      return x - y > -5 ? const Color(0xffffe5bd) : const Color(0xfff7c979);
    }
    if (y == 28 && x >= 5 && x <= 30) return const Color(0xff25345f);
    final stem = (x == 10 || x == 18 || x == 25) && y >= 14 && y <= 22;
    if (stem) return const Color(0xff159f91);
    final leaf =
        ((x - 10).abs() + (y - 16).abs() < 3) ||
        ((x - 18).abs() + (y - 13).abs() < 3) ||
        ((x - 25).abs() + (y - 17).abs() < 3);
    if (leaf) return const Color(0xff35c5a5);
    return y < 21 ? const Color(0xff8b6bb3) : const Color(0xff263d59);
  }

  @override
  bool shouldRepaint(covariant _KnowledgeGardenPainter oldDelegate) =>
      oldDelegate.discovered != discovered ||
      oldDelegate.brightness != brightness;
}
