import 'dart:ui' hide TextStyle, FontWeight;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
import '../../components/touch_controls.dart';
import '../../utils/palette.dart';

// 1. DADOS DOS ELEMENTOS (Símbolo e Eletronegatividade de Pauling)
class ChemElement {
  final String symbol;
  final double electronegativity;
  ChemElement(this.symbol, this.electronegativity);
}

final List<ChemElement> allElements = [
  ChemElement('F', 3.98),
  ChemElement('O', 3.44),
  ChemElement('Cl', 3.16),
  ChemElement('N', 3.04),
  ChemElement('C', 2.55),
  ChemElement('H', 2.20),
  ChemElement('Na', 0.93),
  ChemElement('K', 0.82),
];

// 2. O BURACO (Apenas visual)
class Hole extends PositionComponent {
  Hole({required Vector2 position}) : super(position: position, size: Vector2(80, 40), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    // Desenha uma elipse preta para simular o buraco
    canvas.drawOval(size.toRect(), Paint()..color = Colors.black87);
  }
}

// 3. A TOUPEIRA (O elemento clicável)
class Mole extends PositionComponent with TapCallbacks {
  final ChemElement element;
  final Function(Mole) onTapMole;
  
  bool isJumping = false; // Trava para evitar cliques enquanto está debaixo da terra

  Mole({required this.element, required Vector2 position, required this.onTapMole}) 
      : super(position: position, size: Vector2(60, 60), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(TextComponent(
      text: element.symbol,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: kPixelFont)),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    ));
    
    scale = Vector2.zero();
    add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3, curve: Curves.easeOutBack)));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, Paint()..color = Colors.brown);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isJumping) {
      onTapMole(this);
    }
  }

  // NOVO: Função que faz a toupeira mudar de buraco com animação
  void jumpTo(Vector2 newPosition) {
    isJumping = true; // Impede o clique
    
    // 1. Encolhe (entra no buraco)
    add(ScaleEffect.to(
      Vector2.zero(), 
      EffectController(duration: 0.15),
      onComplete: () {
        // 2. Muda a coordenada instantaneamente enquanto está invisível
        position = newPosition; 
        
        // 3. Cresce novamente (sai no novo buraco)
        add(ScaleEffect.to(
          Vector2.all(1.0), 
          EffectController(duration: 0.15, curve: Curves.easeOutBack),
          onComplete: () => isJumping = false // Libera o clique novamente
        ));
      }
    ));
  }

  void hide() {
    isJumping = true;
    add(ScaleEffect.to(
      Vector2.zero(), 
      EffectController(duration: 0.2), 
      onComplete: () => removeFromParent()
    ));
  }
}

// 4. A CENA DO MINIGAME
class WhackAMoleMinigame extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler {
  final Random rng = Random();
  
  late TextComponent instructionUI;
  late TextComponent scoreUI;

  final List<Vector2> holePositions = [];
  Mole? moleA;
  Mole? moleB;

  int score = 0;
  int currentRound = 0;
  final int totalRounds = 5;
  final int pointsToWin = 3;
  
  bool isWaitingInput = false;
  bool isGameOver = false;

  // NOVO: Variáveis do Temporizador de pulo
  double jumpTimer = 0;
  final double jumpInterval = 2.0; // Tempo em segundos para elas mudarem de buraco

