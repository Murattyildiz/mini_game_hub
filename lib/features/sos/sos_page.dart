import 'package:flutter/material.dart';
import 'dart:math' as math;

enum _Player { blue, red }

class SOSGamePage extends StatefulWidget {
  const SOSGamePage({super.key});

  @override
  State<SOSGamePage> createState() => _SOSGamePageState();
}

class _SOSGamePageState extends State<SOSGamePage> {
  int _size = 3; // 3 or 5
  late List<List<String>> _board; // '', 'S', 'O'
  _Player _turn = _Player.blue;
  String _selectedLetter = 'S';
  int _scoreBlue = 0;
  int _scoreRed = 0;
  bool _gameOver = false;
  bool _vsBot = false; // Bot always plays Kırmızı
  bool _botThinking = false;
  int _highlightToken = 0;
  Set<String> _highlightCells = {};
  bool _darkTheme = false;
  int _animMs = 900; // highlight & transitions duration

  @override
  void initState() {
    super.initState();
    _resetBoard(keepScores: false);
  }

  void _resetBoard({bool keepScores = true}) {
    _board = List.generate(_size, (_) => List.filled(_size, ''));
    _turn = _Player.blue;
    _selectedLetter = 'S';
    _gameOver = false;
    _highlightCells.clear();
    _highlightToken++;
    if (!keepScores) {
      _scoreBlue = 0;
      _scoreRed = 0;
    }
    setState(() {});
  }

  void _changeSize(int newSize) {
    if (newSize == _size) return;
    setState(() {
      _size = newSize;
    });
    _resetBoard(keepScores: false);
  }

  bool _inBounds(int r, int c) => r >= 0 && c >= 0 && r < _size && c < _size;

  int _countNewSOS(int r, int c) {
    final letter = _board[r][c];
    if (letter.isEmpty) return 0;
    int count = 0;
    const dirs = [
      [1, 0], // vertical
      [0, 1], // horizontal
      [1, 1], // diag down-right
      [1, -1], // diag down-left
    ];
    if (letter == 'S') {
      for (final d in dirs) {
        final dr = d[0], dc = d[1];
        final r1 = r + dr, c1 = c + dc;
        final r2 = r + 2 * dr, c2 = c + 2 * dc;
        if (_inBounds(r1, c1) && _inBounds(r2, c2)) {
          if (_board[r1][c1] == 'O' && _board[r2][c2] == 'S') count++;
        }
        final rr1 = r - dr, cc1 = c - dc;
        final rr2 = r - 2 * dr, cc2 = c - 2 * dc;
        if (_inBounds(rr1, cc1) && _inBounds(rr2, cc2)) {
          if (_board[rr1][cc1] == 'O' && _board[rr2][cc2] == 'S') count++;
        }
      }
    } else if (letter == 'O') {
      for (final d in dirs) {
        final dr = d[0], dc = d[1];
        final r1 = r - dr, c1 = c - dc;
        final r2 = r + dr, c2 = c + dc;
        if (_inBounds(r1, c1) && _inBounds(r2, c2)) {
          if (_board[r1][c1] == 'S' && _board[r2][c2] == 'S') count++;
        }
      }
    }
    return count;
  }

  _Eval _evaluateNewSOS(int r, int c) {
    final letter = _board[r][c];
    if (letter.isEmpty) return const _Eval(0, {});
    int count = 0;
    final Set<String> cells = {};
    const dirs = [
      [1, 0], [0, 1], [1, 1], [1, -1]
    ];
    String key(int rr, int cc) => '$rr,$cc';
    if (letter == 'S') {
      for (final d in dirs) {
        final dr = d[0], dc = d[1];
        // forward S-O-S
        final r1 = r + dr, c1 = c + dc;
        final r2 = r + 2 * dr, c2 = c + 2 * dc;
        if (_inBounds(r1, c1) && _inBounds(r2, c2)) {
          if (_board[r1][c1] == 'O' && _board[r2][c2] == 'S') {
            count++;
            cells.addAll({ key(r, c), key(r1, c1), key(r2, c2) });
          }
        }
        // backward S-O-S
        final rr1 = r - dr, cc1 = c - dc;
        final rr2 = r - 2 * dr, cc2 = c - 2 * dc;
        if (_inBounds(rr1, cc1) && _inBounds(rr2, cc2)) {
          if (_board[rr1][cc1] == 'O' && _board[rr2][cc2] == 'S') {
            count++;
            cells.addAll({ key(r, c), key(rr1, cc1), key(rr2, cc2) });
          }
        }
      }
    } else if (letter == 'O') {
      for (final d in dirs) {
        final dr = d[0], dc = d[1];
        final r1 = r - dr, c1 = c - dc;
        final r2 = r + dr, c2 = c + dc;
        if (_inBounds(r1, c1) && _inBounds(r2, c2)) {
          if (_board[r1][c1] == 'S' && _board[r2][c2] == 'S') {
            count++;
            cells.addAll({ key(r1, c1), key(r, c), key(r2, c2) });
          }
        }
      }
    }
    return _Eval(count, cells);
  }

