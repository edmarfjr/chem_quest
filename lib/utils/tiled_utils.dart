import 'dart:ui';

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
