// Aqui escondemos as classes conflitantes do dart:ui
import 'dart:ui' hide TextStyle, FontWeight; 

// Agora importamos o material inteiro do Flutter (que traz o TextStyle e Colors corretos)
import 'package:flutter/material.dart'; 

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
import '../../components/virtual_screen.dart';
import '../../components/touch_controls.dart';
import '../../utils/palette.dart';

// 1. MODELO DA CARTA
class QuestionCard {
  final String text;
  final bool isTrue;
  final String image; // arte da carta (em assets/images)
  QuestionCard(this.text, this.isTrue, this.image);
}

// 2. O COMPONENTE VISUAL DA CARTA (Nova classe!)
class CardComponent extends PositionComponent {
  final String text;
  final String image;

  CardComponent({required this.text, required this.image, required Vector2 position, required Vector2 size})
      : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Adiciona o texto no meio da carta, quebrando linha para caber na largura da carta
    const padding = 8.0;
    add(TextBoxComponent(
      text: text,
      position: Vector2(size.x / 2, size.y / 2),
      size: Vector2(size.x - padding * 2, size.y - padding * 2),
      anchor: Anchor.center,
      align: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Palette.preto, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: kPixelFont),
      ),
    ));

    // Ilustração na parte de baixo da carta (arte 24x24 ampliada 6x, mantém o pixel art nítido)
    final art = SpriteComponent(
      sprite: Sprite(await Flame.images.load(image)),
      size: Vector2.all(24 * 6),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 1.45),
    );
    art.paint.filterQuality = FilterQuality.none;
    art.paint.isAntiAlias = false;
    add(art);
  }

  @override
  void render(Canvas canvas) {
    // Desenha o fundo da carta (um retângulo branco com bordas arredondadas)
    final rrect = RRect.fromRectAndCorners(Rect.fromLTWH(0, 0, size.x, size.y *2 - 16));
    final rrectCarta = RRect.fromRectAndCorners(Rect.fromLTWH(-8, -8, size.x + 16, size.y *2));
    canvas.drawRRect(rrectCarta, Paint()..color = Palette.branco);
    canvas.drawRRect(rrectCarta, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 2);

    canvas.drawRRect(rrect, Paint()..color = Palette.branco);
    canvas.drawRRect(rrect, Paint()..color = Palette.preto..style = PaintingStyle.stroke..strokeWidth = 2);
  }
}

// 3. A CENA DO MINIGAME
class TrueFalseMinigame extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler, VirtualScreen {
  late List<QuestionCard> deck;
  int currentCardIndex = 0;
  int score = 0;
  final int pointsToWin = 3;
  bool isGameOver = false;

  late TextComponent scoreText;
  CardComponent? activeCard; // A carta que está na tela agora

  @override
  Future<void> onLoad() async {
    fitToScreen(gameRef.size);

    deck = [
      QuestionCard("A água ferve a 100°C ao nível do mar.", true, 'imgCartas_Animation 1_0.png'),
      QuestionCard("O símbolo químico do Ouro é Ag.", false, 'imgCartas_Animation 1_1.png'),
      QuestionCard("O oxigênio é o gás mais abundante na atmosfera.", false, 'imgCartas_Animation 1_2.png'),
      QuestionCard("O próton possui carga positiva.", true, 'imgCartas_Animation 1_3.png'),
      QuestionCard("Misturar um ácido e uma base gera sal e água.", true, 'imgCartas_Animation 1_4.png'),
    ];
    deck.shuffle();

    scoreText = TextComponent(
      text: 'Pontos: $score / $pointsToWin',
      position: Vector2(20, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco)),
    );
    add(scoreText);

    // Botões
    add(AnswerButton(
      label: 'VERDADEIRO',
      position: Vector2(size.x / 2 - 120, size.y / 2 + 200),
      color: Palette.verde,
      onTap: () => checkAnswer(true),
    ));

    add(AnswerButton(
      label: 'FALSO',
      position: Vector2(size.x / 2 + 120, size.y / 2 + 200),
      color: Palette.vermelho,
      onTap: () => checkAnswer(false),
    ));

    if (kShowTouchControls) {
      add(touchExitButton(size, () => gameRef.router.pop()));
    }

    // Exibe a primeira carta com animação de entrada
    showNextCard();
  }

  // Anima a entrada de uma nova carta
  void showNextCard() {
    if (currentCardIndex >= deck.length) return;

    activeCard = CardComponent(
      text: deck[currentCardIndex].text,
      image: deck[currentCardIndex].image,
      position: Vector2(size.x / 2, -100), // Começa fora da tela (em cima)
      size: Vector2(250, 200),
    );
    add(activeCard!);

    // Efeito para deslizar até o centro
    activeCard!.add(
      MoveEffect.to(
        Vector2(size.x / 2, size.y / 2 - 150),
        EffectController(duration: 0.4, curve: Curves.easeOut),
      ),
    );
  }

  void checkAnswer(bool playerAnswer) {
    if (isGameOver || activeCard == null) return;

    if (deck[currentCardIndex].isTrue == playerAnswer) {
      score++;
    }

    // Salva a referência da carta atual para animá-la antes de destruí-la
    final cardToDiscard = activeCard!;
    activeCard = null; // Limpa para não clicar duas vezes rápido
    currentCardIndex++;

    // Efeito para descartar a carta voando para o lado
    cardToDiscard.add(
      MoveEffect.by(
        Vector2(playerAnswer ? -400 : 400, 200), // Verdadeiro voa pra esquerda, falso pra direita
        EffectController(duration: 0.3),
        onComplete: () {
          // Quando a animação terminar, remove do jogo
          cardToDiscard.removeFromParent(); 
          
          // Verifica se ganhou ou perdeu
          if (score >= pointsToWin) {
            endGame(true);
          } else if (currentCardIndex >= deck.length) {
            endGame(false);
          } else {
            // Se o jogo continua, puxa a próxima carta
            scoreText.text = 'Pontos: $score / $pointsToWin';
            showNextCard();
          }
        }
      )
    );
  }

  void endGame(bool won) {
    isGameOver = true;
    add(TextComponent(
      text: won ? 'SUCESSO! VOCÊ PASSOU!' : 'FALHOU! ACABARAM AS CARTAS.',
      position: Vector2(size.x / 2, size.y / 2 - 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24)),
    ));
    if (kShowTouchControls) {
      scoreText.text = 'Fim de jogo';
      add(touchRestartButton(
        Vector2(size.x / 2, size.y / 2 + 40),
        () => gameRef.restartMinigame('minigame_cards'),
      ));
    } else {
      scoreText.text = 'ESC: voltar | R: reiniciar';
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
      gameRef.restartMinigame('minigame_cards');
      return false;
    }
    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.escape)) {
      gameRef.router.pop();
      return false;
    }
    return super.onKeyEvent(event, keysPressed);
  }
}

// 4. O COMPONENTE DO BOTÃO FICA IGUAL AO ANTERIOR
class AnswerButton extends PositionComponent with TapCallbacks {
  final String label;
  final Color color;
  final VoidCallback onTap;

  AnswerButton({
    required this.label, 
    required Vector2 position, 
    required this.color,
    required this.onTap
  }) : super(position: position, size: Vector2(150, 50), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: label,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont)),
    ));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = color);
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap(); 
  }
}