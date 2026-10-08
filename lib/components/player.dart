import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flame/collisions.dart'; // Importar colisões
import '../game.dart';
import 'wall.dart';

class Player extends PositionComponent with KeyboardHandler, CollisionCallbacks, HasGameRef<ChemQuestGame> {
  Vector2 velocity = Vector2.zero();
  final double speed = 100.0; // Velocidade de movimento (pixels por segundo)
  Vector2 _lastPosition = Vector2.zero();

  late final SpriteComponent _visual;
  double _animTime = 0.0;
  bool _facingLeft = false;

  /// Joystick virtual (controles de toque). Se null, só o teclado move o jogador.
  JoystickComponent? joystick;
  bool _joystickWasActive = false;

  Player() : super(size: Vector2.all(16), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _visual = SpriteComponent(
      sprite: await gameRef.loadSprite('player.png'),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _visual.paint.filterQuality = FilterQuality.none;
    _visual.paint.isAntiAlias = false;
    add(_visual);

    add(RectangleHitbox(
      anchor: Anchor.center,
      size: Vector2(14, 14),
      position: size / 2, // Centraliza a hitbox reduzida no sprite
    ));
  }

  @override
  void update(double dt) {
    _lastPosition = position.clone();
    super.update(dt);
    _applyJoystick();
    // Atualiza a posição baseada na velocidade e no tempo (dt)
    position += velocity * speed * dt;

    _animTime += dt;
    _updateAnimation(dt);
  }

  void _applyJoystick() {
    final joy = joystick;
    if (joy == null) return;

    if (joy.direction != JoystickDirection.idle) {
      // relativeDelta vai de 0 a 1, então o toque também controla a velocidade
      velocity = joy.relativeDelta;
      if (velocity.x < -0.2) {
        _facingLeft = true;
      } else if (velocity.x > 0.2) {
        _facingLeft = false;
      }
      _joystickWasActive = true;
    } else if (_joystickWasActive) {
      // Soltou o joystick: para o jogador (sem interferir no teclado quando o joystick não é usado)
      velocity = Vector2.zero();
      _joystickWasActive = false;
    }
  }

  void _updateAnimation(double dt) {
    final isWalking = velocity.length > 0;
    final facingSign = _facingLeft ? -1.0 : 1.0;

    if (isWalking) {
      // Animação de andar: pulinho vertical + balanço lateral + squash/stretch.
      const walkFrequency = 20.0; // Velocidade da passada
      final wave = sin(_animTime * walkFrequency);

      // Pulinho vertical (bounce)
      final bounceOffset = wave.abs() * 1.5;

      // Squash/stretch: comprime na vertical quando "pisa", estica quando "salta"
      final squash = 1.0 - (wave.abs() * 0.08);
      final stretch = 1.0 + (wave.abs() * 0.08);

      // Balanço/giro leve pro lado, como se estivesse cambaleando ao andar
      final tilt = wave * 0.08;

      _visual.position = Vector2(size.x / 2, size.y / 2 - bounceOffset);
      _visual.scale = Vector2(stretch * facingSign, squash);
      _visual.angle = tilt;
    } else {
      // Animação de respiração: escala sobe e desce devagar quando parado.
      const breathFrequency = 3.0;
      final breath = sin(_animTime * breathFrequency);

      final breathScaleY = 1.0 + (breath * 0.04);
      final breathScaleX = 1.0 - (breath * 0.02);

      _visual.position = Vector2(size.x / 2, size.y / 2);
      _visual.scale = Vector2(breathScaleX * facingSign, breathScaleY);
      _visual.angle = 0.0;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // Se o objeto no qual batemos for uma Wall (Parede)
    if (other is Wall) {
      // Impede o movimento voltando pra posição do frame anterior
      position = _lastPosition;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    double dirX = 0.0;
    double dirY = 0.0;
    // Movimentação horizontal
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || keysPressed.contains(LogicalKeyboardKey.keyA)) {
      dirX -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || keysPressed.contains(LogicalKeyboardKey.keyD)) {
      dirX += 1;
    }

    // Movimentação vertical
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp) || keysPressed.contains(LogicalKeyboardKey.keyW)) {
      dirY -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown) || keysPressed.contains(LogicalKeyboardKey.keyS)) {
      dirY += 1;
    }

    // Atualiza a direção que o sprite deve encarar (mantém a última ao mover só na vertical)
    if (dirX < 0) {
      _facingLeft = true;
    } else if (dirX > 0) {
      _facingLeft = false;
    }

    velocity = Vector2(dirX, dirY);

    // Normaliza a velocidade para o jogador não andar mais rápido na diagonal
    if (velocity.length > 0) {
      velocity.normalize();
    }

    return super.onKeyEvent(event, keysPressed);
  }
}
