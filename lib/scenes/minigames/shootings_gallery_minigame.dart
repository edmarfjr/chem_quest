//import 'dart:ui' hide TextStyle, FontWeight;
import 'package:chem_quest/utils/palette.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart'; // NOVO: Para usar hitboxes
//import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
import '../../components/virtual_screen.dart';
import '../../utils/tiled_utils.dart';
import '../../components/touch_controls.dart';

// --- DADOS DA MOLÉCULA ---
class MoleculeData {
  final String display;
  final String missing;
  final String complete;
  MoleculeData(this.display, this.missing, this.complete);
}

// 1. O PROJÉTIL (Agora com Colisão)
class Bullet extends PositionComponent with CollisionCallbacks {
  final String element;
  final double speed = 400.0;

  Bullet({required this.element, required Vector2 position}) 
      : super(position: position, size: Vector2(20, 20), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Adicionamos a Hitbox na bala
    add(RectangleHitbox());
    
    add(TextComponent(
      text: element[0], 
      textRenderer: TextPaint(style: TextStyle(color: Palette.preto, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: kPixelFont)),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= speed * dt;
    if (position.y < -50) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, Paint()..color = Palette.laranja);
  }

  // Quando a bala bate em qualquer coisa
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // Se bateu num alvo, a bala se destrói independentemente se acertou o elemento ou não
    if (other is MoleculeTarget) {
      removeFromParent();
    }
  }
}

// 2. O ALVO (A Molécula Incompleta)
class MoleculeTarget extends PositionComponent with CollisionCallbacks, HasGameRef<ChemQuestGame> {
  final MoleculeData data;
  bool isCompleted = false;
  double speed = 100.0;
  int direction = 1; // 1 = Direita, -1 = Esquerda

  late Sprite sprite;
  late TextComponent textComp;
  final VoidCallback onComplete; // Avisa a cena principal que foi completada
  final VoidCallback onMiss; // Avisa a cena principal que foi atingido com o elemento errado

  MoleculeTarget({required this.data, required Vector2 position, required this.direction, required this.onComplete, required this.onMiss})
      : super(position: position, size: Vector2(80, 80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('alvo.png');

    // CollisionType.passive salva memória, ele só reage a objetos ativos (a bala)
    add(RectangleHitbox(collisionType: CollisionType.passive));

    textComp = TextComponent(
      text: data.display,
      textRenderer: TextPaint(style: const TextStyle(color: Palette.branco, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: kPixelFont, shadows: kTextOutline)),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2 - 8),
    );
    add(textComp);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCompleted) return; // Se já completou, para de andar

    // Movimentação automática de "Vai e Vem"
    position.x += speed * direction * dt;

    // Bate nas bordas da tela e inverte a direção
    if (position.x < size.x / 2) {
      position.x = size.x / 2;
      direction = 1;
    } else if (position.x > VirtualScreen.designWidth - size.x / 2) {
      position.x = VirtualScreen.designWidth - size.x / 2;
      direction = -1;
    }
  }

  // Sombra: elipse escura sob o sprite
  static final Paint _shadowPaint = Paint()..color = Palette.preto;

  @override
  void render(Canvas canvas) {
    final shadow = Rect.fromCenter(
      center: Offset(size.x / 2 - 2, size.y * 0.95),
      width: size.x * 0.8,
      height: size.y * 0.2,
    );
    canvas.drawOval(shadow, _shadowPaint);
    sprite.render(canvas, size: size);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    // Se a colisão for com uma Bala e o alvo ainda não foi completado
    if (other is Bullet && !isCompleted) {
      
      // Verifica se a primeira letra da arma (ex: 'O') bate com o que falta
      if (other.element[0] == data.missing) {
        isCompleted = true;
        textComp.text = data.complete; // Muda para a fórmula completa (ex: H2O)
        
        onComplete(); // Avisa a fase que ganhamos pontos

        // Remove o alvo da tela depois de meio segundo (para o jogador ver que completou)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (isMounted) removeFromParent();
        });
      } else {
        onMiss(); // Elemento errado: o jogador perde uma vida
      }
    }
  }
}

