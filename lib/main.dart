import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Jogo pensado para tela deitada (no desktop essas chamadas não têm efeito)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final game = ChemQuestGame();

  runApp(
    GameWidget(
      game: game,
      autofocus: true, // Adicione esta linha!
    ),
  );
}
