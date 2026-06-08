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
          (json['stats'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ),
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
        'N': 'Normal',
        'S': 'Special',
        'R': 'Rare',
        'W': 'World Class',
        'G': 'GOAT',
      }[tier] ??
      tier;
}
