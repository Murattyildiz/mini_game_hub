import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Cell {
  final int row;
  final int col;
  final int value; // 0 = empty
  final bool given; // true if pre-filled
  const Cell({required this.row, required this.col, required this.value, required this.given});

  Cell copyWith({int? value}) => Cell(row: row, col: col, value: value ?? this.value, given: given);
}

class Pos {
  final int row;
  final int col;
  const Pos(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Pos && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
}

class SudokuState {
  final List<List<Cell>> board; // 9x9
  final Pos? selected;
  final Set<Pos> conflicts;
  final bool completed;

  const SudokuState({
    required this.board,
    required this.selected,
    required this.conflicts,
    required this.completed,
  });

  SudokuState copyWith({
    List<List<Cell>>? board,
    Pos? selected,
    Set<Pos>? conflicts,
    bool? completed,
  }) {
    return SudokuState(
      board: board ?? this.board,
      selected: selected ?? this.selected,
      conflicts: conflicts ?? this.conflicts,
      completed: completed ?? this.completed,
    );
  }
}

class SudokuNotifier extends StateNotifier<SudokuState> {
  SudokuNotifier() : super(_initial());

  static SudokuState _initial() {
    final puzzle = _puzzle('easy');
    final board = List.generate(9, (r) => List.generate(9, (c) {
          final v = puzzle[r][c];
          return Cell(row: r, col: c, value: v, given: v != 0);
        }));
    return SudokuState(board: board, selected: null, conflicts: <Pos>{}, completed: false);
  }

  void newGame(String difficulty) {
    final puzzle = _puzzle(difficulty);
    final board = List.generate(9, (r) => List.generate(9, (c) {
          final v = puzzle[r][c];
          return Cell(row: r, col: c, value: v, given: v != 0);
        }));
    state = SudokuState(board: board, selected: null, conflicts: <Pos>{}, completed: false);
  }

  void select(int row, int col) {
    state = state.copyWith(selected: Pos(row, col));
  }

  void input(int number) {
    final sel = state.selected;
    if (sel == null) return;
    final r = sel.row;
    final c = sel.col;
    final cell = state.board[r][c];
    if (cell.given) return;

    final newBoard = _cloneBoard(state.board);
    newBoard[r][c] = newBoard[r][c].copyWith(value: number);
    final conflicts = _computeConflicts(newBoard, r, c);

    state = state.copyWith(board: newBoard, conflicts: conflicts, completed: _isComplete(newBoard) && conflicts.isEmpty);
  }

  void erase() {
    final sel = state.selected;
    if (sel == null) return;
    final r = sel.row;
    final c = sel.col;
    final cell = state.board[r][c];
    if (cell.given) return;
    final newBoard = _cloneBoard(state.board);
    newBoard[r][c] = newBoard[r][c].copyWith(value: 0);
    final conflicts = _computeConflicts(newBoard, r, c);
    state = state.copyWith(board: newBoard, conflicts: conflicts, completed: false);
  }

  void clearSelected() {
    state = state.copyWith(selected: null);
  }

  // Helpers
  static List<List<Cell>> _cloneBoard(List<List<Cell>> b) =>
      List.generate(9, (r) => List.generate(9, (c) => b[r][c]));

  static Set<Pos> _computeConflicts(List<List<Cell>> board, int r, int c) {
    final conflicts = <Pos>{};
    final v = board[r][c].value;
    if (v == 0) return conflicts;

    // row
    for (int cc = 0; cc < 9; cc++) {
      if (cc == c) continue;
      if (board[r][cc].value == v) {
        conflicts.add(Pos(r, c));
        conflicts.add(Pos(r, cc));
      }
    }
    // col
    for (int rr = 0; rr < 9; rr++) {
      if (rr == r) continue;
      if (board[rr][c].value == v) {
        conflicts.add(Pos(r, c));
        conflicts.add(Pos(rr, c));
      }
    }
    // box
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if (rr == r && cc == c) continue;
        if (board[rr][cc].value == v) {
          conflicts.add(Pos(r, c));
          conflicts.add(Pos(rr, cc));
        }
      }
    }
    return conflicts;
  }

  static bool _isComplete(List<List<Cell>> board) {
    for (final row in board) {
      for (final cell in row) {
        if (cell.value == 0) return false;
      }
    }
    return true;
  }

  static List<List<int>> _puzzle(String difficulty) {
    // Basit sabit örnekler; ileride gerçek üretici eklenebilir.
    const easy = [
      [0,0,0, 2,6,0, 7,0,1],
      [6,8,0, 0,7,0, 0,9,0],
      [1,9,0, 0,0,4, 5,0,0],

      [8,2,0, 1,0,0, 0,4,0],
      [0,0,4, 6,0,2, 9,0,0],
      [0,5,0, 0,0,3, 0,2,8],

      [0,0,9, 3,0,0, 0,7,4],
      [0,4,0, 0,5,0, 0,3,6],
      [7,0,3, 0,1,8, 0,0,0],
    ];
    const medium = easy; // şimdilik aynı
    const hard = easy; // şimdilik aynı
    switch (difficulty) {
      case 'medium':
        return medium;
      case 'hard':
        return hard;
      case 'easy':
      default:
        return easy;
    }
  }
}

final sudokuProvider = StateNotifierProvider<SudokuNotifier, SudokuState>((ref) => SudokuNotifier());
