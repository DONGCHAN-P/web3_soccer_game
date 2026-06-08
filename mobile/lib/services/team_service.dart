import '../main.dart';
import '../models/player.dart';

class TeamService {
  Future<Map<String, dynamic>?> getTeam(String userId) => supabase
      .from('teams')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

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
    final rows = players
        .map((p) => {
              'team_id': teamId,
              'name': p.name,
              'position': p.position,
              'nationality': p.nationality,
              'rating': p.rating,
              'tier': p.tier,
              'age': p.age,
              'stats': p.stats,
            })
        .toList();
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
