import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/engine/match_engine.dart';
import 'package:soccer_manager/engine/player_generator.dart';
import 'package:soccer_manager/models/player.dart';

void main() {
  group('MatchEngine', () {
    final gen = PlayerGenerator();
    final engine = MatchEngine();

    List<Player> home() => gen.generateSquad(startId: 0);
    List<Player> away() => gen.generateSquad(startId: 100);

    test('simulate returns a result', () {
      final result = engine.simulate(
        homeTeam: 'Home FC', awayTeam: 'Away FC',
        homePlayers: home(), awayPlayers: away(),
      );
      expect(result, isNotNull);
    });

    test('scores are non-negative', () {
      final r = engine.simulate(
        homeTeam: 'Home FC', awayTeam: 'Away FC',
        homePlayers: home(), awayPlayers: away(),
      );
      expect(r.homeScore, greaterThanOrEqualTo(0));
      expect(r.awayScore, greaterThanOrEqualTo(0));
    });

    test('possession is between 0 and 100', () {
      final r = engine.simulate(
        homeTeam: 'Home FC', awayTeam: 'Away FC',
        homePlayers: home(), awayPlayers: away(),
      );
      expect(r.homePossession, greaterThanOrEqualTo(0));
      expect(r.homePossession, lessThanOrEqualTo(100));
    });

    test('events list is not empty', () {
      final r = engine.simulate(
        homeTeam: 'Home FC', awayTeam: 'Away FC',
        homePlayers: home(), awayPlayers: away(),
      );
      expect(r.events, isNotEmpty);
    });

    test('multiple runs produce different scores', () {
      final scores = <String>{};
      for (var i = 0; i < 5; i++) {
        final r = engine.simulate(
          homeTeam: 'A', awayTeam: 'B',
          homePlayers: home(), awayPlayers: away(),
        );
        scores.add('${r.homeScore}-${r.awayScore}');
      }
      expect(scores.length, greaterThanOrEqualTo(2));
    });

    test('event types are valid', () {
      final validTypes = {'goal', 'save', 'miss', 'tackle'};
      final r = engine.simulate(
        homeTeam: 'A', awayTeam: 'B',
        homePlayers: home(), awayPlayers: away(),
      );
      for (final ev in r.events) {
        expect(validTypes, contains(ev.type));
        expect(['home', 'away'], contains(ev.team));
      }
    });
  });
}
