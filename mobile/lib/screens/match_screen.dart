import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/match_engine.dart';
import '../engine/player_generator.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../services/match_service.dart';

class MatchScreen extends StatefulWidget {
  final List<Player> squad;
  final String teamName;
  final String teamId;
  const MatchScreen({
    super.key,
    required this.squad,
    required this.teamName,
    required this.teamId,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _matchSvc = MatchService();
  final _engine   = MatchEngine();
  final _gen      = PlayerGenerator();
  MatchResult? _result;
  final List<MatchEvent> _feed = [];
  int _homeScore = 0, _awayScore = 0;
  bool _running = false, _finished = false;
  Timer? _timer;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _startMatch() {
    final awaySquad = _gen.generateSquad(startId: 100);
    _result = _engine.simulate(
      homeTeam: widget.teamName,
      awayTeam: 'Rival FC',
      homePlayers: widget.squad,
      awayPlayers: awaySquad,
    );
    setState(() {
      _running = true;
      _finished = false;
      _feed.clear();
      _homeScore = 0;
      _awayScore = 0;
    });

    int idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 350), (t) {
      if (idx >= _result!.events.length) {
        t.cancel();
        setState(() { _running = false; _finished = true; });
        _matchSvc.saveMatch(teamId: widget.teamId, result: _result!);
        return;
      }
      final ev = _result!.events[idx++];
      if (ev.type == 'goal') {
        if (ev.team == 'home') _homeScore++; else _awayScore++;
      }
      setState(() => _feed.insert(0, ev));
    });
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'goal':   return const Color(0xFF4FC3F7);
      case 'save':   return const Color(0xFF81C784);
      case 'miss':   return const Color(0xFF9E9E9E);
      default:       return const Color(0xFF6B8CAE);
    }
  }

  String get _resultText {
    if (_homeScore > _awayScore) return '🏆 ${widget.teamName} 승!';
    if (_homeScore < _awayScore) return '😞 Rival FC 승!';
    return '🤝 무승부';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.teamName} vs Rival FC')),
      body: Column(
        children: [
          // 스코어보드
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.teamName,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$_homeScore : $_awayScore',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rival FC',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          // 이벤트 피드
          Expanded(
            child: _feed.isEmpty
                ? Center(
                    child: Text(
                      _running ? '...' : '킥오프 버튼을 눌러 경기를 시작하세요',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _feed.length,
                    itemBuilder: (_, i) {
                      final ev = _feed[i];
                      return ListTile(
                        dense: true,
                        leading: Text(
                          "${ev.minute}'",
                          style: TextStyle(
                            color: _eventColor(ev.type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        title: Text(ev.description, style: const TextStyle(fontSize: 13)),
                      );
                    },
                  ),
          ),
          // 하단 컨트롤
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_finished) ...[
                    Text(
                      _resultText,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_result != null)
                      Text(
                        '점유율 ${_result!.homePossession.toStringAsFixed(0)}% | '
                        '슈팅 ${_result!.homeShots} : ${_result!.awayShots}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _running ? null : _startMatch,
                      child: Text(_finished ? '다시 경기' : '킥오프'),
                    ),
                  ),
                  if (_finished)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('홈으로 돌아가기'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
