import 'package:flame/components.dart';
import 'package:flame/collisions.dart';

// Componente invisível que bloqueia o jogador
class Wall extends PositionComponent {
  Wall({required Vector2 position, required Vector2 size}) 
      : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // CollisionType.passive significa que as paredes não checam colisões 
    // umas com as outras, o que salva muita memória!
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }
}