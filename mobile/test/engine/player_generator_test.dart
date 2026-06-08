import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/engine/player_generator.dart';

void main() {
  group('PlayerGenerator', () {
    final gen = PlayerGenerator();

    test('generatePlayer returns valid player', () {
      final p = gen.generatePlayer(id: 'test-1', position: 'ST');
      expect(p.position, 'ST');
      expect(p.rating, greaterThan(0));
      expect(p.rating, lessThan(100));
      expect(['N', 'S', 'R', 'W', 'G'], contains(p.tier));
      expect(p.stats, isNotEmpty);
    });

    test('stats are in valid range', () {
      final p = gen.generatePlayer(id: 'test-2', position: 'CM');
      for (final v in p.stats.values) {
        expect(v, greaterThanOrEqualTo(1));
        expect(v, lessThanOrEqualTo(99));
      }
    });

    test('generateSquad returns 11 players', () {
      final squad = gen.generateSquad(startId: 0);
      expect(squad.length, 11);
    });

    test('generateSquad has exactly one GK', () {
      final squad = gen.generateSquad(startId: 0);
      expect(squad.where((p) => p.position == 'GK').length, 1);
    });

    test('tier thresholds are correct', () {
      expect(PlayerGenerator.getTier(59.9), 'N');
      expect(PlayerGenerator.getTier(60.0), 'S');
      expect(PlayerGenerator.getTier(70.0), 'R');
      expect(PlayerGenerator.getTier(80.0), 'W');
      expect(PlayerGenerator.getTier(90.0), 'G');
    });

    test('generatePlayer without explicit position returns valid position', () {
      final validPositions = {'GK', 'CB', 'RB', 'LB', 'CDM', 'CM', 'CAM', 'RW', 'LW', 'ST'};
      final p = gen.generatePlayer(id: 'test-3');
      expect(validPositions, contains(p.position));
    });
  });
}
