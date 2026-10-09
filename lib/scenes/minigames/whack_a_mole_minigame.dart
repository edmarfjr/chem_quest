import 'dart:ui' hide TextStyle, FontWeight;
import 'dart:math';
import 'package:flutter/material.dart' hide PointerMoveEvent;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
import '../../components/virtual_screen.dart';
import '../../components/touch_controls.dart';
import '../../utils/palette.dart';
import '../../utils/tiled_utils.dart';

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

// Spritesheet mole.png: 4 quadros de 24x24 lado a lado
//   0 = buraco vazio | 1 e 2 = toupeira subindo | 3 = toupeira totalmente fora
const double _moleFrameSrc = 24;
const double _moleSpriteSize = 72; // 3x o tamanho original, mantém o pixel art nítido
final Paint _pixelPaint = Paint()..filterQuality = FilterQuality.none..isAntiAlias = false;

Future<List<Sprite>> _loadMoleFrames() async {
  final sheet = await Flame.images.load('mole.png');
  return List.generate(
    4,
    (i) => Sprite(sheet, srcPosition: Vector2(i * _moleFrameSrc, 0), srcSize: Vector2.all(_moleFrameSrc)),
  );
}

// 2. O BURACO (Apenas visual: primeiro quadro da animação)
class Hole extends PositionComponent {
  late final Sprite _sprite;

  Hole({required Vector2 position}) : super(position: position, size: Vector2.all(_moleSpriteSize), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _sprite = (await _loadMoleFrames())[0];
  }

  @override
  void render(Canvas canvas) {
    _sprite.render(canvas, size: size, overridePaint: _pixelPaint);
  }
}

// Texto do elemento: só aparece com a toupeira totalmente fora do buraco
class _ElementLabel extends TextComponent with HasVisibility {
  _ElementLabel({required String text, required Vector2 position})
      : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: kPixelFont, shadows: kTextOutline),
          ),
        );
}

// 3. A TOUPEIRA (O elemento clicável)
class Mole extends PositionComponent with TapCallbacks {
  static const int _lastFrame = 3;
  static const double _frameTime = 0.07; // segundos por quadro

  final ChemElement element;
  final Function(Mole) onTapMole;

  bool isJumping = false; // Trava para evitar cliques enquanto está debaixo da terra

  late final List<Sprite> _frames;
  late final _ElementLabel _label;
  int _frame = 0;

  // Animação por quadros: fila de quadros a exibir e o que fazer ao terminar
  final List<int> _queue = [];
  double _timer = 0;
  VoidCallback? _onDone;

  Mole({required this.element, required Vector2 position, required this.onTapMole})
      : super(position: position, size: Vector2.all(_moleSpriteSize), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _frames = await _loadMoleFrames();

    _label = _ElementLabel(text: element.symbol, position: Vector2(size.x / 2, size.y * 0.5));
    _label.isVisible = false;
    add(_label);

    _play(const [0, 1, 2, _lastFrame]); // sai do buraco
  }

  void _play(List<int> frames, {VoidCallback? onDone}) {
    _queue
      ..clear()
      ..addAll(frames);
    _onDone = onDone;
    _timer = 0;
    _showNextFrame();
  }

  void _showNextFrame() {
    _frame = _queue.removeAt(0);
    _label.isVisible = _frame == _lastFrame;
    if (_queue.isEmpty) {
      final done = _onDone;
      _onDone = null;
      done?.call();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_queue.isEmpty) return;
    _timer += dt;
    while (_timer >= _frameTime && _queue.isNotEmpty) {
      _timer -= _frameTime;
      _showNextFrame();
    }
  }

  @override
  void render(Canvas canvas) {
    _frames[_frame].render(canvas, size: size, overridePaint: _pixelPaint);
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = true; // a cena também precisa do toque para balançar o martelo
    if (!isJumping) {
      onTapMole(this);
    }
  }

