import 'dart:math';
import '../models/player.dart';

const positionMainAttrs = <String, List<String>>{
  'GK':  ['반사 신경', '다이빙', '핸들링', '1대1 방어'],
  'CB':  ['태클', '헤딩', '인터셉트', '힘'],
  'RB':  ['속도', '태클', '크로스', '스태미너'],
  'LB':  ['속도', '태클', '크로스', '스태미너'],
  'CDM': ['태클', '인터셉트', '경기 지능', '위치 선정'],
  'CM':  ['패스', '경기 지능', '퍼스트 터치', '위치 선정'],
  'CAM': ['패스', '드리블', '공간 침투', '공격 성향'],
  'RW':  ['속도', '드리블', '크로스', '민첩성'],
  'LW':  ['속도', '드리블', '크로스', '민첩성'],
  'ST':  ['슛 정확도', '헤딩', '공간 침투', '균형 감각'],
};

const _positionSecAttrs = <String, List<String>>{
  'GK':  ['킥 능력', '반응 속도', '펀칭'],
  'CB':  ['침착함', '균형감각', '패스'],
  'RB':  ['인터셉트', '드리블', '민첩성'],
  'LB':  ['인터셉트', '드리블', '민첩성'],
  'CDM': ['팀워크', '수비 성향', '스태미너'],
  'CM':  ['킥 능력', '공간 침투', '체력 회복력'],
  'CAM': ['슛 정확도', '크로스', '위치 선정'],
  'RW':  ['슛 정확도', '퍼스트 터치', '가속력'],
  'LW':  ['슛 정확도', '퍼스트 터치', '가속력'],
  'ST':  ['가속도', '공격 성향', '위치 선정'],
};

const _allAttrs = [
  '1대1 방어', '가속력', '가속도', '경기 지능', '공간 침투', '공격 성향',
  '균형 감각', '균형감각', '다이빙', '드리블', '리더십', '민첩성',
  '반사 신경', '반응 속도', '수비 성향', '스태미너', '슛 정확도',
  '위치 선정', '인터셉트', '체력 회복력', '침착함', '크로스', '킥 능력',
  '태클', '팀워크', '패스', '펀칭', '퍼스트 터치', '핸들링', '헤딩',
  '힘', '속도', '점프력',
];

const _formationSlots = [
  'GK', 'CB', 'CB', 'RB', 'LB', 'CDM', 'CM', 'CM', 'RW', 'LW', 'ST',
];

const _fifaNations = [
  'Argentina', 'France', 'Brazil', 'England', 'Belgium', 'Croatia',
  'Netherlands', 'Italy', 'Portugal', 'Spain', 'USA', 'Mexico',
  'Germany', 'Switzerland', 'Morocco', 'Uruguay', 'Denmark', 'Colombia',
  'Senegal', 'Japan', 'Sweden', 'Poland', 'Iran', 'Serbia', 'South Korea',
  'Ukraine', 'Australia', 'Chile', 'Austria', 'Tunisia',
];

const _rawPositionDist = <String, double>{
  'GK': 0.10, 'CB': 0.20, 'RB': 0.10, 'LB': 0.10,
  'CDM': 0.10, 'CM': 0.15, 'CAM': 0.08,
  'RW': 0.07, 'LW': 0.07, 'ST': 0.08,
};

class PlayerGenerator {
  final Random _rng;

  PlayerGenerator({Random? random}) : _rng = random ?? Random();

  double _normal(double mean, double std) {
    double u, v;
    do { u = _rng.nextDouble(); } while (u == 0);
    do { v = _rng.nextDouble(); } while (v == 0);
    return mean + std * sqrt(-2 * log(u)) * cos(2 * pi * v);
  }

  int _clamp(double v, int lo, int hi) => v.round().clamp(lo, hi);

  static String getTier(double rating) {
    if (rating < 60) return 'N';
    if (rating < 70) return 'S';
    if (rating < 80) return 'R';
    if (rating < 90) return 'W';
    return 'G';
  }

  String _assignNationality(double rating) {
    final idx = (rating / 100 * _fifaNations.length).floor().clamp(0, _fifaNations.length - 1);
    return _fifaNations[_rng.nextInt(idx + 1)];
  }

  Player generatePlayer({required String id, String? position}) {
    final pos = position ?? _randomPosition();
    final mainAttrs = positionMainAttrs[pos] ?? [];
    final secAttrs = _positionSecAttrs[pos] ?? [];

    final stats = <String, int>{};
    final mainVals = <double>[];
    final secVals = <double>[];

    for (final attr in _allAttrs) {
      double v;
      if (mainAttrs.contains(attr)) {
        v = _normal(70, 30).clamp(38, 99);
        mainVals.add(v);
      } else if (secAttrs.contains(attr)) {
        v = _normal(60, 20).clamp(35, 90);
        secVals.add(v);
      } else {
        v = _normal(35, 20);
      }
      stats[attr] = _clamp(v, 1, 99);
    }

    final avgMain = mainVals.isEmpty
        ? 0.0
        : mainVals.reduce((a, b) => a + b) / mainVals.length;
    final avgSec = secVals.isEmpty
        ? 0.0
        : secVals.reduce((a, b) => a + b) / secVals.length;
    final rating = double.parse((avgMain * 0.7 + avgSec * 0.3).toStringAsFixed(1));

    return Player(
      id: id,
      name: 'Player_${id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')}',
      position: pos,
      nationality: _assignNationality(rating),
      rating: rating,
      tier: getTier(rating),
      age: 18 + _rng.nextInt(20),
      stats: stats,
    );
  }

  List<Player> generateSquad({required int startId}) {
    return List.generate(
      _formationSlots.length,
      (i) => generatePlayer(
        id: 'local-${startId + i}',
        position: _formationSlots[i],
      ),
    );
  }

  String _randomPosition() {
    final total = _rawPositionDist.values.reduce((a, b) => a + b);
    double r = _rng.nextDouble() * total;
    for (final entry in _rawPositionDist.entries) {
      r -= entry.value;
      if (r <= 0) return entry.key;
    }
    return 'CM';
  }
}
