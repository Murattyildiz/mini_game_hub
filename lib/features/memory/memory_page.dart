import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'data/memory_stats_repo.dart';

class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({super.key});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

enum _Difficulty { easy, medium, hard }

class _CardData {
  final String content;
  bool matched = false; // default, no need to pass via ctor
  _CardData(this.content);
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  _Difficulty _difficulty = _Difficulty.easy;
  late int _rows;
  late int _cols;
  late List<_CardData> _cards; // length = rows*cols, each pair duplicated
  int? _revealedA;
  int? _revealedB;
  bool _busy = false;
  int _moves = 0;
  int _matchedPairs = 0;
  Timer? _timer;
  int _elapsed = 0;
  bool _paused = false;
  // Challenge mode
  bool _challenge = false;
  int _countdown = 0; // seconds remaining when challenge is on
  // Stats repo
  MemoryStatsRepo? _stats;
  // Best scores (per difficulty)
  final Map<_Difficulty, int?> _bestTime = {
    _Difficulty.easy: null,
    _Difficulty.medium: null,
    _Difficulty.hard: null,
  };
  final Map<_Difficulty, int?> _bestMoves = {
    _Difficulty.easy: null,
    _Difficulty.medium: null,
    _Difficulty.hard: null,
  };
  // Local theme
  bool _dark = false;
  int _seedIndex = 0;
  static final List<Color> _seeds = [
    Colors.blue, Colors.teal, Colors.deepPurple, Colors.orange, Colors.pink,
  ];

