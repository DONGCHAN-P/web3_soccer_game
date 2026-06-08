import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/team_service.dart';
import 'auth_screen.dart';
import 'match_screen.dart';
import 'squad_screen.dart';

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
      if (mounted) setState(() { _team = team; _squad = squad; });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  double get _avgRating => _squad.isEmpty
      ? 0
      : _squad.map((p) => p.rating).reduce((a, b) => a + b) / _squad.length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?['name'] ?? 'Soccer Manager'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 팀 통계 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('팀 현황', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _statRow('선수단', '${_squad.length}명'),
                    _statRow('평균 레이팅', _avgRating.toStringAsFixed(1)),
                    _statRow(
                      '포메이션',
                      '4-3-3',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 메뉴
            _menuCard(
              icon: Icons.people,
              label: '스쿼드 관리',
              subtitle: '선수 ${_squad.length}명 보기',
              onTap: _squad.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SquadScreen(
                            squad: _squad,
                            teamName: _team?['name'] ?? '',
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 8),
            _menuCard(
              icon: Icons.sports_soccer,
              label: '경기 시작',
              subtitle: 'AI Rival FC와 경기',
              onTap: _squad.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchScreen(
                            squad: _squad,
                            teamName: _team?['name'] ?? 'My FC',
                            teamId: _team?['id'] as String,
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _menuCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
  }) =>
      Card(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF4FC3F7), size: 28),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