  // NOVO: Função que faz a toupeira mudar de buraco com animação
  void jumpTo(Vector2 newPosition) {
    isJumping = true; // Impede o clique

    // 1. Entra no buraco
    _play(const [2, 1, 0], onDone: () {
      // 2. Muda a coordenada enquanto está escondida
      position = newPosition;

      // 3. Sai no novo buraco
      _play(const [1, 2, _lastFrame], onDone: () => isJumping = false); // Libera o clique novamente
    });
  }

  void hide() {
    isJumping = true;
    _play(const [2, 1, 0], onDone: removeFromParent);
  }
}

// MARTELO: segue o ponteiro e inclina para baixo ao clicar/tocar
class Hammer extends PositionComponent with HasVisibility {
  static const double _spriteSize = 96; // sprite 16x16 ampliado 3x
  static const double _swingDuration = 0.2; // segundos
  static const double _idleAngle = 0.0; // o sprite já vem inclinado 45° para a esquerda
  static const double _hitAngle = -80 * pi / 180; // 80° anti-horário: a cabeça desce para a esquerda, "batendo"

  late final Sprite _sprite;
  double _swingTime = _swingDuration; // >= duração significa parado

  Hammer() : super(size: Vector2.all(_spriteSize), anchor: Anchor.center, priority: 200) {
    angle = _idleAngle;
  }

  @override
  Future<void> onLoad() async {
    _sprite = Sprite(await Flame.images.load('hammer.png'));
  }

  void swing() => _swingTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_swingTime >= _swingDuration) return;

    _swingTime += dt;
    final p = (_swingTime / _swingDuration).clamp(0.0, 1.0);
    // Desce rápido (40% do tempo) e volta devagar
    final k = p < 0.4 ? p / 0.4 : 1 - (p - 0.4) / 0.6;
    angle = _idleAngle + (_hitAngle - _idleAngle) * k;
  }

  @override
  void render(Canvas canvas) {
    _sprite.render(canvas, size: size, overridePaint: _pixelPaint);
  }
}

// 4. A CENA DO MINIGAME
class WhackAMoleMinigame extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler, TapCallbacks, PointerMoveCallbacks, VirtualScreen {
  final Random rng = Random();
  
  late TextComponent instructionUI;
  late TextComponent scoreUI;
  late Hammer _hammer;
  TiledBackground? _background; // mapa whackAmole.tmx usado como fundo

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
    fitToScreen(gameRef.size);

    _background = await TiledBackground.load('whackAmole.tmx');
    add(_background!);
    _background!.fit(screenRect);

    final defaultTextRenderer = TextPaint(style: const TextStyle(fontFamily: kPixelFont));
    instructionUI = TextComponent(text: 'Acerte o MAIS ELETRONEGATIVO!', position: Vector2(size.x / 2, 40), anchor: Anchor.center, textRenderer: defaultTextRenderer);
    scoreUI = TextComponent(text: 'Pontos: $score / $pointsToWin | Rodada: 1/$totalRounds', position: Vector2(size.x / 2, 80), anchor: Anchor.center, textRenderer: defaultTextRenderer);
    
    add(instructionUI);
    add(scoreUI);

    _hammer = Hammer()..isVisible = false; // aparece no primeiro movimento/toque
    add(_hammer);

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

  // O martelo substitui o cursor do mouse
  @override
  void onMount() {
    super.onMount();
    gameRef.mouseCursor = SystemMouseCursors.none;
  }

  @override
  void onRemove() {
    gameRef.mouseCursor = MouseCursor.defer;
    super.onRemove();
  }

  void _moveHammer(Vector2 position) {
    _hammer
      ..position = position
      ..isVisible = true;
  }

  @override
  void onPointerMove(PointerMoveEvent event) => _moveHammer(event.localPosition);

  @override
  void onTapDown(TapDownEvent event) {
    _moveHammer(event.localPosition);
    _hammer.swing();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size); // VirtualScreen reposiciona/escala a cena
    _background?.fit(screenRect);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(screenRect, Paint()..color = const Color(0xFF2E7D32));
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