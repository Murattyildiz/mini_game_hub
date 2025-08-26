import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/sudoku_notifier.dart';
import 'widgets/sudoku_grid.dart';

class SudokuPage extends ConsumerWidget {
  const SudokuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sudokuProvider);
    final notifier = ref.read(sudokuProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
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
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SudokuGrid(
              board: state.board,
              selected: state.selected,
              onSelect: notifier.select,
              conflicts: state.conflicts,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 8,
              children: [
                for (int n = 1; n <= 9; n++)
                  ElevatedButton(
                    onPressed: () => notifier.input(n),
                    child: Text('$n'),
                  ),
                ElevatedButton(
                  onPressed: notifier.erase,
                  child: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