// 3. O JOGADOR DO MINIGAME (Mantivemos Igual)
class ShooterPlayer extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler {
  final double speed = 300.0;
  int direction = 0;
  int touchDirection = 0; // -1, 0 ou 1, controlado pelos botões de toque
  final String Function() getAmmo;
  late Sprite sprite;
  late TextComponent _ammoLabel;

  ShooterPlayer({required Vector2 position, required this.getAmmo}) : super(position: position, size: Vector2(96, 96), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('playerTiro.png');

    // Letra do elemento da munição atual, no centro do sprite
    _ammoLabel = TextComponent(
      text: _ammoSymbol,
      anchor: Anchor.center,
      position: size / 2 + Vector2(0, 16),
      textRenderer: TextPaint(
        style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24, fontWeight: FontWeight.bold, shadows: kTextOutline),
      ),
    );
    add(_ammoLabel);
  }

  String get _ammoSymbol => getAmmo()[0]; // 'H (Hidrogênio)' -> 'H'

  @override
  void render(Canvas canvas) { sprite.render(canvas, size: size); }

  @override
  void update(double dt) {
    super.update(dt);
    if (_ammoLabel.text != _ammoSymbol) _ammoLabel.text = _ammoSymbol;
    position.x += (direction + touchDirection).clamp(-1, 1) * speed * dt;
    if (position.x < 20) position.x = 20;
    if (position.x > VirtualScreen.designWidth - 20) position.x = VirtualScreen.designWidth - 20;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    direction = 0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) direction -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) direction += 1;

    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.keyZ)) {
      shoot();
    }
    return super.onKeyEvent(event, keysPressed);
  }

  void shoot() {
    parent?.add(Bullet(element: getAmmo(), position: Vector2(position.x, position.y - size.y / 2)));
  }
}

// 4. A CENA DO MINIGAME
class ShootingGalleryMinigame extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler, VirtualScreen {
  
  late TextComponent elementUI;
  late TextComponent scoreUI;
  
  final List<String> ammoTypes = ['H (Hidrogênio)', 'O (Oxigênio)', 'C (Carbono)'];
  int currentAmmoIndex = 0;
  
  int targetsCompleted = 0;
  final int totalTargets = 3; // Quantidade para vencer
  bool gameOver = false;
  late ShooterPlayer shooter;

  final int maxLives = 3;
  late int lives = maxLives;
  late TextComponent livesUI;
  TouchHud? _hud; // botões de toque (só no celular)
  TiledBackground? _background; // mapa shootingGalery.tmx usado como fundo

  // No celular os botões substituem as dicas de teclado
  String get _ammoText => kShowTouchControls
      ? 'Munição: ${ammoTypes[currentAmmoIndex]}'
      : 'Munição: ${ammoTypes[currentAmmoIndex]}\n(X) Trocar | (Z) Atirar';

  void nextAmmo() {
    currentAmmoIndex++;
    if (currentAmmoIndex >= ammoTypes.length) currentAmmoIndex = 0;
    elementUI.text = _ammoText;
  }

