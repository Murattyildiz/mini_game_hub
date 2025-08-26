import 'package:flutter/material.dart';
import '../application/sudoku_notifier.dart';

class SudokuGrid extends StatelessWidget {
  final List<List<Cell>> board;
  final Pos? selected;
  final Set<Pos> conflicts;
  final Set<Pos> peers;
  final Set<Pos> sameValues;
  final void Function(int row, int col) onSelect;

  const SudokuGrid({
    super.key,
    required this.board,
    required this.selected,
    required this.onSelect,
    required this.conflicts,
    this.peers = const {},
    this.sameValues = const {},
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(width: 2, color: Theme.of(context).colorScheme.primary),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemCount: 81,
          itemBuilder: (context, index) {
            final r = index ~/ 9;
            final c = index % 9;
            final cell = board[r][c];
            final isSelected = selected != null && selected!.row == r && selected!.col == c;
            final here = Pos(r, c);
            final isConflict = conflicts.contains(here);
            final isPeer = peers.contains(here);
            final bool isSame = sameValues.contains(here);
            final Color bg = isSelected
                ? Theme.of(context).colorScheme.secondaryContainer
                : isConflict
                    ? Colors.red.withOpacity(0.25)
                    : isSame
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                        : isPeer
                        ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4)
                        : Colors.transparent;

            return InkWell(
              onTap: () => onSelect(r, c),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    top: BorderSide(
                      width: r % 3 == 0 ? 2 : 0.5,
                      color: Colors.grey.shade700,
                    ),
                    left: BorderSide(
                      width: c % 3 == 0 ? 2 : 0.5,
                      color: Colors.grey.shade700,
                    ),
                    right: BorderSide(
                      width: (c + 1) % 3 == 0 ? 2 : 0.5,
                      color: Colors.grey.shade700,
                    ),
                    bottom: BorderSide(
                      width: (r + 1) % 3 == 0 ? 2 : 0.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  cell.value == 0 ? '' : '${cell.value}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: cell.given ? FontWeight.bold : FontWeight.normal,
                    color: cell.given ? Theme.of(context).colorScheme.onSurface : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
