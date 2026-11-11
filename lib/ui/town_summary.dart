import 'package:focus_town/domain/town.dart';

/// One sentence a screen reader says for the whole town.
String townSummary(TownState town) {
  final ruins = town.buildings
      .where((b) => b.status == BuildingStatus.ruin)
      .length;
  final buildings = town.buildings.length - ruins;
  final b = '$buildings ${buildings == 1 ? 'building' : 'buildings'}';
  final w = '${town.workers} ${town.workers == 1 ? 'worker' : 'workers'}';
  final r = ruins == 0 ? '' : ', and $ruins ${ruins == 1 ? 'ruin' : 'ruins'}';
  return 'Your town has $b and $w$r.';
}
