import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
import '../../components/touch_controls.dart';
import '../../components/virtual_screen.dart';
import '../../utils/palette.dart';

// 1. MODELO DA PERGUNTA: uma molécula, seus grupos funcionais e 3 alternativas erradas
class MoleculeQuestion {
  final String name;
  final String image; // arte da molécula, em assets/images
  final List<String> correct;
  final List<List<String>> wrong;
  const MoleculeQuestion(this.name, this.image, this.correct, this.wrong);
}

const List<MoleculeQuestion> _questions = [
  MoleculeQuestion('Dopamina', 'dopamina.png', ['fenol', 'amina'], [
    ['álcool', 'amina'],
    ['fenol', 'álcool'],
    ['fenol', 'álcool', 'amina'],
  ]),
  MoleculeQuestion('Serotonina', 'serotonina.png', ['fenol', 'amina'], [
    ['álcool', 'amina'],
    ['fenol', 'álcool'],
    ['amina'],
  ]),
  MoleculeQuestion('Epinefrina', 'epinefrina.png', ['fenol', 'álcool', 'amina'], [
    ['fenol', 'amina'],
    ['álcool', 'amina'],
    ['fenol', 'álcool'],
  ]),
  MoleculeQuestion('Feniletilamina', 'feniletilamina.png', ['amina'], [
    ['fenol', 'amina'],
    ['álcool', 'amina'],
    ['fenol'],
  ]),
  MoleculeQuestion('Norepinefrina', 'norepinefrina.png', ['fenol', 'álcool', 'amina'], [
    ['fenol', 'amina'],
    ['fenol', 'álcool'],
    ['álcool', 'amina'],
  ]),
];

// ['fenol', 'álcool', 'amina'] -> "Fenol, álcool e amina"; ['amina'] -> "Apenas amina"
String _groupsLabel(List<String> groups) {
  final text = groups.length == 1
      ? 'apenas ${groups.first}'
      : '${groups.sublist(0, groups.length - 1).join(', ')} e ${groups.last}';
  return text[0].toUpperCase() + text.substring(1);
}

// 2. A CARTA COM A MOLÉCULA (nome + arte; se a arte ainda não existir, mostra um aviso no lugar)
class MoleculeCard extends PositionComponent {
  final String name;
  final String image;

  MoleculeCard({required this.name, required this.image, required Vector2 position})
      : super(position: position, size: Vector2(360, 230), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: name,
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 14),
      textRenderer: TextPaint(
        style: const TextStyle(color: Palette.preto, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: kPixelFont),
      ),
    ));

    Sprite? sprite;
    try {
      sprite = Sprite(await Flame.images.load(image));
    } catch (_) {
      sprite = null; // arte ainda não criada
    }

    final artCenter = Vector2(size.x / 2, 140);
    if (sprite != null) {
      // Ampliação inteira (quando possível) para manter o pixel art nítido
      final box = Vector2(size.x - 40, 150);
      var scale = min(box.x / sprite.srcSize.x, box.y / sprite.srcSize.y);
      if (scale >= 1) scale = scale.floorToDouble();
      final art = SpriteComponent(
        sprite: sprite,
        size: sprite.srcSize * scale,
        anchor: Anchor.center,
        position: artCenter,
      );
      art.paint.filterQuality = FilterQuality.none;
      art.paint.isAntiAlias = false;
      add(art);
    } else {
      add(TextComponent(
        text: '(arte: $image)',
        anchor: Anchor.center,
        position: artCenter,
        textRenderer: TextPaint(
          style: const TextStyle(color: Palette.cinzaEsc, fontSize: 12, fontFamily: kPixelFont),
        ),
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12));
    canvas.drawRRect(rrect, Paint()..color = Palette.branco);
    canvas.drawRRect(rrect, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

// 3. BOTÃO DE ALTERNATIVA
class OptionButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onTap;
  Color color = Palette.indigo;

  OptionButton({required this.label, required Vector2 position, required this.onTap})
      : super(position: position, size: Vector2(320, 56), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: label,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(color: Palette.branco, fontSize: 16, fontFamily: kPixelFont, shadows: kTextOutline),
      ),
    ));
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawRRect(rrect, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}

