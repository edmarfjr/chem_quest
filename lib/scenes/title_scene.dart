import 'dart:ui' hide TextStyle, FontWeight;

import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../components/touch_controls.dart';
import '../components/virtual_screen.dart';
import '../game.dart';
import '../utils/palette.dart';

// Contorno grosso (3 px) nas 8 direções para o título aparecer bem sobre qualquer fundo
const List<Shadow> _titleOutline = [
  Shadow(color: Palette.preto, offset: Offset(3, 0)),
  Shadow(color: Palette.preto, offset: Offset(-3, 0)),
  Shadow(color: Palette.preto, offset: Offset(0, 3)),
  Shadow(color: Palette.preto, offset: Offset(0, -3)),
  Shadow(color: Palette.preto, offset: Offset(3, 3)),
  Shadow(color: Palette.preto, offset: Offset(-3, -3)),
  Shadow(color: Palette.preto, offset: Offset(3, -3)),
  Shadow(color: Palette.preto, offset: Offset(-3, 3)),
];

/// Botão grande da tela de título.
class StartButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onTap;
  bool _pressed = false;

  StartButton({required this.label, required Vector2 position, required this.onTap})
      : super(position: position, size: Vector2(300, 72), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: label,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 28, fontWeight: FontWeight.bold, shadows: kTextOutline),
      ),
    ));
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(14));
    canvas.drawRRect(rrect, Paint()..color = _pressed ? Palette.roxoEsc : Palette.vermelho);
    canvas.drawRRect(rrect, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 4);
  }

  @override
  void onTapDown(TapDownEvent event) => _pressed = true;

  @override
  void onTapUp(TapUpEvent event) {
    _pressed = false;
    onTap();
  }

  @override
  void onTapCancel(TapCancelEvent event) => _pressed = false;
}

/// Tela de título: "CIRCO DA QUÍMICA" com um botão para iniciar o jogo.
class TitleScene extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler, VirtualScreen {
  bool _started = false;

  @override
  Future<void> onLoad() async {
    fitToScreen(gameRef.size);

    add(TextComponent(
      text: 'CIRCO DA',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 205),
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.amarelo, fontSize: 64, fontWeight: FontWeight.bold, shadows: _titleOutline),
      ),
    ));
    add(TextComponent(
      text: 'QUÍMICA',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 285),
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.amarelo, fontSize: 64, fontWeight: FontWeight.bold, shadows: _titleOutline),
      ),
    ));

    add(StartButton(label: 'INICIAR', position: Vector2(size.x / 2, 440), onTap: _start));

    if (!kShowTouchControls) {
      add(TextComponent(
        text: 'ou aperte ENTER',
        anchor: Anchor.center,
        position: Vector2(size.x / 2, 505),
        textRenderer: TextPaint(
          style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 14, shadows: kTextOutline),
        ),
      ));
    }
  }

  void _start() {
    if (_started) return;
    _started = true;
    gameRef.router.pushReplacementNamed('world');
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent &&
        (keysPressed.contains(LogicalKeyboardKey.enter) ||
            keysPressed.contains(LogicalKeyboardKey.numpadEnter) ||
            keysPressed.contains(LogicalKeyboardKey.space) ||
            keysPressed.contains(LogicalKeyboardKey.keyZ))) {
      _start();
      return false;
    }
    return super.onKeyEvent(event, keysPressed);
  }

  // Fundo: toldo de circo listrado (vermelho e branco) com a borda em ondas, sobre azul escuro
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final screen = screenRect;
    canvas.drawRect(screen, Paint()..color = Palette.azulEsc);

    const stripe = 80.0;
    const height = 70.0;
    final first = (screen.left / stripe).floor();
    final last = (screen.right / stripe).ceil();
    for (var i = first; i < last; i++) {
      final color = Paint()..color = i.isEven ? Palette.vermelho : Palette.branco;
      final x = i * stripe;
      canvas.drawRect(Rect.fromLTRB(x, screen.top, x + stripe, height), color);
      canvas.drawCircle(Offset(x + stripe / 2, height), stripe / 2, color);
    }
  }
}
