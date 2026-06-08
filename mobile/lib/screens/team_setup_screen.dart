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
  final _nameCtrl = TextEditingController(text: 'My FC');
  final _teamSvc  = TeamService();
  final _auth     = AuthService();
  bool _loading   = false;
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
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
              const Text(
                '⚽ 구단 창설',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '4-3-3 포메이션으로 11명 선수단이\n자동 생성됩니다',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
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
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createTeam,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('구단 창설'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
