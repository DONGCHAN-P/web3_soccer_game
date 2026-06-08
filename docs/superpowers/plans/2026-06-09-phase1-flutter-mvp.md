# Phase 1: Flutter MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter 모바일 앱 MVP를 구축한다 — Supabase 인증, 팀/선수 데이터 영속화, Dart 경기 엔진, 핵심 화면 5개.

**Architecture:** Flutter 앱이 Supabase(Auth + PostgreSQL)에 직접 연결된다. 경기 시뮬레이션은 Python 엔진을 Dart로 이식해 앱 내에서 실행하고, 결과만 Supabase에 저장한다. 서버 없이 동작하는 완전한 오프라인-퍼스트 앱이다.

**Tech Stack:** Flutter 3.x, Dart, supabase_flutter ^2.5.0, flutter_dotenv ^5.1.0

---

## 목표 파일 구조

```
web3_soccer_game/
├── mobile/                          ← Flutter 앱
│   ├── lib/
│   │   ├── main.dart                - Supabase 초기화, 앱 진입점
│   │   ├── app.dart                 - MaterialApp + 라우트 정의
│   │   ├── models/
│   │   │   ├── player.dart          - Player 데이터 클래스, fromJson/toJson
│   │   │   └── match_result.dart    - MatchResult, MatchEvent 데이터 클래스
│   │   ├── engine/
│   │   │   ├── player_generator.dart - Python engine/player.py Dart 이식
│   │   │   └── match_engine.dart     - Python engine/match_engine.py Dart 이식
│   │   ├── services/
│   │   │   ├── auth_service.dart    - Supabase Auth 래퍼
│   │   │   ├── team_service.dart    - 팀/선수 CRUD (Supabase)
│   │   │   └── match_service.dart   - 경기 결과 저장/조회 (Supabase)
│   │   └── screens/
│   │       ├── auth_screen.dart     - 로그인 + 회원가입
│   │       ├── team_setup_screen.dart - 최초 팀 이름 입력 + 스쿼드 생성
│   │       ├── home_screen.dart     - 메인 허브 (팀 현황, 최근 결과)
│   │       ├── squad_screen.dart    - 선발 11명 관리
│   │       └── match_screen.dart    - 경기 이벤트 피드 + 결과
│   ├── test/
│   │   ├── engine/
│   │   │   ├── player_generator_test.dart
│   │   │   └── match_engine_test.dart
│   │   └── models/
│   │       └── player_test.dart
│   ├── .env                         - SUPABASE_URL, SUPABASE_ANON_KEY
│   └── pubspec.yaml
└── supabase/
    └── migrations/
        └── 001_initial_schema.sql
```

---

## Task 1: Supabase 프로젝트 설정

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`

> 이 태스크는 수동 설정 단계를 포함한다.

- [ ] **Step 1: Supabase 프로젝트 생성 (수동)**

  1. https://supabase.com/dashboard 접속 → "New project"
  2. 프로젝트 이름: `soccer-manager`, 비밀번호 설정, 리전: Northeast Asia (Tokyo)
  3. 생성 완료 후 Settings → API 에서 다음 값 복사:
     - `Project URL` (예: `https://xxxx.supabase.co`)
     - `anon public` key

- [ ] **Step 2: 스키마 SQL 작성**

`supabase/migrations/001_initial_schema.sql`:

