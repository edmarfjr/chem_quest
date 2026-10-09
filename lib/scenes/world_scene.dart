import 'dart:math';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flame/rendering.dart';
import 'package:flame_tiled/flame_tiled.dart';
import '../components/minigame_trigger.dart';
import '../components/player.dart';
import '../components/touch_controls.dart';
import '../utils/palette.dart';
import '../utils/tiled_utils.dart';
import '../components/wall.dart';

// Trava a posição da câmera dentro dos limites do mapa, considerando o zoom
// (o `considerViewport` do CameraComponent.setBounds não leva o zoom em conta
// e acaba deixando a câmera vazar para fora do mapa quando ele é != 1).
// Em telas grandes o zoom sobe o suficiente para o mapa sempre cobrir a tela inteira.
class _MapBoundsBehavior extends Component with ParentIsA<Viewfinder> {
  final Vector2 mapSize;
  final double baseZoom;
  _MapBoundsBehavior(this.mapSize, {required this.baseZoom}) : super(priority: 1000);

  @override
  void update(double dt) {
    super.update(dt);
    final viewportSize = parent.camera.viewport.size;
    final minZoom = max(viewportSize.x / mapSize.x, viewportSize.y / mapSize.y);
    final zoom = max(baseZoom, minZoom);
    if (parent.zoom != zoom) parent.zoom = zoom;
    final halfW = viewportSize.x / zoom / 2;
    final halfH = viewportSize.y / zoom / 2;

    var minX = halfW;
    var maxX = mapSize.x - halfW;
    if (minX > maxX) {
      minX = maxX = mapSize.x / 2;
    }
    var minY = halfH;
    var maxY = mapSize.y - halfH;
    if (minY > maxY) {
      minY = maxY = mapSize.y / 2;
    }

    // `Viewfinder.position` devolve uma cópia: é preciso atribuir um novo vetor
    final pos = parent.position;
    parent.position = Vector2(pos.x.clamp(minX, maxX), pos.y.clamp(minY, maxY));
  }
}

class WorldScene extends Component {
  late final World world;
  late final CameraComponent camera;

  @override
  Future<void> onLoad() async {
    // 1. Cria o mundo onde o jogo acontece
    world = World();
    add(world);

    // 1. Carrega o mapa (ajuste o Vector2.all para o tamanho dos seus tiles, ex: 16x16 ou 32x32)
    // Lembre-se de ter o arquivo assets/tiles/laboratorio.tmx
    final map = await TiledComponent.load('lab1.tmx', Vector2.all(16),useAtlas: false);

    makeTiledPixelPerfect(map);

    world.add(map);

    final collisionLayer = map.tileMap.getLayer<ObjectGroup>('Colisoes');
    
    if (collisionLayer != null) {
      for (final obj in collisionLayer.objects) {
        // Cria uma Wall para cada retângulo desenhado no Tiled
        final wall = Wall(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
        );
        world.add(wall);
      }
    }

    final interactionLayer = map.tileMap.getLayer<ObjectGroup>('Interacoes');
    
    if (interactionLayer != null) {
      for (final obj in interactionLayer.objects) {
        final trigger = MinigameTrigger(
          position: Vector2(obj.x, obj.y),
          size: Vector2(obj.width, obj.height),
          minigameRoute: obj.name, // Pega o nome "minigame_cards" que você colocou no Tiled
        );
        world.add(trigger);
      }
    }

    // 2. Instancia o jogador
    final player = Player();
    
    // Posiciona o jogador no meio do mapa (opcional, calcule baseado no tamanho do mapa)
    player.position = Vector2(14*16,6*16);
    world.add(player);

    // 3. Configura a câmera
    camera = CameraComponent(world: world);
    camera.follow(player);
    
    
    // Opcional: Trava a câmera nos limites do mapa para ela não mostrar o fundo fora do laboratório

    camera.viewfinder.add(_MapBoundsBehavior(map.size, baseZoom: 4.0));

    // 4. Joystick virtual (HUD fixo na tela) para celular/tablet
    if (kShowTouchControls) {
      final joystick = JoystickComponent(
        knob: CircleComponent(radius: 24, paint: Paint()..color = Palette.branco.withValues(alpha: 0.7)),
        background: CircleComponent(radius: 56, paint: Paint()..color = Palette.preto.withValues(alpha: 0.35)),
        margin: const EdgeInsets.only(left: 40, bottom: 40),
      );
      camera.viewport.add(joystick);
      player.joystick = joystick;
    }

    add(camera);
  }
}