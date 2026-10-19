import 'dart:math';
import 'dart:ui' hide TextStyle, FontWeight;

import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../components/touch_controls.dart';
import '../components/virtual_screen.dart';
import '../game.dart';
import '../utils/palette.dart';

// Contorno grosso (4 px) nas 8 direções para o título aparecer bem sobre qualquer fundo
const List<Shadow> _titleOutline = [
  Shadow(color: Palette.preto, offset: Offset(4, 0)),
  Shadow(color: Palette.preto, offset: Offset(-4, 0)),
  Shadow(color: Palette.preto, offset: Offset(0, 4)),
  Shadow(color: Palette.preto, offset: Offset(0, -4)),
  Shadow(color: Palette.preto, offset: Offset(4, 4)),
  Shadow(color: Palette.preto, offset: Offset(-4, -4)),
  Shadow(color: Palette.preto, offset: Offset(4, -4)),
  Shadow(color: Palette.preto, offset: Offset(-4, 4)),
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
    canvas.drawRRect(rrect, Paint()..color = _pressed ? Palette.chocolate : Palette.marromEsc);
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

/// Tela de título: "Chem Quest" numa aldeia indígena, com um botão para iniciar o jogo.
class TitleScene extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler, VirtualScreen {
  bool _started = false;

  @override
  Future<void> onLoad() async {
    fitToScreen(gameRef.size);

    add(TextComponent(
      text: 'Chem Quest',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 170),
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.amarelo, fontSize: 84, fontWeight: FontWeight.bold, shadows: _titleOutline),
      ),
    ));

    add(StartButton(label: 'INICIAR', position: Vector2(size.x / 2, 320), onTap: _start));

    if (!kShowTouchControls) {
      add(TextComponent(
        text: 'ou aperte ENTER',
        anchor: Anchor.center,
        position: Vector2(size.x / 2, 382),
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

  // Fundo: aldeia indígena ao amanhecer (céu, sol, morros, ocas, palmeiras e uma faixa de grafismos)
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final screen = screenRect;
    _drawSky(canvas, screen);

    // Sol atrás dos morros
    canvas.drawCircle(const Offset(770, 330), 92, Paint()..color = Palette.laranja.withValues(alpha: 0.35));
    canvas.drawCircle(const Offset(770, 330), 66, Paint()..color = Palette.amarelo);

    _drawHills(canvas, screen, baseline: 395, amplitude: 34, color: Palette.forest, seed: 0);
    _drawHills(canvas, screen, baseline: 425, amplitude: 22, color: Palette.verdeEsc, seed: 2.5);
    _drawGround(canvas, screen);

    // Ocas ao fundo (menores) e na frente (maiores)
    _drawOca(canvas, 300, 462, 190, 150);
    _drawOca(canvas, 665, 462, 200, 158);
    _drawOca(canvas, 135, 512, 270, 210);
    _drawOca(canvas, 835, 512, 280, 216);

    _drawPalm(canvas, 40, 520, 230);
    _drawPalm(canvas, 925, 520, 250);

    _drawGrafismoBand(canvas, screen);
  }

  void _drawSky(Canvas canvas, Rect screen) {
    // Faixas de cor (visual pixelado): azul no alto, esquentando até o amarelo do horizonte
    const bands = 14;
    const horizon = 430.0;
    final top = Palette.azul;
    final mid = Palette.bege;
    final bottom = Palette.amarelo;
    final bandHeight = (horizon - screen.top) / bands;
    for (var i = 0; i < bands; i++) {
      final t = i / (bands - 1);
      final color = t < 0.6 ? Color.lerp(top, mid, t / 0.6)! : Color.lerp(mid, bottom, (t - 0.6) / 0.4)!;
      canvas.drawRect(
        Rect.fromLTWH(screen.left, screen.top + i * bandHeight, screen.width, bandHeight + 1),
        Paint()..color = color,
      );
    }
  }

  void _drawHills(Canvas canvas, Rect screen, {required double baseline, required double amplitude, required Color color, required double seed}) {
    final path = Path()..moveTo(screen.left, screen.bottom);
    for (var x = screen.left; x <= screen.right + 8; x += 8) {
      final y = baseline - amplitude * (0.6 * sin(x / 150 + seed) + 0.4 * sin(x / 61 + seed * 2));
      path.lineTo(x, y);
    }
    path.lineTo(screen.right, screen.bottom);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawGround(Canvas canvas, Rect screen) {
    const top = 440.0;
    canvas.drawRect(Rect.fromLTRB(screen.left, top, screen.right, screen.bottom), Paint()..color = Palette.jade);

    // Tufos de capim espalhados (sempre os mesmos, para não piscar)
    final rng = Random(7);
    final grass = Paint()..color = Palette.verdeEsc;
    for (var i = 0; i < 90; i++) {
      final x = screen.left + rng.nextDouble() * screen.width;
      final y = top + 10 + rng.nextDouble() * (screen.bottom - top - 20);
      canvas.drawRect(Rect.fromLTWH(x, y, 10, 3), grass);
      canvas.drawRect(Rect.fromLTWH(x + 3, y - 3, 3, 3), grass);
    }

    // Terreiro de terra batida no centro da aldeia
    canvas.drawOval(Rect.fromCenter(center: const Offset(480, 535), width: 460, height: 80), Paint()..color = Palette.picotronBege);
  }

  // Oca: casa grande de palha, com a cobertura descendo quase até o chão
  void _drawOca(Canvas canvas, double centerX, double baseY, double width, double height) {
    final roof = Path()
      ..moveTo(centerX - width / 2, baseY)
      ..quadraticBezierTo(centerX - width * 0.30, baseY - height * 0.9, centerX, baseY - height)
      ..quadraticBezierTo(centerX + width * 0.30, baseY - height * 0.9, centerX + width / 2, baseY)
      ..close();
    canvas.drawPath(roof, Paint()..color = Palette.picotronBege);

    // Fileiras de palha
    canvas.save();
    canvas.clipPath(roof);
    final straw = Paint()
      ..color = Palette.marromEsc
      ..strokeWidth = 4;
    for (var y = baseY - 14; y > baseY - height; y -= 18) {
      canvas.drawLine(Offset(centerX - width / 2, y), Offset(centerX + width / 2, y), straw);
    }
    canvas.restore();

    // Porta
    final door = Rect.fromCenter(center: Offset(centerX, baseY - height * 0.16), width: width * 0.17, height: height * 0.32);
    canvas.drawRRect(RRect.fromRectAndCorners(door, topLeft: const Radius.circular(40), topRight: const Radius.circular(40)), Paint()..color = Palette.onyx);

    canvas.drawPath(
      roof,
      Paint()
        ..color = Palette.preto
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _drawPalm(Canvas canvas, double x, double baseY, double height) {
    final trunk = Path()
      ..moveTo(x - 9, baseY)
      ..lineTo(x - 5, baseY - height)
      ..lineTo(x + 5, baseY - height)
      ..lineTo(x + 9, baseY)
      ..close();
    canvas.drawPath(trunk, Paint()..color = Palette.marromEsc);
    canvas.drawPath(trunk, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 3);

    // Folhas saindo do topo
    for (final angle in [-2.5, -1.9, -1.25, -0.6, 0.05, 0.7]) {
      canvas.save();
      canvas.translate(x, baseY - height);
      canvas.rotate(angle);
      final leaf = Rect.fromLTWH(0, -9, height * 0.5, 18);
      canvas.drawOval(leaf, Paint()..color = Palette.verdeEsc);
      canvas.drawOval(leaf, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.restore();
    }
  }

  // Faixa de grafismos geométricos (zigue-zague) na base da tela
  void _drawGrafismoBand(Canvas canvas, Rect screen) {
    const height = 54.0;
    final top = screen.bottom - height;
    canvas.drawRect(Rect.fromLTRB(screen.left, top, screen.right, screen.bottom), Paint()..color = Palette.onyx);

    const step = 36.0;
    final first = (screen.left / step).floor();
    final last = (screen.right / step).ceil();
    final red = Paint()..color = Palette.vermelho;
    final cream = Paint()..color = Palette.bege;
    for (var i = first; i < last; i++) {
      final x = i * step;
      final up = Path()
        ..moveTo(x, screen.bottom - 8)
        ..lineTo(x + step / 2, top + 10)
        ..lineTo(x + step, screen.bottom - 8)
        ..close();
      canvas.drawPath(up, i.isEven ? red : cream);
      canvas.drawRect(Rect.fromLTWH(x + step / 2 - 3, top + 3, 6, 6), i.isEven ? cream : red);
    }
    canvas.drawRect(Rect.fromLTRB(screen.left, top, screen.right, top + 4), Paint()..color = Palette.amarelo);
  }
}
