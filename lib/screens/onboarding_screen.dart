import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _isCompleting = false;

  static const _pages = [
    (
      title: 'Her gün birkaç kelime',
      description:
          'Kelime kartlarını değerlendir, quizlerle bilgini pekiştir ve '
          'günlük hedefini tamamla.',
      icon: Icons.menu_book_rounded,
    ),
    (
      title: 'XP kazan, kategorileri aç',
      description:
          'Çalıştıkça XP kazan. Yeni kategori açma hakkını istediğin '
          'kategori için kullan.',
      icon: Icons.lock_open_rounded,
    ),
    (
      title: '1080 parçayı keşfet',
      description:
          'Öğrendiğin her benzersiz kelime Gizli Mozaik’in bir parçasını '
          'ortaya çıkarır.',
      icon: Icons.grid_view_rounded,
    ),
  ];

  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  void _goTo(int target) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _pages.length - 1;
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('onboarding-skip'),
                  onPressed: _isCompleting ? null : _finish,
                  child: const Text('Atla'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('onboarding-pages'),
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => _OnboardingPage(
                    title: _pages[index].title,
                    description: _pages[index].description,
                    icon: _pages[index].icon,
                    showMosaic: index == 2,
                  ),
                ),
              ),
              Semantics(
                label: 'Rehber sayfası ${_page + 1} / ${_pages.length}',
                liveRegion: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      width: index == _page ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('onboarding-back'),
                        onPressed: _page == 0 || _isCompleting
                            ? null
                            : () => _goTo(_page - 1),
                        child: const Text('Geri'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: ValueKey(
                          lastPage ? 'onboarding-start' : 'onboarding-next',
                        ),
                        onPressed: _isCompleting
                            ? null
                            : lastPage
                            ? _finish
                            : () => _goTo(_page + 1),
                        child: _isCompleting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(lastPage ? 'Başlayalım' : 'İleri'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.showMosaic,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool showMosaic;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(32),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
            child: Column(
              children: [
                SizedBox(
                  height: 184,
                  child: showMosaic
                      ? const _MosaicPreview()
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primaryContainer,
                                    colors.secondaryContainer,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Icon(icon, size: 82, color: colors.primary),
                            if (icon == Icons.lock_open_rounded)
                              Positioned(
                                right: 48,
                                top: 28,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.secondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: Text(
                                      'XP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MosaicPreview extends StatelessWidget {
  const _MosaicPreview();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kısmen keşfedilmiş Gizli Mozaik önizlemesi',
      image: true,
      child: CustomPaint(
        size: const Size(190, 170),
        painter: _MosaicPreviewPainter(
          primary: Theme.of(context).colorScheme.primary,
          secondary: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _MosaicPreviewPainter extends CustomPainter {
  const _MosaicPreviewPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 8;
    const rows = 7;
    final cell = math.min(size.width / columns, size.height / rows);
    final origin = Offset(
      (size.width - columns * cell) / 2,
      (size.height - rows * cell) / 2,
    );
    final palette = [
      primary,
      secondary,
      const Color(0xFF6957B8),
      const Color(0xFFF39A52),
    ];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final revealed = (x * 3 + y * 5) % 4 == 0 || y >= rows - 2;
        final color = revealed
            ? palette[(x + y) % palette.length]
            : const Color(0xFF8A939D).withValues(alpha: 0.48);
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + x * cell,
            origin.dy + y * cell,
            cell - 1,
            cell - 1,
          ),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MosaicPreviewPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
