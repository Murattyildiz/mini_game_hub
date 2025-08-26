import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/sudoku_notifier.dart';
import 'widgets/sudoku_grid.dart';

class SudokuPage extends ConsumerWidget {
  const SudokuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sudokuProvider);
    final notifier = ref.read(sudokuProvider.notifier);

    // Show completion info
    if (state.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tebrikler! Sudoku tamamlandı.')),
        );
      });
    }

    // Compute peers for highlighting (row/col/box of selected)
    Set<Pos> peers = {};
    Set<Pos> sameValues = {};
    final sel = state.selected;
    if (sel != null) {
      final r = sel.row, c = sel.col;
      // row
      for (int cc = 0; cc < 9; cc++) {
        if (cc == c) continue;
        peers.add(Pos(r, cc));
      }
      // col
      for (int rr = 0; rr < 9; rr++) {
        if (rr == r) continue;
        peers.add(Pos(rr, c));
      }
      // box
      final br = (r ~/ 3) * 3;
      final bc = (c ~/ 3) * 3;
      for (int rr = br; rr < br + 3; rr++) {
        for (int cc = bc; cc < bc + 3; cc++) {
          if (rr == r && cc == c) continue;
          peers.add(Pos(rr, cc));
        }
      }

      // same values highlighting
      final v = state.board[r][c].value;
      if (v != 0) {
        for (int rr = 0; rr < 9; rr++) {
          for (int cc = 0; cc < 9; cc++) {
            if (rr == r && cc == c) continue;
            if (state.board[rr][cc].value == v) {
              sameValues.add(Pos(rr, cc));
            }
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Geri Al',
            onPressed: ref.read(sudokuProvider.notifier).undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'İleri Al',
            onPressed: ref.read(sudokuProvider.notifier).redo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Sıfırla',
            onPressed: ref.read(sudokuProvider.notifier).reset,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => notifier.newGame(v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'easy', child: Text('Kolay')),
              PopupMenuItem(value: 'medium', child: Text('Orta')),
              PopupMenuItem(value: 'hard', child: Text('Zor')),
            ],
          ),
          IconButton(
            tooltip: 'Temizle',
            onPressed: notifier.clearSelected,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final n = ref.read(sudokuProvider.notifier);
            final k = event.logicalKey;
            // arrows
            if (k == LogicalKeyboardKey.arrowUp) { n.moveSelection(-1, 0); return KeyEventResult.handled; }
            if (k == LogicalKeyboardKey.arrowDown) { n.moveSelection(1, 0); return KeyEventResult.handled; }
            if (k == LogicalKeyboardKey.arrowLeft) { n.moveSelection(0, -1); return KeyEventResult.handled; }
            if (k == LogicalKeyboardKey.arrowRight) { n.moveSelection(0, 1); return KeyEventResult.handled; }
            // numbers top row
            const digitKeys = [
              LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6,
              LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9,
            ];
            for (int i = 0; i < digitKeys.length; i++) {
              if (k == digitKeys[i]) { n.input(i + 1); return KeyEventResult.handled; }
            }
            // numpad
            const numpad = [
              LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3,
              LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5, LogicalKeyboardKey.numpad6,
              LogicalKeyboardKey.numpad7, LogicalKeyboardKey.numpad8, LogicalKeyboardKey.numpad9,
            ];
            for (int i = 0; i < numpad.length; i++) {
              if (k == numpad[i]) { n.input(i + 1); return KeyEventResult.handled; }
            }
            // erase
            if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace ||
                k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
              n.erase();
              return KeyEventResult.handled;
            }
            // escape to clear selection
            if (k == LogicalKeyboardKey.escape) { n.clearSelected(); return KeyEventResult.handled; }
            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SudokuGrid(
                      board: state.board,
                      selected: state.selected,
                      onSelect: notifier.select,
                      conflicts: state.conflicts,
                      peers: peers,
                      sameValues: sameValues,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int n = 1; n <= 9; n++) ...[
                        ElevatedButton(
                          onPressed: () => notifier.input(n),
                          child: Text('$n'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(
                        onPressed: notifier.erase,
                        child: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
