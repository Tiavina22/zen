import 'dart:ui';
import 'package:flutter/material.dart';

class BlurDialog extends StatelessWidget {
  final Widget child;
  final double blurAmount;
  final Color overlayColor;

  const BlurDialog({
    super.key,
    required this.child,
    this.blurAmount = 5.0,
    this.overlayColor = const Color(0x40000000),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fond flouté
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurAmount,
              sigmaY: blurAmount,
            ),
            child: Container(
              color: overlayColor,
            ),
          ),
        ),
        // Contenu du dialogue
        Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.8, end: 1.0),
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
} 