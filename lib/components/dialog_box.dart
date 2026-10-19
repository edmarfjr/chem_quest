import 'dart:math';
import 'dart:ui' show Canvas, Paint, PaintingStyle, Path, RRect, Radius;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show TextStyle;
import '../utils/palette.dart';
import 'touch_controls.dart';

class _Glyph {
  final String ch;
  final bool highlighted;
  _Glyph(this.ch, this.highlighted);
}

/// Caixa de diálogo na parte de baixo da tela (para ficar no HUD da câmera, em coordenadas de tela).
///
/// O texto aparece letra por letra. Trechos entre `*asteriscos*` ficam destacados em amarelo.
/// [advance] completa o texto (se ainda estiver aparecendo) ou fecha a caixa; tocar na caixa faz o mesmo.
class DialogBox extends PositionComponent with TapCallbacks, HasVisibility {
  static const double _padding = 18;
  static const double _fontSize = 18;
  static const double _lineHeight = _fontSize * 1.6;
  static const double _charsPerSecond = 45;
  static const double _minHeight = 110;

  final TextPaint _normal = TextPaint(
    style: const TextStyle(color: Palette.branco, fontSize: _fontSize, fontFamily: kPixelFont),
  );
  final TextPaint _highlight = TextPaint(
    style: const TextStyle(color: Palette.amarelo, fontSize: _fontSize, fontFamily: kPixelFont),
  );
  final Map<String, double> _widths = {};

  List<_Glyph> _glyphs = [];
  List<List<_Glyph>> _lines = [];
  double _shown = 0; // quantas letras já apareceram
  double _clock = 0;

  DialogBox() : super(anchor: Anchor.bottomCenter, priority: 200) {
    isVisible = false;
  }

  bool get isOpen => isVisible;
  bool get _finished => _shown >= _glyphs.length;

  /// Abre a caixa com [markup]; `*trecho*` fica destacado.
  void show(String markup) {
    _glyphs = _parse(markup);
    _layout();
    _shown = 0;
    isVisible = true;
  }

  /// Completa o texto ou, se ele já estiver inteiro, fecha a caixa.
  void advance() {
    if (!isOpen) return;
    if (_finished) {
      isVisible = false;
    } else {
      _shown = _glyphs.length.toDouble();
    }
  }

  List<_Glyph> _parse(String markup) {
    final glyphs = <_Glyph>[];
    var highlighted = false;
    for (final ch in markup.split('')) {
      if (ch == '*') {
        highlighted = !highlighted;
      } else {
        glyphs.add(_Glyph(ch, highlighted));
      }
    }
    return glyphs;
  }

  double _width(String ch) => _widths.putIfAbsent(ch, () => _normal.getLineMetrics(ch).width);

  // Quebra o texto em linhas que caibam na largura da caixa (palavra inteira por linha)
  void _layout() {
    final maxWidth = size.x - _padding * 2;
    final lines = <List<_Glyph>>[];
    var line = <_Glyph>[];
    var lineWidth = 0.0;
    var word = <_Glyph>[];
    var wordWidth = 0.0;

    void flushWord() {
      if (word.isEmpty) return;
      if (line.isNotEmpty && lineWidth + wordWidth > maxWidth) {
        if (line.last.ch == ' ') line.removeLast();
        lines.add(line);
        line = [];
        lineWidth = 0;
      }
      line.addAll(word);
      lineWidth += wordWidth;
      word = [];
      wordWidth = 0;
    }

    for (final glyph in _glyphs) {
      if (glyph.ch == '\n') {
        flushWord();
        lines.add(line);
        line = [];
        lineWidth = 0;
      } else if (glyph.ch == ' ') {
        flushWord();
        if (line.isNotEmpty && line.last.ch != ' ') {
          line.add(glyph);
          lineWidth += _width(' ');
        }
      } else {
        word.add(glyph);
        wordWidth += _width(glyph.ch);
      }
    }
    flushWord();
    if (line.isNotEmpty) lines.add(line);

    _lines = lines;
    size.y = max(_minHeight, lines.length * _lineHeight + _padding * 2 + 14);
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size.x = min(gameSize.x - 48, 760);
    position = Vector2(gameSize.x / 2, gameSize.y - 20);
    if (_glyphs.isNotEmpty) _layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isOpen) return;
    _clock += dt;
    if (!_finished) _shown = min(_glyphs.length.toDouble(), _shown + dt * _charsPerSecond);
  }

  @override
  void render(Canvas canvas) {
    final panel = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10));
    canvas.drawRRect(panel, Paint()..color = Palette.preto.withValues(alpha: 0.88));
    canvas.drawRRect(
      panel,
      Paint()
        ..color = Palette.branco
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Texto, só até onde o efeito de digitação chegou
    var drawn = 0;
    final limit = _shown.floor();
    var y = _padding;
    for (final line in _lines) {
      var x = _padding;
      for (final glyph in line) {
        if (drawn >= limit) break;
        if (glyph.ch != ' ') {
          (glyph.highlighted ? _highlight : _normal).render(canvas, glyph.ch, Vector2(x, y));
        }
        x += _width(glyph.ch);
        drawn++;
      }
      y += _lineHeight;
    }

    // Setinha piscando no canto: "toque/Z para continuar" quando o texto já está inteiro
    if (_finished && (_clock * 2).floor().isEven) {
      final right = size.x - _padding;
      final bottom = size.y - 12;
      final arrow = Path()
        ..moveTo(right - 12, bottom - 10)
        ..lineTo(right, bottom - 10)
        ..lineTo(right - 6, bottom)
        ..close();
      canvas.drawPath(arrow, Paint()..color = Palette.branco);
    }
  }

  // Só recebe toques quando está aberta; fechada, não pode bloquear o joystick e os botões que estão embaixo
  @override
  bool containsLocalPoint(Vector2 point) => isVisible && super.containsLocalPoint(point);

  @override
  void onTapDown(TapDownEvent event) => advance();
}