  static const List<String> _emojiPool = [
    '🍎','🍌','🍉','🍇','🍓','🍒','🍍','🥝','🥑','🍑','🍋','🍊','🥥','🥕','🌽','🍆','🍔','🍟','🍕','🌭','🍪','🍩','🍰','🧁',
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🐔','🐧','🐦','🐤','🦆','🦉','🐺','🦄','🐝'
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame(_difficulty);
    // Load persisted best scores
    unawaited(_loadBest());
    // Prepare stats repo
    unawaited(_initStats());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame(_Difficulty diff) {
    _difficulty = diff;
    switch (diff) {
      case _Difficulty.easy:
        _rows = 4; _cols = 4; // 8 pairs
        break;
      case _Difficulty.medium:
        _rows = 4; _cols = 5; // 10 pairs
        break;
      case _Difficulty.hard:
        _rows = 6; _cols = 6; // 18 pairs
        break;
    }
    final pairs = (_rows * _cols) ~/ 2;
    final pool = List<String>.from(_emojiPool)..shuffle();
    final chosen = pool.take(pairs).toList();
    final list = <_CardData>[];
    for (final e in chosen) {
      list.add(_CardData(e));
      list.add(_CardData(e));
    }
    list.shuffle();
    setState(() {
      _cards = list;
      _revealedA = null;
      _revealedB = null;
      _busy = false;
      _moves = 0;
      _matchedPairs = 0;
      _elapsed = 0;
      _paused = false;
      _resetChallengeCountdown();
    });
    _restartTimer();
  }

  Future<void> _initStats() async {
    final repo = await MemoryStatsRepo.create();
    if (!mounted) return;
    setState(() => _stats = repo);
  }

  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      for (final d in _Difficulty.values) {
        _bestTime[d] = sp.getInt(_bestKey(d, true));
        _bestMoves[d] = sp.getInt(_bestKey(d, false));
      }
    });
  }

  Future<void> _updateBestIfNeeded() async {
    final sp = await SharedPreferences.getInstance();
    final curBestTime = _bestTime[_difficulty];
    final curBestMoves = _bestMoves[_difficulty];
    bool improved = false;
    if (curBestTime == null || _elapsed < curBestTime) {
      _bestTime[_difficulty] = _elapsed;
      await sp.setInt(_bestKey(_difficulty, true), _elapsed);
      improved = true;
    }
    if (curBestMoves == null || _moves < curBestMoves) {
      _bestMoves[_difficulty] = _moves;
      await sp.setInt(_bestKey(_difficulty, false), _moves);
      improved = true;
    }
    if (improved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni rekor!')),
      );
    }
  }

  String _bestKey(_Difficulty d, bool time) =>
      'memory.best.${time ? 'time' : 'moves'}.${d.name}';

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() {
        _elapsed += 1;
        if (_challenge && _countdown > 0) {
          _countdown -= 1;
          if (_countdown == 0) {
            // time over => stop game interaction
            _paused = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Süre bitti! Challenge başarısız.')),
            );
            // Record fail
            _submitStats(success: false, bonus: 0);
          }
        }
      });
    });
  }

  bool _isFaceUp(int i) {
    if (_cards[i].matched) return true;
    return _revealedA == i || _revealedB == i;
  }

  Future<void> _tapCard(int i) async {
    if (_busy || _cards[i].matched || _isFaceUp(i) || _paused) return;
    _playFlip();
    setState(() {
      if (_revealedA == null) {
        _revealedA = i;
      } else if (_revealedB == null) {
        _revealedB = i;
      }
    });

    if (_revealedA != null && _revealedB != null) {
      _busy = true;
      setState(() { _moves += 1; });
      await Future.delayed(const Duration(milliseconds: 600));
      final a = _revealedA!;
      final b = _revealedB!;
      if (_cards[a].content == _cards[b].content) {
        _playMatch();
        setState(() {
          _cards[a].matched = true;
          _cards[b].matched = true;
          _matchedPairs += 1;
        });
        if (_matchedPairs == (_rows * _cols) ~/ 2) {
          _timer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tebrikler! Süre: ${_fmtTime(_elapsed)} • Hamle: $_moves')),
            );
          }
          unawaited(_updateBestIfNeeded());
          // Submit stats
          final bonus = _challenge ? (_countdown.clamp(0, 1 << 30)) : 0;
          unawaited(_submitStats(success: true, bonus: bonus));
        }
      }
      setState(() {
        _revealedA = null;
        _revealedB = null;
      });
      _busy = false;
    }
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  void _resetChallengeCountdown() {
    if (!_challenge) {
      _countdown = 0;
      return;
    }
    switch (_difficulty) {
      case _Difficulty.easy:
        _countdown = 90;
        break;
      case _Difficulty.medium:
        _countdown = 150;
        break;
      case _Difficulty.hard:
        _countdown = 240;
        break;
    }
  }

  Future<void> _submitStats({required bool success, required int bonus}) async {
    final repo = _stats;
    if (repo == null) return;
    final mapDiff = switch (_difficulty) {
      _Difficulty.easy => MemoryDifficulty.easy,
      _Difficulty.medium => MemoryDifficulty.medium,
      _Difficulty.hard => MemoryDifficulty.hard,
    };
    await repo.recordGameResult(MemoryGameResult(
      difficulty: mapDiff,
      timeSeconds: _elapsed,
      moves: _moves,
      success: success,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      bonus: bonus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final time = _fmtTime(_elapsed);
    final seed = _seeds[_seedIndex % _seeds.length];
    final themed = Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: _dark ? Brightness.dark : Brightness.light),
      useMaterial3: true,
    );
    return Theme(
      data: themed,
      child: Scaffold(
      appBar: AppBar(
        title: Text('Kart Eşleştirme • $time • $_moves hamle${_challenge ? ' • ⏳ ${_fmtTime(_countdown)}' : ''}'),
        actions: [
          PopupMenuButton<_Difficulty>(
            tooltip: 'Zorluk',
            onSelected: (d) => _startNewGame(d),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Difficulty.easy, child: Text('Kolay (4x4)')),
              PopupMenuItem(value: _Difficulty.medium, child: Text('Orta (4x5)')),
              PopupMenuItem(value: _Difficulty.hard, child: Text('Zor (6x6)')),
            ],
            icon: const Icon(Icons.grid_view),
          ),
          IconButton(
            tooltip: 'İstatistikler',
            onPressed: () => context.push('/memory_stats'),
            icon: const Icon(Icons.leaderboard_outlined),
          ),
          IconButton(
            tooltip: 'Tema',
            onPressed: () => setState(() => _seedIndex = (_seedIndex + 1) % _seeds.length),
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: _dark ? 'Açık Tema' : 'Koyu Tema',
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            tooltip: _challenge ? 'Challenge: Açık' : 'Challenge: Kapalı',
            onPressed: () {
              setState(() {
                _challenge = !_challenge;
                _resetChallengeCountdown();
              });
            },
            icon: Icon(_challenge ? Icons.timer : Icons.timer_off),
          ),
          IconButton(
            tooltip: _paused ? 'Devam' : 'Duraklat',
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          ),
          IconButton(
            tooltip: 'Sıfırla',
            onPressed: () => _startNewGame(_difficulty),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSide = math.min(constraints.maxWidth, constraints.maxHeight);
            final cellSize = boardSide / _cols;
            final fontSize = cellSize * 0.55;
            final bestT = _bestTime[_difficulty];
            final bestM = _bestMoves[_difficulty];
            return Center(
              child: SizedBox(
                width: boardSide,
                height: boardSide,
                child: Column(
                  children: [
                    if (bestT != null || bestM != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (bestT != null)
                              _Badge(label: 'En iyi süre', value: _fmtTime(bestT)),
                            const SizedBox(width: 8),
                            if (bestM != null)
                              _Badge(label: 'En iyi hamle', value: '${bestM}'),
                          ],
                        ),
                      ),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _cols,
                        ),
                        itemCount: _rows * _cols,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final faceUp = _isFaceUp(index);
                          return _FlipCard(
                            size: cellSize,
                            faceUp: faceUp,
                            matched: card.matched,
                            frontChild: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              scale: card.matched ? 1.06 : 1.0,
                              child: Container(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                alignment: Alignment.center,
                                child: Text(card.content, style: TextStyle(fontSize: fontSize)),
                              ),
                            ),
                            backChild: Container(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              alignment: Alignment.center,
                              child: Icon(Icons.help_outline, size: fontSize * 0.9, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            onTap: () => _tapCard(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  const _Badge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
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

// Simple feedback helpers (no external assets needed)
void _playFlip() {
  SystemSound.play(SystemSoundType.click);
  HapticFeedback.selectionClick();
}

void _playMatch() {
  HapticFeedback.heavyImpact();
}

class _FlipCard extends StatelessWidget {
  final double size;
  final bool faceUp;
  final bool matched;
  final Widget frontChild; // shown when faceUp
  final Widget backChild; // shown when faceDown
  final VoidCallback onTap;
  const _FlipCard({
    required this.size,
    required this.faceUp,
    required this.matched,
    required this.frontChild,
    required this.backChild,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // simple flip animation using AnimatedSwitcher + rotation
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap: onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) {
            final rotate = Tween(begin: math.pi, end: 0.0).animate(anim);
            return AnimatedBuilder(
              animation: rotate,
              child: child,
              builder: (context, child) {
                final val = rotate.value;
                return Transform(
                  transform: Matrix4.rotationY(val),
                  alignment: Alignment.center,
                  child: child,
                );
              },
            );
          },
          child: SizedBox(
            key: ValueKey<bool>(faceUp || matched),
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: matched ? Colors.amber : Colors.grey.shade600,
                  width: matched ? 3 : 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: faceUp || matched ? frontChild : backChild,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
