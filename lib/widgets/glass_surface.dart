import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 14,
    this.enableBlur = true,
    this.showHighlight = true,
    this.showShadow = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool enableBlur;
  final bool showHighlight;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xB31B2B38) : const Color(0xB8FFFFFF);
    final highlight = isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x8AFFFFFF);
    final border = isDark ? const Color(0x35FFFFFF) : const Color(0xA6FFFFFF);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: showHighlight ? null : fill,
        gradient: showHighlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [highlight, fill],
              )
            : null,
        borderRadius: borderRadius,
        border: Border.all(color: border, width: 0.8),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (enableBlur && blurSigma > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    final clippedSurface = ClipRRect(
      borderRadius: borderRadius,
      child: content,
    );
    if (!showShadow) return clippedSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: clippedSurface,
    );
  }
}

class GlassBackground extends StatelessWidget {
  const GlassBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColors = isDark
        ? const [Color(0xFF0E1720), Color(0xFF112434), Color(0xFF151B2D)]
        : const [Color(0xFFFFF9F1), Color(0xFFF1FBF9), Color(0xFFF7F2FF)];

    return DecoratedBox(
      key: const ValueKey('glass-background'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: baseColors,
          stops: const [0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -120,
            right: -90,
            child: _AmbientGlow(
              size: 320,
              lightColor: Color(0x2E67DAD4),
              darkColor: Color(0x2638BDB7),
            ),
          ),
          const Positioned(
            top: 250,
            left: -150,
            child: _AmbientGlow(
              size: 340,
              lightColor: Color(0x2478BDF0),
              darkColor: Color(0x1F388BD0),
            ),
          ),
          const Positioned(
            bottom: -150,
            right: -130,
            child: _AmbientGlow(
              size: 360,
              lightColor: Color(0x1FAD8FE8),
              darkColor: Color(0x182C78C7),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.lightColor,
    required this.darkColor,
  });

  final double size;
  final Color lightColor;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
