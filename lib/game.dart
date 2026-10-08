import 'package:chem_quest/scenes/minigames/shootings_gallery_minigame.dart';
import 'package:chem_quest/scenes/minigames/whack_a_mole_minigame.dart';
import 'package:chem_quest/scenes/world_scene.dart';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'scenes/minigames/true_false_minigame.dart';

// Importaremos as cenas assim que as criarmos:
// import 'scenes/world_scene.dart';
// import 'scenes/minigames/true_false_minigame.dart';

class ChemQuestGame extends FlameGame with HasKeyboardHandlerComponents, HasCollisionDetection {
  late final RouterComponent router;

  @override
  Color backgroundColor() => const Color(0xff1d2b53);

  @override
  Future<void> onLoad() async {
    // Configuração das Rotas do jogo
    router = RouterComponent(
      initialRoute: 'world',
      routes: {
        // Rota principal: Onde o boneco anda pelo laboratório
        'world': Route(_buildWorldScene),
        
        // Rotas dos Minigames
        // maintainState: false descarta a cena ao sair, então cada entrada começa um jogo novo
        'minigame_cards': Route(_buildTrueFalseMinigame, maintainState: false),
        'minigame_shooter': Route(_buildShootingGallery, maintainState: false),
        'minigame_whack': Route(_buildWhackAMole, maintainState: false),
      },
    );

    add(router);
  }

  // Reinicia um minigame: troca a rota atual por uma nova (cena recriada do zero).
  // pushReplacementNamed não serve aqui, pois ignora a rota que já está no topo.
  void restartMinigame(String routeName) {
    final builder = switch (routeName) {
      'minigame_cards' => _buildTrueFalseMinigame,
      'minigame_shooter' => _buildShootingGallery,
      'minigame_whack' => _buildWhackAMole,
      _ => throw ArgumentError('Minigame desconhecido: $routeName'),
    };
    router.pushReplacement(Route(builder, maintainState: false), name: routeName);
  }

  // Métodos construtores para cada cena
  Component _buildWorldScene() => WorldScene();

  Component _buildTrueFalseMinigame() {
    return TrueFalseMinigame(); // Chama a nossa nova classe
  }

  Component _buildShootingGallery() {
    return ShootingGalleryMinigame();
  }

  Component _buildWhackAMole() {
    return WhackAMoleMinigame();
  }
}