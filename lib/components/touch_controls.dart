import 'dart:ui' show Canvas, Paint, PaintingStyle, RRect, Radius, VoidCallback;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle;
import '../utils/palette.dart';

/// Coloque true para ver os controles de toque também no desktop (para testes).
const bool kForceTouchControls = false;

/// Controles de toque aparecem em celular/tablet (Android/iOS, inclusive no navegador mobile).
bool get kShowTouchControls =>
    kForceTouchControls ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Botão de tela. Suporta toque simples ([onTap]) e "segurar" ([onPress]/[onRelease]).
class TouchButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback? onPress;
  final VoidCallback? onRelease;
  final VoidCallback? onTap;
  bool _pressed = false;

  TouchButton({
    required this.label,
    required Vector2 position,
    required Vector2 size,
    Anchor anchor = Anchor.center,
    this.onPress,
    this.onRelease,
    this.onTap,
  }) : super(position: position, size: size, anchor: anchor, priority: 100);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: label,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(color: Palette.branco, fontSize: 14, fontFamily: kPixelFont),
      ),
    ));
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = Palette.preto.withValues(alpha: _pressed ? 0.75 : 0.45));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Palette.branco.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    onPress?.call();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _release();
    onTap?.call();
  }

  @override
  void onTapCancel(TapCancelEvent event) => _release();

  void _release() {
    if (!_pressed) return;
    _pressed = false;
    onRelease?.call();
  }
}

/// Botão "SAIR" no canto superior direito da cena do minigame.
TouchButton touchExitButton(Vector2 sceneSize, VoidCallback onExit) => TouchButton(
      label: 'SAIR',
      position: Vector2(sceneSize.x - 16, 16),
      size: Vector2(90, 40),
      anchor: Anchor.topRight,
      onTap: onExit,
    );

/// Botão "REINICIAR", mostrado quando o minigame termina.
TouchButton touchRestartButton(Vector2 position, VoidCallback onRestart) => TouchButton(
      label: 'REINICIAR',
      position: position,
      size: Vector2(180, 48),
      onTap: onRestart,
    );
