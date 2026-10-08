import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import '../game.dart';
import 'player.dart';

class MinigameTrigger extends PositionComponent with CollisionCallbacks, HasGameRef<ChemQuestGame> {
  final String minigameRoute; // Vai guardar qual rota este objeto abre
  bool _hasTriggered = false; // Evita que abra 50 vezes no mesmo segundo

  MinigameTrigger({required Vector2 position, required Vector2 size, required this.minigameRoute}) 
      : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    // É passivo porque ele não empurra ninguém, só detecta que foi tocado
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  // Diferente da parede (que usa onCollision constante), 
  // aqui usamos onCollisionStart para disparar apenas 1 vez quando encostar
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    print('clicou2');
    // Se quem bateu foi o Player e o minigame ainda não foi ativado
    if (other is Player && !_hasTriggered) {
      _hasTriggered = true;
      
      // Empilha a tela do minigame por cima do mapa!
      gameRef.router.pushNamed(minigameRoute);
      
      // Dá um "cooldown" de 2 segundos para o jogador poder voltar 
      // do minigame e sair de cima do objeto sem abrir de novo sem querer.
      Future.delayed(const Duration(seconds: 2), () {
        _hasTriggered = false;
      });
    }
  }
}