  @override
  Future<void> onLoad() async {
    fitToScreen(gameRef.size);

    _background = await TiledBackground.load('shootingGalery.tmx');
    add(_background!);
    _background!.fit(screenRect);

    elementUI = TextComponent(
      text: _ammoText,
      position: Vector2(20, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24, shadows: kTextOutline)),
    );
    scoreUI = TextComponent(
      text: 'Completadas: 0 / $totalTargets',
      position: Vector2(size.x - 'Completadas: 0 / $totalTargets'.length * 12 - 20, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24, shadows: kTextOutline)),
    );
    
    livesUI = TextComponent(
      text: 'Vidas: $lives',
      position: Vector2(size.x / 2, 20),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco, fontSize: 24, shadows: kTextOutline)),
    );

    add(elementUI);
    add(scoreUI);
    add(livesUI);

    shooter = ShooterPlayer(position: Vector2(size.x / 2, size.y - 50), getAmmo: () => ammoTypes[currentAmmoIndex]);
    add(shooter);

    if (kShowTouchControls) _addTouchControls();

    // Geração dos Alvos
    spawnTargets();
  }

  // Botões em coordenadas reais da tela (não escalam com a cena), presos aos cantos
  void _addTouchControls() {
    final hud = TouchHud(gameRef.size);
    hud.addItem(MovePad(onChange: (direction) => shooter.touchDirection = direction), (s) => Vector2(24, s.y - 100));
    hud.addItem(
      TouchButton(label: 'ATIRAR', position: Vector2.zero(), size: Vector2(110, 80), onPress: shooter.shoot),
      (s) => Vector2(s.x - 72, s.y - 60),
    );
    hud.addItem(
      TouchButton(label: 'TROCAR', position: Vector2.zero(), size: Vector2(110, 56), onTap: nextAmmo),
      (s) => Vector2(s.x - 72, s.y - 156),
    );
    hud.addItem(touchExitButton(Vector2.zero(), () => gameRef.router.pop()), (s) => Vector2(s.x - 16, 16));
    _hud = hud;
    gameRef.add(hud);
  }

  @override
  void onRemove() {
    _hud?.removeFromParent();
    super.onRemove();
  }

  void spawnTargets() {
    // 1. Água (Falta O)
    add(MoleculeTarget(
      data: MoleculeData('H2_', 'O', 'H2O'),
      position: Vector2(100, 140),
      direction: 1, // Começa indo pra direita
      onComplete: handleTargetCompleted,
      onMiss: handleMiss,
    ));

    // 2. Gás Carbônico (Falta C)
    add(MoleculeTarget(
      data: MoleculeData('_O2', 'C', 'CO2'),
      position: Vector2(size.x - 100, 220),
      direction: -1, // Começa indo pra esquerda
      onComplete: handleTargetCompleted,
      onMiss: handleMiss,
    ));

    // 3. Metano (Falta H)
    add(MoleculeTarget(
      data: MoleculeData('CH3_', 'H', 'CH4'),
      position: Vector2(size.x / 2, 300),
      direction: 1,
      onComplete: handleTargetCompleted,
      onMiss: handleMiss,
    ));
  }

  void handleTargetCompleted() {
    if (gameOver) return;
    targetsCompleted++;
    scoreUI.text = 'Completadas: $targetsCompleted / $totalTargets';

    if (targetsCompleted >= totalTargets) _endGame(true);
  }

  void handleMiss() {
    if (gameOver) return;
    lives--;
    livesUI.text = 'Vidas: $lives';

    if (lives <= 0) _endGame(false);
  }

  void _endGame(bool won) {
    gameOver = true;
    final title = won ? 'LABORATÓRIO LIMPO!' : 'SEM VIDAS! FALHOU!';
    add(TextComponent(
      text: kShowTouchControls ? title : '$title\nESC: sair | R: reiniciar',
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: TextStyle(color: won ? Palette.jade : Palette.vermelho, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: kPixelFont, shadows: kTextOutline)),
    ));
    if (kShowTouchControls) {
      _hud?.addItem(
        touchRestartButton(Vector2.zero(), () => gameRef.restartMinigame('minigame_shooter')),
        (s) => Vector2(s.x / 2, s.y / 2 + 50),
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size); // VirtualScreen reposiciona/escala a cena
    _background?.fit(screenRect);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(screenRect, Paint()..color = Palette.azulEsc);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (gameOver && keysPressed.contains(LogicalKeyboardKey.keyR)) {
        gameRef.restartMinigame('minigame_shooter');
        return false;
      }
      if (keysPressed.contains(LogicalKeyboardKey.keyX)) {
        nextAmmo();
        return false;
      }
      if (keysPressed.contains(LogicalKeyboardKey.escape)) {
        gameRef.router.pop();
        return false;
      }
    }
    return super.onKeyEvent(event, keysPressed);
  }
}