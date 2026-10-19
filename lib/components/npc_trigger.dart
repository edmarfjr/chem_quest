import 'package:flame/components.dart';
import 'interactive_object.dart';

/// NPC do mapa: ao interagir, mostra o diálogo dele na caixa de texto.
class NpcTrigger extends InteractiveObject {
  final String dialogue;
  final void Function(String dialogue) onTalk; // a cena do mapa mostra/avança a caixa de texto

  NpcTrigger({required super.position, required super.size, required this.dialogue, required this.onTalk});

  @override
  String get actionLabel => 'FALAR';

  @override
  void interact() => onTalk(dialogue);
}
