//import 'dart:ui' hide TextStyle, FontWeight;
import 'package:chem_quest/utils/palette.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart'; // NOVO: Para usar hitboxes
//import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import '../../game.dart';
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

  MoleculeTarget({required this.data, required Vector2 position, required this.direction, required this.onComplete})
      : super(position: position, size: Vector2(80, 80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('alvo.png');

    // CollisionType.passive salva memória, ele só reage a objetos ativos (a bala)
    add(RectangleHitbox(collisionType: CollisionType.passive));

    textComp = TextComponent(
      text: data.display,
      textRenderer: TextPaint(style: const TextStyle(color: Palette.branco, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: kPixelFont
      ,shadows: [Shadow(color: Palette.preto, offset: Offset(1, 1)),
          Shadow(color: Palette.preto, offset: Offset(-1, -1)),
          Shadow(color: Palette.preto, offset: Offset(1, -1)),
          Shadow(color: Palette.preto, offset: Offset(-1, 1)),
          Shadow(color: Palette.preto, offset: Offset(0, 1)),
          Shadow(color: Palette.preto, offset: Offset(0, -1)),
          Shadow(color: Palette.preto, offset: Offset(1, 0)),
          Shadow(color: Palette.preto, offset: Offset(-1, 0)),] 
      )),
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
    } else if (position.x > gameRef.size.x - size.x / 2) {
      position.x = gameRef.size.x - size.x / 2;
      direction = -1;
    }
  }

  @override
  void render(Canvas canvas) {
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

  ShooterPlayer({required Vector2 position, required this.getAmmo}) : super(position: position, size: Vector2(96, 96), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('playerTiro.png');
  }

  @override
  void render(Canvas canvas) { sprite.render(canvas, size: size); }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += (direction + touchDirection).clamp(-1, 1) * speed * dt;
    if (position.x < 20) position.x = 20;
    if (position.x > gameRef.size.x - 20) position.x = gameRef.size.x - 20;
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
class ShootingGalleryMinigame extends PositionComponent with HasGameRef<ChemQuestGame>, KeyboardHandler {
  
  late TextComponent elementUI;
  late TextComponent scoreUI;
  
  final List<String> ammoTypes = ['H (Hidrogênio)', 'O (Oxigênio)', 'C (Carbono)'];
  int currentAmmoIndex = 0;
  
  int targetsCompleted = 0;
  final int totalTargets = 3; // Quantidade para vencer
  bool gameOver = false;
  late ShooterPlayer shooter;

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
    size = gameRef.size;

    elementUI = TextComponent(
      text: _ammoText,
      position: Vector2(20, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco)),
    );
    scoreUI = TextComponent(
      text: 'Completadas: 0 / $totalTargets',
      position: Vector2(size.x - 250, 20),
      textRenderer: TextPaint(style: const TextStyle(fontFamily: kPixelFont, color: Palette.branco)),
    );
    
    add(elementUI);
    add(scoreUI);

    shooter = ShooterPlayer(position: Vector2(size.x / 2, size.y - 50), getAmmo: () => ammoTypes[currentAmmoIndex]);
    add(shooter);

    if (kShowTouchControls) _addTouchControls();

    // Geração dos Alvos
    spawnTargets();
  }

  void _addTouchControls() {
    final buttonSize = Vector2(80, 80);
    final y = size.y - 60;
    add(TouchButton(
      label: '<',
      position: Vector2(64, y),
      size: buttonSize,
      onPress: () => shooter.touchDirection -= 1,
      onRelease: () => shooter.touchDirection += 1,
    ));
    add(TouchButton(
      label: '>',
      position: Vector2(160, y),
      size: buttonSize,
      onPress: () => shooter.touchDirection += 1,
      onRelease: () => shooter.touchDirection -= 1,
    ));
    add(TouchButton(
      label: 'ATIRAR',
      position: Vector2(size.x - 72, y),
      size: Vector2(110, 80),
      onPress: shooter.shoot,
    ));
    add(TouchButton(
      label: 'TROCAR',
      position: Vector2(size.x - 72, y - 96),
      size: Vector2(110, 56),
      onTap: nextAmmo,
    ));
    add(touchExitButton(size, () => gameRef.router.pop()));
  }

  void spawnTargets() {
    // 1. Água (Falta O)
    add(MoleculeTarget(
      data: MoleculeData('H2_', 'O', 'H2O'),
      position: Vector2(100, 100),
      direction: 1, // Começa indo pra direita
      onComplete: handleTargetCompleted,
    ));

    // 2. Gás Carbônico (Falta C)
    add(MoleculeTarget(
      data: MoleculeData('_O2', 'C', 'CO2'),
      position: Vector2(size.x - 100, 160),
      direction: -1, // Começa indo pra esquerda
      onComplete: handleTargetCompleted,
    ));

    // 3. Metano (Falta H)
    add(MoleculeTarget(
      data: MoleculeData('CH3_', 'H', 'CH4'),
      position: Vector2(size.x / 2, 220),
      direction: 1,
      onComplete: handleTargetCompleted,
    ));
  }

  void handleTargetCompleted() {
    targetsCompleted++;
    scoreUI.text = 'Completadas: $targetsCompleted / $totalTargets';

    if (targetsCompleted >= totalTargets) {
      gameOver = true;
      add(TextComponent(
        text: kShowTouchControls ? 'LABORATÓRIO LIMPO!' : 'LABORATÓRIO LIMPO!\nESC: sair | R: reiniciar',
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: const TextStyle(color: Palette.jade, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: kPixelFont)),
      ));
      if (kShowTouchControls) {
        add(touchRestartButton(
          Vector2(size.x / 2, size.y / 2 + 50),
          () => gameRef.restartMinigame('minigame_shooter'),
        ));
      }
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
    canvas.drawRect(size.toRect(), Paint()..color = Palette.azulEsc);
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