```sql
-- 팀 테이블
create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users not null,
  name        text not null,
  created_at  timestamptz default now()
);

-- 선수 테이블 (stats를 JSONB로 단순화)
create table public.players (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid references public.teams on delete cascade not null,
  name        text not null,
  position    text not null,
  nationality text not null,
  rating      numeric(4,1) not null,
  tier        text not null,
  age         integer not null default 25,
  stats       jsonb not null default '{}'
);

-- 경기 기록
create table public.matches (
  id               uuid primary key default gen_random_uuid(),
  team_id          uuid references public.teams on delete cascade not null,
  away_team_name   text not null,
  home_score       integer not null,
  away_score       integer not null,
  home_possession  numeric(4,1),
  played_at        timestamptz default now()
);

-- 경기 이벤트
create table public.match_events (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid references public.matches on delete cascade not null,
  minute      integer not null,
  event_type  text not null,
  description text not null
);

-- 스쿼드 슬롯 (팀당 1개)
create table public.squad_slots (
  id        uuid primary key default gen_random_uuid(),
  team_id   uuid references public.teams on delete cascade not null unique,
  formation text not null default '4-3-3',
  slots     jsonb not null default '[]'
);

-- RLS 활성화
alter table public.teams        enable row level security;
alter table public.players      enable row level security;
alter table public.matches      enable row level security;
alter table public.match_events enable row level security;
alter table public.squad_slots  enable row level security;

-- RLS 정책: 본인 데이터만 접근
create policy "teams_own" on public.teams
  for all using (auth.uid() = user_id);

create policy "players_own" on public.players
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );

create policy "matches_own" on public.matches
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );

create policy "match_events_own" on public.match_events
  for all using (
    match_id in (
      select id from public.matches
      where team_id in (select id from public.teams where user_id = auth.uid())
    )
  );

create policy "squad_slots_own" on public.squad_slots
  for all using (
    team_id in (select id from public.teams where user_id = auth.uid())
  );
```

- [ ] **Step 3: Supabase SQL 에디터에서 실행 (수동)**

  1. Supabase 대시보드 → SQL Editor → "New query"
  2. 위 SQL 전체 붙여넣기 → Run
  3. Table Editor에서 5개 테이블 생성 확인

- [ ] **Step 4: Commit**

```bash
git add supabase/
git commit -m "feat: add Supabase schema migration"
```

---

## Task 2: Flutter 프로젝트 생성

**Files:**
- Create: `mobile/` (Flutter 프로젝트)

- [ ] **Step 1: Flutter 버전 확인**

```bash
flutter --version
```

Expected: Flutter 3.x 이상. 없으면 https://flutter.dev/docs/get-started/install 에서 설치.

- [ ] **Step 2: Flutter 프로젝트 생성**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
flutter create mobile --org com.dongchan --project-name soccer_manager
```

Expected: `mobile/` 폴더 생성됨

- [ ] **Step 3: 기본 테스트 실행**

```bash
cd mobile
flutter test
```

Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
cd ..
git add mobile/
git commit -m "feat: create Flutter project"
```

---

## Task 3: 의존성 설정 + Supabase 초기화

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/.env`
- Modify: `mobile/lib/main.dart`
- Create: `mobile/lib/app.dart`

- [ ] **Step 1: pubspec.yaml 의존성 추가**

`mobile/pubspec.yaml`의 `dependencies:` 섹션을 다음으로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  flutter_dotenv: ^5.1.0
```

`flutter:` 섹션에 assets 추가:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

- [ ] **Step 2: 패키지 설치**

```bash
cd mobile
flutter pub get
```

Expected: 의존성 설치 완료

- [ ] **Step 3: .env 파일 생성**

`mobile/.env`:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

Task 1 Step 1에서 복사한 실제 값으로 교체.

- [ ] **Step 4: .gitignore에 .env 추가**

`mobile/.gitignore` 맨 아래에 추가:

```
.env
```

- [ ] **Step 5: main.dart 작성**

`mobile/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const SoccerManagerApp());
}

final supabase = Supabase.instance.client;
```

- [ ] **Step 6: app.dart 작성**

`mobile/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'main.dart';

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soccer Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4FC3F7),
          surface: const Color(0xFF0C0F1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C0F1A),
        useMaterial3: true,
      ),
      home: supabase.auth.currentSession != null
          ? const HomeScreen()
          : const AuthScreen(),
    );
  }
}
```

- [ ] **Step 7: 앱 빌드 확인**

```bash
cd mobile
flutter run --debug
```

Expected: 앱이 실행되고 화면이 표시됨 (AuthScreen)

- [ ] **Step 8: Commit**

```bash
cd ..
git add mobile/pubspec.yaml mobile/lib/main.dart mobile/lib/app.dart mobile/.gitignore
git commit -m "feat: add Supabase init and app entry point"
```

---

## Task 4: Player 모델 + MatchResult 모델

**Files:**
- Create: `mobile/lib/models/player.dart`
- Create: `mobile/lib/models/match_result.dart`
- Create: `mobile/test/models/player_test.dart`

- [ ] **Step 1: 테스트 먼저 작성**

