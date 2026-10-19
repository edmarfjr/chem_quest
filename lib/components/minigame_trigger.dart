import 'package:flame/components.dart';
import '../game.dart';
import 'interactive_object.dart';

class MinigameTrigger extends InteractiveObject with HasGameRef<ChemQuestGame> {
  final String minigameRoute; // Vai guardar qual rota este objeto abre

  MinigameTrigger({required super.position, required super.size, required this.minigameRoute});

  @override
  String get actionLabel => 'JOGAR';

  /// Abre o minigame (chamado pelo botão Z ou pelo botão da tela).
  @override
  void interact() {
    // Só vale com o mapa na frente; evita abrir de novo se o botão for apertado dentro de um minigame
    if (gameRef.router.currentRoute.name != 'world') return;
    gameRef.router.pushNamed(minigameRoute);
  }
}
