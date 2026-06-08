class MatchEvent {
  final int minute;
  final String type;
  final String team;
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