`mobile/test/models/player_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/player.dart';

void main() {
  group('Player', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'abc-123',
        'name': 'Player_001',
        'position': 'ST',
        'nationality': 'Brazil',
        'rating': 72.5,
        'tier': 'R',
        'age': 25,
        'stats': {'슛 정확도': 75, '헤딩': 68},
      };
      final p = Player.fromJson(json);
      expect(p.id, 'abc-123');
      expect(p.position, 'ST');
      expect(p.rating, 72.5);
      expect(p.tier, 'R');
      expect(p.stats['슛 정확도'], 75);
    });

    test('toJson roundtrip', () {
      final json = {
        'id': 'abc-123',
        'name': 'Player_001',
        'position': 'GK',
        'nationality': 'France',
        'rating': 65.0,
        'tier': 'S',
        'age': 28,
        'stats': {'반사 신경': 70},
      };
      final p = Player.fromJson(json);
      final out = p.toJson();
      expect(out['position'], 'GK');
      expect(out['stats']['반사 신경'], 70);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd mobile
flutter test test/models/player_test.dart
```

Expected: FAIL (Player class not defined)

- [ ] **Step 3: player.dart 구현**

`mobile/lib/models/player.dart`:

```dart
class Player {
  final String id;
  final String name;
  final String position;
  final String nationality;
  final double rating;
  final String tier;
  final int age;
  final Map<String, int> stats;

  const Player({
    required this.id,
    required this.name,
    required this.position,
    required this.nationality,
    required this.rating,
    required this.tier,
    required this.age,
    required this.stats,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        position: json['position'] as String,
        nationality: json['nationality'] as String,
        rating: (json['rating'] as num).toDouble(),
        tier: json['tier'] as String,
        age: (json['age'] as num).toInt(),
        stats: Map<String, int>.from(
          (json['stats'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'nationality': nationality,
        'rating': rating,
        'tier': tier,
        'age': age,
        'stats': stats,
      };

  String get tierLabel => const {
        'N': 'Normal', 'S': 'Special', 'R': 'Rare',
        'W': 'World Class', 'G': 'GOAT',
      }[tier] ?? tier;
}
```

- [ ] **Step 4: match_result.dart 구현**

`mobile/lib/models/match_result.dart`:

```dart
class MatchEvent {
  final int minute;
  final String type;   // goal | save | miss | tackle
  final String team;   // home | away
  final String description;

  const MatchEvent({
    required this.minute,
    required this.type,
    required this.team,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'type': type,
        'team': team,
        'description': description,
      };
}

class MatchResult {
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final double homePossession;
  final int homeShots;
  final int awayShots;
  final List<MatchEvent> events;

  const MatchResult({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.homePossession,
    required this.homeShots,
    required this.awayShots,
    required this.events,
  });

  String get scoreStr => '$homeScore : $awayScore';
}
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
flutter test test/models/player_test.dart
```

Expected: All tests passed

- [ ] **Step 6: Commit**

```bash
cd ..
git add mobile/lib/models/ mobile/test/models/
git commit -m "feat: add Player and MatchResult models"
```

---

## Task 5: Dart 선수 생성 엔진

**Files:**
- Create: `mobile/lib/engine/player_generator.dart`
- Create: `mobile/test/engine/player_generator_test.dart`

- [ ] **Step 1: 테스트 먼저 작성**

`mobile/test/engine/player_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/engine/player_generator.dart';
import 'package:soccer_manager/models/player.dart';

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
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd mobile
flutter test test/engine/player_generator_test.dart
```

Expected: FAIL (PlayerGenerator not defined)

- [ ] **Step 3: player_generator.dart 구현**

`mobile/lib/engine/player_generator.dart`:

