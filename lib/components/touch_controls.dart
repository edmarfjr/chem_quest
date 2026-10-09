import 'dart:ui' show Canvas, Paint, PaintingStyle, RRect, Radius, Rect, VoidCallback;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
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

void _drawButtonBox(Canvas canvas, Rect rect, bool pressed) {
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
  canvas.drawRRect(rrect, Paint()..color = Palette.preto.withValues(alpha: pressed ? 0.75 : 0.45));
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = Palette.branco.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}

TextComponent _buttonLabel(String text, Vector2 center) => TextComponent(
      text: text,
      anchor: Anchor.center,
      position: center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Palette.branco, fontSize: 14, fontFamily: kPixelFont),
      ),
    );

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
    add(_buttonLabel(label, size / 2));
  }

  @override
  void render(Canvas canvas) => _drawButtonBox(canvas, size.toRect(), _pressed);

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

/// Par de botões "<" e ">" para mover. Funciona com toque (segurar o dedo parado sobre o botão)
/// e com arrasto (deslizar o dedo de um botão para o outro sem soltar). Sair da área solta o movimento.
///
/// O Flame só inicia o arrasto depois que o dedo se move um pouco, por isso o toque parado é
/// tratado por [TapCallbacks] e o movimento por [DragCallbacks]; a direção vale enquanto um dos dois
/// estiver ativo.
class MovePad extends PositionComponent with TapCallbacks, DragCallbacks {
  static const double _button = 80;
  static const double _gap = 16;
  static const double _slop = 24; // tolerância ao redor dos botões enquanto o dedo está pressionado

  final void Function(int direction) onChange; // -1 esquerda, 0 parado, 1 direita
  int _direction = 0;
  bool _tapping = false;
  bool _dragging = false;

  MovePad({required this.onChange})
      : super(size: Vector2(_button * 2 + _gap, _button), priority: 100);

  @override
  Future<void> onLoad() async {
    add(_buttonLabel('<', Vector2(_button / 2, _button / 2)));
    add(_buttonLabel('>', Vector2(_button + _gap + _button / 2, _button / 2)));
  }

  @override
  void render(Canvas canvas) {
    _drawButtonBox(canvas, Rect.fromLTWH(0, 0, _button, _button), _direction < 0);
    _drawButtonBox(canvas, Rect.fromLTWH(_button + _gap, 0, _button, _button), _direction > 0);
  }

  void _setDirection(int direction) {
    if (direction == _direction) return;
    _direction = direction;
    onChange(direction);
  }

  void _updateFrom(Vector2 p) {
    var direction = 0;
    if (p.y >= -_slop && p.y <= size.y + _slop) {
      if (p.x >= -_slop && p.x < size.x / 2) {
        direction = -1;
      } else if (p.x >= size.x / 2 && p.x <= size.x + _slop) {
        direction = 1;
      }
    }
    _setDirection(direction);
  }

  void _releaseIfIdle() {
    if (!_tapping && !_dragging) _setDirection(0);
  }

  // --- toque (dedo parado)
  @override
  void onTapDown(TapDownEvent event) {
    _tapping = true;
    _updateFrom(event.localPosition);
  }

  @override
  void onTapUp(TapUpEvent event) {
    _tapping = false;
    _releaseIfIdle();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _tapping = false;
    _releaseIfIdle();
  }

  // --- arrasto (dedo se movendo)
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragging = true;
    _updateFrom(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // `localEndPosition` lança StateError quando o dedo sai da área do componente; a posição
    // na tela (canvas) está sempre disponível, então converto por ela. No DragUpdateEvent a posição
    // atual do dedo é a "start" (a "end" soma o delta de novo e passa do ponto).
    _updateFrom(absoluteToLocal(event.canvasStartPosition));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragging = false;
    _releaseIfIdle();
  }
}

/// Camada de botões em coordenadas reais da tela (sem a escala da [VirtualScreen]), presa aos
/// cantos da tela. Adicione ao jogo (`gameRef.add`) e remova junto com a cena.
class TouchHud extends PositionComponent {
  final List<(PositionComponent, Vector2 Function(Vector2 screen))> _items = [];
  Vector2 _screen;

  TouchHud(Vector2 screen)
      : _screen = screen.clone(),
        super(size: screen.clone(), priority: 0x7fffffff); // o RouterComponent do jogo também usa a prioridade máxima; como este entra depois, desenha por cima

  /// [place] recebe o tamanho da tela e devolve a posição do botão (refeita a cada resize).
  void addItem(PositionComponent item, Vector2 Function(Vector2 screen) place) {
    item.position = place(_screen);
    _items.add((item, place));
    add(item);
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    _screen = gameSize.clone();
    size = gameSize.clone();
    for (final (item, place) in _items) {
      item.position = place(_screen);
    }
  }
}

/// Joystick que não quebra quando o Flame entrega o movimento do dedo fora da área dele
/// (ou com a rota escondida): nesses casos `event.localDelta` lança StateError a cada movimento,
/// o que enche o log e pode travar o app.
class SafeJoystick extends JoystickComponent {
  SafeJoystick({super.knob, super.background, super.margin});

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    try {
      return super.onDragUpdate(event);
    } on StateError {
      return false;
    }
  }
}
