import 'dart:ui' show Canvas, Paint, PaintingStyle, Path, RRect, Radius;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/painting.dart' show TextStyle;
import '../utils/palette.dart';
import 'player.dart';
import 'touch_controls.dart';

/// Objeto do mapa com o qual o jogador interage (minigames, NPCs...).
///
/// Encostar só mostra o indicador; a ação acontece quando o jogador aperta Z (PC) ou o botão da tela (celular).
abstract class InteractiveObject extends PositionComponent with CollisionCallbacks {
  late final _InteractPrompt _prompt;

  InteractiveObject({required Vector2 position, required Vector2 size}) : super(position: position, size: size);

  /// Texto do botão de ação no celular (ex.: JOGAR, FALAR)
  String get actionLabel;

  /// O que acontece quando o jogador aperta o botão de ação
  void interact();

  @override
  Future<void> onLoad() async {
    // É passivo porque ele não empurra ninguém, só detecta que foi tocado
    // isSolid: o jogador (14x14) pode caber inteiro dentro do objeto; com hitbox "oca" o Flame
    // considera que a colisão acabou quando ele fica totalmente dentro e o indicador sumiria.
    add(RectangleHitbox(collisionType: CollisionType.passive, isSolid: true));

    // Indicador acima do objeto enquanto o jogador está encostado nele
    _prompt = _InteractPrompt(text: kShowTouchControls ? '!' : 'Aperte Z')
      ..position = Vector2(size.x / 2, -2)
      ..isVisible = false;
    add(_prompt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      other.nearbyObject = this;
      _prompt.isVisible = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      if (other.nearbyObject == this) other.nearbyObject = null;
      _prompt.isVisible = false;
    }
  }
}

// Balãozinho "Aperte Z" (ou "!" no celular) desenhado em unidades do mundo
class _InteractPrompt extends PositionComponent with HasVisibility {
  static const double _fontSize = 6;
  final String text;

  _InteractPrompt({required this.text}) : super(anchor: Anchor.bottomCenter, priority: 100);

  @override
  Future<void> onLoad() async {
    final renderer = TextPaint(
      style: const TextStyle(color: Palette.preto, fontSize: _fontSize, fontFamily: kPixelFont),
    );
    final metrics = renderer.getLineMetrics(text);
    size = Vector2(metrics.width + 6, metrics.height + 4);
    add(TextComponent(
      text: text,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
      textRenderer: renderer,
    ));
  }

  @override
  void render(Canvas canvas) {
    final box = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(2));
    canvas.drawRRect(box, Paint()..color = Palette.branco);
    canvas.drawRRect(
      box,
      Paint()
        ..color = Palette.preto
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
    // Setinha apontando para o objeto
    final tail = Path()
      ..moveTo(size.x / 2 - 2, size.y)
      ..lineTo(size.x / 2 + 2, size.y)
      ..lineTo(size.x / 2, size.y + 2.5)
      ..close();
    canvas.drawPath(tail, Paint()..color = Palette.branco);
    canvas.drawPath(
      tail,
      Paint()
        ..color = Palette.preto
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }
}
