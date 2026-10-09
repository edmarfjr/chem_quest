import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_tiled/flame_tiled.dart';

/// Desliga a suavização dos tiles para o pixel art ficar nítido (inclusive quando o mapa é ampliado).
void makeTiledPixelPerfect(TiledComponent map) {
  try {
    for (final layer in map.tileMap.renderableLayers) {
      final dynamic dynLayer = layer;

      // Tenta na versão atual do pacote (propriedade 'batch')
      try {
        dynLayer.batch?.paint?.filterQuality = FilterQuality.none;
        dynLayer.batch?.paint?.isAntiAlias = false;
      } catch (_) {}

      // Tenta nas versões antigas do pacote (propriedade 'batches')
      try {
        if (dynLayer.batches != null) {
          for (final batch in dynLayer.batches.values) {
            batch.paint?.filterQuality = FilterQuality.none;
            batch.paint?.isAntiAlias = false;
          }
        }
      } catch (_) {}
    }
  } catch (_) {}
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
    final recorder = PictureRecorder();
    map.tileMap.render(Canvas(recorder));
    final image = await recorder.endRecording().toImageSafe(map.size.x.toInt(), map.size.y.toInt());
    return TiledBackground._(image, map.size.clone());
  }

  /// Amplia o mapa para cobrir [area] inteira (mantendo a proporção) e o centraliza nela.
  void fit(Rect area) {
    final scale = max(area.width / mapSize.x, area.height / mapSize.y);
    size = mapSize * scale;
    position = Vector2(area.center.dx, area.center.dy) - size / 2;
  }
}