// 4. A CENA DO MINIGAME
class FunctionalGroupsMinigame extends PositionComponent
    with HasGameRef<ChemQuestGame>, KeyboardHandler, VirtualScreen {
  late List<MoleculeQuestion> deck;
  int currentIndex = 0;
  int score = 0;
  final int pointsToWin = 3;
  bool isGameOver = false;
  bool _answered = false; // trava os botões enquanto mostra o resultado da resposta

  late TextComponent scoreText;
  MoleculeCard? _card;
  final List<OptionButton> _options = [];
  int _correctOption = 0;

  @override
  Future<void> onLoad() async {
    fitToScreen(gameRef.size);

    deck = List.of(_questions)..shuffle();

    scoreText = TextComponent(
      text: 'Pontos: $score / $pointsToWin',
      position: Vector2(20, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, shadows: kTextOutline)),
    );
    add(scoreText);

    add(TextComponent(
      text: 'Qual grupo funcional?',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 20),
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 28, fontWeight: FontWeight.bold, shadows: kTextOutline),
      ),
    ));

    if (kShowTouchControls) {
      add(touchExitButton(size, () => gameRef.router.pop()));
    }

    showNextQuestion();
  }

  void showNextQuestion() {
    final question = deck[currentIndex];
    _answered = false;

    // Alternativas: a certa e as 3 erradas, em ordem aleatória
    final options = [question.correct, ...question.wrong]..shuffle();
    _correctOption = options.indexOf(question.correct);

    final card = MoleculeCard(
      name: question.name,
      image: question.image,
      position: Vector2(size.x / 2, -150), // começa fora da tela (em cima)
    );
    _card = card;
    add(card);
    card.add(MoveEffect.to(
      Vector2(size.x / 2, 190),
      EffectController(duration: 0.4, curve: Curves.easeOut),
    ));

    _options.clear();
    for (var i = 0; i < options.length; i++) {
      final column = i % 2 == 0 ? -1 : 1;
      final row = i ~/ 2;
      final button = OptionButton(
        label: _groupsLabel(options[i]),
        position: Vector2(size.x / 2 + column * 170, 380 + row * 76),
        onTap: () => _answer(i),
      );
      _options.add(button);
      add(button);
    }
  }

  void _answer(int chosen) {
    if (_answered || isGameOver || _card == null) return;
    _answered = true;

    final correct = chosen == _correctOption;
    if (correct) score++;
    scoreText.text = 'Pontos: $score / $pointsToWin';

    // Mostra o resultado: a certa fica verde e, se errou, a escolhida fica vermelha
    _options[_correctOption].color = Palette.verde;
    if (!correct) _options[chosen].color = Palette.vermelho;

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!isMounted) return;
      _discardCard(correct);
    });
  }

  void _discardCard(bool correct) {
    final card = _card!;
    _card = null;
    currentIndex++;

    for (final button in _options) {
      button.removeFromParent();
    }
    _options.clear();

    // A carta sai voando: para a esquerda se acertou, para a direita se errou
    card.add(MoveEffect.by(
      Vector2(correct ? -500 : 500, 200),
      EffectController(duration: 0.3),
      onComplete: () {
        card.removeFromParent();
        if (score >= pointsToWin) {
          endGame(true);
        } else if (currentIndex >= deck.length) {
          endGame(false);
        } else {
          showNextQuestion();
        }
      },
    ));
  }

  void endGame(bool won) {
    isGameOver = true;
    add(TextComponent(
      text: won ? 'SUCESSO! VOCÊ PASSOU!' : 'FALHOU! ACABARAM AS CARTAS.',
      position: Vector2(size.x / 2, size.y / 2 - 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24, shadows: kTextOutline),
      ),
    ));
    if (kShowTouchControls) {
      scoreText.text = 'Fim de jogo';
      add(touchRestartButton(
        Vector2(size.x / 2, size.y / 2 + 40),
        () => gameRef.restartMinigame('minigame_group'),
      ));
    } else {
      scoreText.text = 'Q: voltar | R: reiniciar';
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(screenRect, Paint()..color = Palette.azulEsc);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver && event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.keyR)) {
      gameRef.restartMinigame('minigame_group');
      return false;
    }
    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.keyQ)) {
      gameRef.router.pop();
      return false;
    }
    return super.onKeyEvent(event, keysPressed);
  }
}