```dart
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

const positionSecAttrs = <String, List<String>>{
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
  'GK', 'CB', 'CB', 'RB', 'LB', 'CDM', 'CM', 'CM', 'RW', 'LW', 'ST'
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

  // 정규분포 (Box-Muller)
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
    final secAttrs = positionSecAttrs[pos] ?? [];

    final stats = <String, int>{};
    final mainVals = <double>[];
    final secVals = <double>[];

    for (final attr in _allAttrs) {
      double v;
      if (mainAttrs.contains(attr)) {
        v = _normal(70, 30);
        mainVals.add(v.clamp(38, 99));
      } else if (secAttrs.contains(attr)) {
        v = _normal(60, 20);
        secVals.add(v.clamp(35, 90));
      } else {
        v = _normal(35, 20);
      }
      stats[attr] = _clamp(v, 1, 99);
    }

    final avgMain = mainVals.isEmpty ? 0.0 : mainVals.reduce((a, b) => a + b) / mainVals.length;
    final avgSec  = secVals.isEmpty  ? 0.0 : secVals.reduce((a, b) => a + b) / secVals.length;
    final rating  = double.parse((avgMain * 0.7 + avgSec * 0.3).toStringAsFixed(1));

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
      (i) => generatePlayer(id: 'local-${startId + i}', position: _formationSlots[i]),
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
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/engine/player_generator_test.dart
```

Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
cd ..
git add mobile/lib/engine/player_generator.dart mobile/test/engine/player_generator_test.dart
git commit -m "feat: add Dart player generator engine"
```

---

## Task 6: Dart 경기 시뮬레이션 엔진

**Files:**
- Create: `mobile/lib/engine/match_engine.dart`
- Create: `mobile/test/engine/match_engine_test.dart`

- [ ] **Step 1: 테스트 먼저 작성**

`mobile/test/engine/match_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/engine/match_engine.dart';
import 'package:soccer_manager/engine/player_generator.dart';

