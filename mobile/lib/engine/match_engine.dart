import 'dart:math';
import '../models/player.dart';
import '../models/match_result.dart';

class _Strength {
  final double goalkeeping;
  final double defense;
  final double midfield;
  final double attack;
  final double shooting;
  const _Strength({
    required this.goalkeeping,
    required this.defense,
    required this.midfield,
    required this.attack,
    required this.shooting,
  });
}

class MatchEngine {
  static const _phases = 30;
  final Random _rng;

  MatchEngine({Random? random}) : _rng = random ?? Random();

  double _sigmoid(double d, double scale) =>
      0.2 + 1 / (1 + exp(-d * scale)) * 0.6;

  double _statToProb(double stat, double w, double b, double lo, double hi) =>
      (stat * w + b).clamp(lo, hi);

  double _avgStats(List<Player> players, List<String> attrs) {
    if (players.isEmpty) return 50.0;
    double total = 0;
    int count = 0;
    for (final p in players) {
      for (final a in attrs) {
        total += p.stats[a] ?? 50;
        count++;
      }
    }
    return count > 0 ? total / count : 50.0;
  }

  _Strength _getStrength(List<Player> players) {
    final gk  = players.where((p) => p.position == 'GK').toList();
    final def = players.where((p) => ['CB', 'RB', 'LB'].contains(p.position)).toList();
    final mid = players.where((p) => ['CDM', 'CM', 'CAM'].contains(p.position)).toList();
    final atk = players.where((p) => ['RW', 'LW', 'ST'].contains(p.position)).toList();
    final sht = [...atk, ...mid];

    return _Strength(
      goalkeeping: _avgStats(gk,  ['반사 신경', '다이빙', '핸들링', '1대1 방어']),
      defense:     _avgStats(def, ['태클', '인터셉트', '헤딩', '힘', '위치 선정']),
      midfield:    _avgStats(mid, ['패스', '경기 지능', '위치 선정', '퍼스트 터치', '스태미너']),
      attack:      _avgStats(atk, ['드리블', '속도', '공간 침투', '민첩성', '가속력']),
      shooting:    _avgStats(sht, ['슛 정확도', '공격 성향']),
    );
  }

  MatchResult simulate({
    required String homeTeam,
    required String awayTeam,
    required List<Player> homePlayers,
    required List<Player> awayPlayers,
  }) {
    final hs = _getStrength(homePlayers);
    final as_ = _getStrength(awayPlayers);
    final events = <MatchEvent>[];
    int homeScore = 0, awayScore = 0;
    int homeShots = 0, awayShots = 0;
    int homePossCount = 0;

    for (int ph = 0; ph < _phases; ph++) {
      final minute = ph * 3 + 1 + _rng.nextInt(3);
      final homePossProb = _sigmoid(hs.midfield - as_.midfield, 0.06);
      final homeHasBall = _rng.nextDouble() < homePossProb;
      if (homeHasBall) homePossCount++;

      final atkStr  = homeHasBall ? hs : as_;
      final defStr  = homeHasBall ? as_ : hs;
      final side    = homeHasBall ? 'home' : 'away';
      final atkName = homeHasBall ? homeTeam : awayTeam;
      final defName = homeHasBall ? awayTeam : homeTeam;

      final ap = atkStr.attack * 0.65 + atkStr.midfield * 0.35;
      final dp = defStr.defense * 0.75 + defStr.midfield * 0.25;
      final chanceProb = _sigmoid(ap - dp, 0.05).clamp(0.0, 0.72);

      if (_rng.nextDouble() > chanceProb) {
        if (_rng.nextDouble() < 0.3) {
          events.add(MatchEvent(
            minute: minute, type: 'tackle', team: side == 'home' ? 'away' : 'home',
            description: '🛡️ $defName 수비 차단',
          ));
        }
        continue;
      }

      if (homeHasBall) homeShots++; else awayShots++;

      final shootProb = _statToProb(atkStr.shooting, 0.005, 0.25, 0.30, 0.70);
      if (_rng.nextDouble() > shootProb) {
        events.add(MatchEvent(
          minute: minute, type: 'miss', team: side,
          description: '💨 $atkName 슈팅 빗나감',
        ));
        continue;
      }

      final gkProb = _statToProb(defStr.goalkeeping, 0.007, 0.20, 0.50, 0.80);
      if (_rng.nextDouble() > gkProb) {
        if (homeHasBall) homeScore++; else awayScore++;
        events.add(MatchEvent(
          minute: minute, type: 'goal', team: side,
          description: '⚽ $atkName 골! ($homeScore-$awayScore)',
        ));
      } else {
        events.add(MatchEvent(
          minute: minute, type: 'save', team: side,
          description: '🧤 $defName 골키퍼 선방!',
        ));
      }
    }

    return MatchResult(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeScore: homeScore,
      awayScore: awayScore,
      homePossession: double.parse(
        (homePossCount / _phases * 100).toStringAsFixed(1),
      ),
      homeShots: homeShots,
      awayShots: awayShots,
      events: events,
    );
  }
}
