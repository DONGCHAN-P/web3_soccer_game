import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/player.dart';

void main() {
  group('Player', () {
    final sampleJson = {
      'id': 'abc-123',
      'name': 'Player_001',
      'position': 'ST',
      'nationality': 'Brazil',
      'rating': 72.5,
      'tier': 'R',
      'age': 25,
      'stats': {'슛 정확도': 75, '헤딩': 68},
    };

    test('fromJson parses correctly', () {
      final p = Player.fromJson(sampleJson);
      expect(p.id, 'abc-123');
      expect(p.position, 'ST');
      expect(p.rating, 72.5);
      expect(p.tier, 'R');
      expect(p.stats['슛 정확도'], 75);
    });

    test('toJson roundtrip', () {
      final p = Player.fromJson(sampleJson);
      final out = p.toJson();
      expect(out['position'], 'ST');
      expect(out['stats']['슛 정확도'], 75);
      expect(out['rating'], 72.5);
    });

    test('tierLabel returns correct label', () {
      final labels = {
        'N': 'Normal', 'S': 'Special', 'R': 'Rare',
        'W': 'World Class', 'G': 'GOAT',
      };
      for (final entry in labels.entries) {
        final p = Player.fromJson({...sampleJson, 'tier': entry.key});
        expect(p.tierLabel, entry.value);
      }
    });

    test('stats with numeric values from Supabase parses correctly', () {
      final json = {...sampleJson, 'stats': {'슛 정확도': 75.0, '헤딩': 68.0}};
      final p = Player.fromJson(json);
      expect(p.stats['슛 정확도'], 75);
      expect(p.stats['헤딩'], 68);
    });
  });
}