void main() {
  group('MatchEngine', () {
    final gen = PlayerGenerator();
    final engine = MatchEngine();

    List<dynamic> makeSquad(int start) => gen.generateSquad(startId: start);

    test('simulate returns result', () {
      final result = engine.simulate(
        homeTeam: 'Home FC',
        awayTeam: 'Away FC',
        homePlayers: makeSquad(0),
        awayPlayers: makeSquad(100),
      );
      expect(result, isNotNull);
    });

    test('scores are non-negative', () {
      final result = engine.simulate(
        homeTeam: 'Home FC',
        awayTeam: 'Away FC',
        homePlayers: makeSquad(0),
        awayPlayers: makeSquad(100),
      );
      expect(result.homeScore, greaterThanOrEqualTo(0));
      expect(result.awayScore, greaterThanOrEqualTo(0));
    });

    test('possession is between 0 and 100', () {
      final result = engine.simulate(
        homeTeam: 'Home FC',
        awayTeam: 'Away FC',
        homePlayers: makeSquad(0),
        awayPlayers: makeSquad(100),
      );
      expect(result.homePossession, greaterThanOrEqualTo(0));
      expect(result.homePossession, lessThanOrEqualTo(100));
    });

    test('events list is not empty', () {
      final result = engine.simulate(
        homeTeam: 'Home FC',
        awayTeam: 'Away FC',
        homePlayers: makeSquad(0),
        awayPlayers: makeSquad(100),
      );
      expect(result.events, isNotEmpty);
    });

    test('multiple runs produce different results', () {
      final scores = <String>{};
      for (var i = 0; i < 5; i++) {
        final r = engine.simulate(
          homeTeam: 'A', awayTeam: 'B',
          homePlayers: makeSquad(0), awayPlayers: makeSquad(100),
        );
        scores.add('${r.homeScore}-${r.awayScore}');
      }
      expect(scores.length, greaterThanOrEqualTo(2));
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd mobile
flutter test test/engine/match_engine_test.dart
```

Expected: FAIL (MatchEngine not defined)

- [ ] **Step 3: match_engine.dart 구현**

`mobile/lib/engine/match_engine.dart`:

```dart
import 'dart:math';
import '../models/player.dart';
import '../models/match_result.dart';
import 'player_generator.dart';

class _TeamStrength {
  final double goalkeeping;
  final double defense;
  final double midfield;
  final double attack;
  final double shooting;
  const _TeamStrength({
    required this.goalkeeping,
    required this.defense,
    required this.midfield,
    required this.attack,
    required this.shooting,
  });
}

class MatchEngine {
  static const _phases = 30;
  static const _possScale = 0.06;
  static const _chanceScale = 0.05;
  static const _maxChance = 0.72;
  static const _shootWeight = 0.005;
  static const _shootBase = 0.25;
  static const _gkWeight = 0.007;
  static const _gkBase = 0.20;

  final Random _rng;
  MatchEngine({Random? random}) : _rng = random ?? Random();

  double _sigmoid(double d, double s) => 0.2 + 1 / (1 + exp(-d * s)) * 0.6;

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

  _TeamStrength _getStrength(List<Player> players) {
    final gk  = players.where((p) => p.position == 'GK').toList();
    final def = players.where((p) => ['CB','RB','LB'].contains(p.position)).toList();
    final mid = players.where((p) => ['CDM','CM','CAM'].contains(p.position)).toList();
    final atk = players.where((p) => ['RW','LW','ST'].contains(p.position)).toList();
    final sht = [...atk, ...mid];

    return _TeamStrength(
      goalkeeping: _avgStats(gk,  ['반사 신경','다이빙','핸들링','1대1 방어']),
      defense:     _avgStats(def, ['태클','인터셉트','헤딩','힘','위치 선정']),
      midfield:    _avgStats(mid, ['패스','경기 지능','위치 선정','퍼스트 터치','스태미너']),
      attack:      _avgStats(atk, ['드리블','속도','공간 침투','민첩성','가속력']),
      shooting:    _avgStats(sht, ['슛 정확도','공격 성향']),
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
      final homePossProb = _sigmoid(hs.midfield - as_.midfield, _possScale);
      final homeHasBall = _rng.nextDouble() < homePossProb;

      if (homeHasBall) homePossCount++;

      final atkStr = homeHasBall ? hs : as_;
      final defStr = homeHasBall ? as_ : hs;
      final side   = homeHasBall ? 'home' : 'away';
      final atkName = homeHasBall ? homeTeam : awayTeam;
      final defName = homeHasBall ? awayTeam : homeTeam;

      final ap = atkStr.attack * 0.65 + atkStr.midfield * 0.35;
      final dp = defStr.defense * 0.75 + defStr.midfield * 0.25;
      final chanceProb = _sigmoid(ap - dp, _chanceScale).clamp(0, _maxChance);

      if (_rng.nextDouble() > chanceProb) {
        if (_rng.nextDouble() < 0.3) {
          events.add(MatchEvent(
            minute: minute, type: 'tackle', team: side,
            description: '🛡️ $defName 수비 차단',
          ));
        }
        continue;
      }

      if (homeHasBall) homeShots++; else awayShots++;

      final shootProb = _statToProb(atkStr.shooting, _shootWeight, _shootBase, 0.30, 0.70);
      if (_rng.nextDouble() > shootProb) {
        events.add(MatchEvent(
          minute: minute, type: 'miss', team: side,
          description: '💨 $atkName 슈팅 빗나감',
        ));
        continue;
      }

      final gkProb = _statToProb(defStr.goalkeeping, _gkWeight, _gkBase, 0.50, 0.80);
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
      homePossession: double.parse((homePossCount / _phases * 100).toStringAsFixed(1)),
      homeShots: homeShots,
      awayShots: awayShots,
      events: events,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/engine/match_engine_test.dart
```

Expected: All tests passed

- [ ] **Step 5: 전체 테스트 실행**

```bash
flutter test
```

Expected: All tests passed

- [ ] **Step 6: Commit**

```bash
cd ..
git add mobile/lib/engine/match_engine.dart mobile/test/engine/match_engine_test.dart
git commit -m "feat: add Dart match simulation engine"
```

---

## Task 7: Auth 서비스 + Auth 화면

**Files:**
- Create: `mobile/lib/services/auth_service.dart`
- Create: `mobile/lib/screens/auth_screen.dart`

- [ ] **Step 1: auth_service.dart 작성**

`mobile/lib/services/auth_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class AuthService {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      supabase.auth.signUp(email: email, password: password);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      supabase.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => supabase.auth.signOut();

  String? get currentUserId => supabase.auth.currentUser?.id;
}
```

- [ ] **Step 2: auth_screen.dart 작성**

`mobile/lib/screens/auth_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'home_screen.dart';
import 'team_setup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _auth      = AuthService();
  bool _isLogin    = true;
  bool _loading    = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await _auth.signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        await _auth.signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      }
      if (!mounted) return;
      final hasTeam = await _checkHasTeam();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => hasTeam ? const HomeScreen() : const TeamSetupScreen()),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _checkHasTeam() async {
    final res = await supabase
        .from('teams')
        .select('id')
        .eq('user_id', _auth.currentUserId!)
        .maybeSingle();
    return res != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚽ Soccer Manager',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7))),
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(_isLogin ? '로그인' : '회원가입'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
cd mobile
flutter run --debug
```

Expected: 로그인 화면 표시. 이메일/비밀번호 입력 가능.

- [ ] **Step 4: Commit**

```bash
cd ..
git add mobile/lib/services/auth_service.dart mobile/lib/screens/auth_screen.dart
git commit -m "feat: add auth service and login/signup screen"
```

---

## Task 8: 팀 서비스 + 팀 생성 화면

**Files:**
- Create: `mobile/lib/services/team_service.dart`
- Create: `mobile/lib/screens/team_setup_screen.dart`

- [ ] **Step 1: team_service.dart 작성**

`mobile/lib/services/team_service.dart`:

```dart
import '../main.dart';
import '../models/player.dart';

class TeamService {
  Future<Map<String, dynamic>?> getTeam(String userId) =>
      supabase.from('teams').select().eq('user_id', userId).maybeSingle();

  Future<Map<String, dynamic>> createTeam({
    required String userId,
    required String name,
  }) async {
    final team = await supabase
        .from('teams')
        .insert({'user_id': userId, 'name': name})
        .select()
        .single();
    return team;
  }

  Future<void> savePlayers(String teamId, List<Player> players) async {
    final rows = players.map((p) => {
      'team_id': teamId,
      'name': p.name,
      'position': p.position,
      'nationality': p.nationality,
      'rating': p.rating,
      'tier': p.tier,
      'age': p.age,
      'stats': p.stats,
    }).toList();
    await supabase.from('players').insert(rows);
  }

  Future<List<Player>> getPlayers(String teamId) async {
    final rows = await supabase
        .from('players')
        .select()
        .eq('team_id', teamId)
        .order('position');
    return rows.map((r) => Player.fromJson(r)).toList();
  }
}
```

- [ ] **Step 2: team_setup_screen.dart 작성**

`mobile/lib/screens/team_setup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../engine/player_generator.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import 'home_screen.dart';

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});
  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _nameCtrl  = TextEditingController(text: 'My FC');
  final _teamSvc   = TeamService();
  final _auth      = AuthService();
  bool _loading    = false;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _createTeam() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final userId = _auth.currentUserId!;
      final team   = await _teamSvc.createTeam(userId: userId, name: _nameCtrl.text.trim());
      final squad  = PlayerGenerator().generateSquad(startId: 0);
      await _teamSvc.savePlayers(team['id'] as String, squad);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('구단 창설', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '구단 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createTeam,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('구단 창설 및 선수단 생성'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('4-3-3 포메이션으로 11명 선수단이 자동 생성됩니다',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 빌드 및 수동 테스트**

```bash
cd mobile
flutter run --debug
```

1. 회원가입 후 팀 생성 화면으로 이동됨 확인
2. 구단 이름 입력 → "구단 창설" 클릭
3. Supabase 대시보드 Table Editor → `teams`, `players` 테이블에 데이터 생성 확인

- [ ] **Step 4: Commit**

```bash
cd ..
git add mobile/lib/services/team_service.dart mobile/lib/screens/team_setup_screen.dart
git commit -m "feat: add team service and team setup screen"
```

---

## Task 9: 홈 화면 + 스쿼드 화면

**Files:**
- Create: `mobile/lib/screens/home_screen.dart`
- Create: `mobile/lib/screens/squad_screen.dart`

- [ ] **Step 1: home_screen.dart 작성**

`mobile/lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import '../models/player.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'squad_screen.dart';
import 'match_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _teamSvc = TeamService();
  final _auth    = AuthService();
  Map<String, dynamic>? _team;
  List<Player> _squad = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final team = await _teamSvc.getTeam(_auth.currentUserId!);
    if (team != null) {
      final squad = await _teamSvc.getPlayers(team['id'] as String);
      setState(() { _team = team; _squad = squad; });
    }
    setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?['name'] ?? 'Soccer Manager'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow('선수단', '${_squad.length}명'),
            _statRow('평균 레이팅', _squad.isEmpty ? '-' :
                (_squad.map((p) => p.rating).reduce((a, b) => a + b) / _squad.length)
                    .toStringAsFixed(1)),
            const SizedBox(height: 24),
            _menuCard('스쿼드 관리', Icons.people, () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => SquadScreen(squad: _squad, teamName: _team?['name'] ?? ''),
              ));
            }),
            const SizedBox(height: 12),
            _menuCard('경기 시작', Icons.sports_soccer, () {
              if (_squad.isEmpty) return;
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MatchScreen(
                  squad: _squad,
                  teamName: _team?['name'] ?? 'My FC',
                  teamId: _team?['id'] as String,
                ),
              ));
            }),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _menuCard(String label, IconData icon, VoidCallback onTap) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF4FC3F7)),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
```

- [ ] **Step 2: squad_screen.dart 작성**

`mobile/lib/screens/squad_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../engine/player_generator.dart';

class SquadScreen extends StatelessWidget {
  final List<Player> squad;
  final String teamName;
  const SquadScreen({super.key, required this.squad, required this.teamName});

  Color _tierColor(String tier) => const {
    'N': Color(0xFF9E9E9E), 'S': Color(0xFF81C784),
    'R': Color(0xFF90CAF9), 'W': Color(0xFFFFCC02), 'G': Color(0xFFF48FB1),
  }[tier] ?? const Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$teamName 스쿼드')),
      body: ListView.separated(
        itemCount: squad.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = squad[i];
          final mainAttrs = positionMainAttrs[p.position] ?? [];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _tierColor(p.tier),
              child: Text(p.tier, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            title: Text(p.name),
            subtitle: Text('${p.position} · ${p.nationality}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.rating.toString(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7))),
                Text(p.tierLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            onTap: () => _showPlayerDetail(context, p, mainAttrs),
          );
        },
      ),
    );
  }

  void _showPlayerDetail(BuildContext context, Player p, List<String> mainAttrs) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.name} (${p.position})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${p.nationality} · ${p.age}세 · ${p.tierLabel}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: mainAttrs.map((a) => Chip(
                label: Text('$a: ${p.stats[a] ?? '-'}'),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 빌드 및 수동 테스트**

```bash
cd mobile
flutter run --debug
```

1. 홈 화면에서 "스쿼드 관리" 탭 → 11명 선수 목록 확인
2. 선수 탭 → 상세 정보 바텀시트 확인

- [ ] **Step 4: Commit**

```bash
cd ..
git add mobile/lib/screens/home_screen.dart mobile/lib/screens/squad_screen.dart
git commit -m "feat: add home screen and squad screen"
```

---

## Task 10: 경기 화면 + 결과 저장

**Files:**
- Create: `mobile/lib/services/match_service.dart`
- Create: `mobile/lib/screens/match_screen.dart`

- [ ] **Step 1: match_service.dart 작성**

`mobile/lib/services/match_service.dart`:

```dart
import '../main.dart';
import '../models/match_result.dart';

class MatchService {
  Future<String> saveMatch({
    required String teamId,
    required MatchResult result,
  }) async {
    final match = await supabase.from('matches').insert({
      'team_id':          teamId,
      'away_team_name':   result.awayTeam,
      'home_score':       result.homeScore,
      'away_score':       result.awayScore,
      'home_possession':  result.homePossession,
    }).select('id').single();

    final matchId = match['id'] as String;
    final eventRows = result.events.map((e) => {
      'match_id':    matchId,
      'minute':      e.minute,
      'event_type':  e.type,
      'description': e.description,
    }).toList();
    await supabase.from('match_events').insert(eventRows);
    return matchId;
  }

  Future<List<Map<String, dynamic>>> getRecentMatches(String teamId, {int limit = 5}) =>
      supabase.from('matches')
          .select()
          .eq('team_id', teamId)
          .order('played_at', ascending: false)
          .limit(limit);
}
```

- [ ] **Step 2: match_screen.dart 작성**

`mobile/lib/screens/match_screen.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/match_engine.dart';
import '../engine/player_generator.dart';
import '../models/player.dart';
import '../models/match_result.dart';
import '../services/match_service.dart';

class MatchScreen extends StatefulWidget {
  final List<Player> squad;
  final String teamName;
  final String teamId;
  const MatchScreen({super.key, required this.squad, required this.teamName, required this.teamId});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _matchSvc = MatchService();
  final _engine   = MatchEngine();
  final _gen      = PlayerGenerator();
  MatchResult? _result;
  final List<MatchEvent> _displayedEvents = [];
  int _homeScore = 0, _awayScore = 0;
  bool _running = false, _finished = false;
  Timer? _timer;

  void _startMatch() {
    final awaySquad = _gen.generateSquad(startId: 100);
    _result = _engine.simulate(
      homeTeam: widget.teamName,
      awayTeam: 'Rival FC',
      homePlayers: widget.squad,
      awayPlayers: awaySquad,
    );

    setState(() { _running = true; _displayedEvents.clear(); _homeScore = 0; _awayScore = 0; });
    int idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (idx >= _result!.events.length) {
        t.cancel();
        setState(() { _finished = true; _running = false; });
        _matchSvc.saveMatch(teamId: widget.teamId, result: _result!);
        return;
      }
      final ev = _result!.events[idx++];
      if (ev.type == 'goal') {
        if (ev.team == 'home') _homeScore++; else _awayScore++;
      }
      setState(() => _displayedEvents.insert(0, ev));
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Color _eventColor(String type) => switch (type) {
    'goal'   => const Color(0xFF4FC3F7),
    'save'   => const Color(0xFF81C784),
    'miss'   => const Color(0xFF9E9E9E),
    _        => const Color(0xFF6B8CAE),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.teamName} vs Rival FC')),
      body: Column(
        children: [
          // 스코어보드
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111827),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.teamName, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 16),
                Text('$_homeScore : $_awayScore',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                const Text('Rival FC', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          // 이벤트 피드
          Expanded(
            child: _displayedEvents.isEmpty
                ? const Center(child: Text('경기 시작 버튼을 누르세요', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _displayedEvents.length,
                    itemBuilder: (_, i) {
                      final ev = _displayedEvents[i];
                      return ListTile(
                        leading: Text("${ev.minute}'",
                            style: TextStyle(color: _eventColor(ev.type), fontWeight: FontWeight.bold)),
                        title: Text(ev.description),
                        dense: true,
                      );
                    },
                  ),
          ),
          // 컨트롤
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_finished)
                  Text(
                    _homeScore > _awayScore ? '🏆 ${widget.teamName} 승!'
                        : _homeScore < _awayScore ? '😞 Rival FC 승!'
                        : '🤝 무승부',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _running ? null : _startMatch,
                    child: Text(_finished ? '다시 경기' : '킥오프'),
                  ),
                ),
                if (_finished)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('홈으로'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 빌드 및 수동 테스트**

```bash
cd mobile
flutter run --debug
```

1. 홈 → "경기 시작" → 킥오프 버튼
2. 이벤트 피드에 경기 진행 표시됨 확인
3. 경기 종료 후 결과 메시지 확인
4. Supabase Table Editor → `matches`, `match_events` 테이블에 결과 저장 확인

- [ ] **Step 4: 전체 테스트 실행**

```bash
flutter test
```

Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
cd ..
git add mobile/lib/services/match_service.dart mobile/lib/screens/match_screen.dart
git commit -m "feat: add match screen and result persistence to Supabase"
```

---

## Task 11: 최종 검증 + 푸시

- [ ] **Step 1: 전체 Flutter 테스트 통과 확인**

```bash
cd mobile
flutter test
```

Expected: All tests passed

- [ ] **Step 2: 앱 전체 흐름 수동 확인**

```
회원가입 → 팀 생성(선수 11명 자동생성) → 홈화면 → 스쿼드 관리 → 경기 시작 → 이벤트 피드 → 결과 저장
```

- [ ] **Step 3: GitHub 푸시**

```bash
cd ..
git push origin main
```

---

## 다음 단계

Phase 1 완료 후 → **Phase 2: 경기 엔진 Supabase Edge Function 이전**

Phase 2 범위:
- Dart 엔진 → TypeScript(Deno) Edge Function으로 이식
- Python 백엔드 제거
- 리그/시즌 시스템 추가
