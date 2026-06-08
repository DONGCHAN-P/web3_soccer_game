import '../main.dart';
import '../models/match_result.dart';

class MatchService {
  Future<String> saveMatch({
    required String teamId,
    required MatchResult result,
  }) async {
    final match = await supabase.from('matches').insert({
      'team_id':         teamId,
      'away_team_name':  result.awayTeam,
      'home_score':      result.homeScore,
      'away_score':      result.awayScore,
      'home_possession': result.homePossession,
    }).select('id').single();

    final matchId = match['id'] as String;
    final eventRows = result.events
        .map((e) => {
              'match_id':    matchId,
              'minute':      e.minute,
              'event_type':  e.type,
              'description': e.description,
            })
        .toList();
    await supabase.from('match_events').insert(eventRows);
    return matchId;
  }

  Future<List<Map<String, dynamic>>> getRecentMatches(
    String teamId, {
    int limit = 5,
  }) =>
      supabase
          .from('matches')
          .select()
          .eq('team_id', teamId)
          .order('played_at', ascending: false)
          .limit(limit);
}
