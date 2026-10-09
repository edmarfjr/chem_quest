import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Faz a cena do minigame ser desenhada numa tela de referência fixa (960x600) e depois
/// ampliada/reduzida para caber na tela real. Assim o layout fica igual no desktop e no celular.
///
/// Sobram faixas nas laterais (ou em cima/embaixo) quando a proporção é diferente; use
/// [screenRect] para desenhar fundos que cubram a tela inteira, faixas incluídas.
mixin VirtualScreen on PositionComponent {
  static const double designWidth = 960;
  static const double designHeight = 600;

  Vector2 _screenSize = Vector2.zero();

  /// Tela inteira nas coordenadas locais da cena (maior ou igual à área de design).
  Rect get screenRect {
    final s = scale.x;
    return Rect.fromLTWH(-position.x / s, -position.y / s, _screenSize.x / s, _screenSize.y / s);
  }

  void fitToScreen(Vector2 screen) {
    // No Android o jogo pode receber tamanho 0 antes do primeiro layout: escala 0 geraria NaN no desenho
    if (screen.x <= 0 || screen.y <= 0) return;
    _screenSize = screen.clone();
    size = Vector2(designWidth, designHeight);
    final s = min(screen.x / designWidth, screen.y / designHeight);
    scale = Vector2.all(s);
    position = (screen - size * s) / 2;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    fitToScreen(size);
  }

  // A cena recebe toques/ponteiro em qualquer ponto da tela, inclusive nas faixas
  @override
  bool containsLocalPoint(Vector2 point) => true;
}
