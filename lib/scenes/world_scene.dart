import 'dart:math';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flame/rendering.dart';
import 'package:flame_tiled/flame_tiled.dart';
import '../components/dialog_box.dart';
import '../components/minigame_trigger.dart';
import '../components/npc_trigger.dart';
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

// Falas dos NPCs (objetos "npc1", "npc2"... da camada Interacoes do mapa). Trechos entre *asteriscos* ficam destacados.
const String _npcWelcome =
    'Bem vindo ao chem quest. Nesse jogo você vai aprender sobre a cultura indígena e como os seus saberes influenciaram na ciência de hoje.';
const Map<String, String> _npcDialogues = {
  'npc1': _npcWelcome,
  'npc2': 'Para nunca esquecer a fila de eletronegatividade vamos lembrar do macete\n'
      '*F*ui *O*ntem *N*o *Cl*ube, *Br*iguei *I* *S*ai *C*orrendo *P*ro *H*ospital',
};

class WorldScene extends Component {
  late final World world;
  late final CameraComponent camera;
  late final Player _player;
  WorldActionButton? _actionButton;
  late final DialogBox _dialog;

  @override
  Future<void> onLoad() async {
    // 1. Cria o mundo onde o jogo acontece
    world = World();
    add(world);

    // 1. Carrega o mapa (ajuste o Vector2.all para o tamanho dos seus tiles, ex: 16x16 ou 32x32)
    // Lembre-se de ter o arquivo assets/tiles/laboratorio.tmx
    final map = await TiledComponent.load('lab1.tmx', Vector2.all(16),useAtlas: false);

    // O mapa vira uma imagem só: com o zoom da câmera, tiles desenhados um a um deixam linhas entre eles
    world.add(await tiledMapAsSprite(map));

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

    // Objetos interagíveis: "npcN" abre um diálogo; os demais da camada Interacoes abrem o minigame de mesmo nome
    for (final layer in map.tileMap.map.layers.whereType<ObjectGroup>()) {
      for (final obj in layer.objects) {
        final name = obj.name.toLowerCase();
        final width = obj.width > 0 ? obj.width : 16.0;
        final height = obj.height > 0 ? obj.height : 16.0;

        if (RegExp(r'^npc\d+$').hasMatch(name)) {
          // Objeto com imagem (tile) tem a origem no canto de baixo; retângulo tem no de cima.
          // A área de interação é um pouco maior que o NPC, para o jogador poder falar encostando ao lado dele.
          const margin = 6.0;
          final top = obj.gid != null ? obj.y - height : obj.y;
          world.add(NpcTrigger(
            position: Vector2(obj.x - margin, top - margin),
            size: Vector2(width + margin * 2, height + margin * 2),
            dialogue: _npcDialogues[name] ?? _npcWelcome,
            onTalk: _talk,
          ));
        } else if (layer.name == 'Interacoes') {
          world.add(MinigameTrigger(
            position: Vector2(obj.x, obj.y),
            size: Vector2(width, height),
            minigameRoute: obj.name, // Pega o nome "minigame_cards" que você colocou no Tiled
          ));
        }
      }
    }

    // 2. Instancia o jogador
    final player = Player();
    _player = player;
    
    // Posiciona o jogador no meio do mapa (opcional, calcule baseado no tamanho do mapa)
    player.position = Vector2(2*16,9*16);
    world.add(player);

    // 3. Configura a câmera
    camera = CameraComponent(world: world);
    camera.follow(player);
    
    
    // Opcional: Trava a câmera nos limites do mapa para ela não mostrar o fundo fora do laboratório

    camera.viewfinder.add(_MapBoundsBehavior(map.size, baseZoom: 4.0));

    // Caixa de diálogo dos NPCs (HUD fixo na tela)
    _dialog = DialogBox();
    camera.viewport.add(_dialog);

    // 4. Joystick virtual (HUD fixo na tela) para celular/tablet
    if (kShowTouchControls) {
      final joystick = SafeJoystick(
        knob: CircleComponent(radius: 24, paint: Paint()..color = Palette.branco.withValues(alpha: 0.7)),
        background: CircleComponent(radius: 56, paint: Paint()..color = Palette.preto.withValues(alpha: 0.35)),
        margin: const EdgeInsets.only(left: 40, bottom: 40),
      );
      camera.viewport.add(joystick);
      player.joystick = joystick;

      // Botão para abrir o minigame quando o jogador encosta num objeto interagível
      _actionButton = WorldActionButton(onTap: () => player.nearbyObject?.interact());
      camera.viewport.add(_actionButton!);
    }

    add(camera);
  }

  // Primeira interação abre a caixa de texto; interagir de novo completa o texto ou fecha a caixa
  void _talk(String dialogue) {
    if (_dialog.isOpen) {
      _dialog.advance();
    } else {
      _dialog.show(dialogue);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // O jogador fica parado enquanto o diálogo está aberto
    _player.frozen = _dialog.isOpen;

    final button = _actionButton;
    if (button != null) {
      final nearby = _player.nearbyObject;
      button.isVisible = nearby != null && !_dialog.isOpen;
      if (nearby != null && button.labelComponent.text != nearby.actionLabel) {
        button.labelComponent.text = nearby.actionLabel;
      }
    }
  }
}
