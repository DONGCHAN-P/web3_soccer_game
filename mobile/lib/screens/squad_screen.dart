import 'package:flutter/material.dart';
import '../engine/player_generator.dart';
import '../models/player.dart';

class SquadScreen extends StatelessWidget {
  final List<Player> squad;
  final String teamName;
  const SquadScreen({super.key, required this.squad, required this.teamName});

  Color _tierColor(String tier) => const {
        'N': Color(0xFF9E9E9E),
        'S': Color(0xFF81C784),
        'R': Color(0xFF90CAF9),
        'W': Color(0xFFFFCC02),
        'G': Color(0xFFF48FB1),
      }[tier] ??
      const Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$teamName 스쿼드 (${squad.length}명)')),
      body: ListView.separated(
        itemCount: squad.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final p = squad[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _tierColor(p.tier),
              child: Text(
                p.tier,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(p.name),
            subtitle: Text('${p.position} · ${p.nationality} · ${p.age}세'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4FC3F7),
                  ),
                ),
                Text(
                  p.tierLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _showDetail(context, p),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Player p) {
    final mainAttrs = positionMainAttrs[p.position] ?? [];
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p.name} (${p.position})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${p.nationality} · ${p.age}세 · ${p.tierLabel}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mainAttrs
                  .map((a) => Chip(label: Text('$a: ${p.stats[a] ?? "-"}')))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
