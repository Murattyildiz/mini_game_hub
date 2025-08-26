import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/memory_stats_repo.dart';

class MemoryStatsPage extends StatefulWidget {
  const MemoryStatsPage({super.key});

  @override
  State<MemoryStatsPage> createState() => _MemoryStatsPageState();
}

class _MemoryStatsPageState extends State<MemoryStatsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  MemoryStatsRepo? _repo;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final r = await MemoryStatsRepo.create();
    if (mounted) setState(() => _repo = r);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kart Eşleştirme • İstatistikler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Kolay'),
            Tab(text: 'Orta'),
            Tab(text: 'Zor'),
          ],
        ),
      ),
      body: _repo == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: const [
                _StatsTab(d: MemoryDifficulty.easy),
                _StatsTab(d: MemoryDifficulty.medium),
                _StatsTab(d: MemoryDifficulty.hard),
              ],
            ),
    );
  }
}

class _StatsTab extends StatefulWidget {
  final MemoryDifficulty d;
  const _StatsTab({required this.d});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  MemoryStatsRepo? _repo;
  int? _bestTime;
  int? _bestMoves;
  int _plays = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final r = await MemoryStatsRepo.create();
    final bt = await r.getBestTime(widget.d);
    final bm = await r.getBestMoves(widget.d);
    final pc = await r.getPlayCount(widget.d);
    if (mounted) {
      setState(() {
        _repo = r;
        _bestTime = bt;
        _bestMoves = bm;
        _plays = pc;
      });
    }
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('En iyi süre', _bestTime != null ? _fmt(_bestTime!) : '—'),
              _chip('En iyi hamle', _bestMoves?.toString() ?? '—'),
              _chip('Oynanma', _plays.toString()),
            ],
          ),
          const SizedBox(height: 16),
          Text('Global Liderlik Tablosu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: repo == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder(
                    stream: repo.leaderboard(widget.d, limit: 25),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return const Center(child: Text('Henüz kayıt yok.'));
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = list[i];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text('Süre: ${_fmt(e.timeSeconds)}  •  Hamle: ${e.moves}'),
                            subtitle: Text('Bonus: ${e.bonus}  •  Tarih: ${DateTime.fromMillisecondsSinceEpoch(e.timestampMs)}'),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: cs.onSecondaryContainer)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSecondaryContainer)),
        ],
      ),
    );
  }
}