  void _play(int r, int c) {
    if (_gameOver) return;
    if (_board[r][c].isNotEmpty) return;

    setState(() {
      _board[r][c] = _selectedLetter;
      final eval = _evaluateNewSOS(r, c);
      final gained = eval.count;
      _applyHighlight(eval.cells);
      if (gained > 0) {
        if (_turn == _Player.blue) {
          _scoreBlue += gained;
        } else {
          _scoreRed += gained;
        }
        // Extra turn if scored
      } else {
        // Switch turn
        _turn = _turn == _Player.blue ? _Player.red : _Player.blue;
      }

      // Game over check
      bool anyEmpty = false;
      for (final row in _board) {
        if (row.contains('')) { anyEmpty = true; break; }
      }
      if (!anyEmpty) {
        _gameOver = true;
      }
    });

    // Bot move if needed
    _maybeBotMove();
  }

  void _applyHighlight(Set<String> cells) {
    _highlightToken++;
    final token = _highlightToken;
    setState(() { _highlightCells = cells; });
    Future.delayed(Duration(milliseconds: _animMs), () {
      if (_highlightToken == token) {
        setState(() { _highlightCells = {}; });
      }
    });
  }

  void _maybeBotMove() async {
    if (_gameOver || !_vsBot) return;
    if (_turn != _Player.red) return; // bot is red
    if (_botThinking) return;
    _botThinking = true;
    await Future.delayed(const Duration(milliseconds: 350));
    while (!_gameOver && _turn == _Player.red) {
      final move = _chooseBotMove();
      if (move == null) break;
      setState(() {
        _selectedLetter = move.letter; // bot picks letter too
        _board[move.r][move.c] = _selectedLetter;
      });
      final eval = _evaluateNewSOS(move.r, move.c);
      final gained = eval.count;
      _applyHighlight(eval.cells);
      if (gained > 0) {
        setState(() { _scoreRed += gained; });
        // extra turn, continue loop
      } else {
        setState(() { _turn = _Player.blue; });
        break;
      }
      // Check game over after each placement
      bool anyEmpty = false;
      for (final row in _board) { if (row.contains('')) { anyEmpty = true; break; } }
      if (!anyEmpty) { setState(() { _gameOver = true; }); break; }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _botThinking = false;
  }

  _BotMove? _chooseBotMove() {
    // Try winning move first
    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        if (_board[r][c].isNotEmpty) continue;
        for (final letter in const ['S','O']) {
          _board[r][c] = letter;
          final gained = _countNewSOS(r, c);
          _board[r][c] = '';
          if (gained > 0) return _BotMove(r, c, letter);
        }
      }
    }
    // Otherwise random move
    final empties = <_BotMove>[];
    for (int r = 0; r < _size; r++) {
      for (int c = 0; c < _size; c++) {
        if (_board[r][c].isEmpty) {
          empties.add(_BotMove(r, c, math.Random().nextBool() ? 'S' : 'O'));
        }
      }
    }
    if (empties.isEmpty) return null;
    return empties[math.Random().nextInt(empties.length)];
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        int tempAnim = _animMs;
        bool tempDark = _darkTheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tune),
                      SizedBox(width: 8),
                      Text('Ayarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: tempDark,
                    onChanged: (v) {
                      setModalState(() => tempDark = v);
                      setState(() => _darkTheme = v);
                    },
                    title: const Text('Koyu Tema'),
                    secondary: const Icon(Icons.dark_mode),
                  ),
                  const SizedBox(height: 8),
                  const Text('Animasyon Hızı', style: TextStyle(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      const Text('Hızlı'),
                      Expanded(
                        child: Slider(
                          value: tempAnim.toDouble(),
                          min: 200,
                          max: 1500,
                          divisions: 13,
                          label: '${tempAnim}ms',
                          onChanged: (val) {
                            setModalState(() => tempAnim = val.round());
                            setState(() => _animMs = val.round());
                          },
                        ),
                      ),
                      const Text('Yavaş'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorBlue = Colors.blue;
    final colorRed = Colors.red;
    final isBlueTurn = _turn == _Player.blue;
    final bg1 = _darkTheme ? const Color(0xFF1E1E1E) : Colors.black12;
    final bg2 = _darkTheme ? const Color(0xFF2A2A2A) : Colors.black12.withOpacity(0.6);
    final borderColor = _darkTheme ? Colors.grey.shade600 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Oyunu'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Tahta Boyutu',
            onSelected: _changeSize,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 3, child: Text('3 x 3')),
              PopupMenuItem(value: 5, child: Text('5 x 5')),
              PopupMenuItem(value: 7, child: Text('7 x 7')),
              PopupMenuItem(value: 9, child: Text('9 x 9')),
            ],
            icon: const Icon(Icons.grid_on),
          ),
          IconButton(
            tooltip: 'Yeni Raund (Skorları Koru)',
            onPressed: () => _resetBoard(keepScores: true),
            icon: const Icon(Icons.play_circle_fill),
          ),
          IconButton(
            tooltip: 'Sıfırla',
            onPressed: () => _resetBoard(keepScores: false),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScoreChip(label: 'Mavi', score: _scoreBlue, color: colorBlue, highlighted: isBlueTurn),
                _LetterPicker(
                  selected: _selectedLetter,
                  onSelect: (v) => setState(() => _selectedLetter = v),
                ),
                _ScoreChip(label: 'Kırmızı', score: _scoreRed, color: colorRed, highlighted: !isBlueTurn),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bot\'a karşı: '),
                Switch(
                  value: _vsBot,
                  onChanged: (v) {
                    setState(() { _vsBot = v; });
                    if (_vsBot) _maybeBotMove();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardSide = math.min(constraints.maxWidth, constraints.maxHeight);
                  final cellSize = boardSide / _size;
                  final fontSize = cellSize * 0.6;
                  final thin = math.max(0.5, cellSize * 0.03);
                  final thick = math.max(2.0, cellSize * 0.08);
                  return Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        primary: false,
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _size,
                        ),
                        itemCount: _size * _size,
                        itemBuilder: (context, index) {
                          final r = index ~/ _size;
                          final c = index % _size;
                          final value = _board[r][c];
                          final isHighlighted = _highlightCells.contains('$r,$c');
                          return InkWell(
                            onTap: () => _play(r, c),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: (_animMs * 0.5).round()),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(width: r == 0 ? thick : thin, color: borderColor),
                                  left: BorderSide(width: c == 0 ? thick : thin, color: borderColor),
                                  right: BorderSide(width: c == _size - 1 ? thick : thin, color: borderColor),
                                  bottom: BorderSide(width: r == _size - 1 ? thick : thin, color: borderColor),
                                ),
                                color: isHighlighted
                                    ? Colors.amber.withOpacity(0.35)
                                    : ((r + c) % 2 == 0 ? bg1 : bg2),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedDefaultTextStyle(
                                duration: Duration(milliseconds: (_animMs * 0.5).round()),
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: value.isEmpty
                                      ? (_darkTheme ? Colors.white70 : Colors.black87)
                                      : (isBlueTurn ? colorBlue : colorRed),
                                ),
                                child: Text(value),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_gameOver)
              _buildGameOver(context)
            else
              Text(
                isBlueTurn ? 'Sıra: Mavi' : 'Sıra: Kırmızı',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isBlueTurn ? colorBlue : colorRed),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver(BuildContext context) {
    String result;
    if (_scoreBlue > _scoreRed) {
      result = 'Mavi kazandı!';
    } else if (_scoreRed > _scoreBlue) {
      result = 'Kırmızı kazandı!';
    } else {
      result = 'Berabere!';
    }
    return Column(
      children: [
        Text(result, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _resetBoard(keepScores: false),
          icon: const Icon(Icons.replay),
          label: const Text('Yeniden Başlat'),
        )
      ],
    );
  }
}

class _Eval {
  final int count;
  final Set<String> cells;
  const _Eval(this.count, this.cells);
}

class _BotMove {
  final int r;
  final int c;
  final String letter;
  const _BotMove(this.r, this.c, this.letter);
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool highlighted;
  const _ScoreChip({required this.label, required this.score, required this.color, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: highlighted ? color.withOpacity(0.15) : null,
      avatar: CircleAvatar(backgroundColor: color),
      label: Text('$label: $score'),
    );
  }
}

class _LetterPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _LetterPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          label: const Text('S'),
          selected: selected == 'S',
          onSelected: (_) => onSelect('S'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('O'),
          selected: selected == 'O',
          onSelected: (_) => onSelect('O'),
        ),
      ],
    );
  }
}
