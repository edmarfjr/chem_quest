import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// Desenha o mapa Tiled inteiro, uma vez e em tamanho original, numa imagem.
///
/// Ampliar tile por tile (zoom da câmera ou escala da cena) deixa frestas entre eles por causa do
/// arredondamento; ampliar uma imagem só não deixa.
Future<Image> renderTiledMapToImage(TiledComponent map) {
  final recorder = PictureRecorder();
  map.tileMap.render(Canvas(recorder));
  return recorder.endRecording().toImageSafe(map.size.x.toInt(), map.size.y.toInt());
}

/// O mapa Tiled como um sprite único (sem frestas entre os tiles e com pixels nítidos).
Future<SpriteComponent> tiledMapAsSprite(TiledComponent map) async {
  final sprite = SpriteComponent(sprite: Sprite(await renderTiledMapToImage(map)), size: map.size.clone());
  sprite.paint.filterQuality = FilterQuality.none;
  sprite.paint.isAntiAlias = false;
  return sprite;
}

/// Fundo de cena a partir de um mapa Tiled (.tmx).
///
/// O mapa é desenhado uma vez em tamanho original e depois ampliado como uma imagem só:
/// ampliar tile por tile com escala fracionada deixa frestas entre eles.
class TiledBackground extends SpriteComponent {
  final Vector2 mapSize;

  TiledBackground._(Image image, this.mapSize) : super(sprite: Sprite(image), priority: -1) {
    paint.filterQuality = FilterQuality.none;
    paint.isAntiAlias = false;
  }

  static Future<TiledBackground> load(String tmx, {double tileSize = 16}) async {
    final map = await TiledComponent.load(tmx, Vector2.all(tileSize), useAtlas: false);
    return TiledBackground._(await renderTiledMapToImage(map), map.size.clone());
  }

  /// Amplia o mapa para cobrir [area] inteira (mantendo a proporção) e o centraliza nela.
  void fit(Rect area) {
    final scale = max(area.width / mapSize.x, area.height / mapSize.y);
    size = mapSize * scale;
    position = Vector2(area.center.dx, area.center.dy) - size / 2;
  }
}