  @override
  Future<void> onLoad() async {
    size = gameRef.size;

    final defaultTextRenderer = TextPaint(style: const TextStyle(fontFamily: kPixelFont));
    instructionUI = TextComponent(text: 'Acerte o MAIS ELETRONEGATIVO!', position: Vector2(size.x / 2, 40), anchor: Anchor.center, textRenderer: defaultTextRenderer);
    scoreUI = TextComponent(text: 'Pontos: $score / $pointsToWin | Rodada: 1/$totalRounds', position: Vector2(size.x / 2, 80), anchor: Anchor.center, textRenderer: defaultTextRenderer);
    
    add(instructionUI);
    add(scoreUI);

    if (kShowTouchControls) {
      add(touchExitButton(size, () => gameRef.router.pop()));
    }

    final double startX = size.x / 2 - 120;
    final double startY = size.y / 2;

    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        final pos = Vector2(startX + (col * 120), startY + (row * 100));
        holePositions.add(pos);
        add(Hole(position: pos));
      }
    }

    Future.delayed(const Duration(seconds: 1), startRound);
  }

  // NOVO: O ciclo de atualização constante do jogo
  @override
  void update(double dt) {
    super.update(dt);
    
    // Se estamos aguardando o clique e o jogo não acabou
    if (isWaitingInput && !isGameOver) {
      jumpTimer += dt; // Soma o tempo que passou
      
      // Se bateu o tempo limite (ex: 2 segundos)
      if (jumpTimer >= jumpInterval) {
        jumpTimer = 0; // Zera o relógio
        relocateMoles(); // Pula de buraco!
      }
    }
  }

  void startRound() {
    if (isGameOver) return;
    
    currentRound++;
    scoreUI.text = 'Pontos: $score / $pointsToWin | Rodada: $currentRound/$totalRounds';
    
    jumpTimer = 0; // Zera o timer ao começar a rodada

    List<Vector2> availableHoles = List.from(holePositions)..shuffle(rng);
    List<ChemElement> availableElements = List.from(allElements)..shuffle(rng);

    moleA = Mole(element: availableElements[0], position: availableHoles[0], onTapMole: handleMoleTap);
    moleB = Mole(element: availableElements[1], position: availableHoles[1], onTapMole: handleMoleTap);

    add(moleA!);
    add(moleB!);
    isWaitingInput = true;
  }

  // NOVO: Função que sorteia novos buracos e manda as toupeiras pularem
  void relocateMoles() {
    List<Vector2> availableHoles = List.from(holePositions)..shuffle(rng);
    
    // Manda as toupeiras para os dois primeiros buracos da lista embaralhada
    moleA?.jumpTo(availableHoles[0]);
    moleB?.jumpTo(availableHoles[1]);
  }

  void handleMoleTap(Mole tappedMole) {
    if (!isWaitingInput) return; 
    isWaitingInput = false; // Trava a tela (Isso também pausa o jumpTimer no update!)

    Mole otherMole = (tappedMole == moleA) ? moleB! : moleA!;

    if (tappedMole.element.electronegativity > otherMole.element.electronegativity) {
      score++; 
      instructionUI.text = 'BOM TRABALHO!';
    } else {
      instructionUI.text = 'ERROU! O maior era ${otherMole.element.symbol}';
    }

    scoreUI.text = 'Pontos: $score / $pointsToWin | Rodada: $currentRound/$totalRounds';

    tappedMole.hide();
    otherMole.hide();

    Future.delayed(const Duration(seconds: 1), () {
      instructionUI.text = 'Acerte o MAIS ELETRONEGATIVO!';
      if (currentRound >= totalRounds) {
        endGame();
      } else {
        startRound();
      }
    });
  }

  void endGame() {
    isGameOver = true;
    bool won = score >= pointsToWin;
    
    add(TextComponent(
      text: won ? 'SUCESSO! VOCÊ PASSOU!' : 'FALHOU!',
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: TextStyle(color: won ? Colors.green : Colors.red, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: kPixelFont)),
    ));
    
    if (kShowTouchControls) {
      instructionUI.text = 'Fim de jogo';
      add(touchRestartButton(
        Vector2(size.x / 2, 130),
        () => gameRef.restartMinigame('minigame_whack'),
      ));
    } else {
      instructionUI.text = 'ESC: voltar ao laboratório | R: reiniciar';
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2E7D32));
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver && event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.keyR)) {
      gameRef.restartMinigame('minigame_whack');
      return false;
    }
    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.escape)) {
      gameRef.router.pop();
      return false;
    }
    return super.onKeyEvent(event, keysPressed);
  }
}