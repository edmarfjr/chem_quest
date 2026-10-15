import 'dart:ui' show Canvas, Paint, PaintingStyle, Path, RRect, Radius;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/painting.dart' show TextStyle;
import '../game.dart';
import '../utils/palette.dart';
import 'player.dart';
import 'touch_controls.dart';

class MinigameTrigger extends PositionComponent with CollisionCallbacks, HasGameRef<ChemQuestGame> {
  final String minigameRoute; // Vai guardar qual rota este objeto abre
  late final _InteractPrompt _prompt;

  MinigameTrigger({required Vector2 position, required Vector2 size, required this.minigameRoute}) 
      : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // É passivo porque ele não empurra ninguém, só detecta que foi tocado
    // isSolid: o jogador (14x14) cabe inteiro dentro do objeto (16x16); com hitbox "oca" o Flame
    // considera que a colisão acabou quando ele fica totalmente dentro e o indicador sumiria.
    add(RectangleHitbox(collisionType: CollisionType.passive, isSolid: true));

    // Indicador acima do objeto enquanto o jogador está encostado nele
    _prompt = _InteractPrompt(text: kShowTouchControls ? '!' : 'Aperte Z')
      ..position = Vector2(size.x / 2, -2)
      ..isVisible = false;
    add(_prompt);
  }

  // Encostar só mostra o indicador; o minigame começa quando o jogador aperta o botão (Z ou botão na tela)
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      other.nearbyTrigger = this;
      _prompt.isVisible = true;
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Player) {
      if (other.nearbyTrigger == this) other.nearbyTrigger = null;
      _prompt.isVisible = false;
    }
  }

  /// Abre o minigame (chamado pelo botão Z ou pelo botão da tela).
  void start() {
    // Só vale com o mapa na frente; evita abrir de novo se o botão for apertado dentro de um minigame
    if (gameRef.router.currentRoute.name != 'world') return;
    gameRef.router.pushNamed(minigameRoute);
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
