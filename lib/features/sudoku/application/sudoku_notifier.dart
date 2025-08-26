import 'package:flutter/foundation.dart';
import 'dart:math';
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
  final String difficulty;

  const SudokuState({
    required this.board,
    required this.selected,
    required this.conflicts,
    required this.completed,
    required this.difficulty,
  });

  SudokuState copyWith({
    List<List<Cell>>? board,
    Pos? selected,
    Set<Pos>? conflicts,
    bool? completed,
    String? difficulty,
  }) {
    return SudokuState(
      board: board ?? this.board,
      selected: selected ?? this.selected,
      conflicts: conflicts ?? this.conflicts,
      completed: completed ?? this.completed,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

class SudokuNotifier extends StateNotifier<SudokuState> {
  SudokuNotifier() : super(_initial()) {
    // keep a copy of the initial board for reset()
    _initialBoard = _cloneBoard(state.board);
  }

  // Undo/redo stacks store only the board snapshots
  final List<List<List<Cell>>> _undo = [];
  final List<List<List<Cell>>> _redo = [];
  late List<List<Cell>> _initialBoard; // for reset

  static SudokuState _initial() {
    final puzzle = _puzzle('easy');
    final board = List.generate(9, (r) => List.generate(9, (c) {
          final v = puzzle[r][c];
          return Cell(row: r, col: c, value: v, given: v != 0);
        }));
    return SudokuState(board: board, selected: null, conflicts: <Pos>{}, completed: false, difficulty: 'easy');
  }

  void newGame(String difficulty) {
    final puzzle = _puzzle(difficulty);
    final board = List.generate(9, (r) => List.generate(9, (c) {
          final v = puzzle[r][c];
          return Cell(row: r, col: c, value: v, given: v != 0);
        }));
    _undo.clear();
    _redo.clear();
    _initialBoard = _cloneBoard(board);
    state = SudokuState(board: board, selected: null, conflicts: <Pos>{}, completed: false, difficulty: difficulty);
  }

  void select(int row, int col) {
    final conflicts = _computeConflicts(state.board, row, col);
    state = state.copyWith(selected: Pos(row, col), conflicts: conflicts, completed: _isComplete(state.board) && conflicts.isEmpty);
  }

  void input(int number) {
    final sel = state.selected;
    if (sel == null) return;
    final r = sel.row;
    final c = sel.col;
    final cell = state.board[r][c];
    if (cell.given) return;

    _undo.add(_cloneBoard(state.board));
    _redo.clear();

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
    _undo.add(_cloneBoard(state.board));
    _redo.clear();

    final newBoard = _cloneBoard(state.board);
    newBoard[r][c] = newBoard[r][c].copyWith(value: 0);
    final conflicts = _computeConflicts(newBoard, r, c);
    state = state.copyWith(board: newBoard, conflicts: conflicts, completed: false);
  }

  void clearSelected() {
    state = state.copyWith(selected: null);
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_cloneBoard(state.board));
    final prev = _undo.removeLast();
    final sel = state.selected;
    final conflicts = sel != null ? _computeConflicts(prev, sel.row, sel.col) : <Pos>{};
    state = state.copyWith(
      board: prev,
      conflicts: conflicts,
      completed: _isComplete(prev) && conflicts.isEmpty,
    );
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_cloneBoard(state.board));
    final next = _redo.removeLast();
    final sel = state.selected;
    final conflicts = sel != null ? _computeConflicts(next, sel.row, sel.col) : <Pos>{};
    state = state.copyWith(
      board: next,
      conflicts: conflicts,
      completed: _isComplete(next) && conflicts.isEmpty,
    );
  }

  void reset() {
    _undo.clear();
    _redo.clear();
    final board = _cloneBoard(_initialBoard);
    state = SudokuState(
      board: board,
      selected: null,
      conflicts: <Pos>{},
      completed: false,
      difficulty: state.difficulty,
    );
  }

  void moveSelection(int dr, int dc) {
    final sel = state.selected ?? const Pos(0, 0);
    int r = (sel.row + dr).clamp(0, 8).toInt();
    int c = (sel.col + dc).clamp(0, 8).toInt();
    select(r, c);
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

  // -------- Puzzle generator (simple backtracking) --------
  static List<List<int>> _generateSolved(Random rnd) {
    final grid = List.generate(9, (_) => List.filled(9, 0));

    bool solve(int r, int c) {
      if (r == 9) return true;
      final nr = c == 8 ? r + 1 : r;
      final nc = c == 8 ? 0 : c + 1;

      final nums = List<int>.generate(9, (i) => i + 1)..shuffle(rnd);
      for (final v in nums) {
        if (_canPlace(grid, r, c, v)) {
          grid[r][c] = v;
          if (solve(nr, nc)) return true;
          grid[r][c] = 0;
        }
      }
      return false;
    }

    solve(0, 0);
    return grid;
  }

  static bool _canPlace(List<List<int>> g, int r, int c, int v) {
    for (int i = 0; i < 9; i++) {
      if (g[r][i] == v || g[i][c] == v) return false;
    }
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if (g[rr][cc] == v) return false;
      }
    }
    return true;
  }

  static List<List<int>> _digHoles(List<List<int>> solved, int clues, Random rnd) {
    final puzzle = List.generate(9, (r) => List<int>.from(solved[r]));
    int filled = 81; // start from full grid
    final positions = [for (int i = 0; i < 81; i++) i]..shuffle(rnd);
    for (final p in positions) {
      if (filled <= clues) break;
      final r = p ~/ 9;
      final c = p % 9;
      if (puzzle[r][c] == 0) continue;
      puzzle[r][c] = 0;
      filled--;
      // NOTE: uniqueness not enforced for speed; acceptable for casual play
      // To enforce uniqueness, we would implement a solver counting solutions.
    }
    return puzzle;
  }

  static List<List<int>> _puzzle(String difficulty) {
    final rnd = Random();
    // approximate clue counts; easy has more givens
    final clues = switch (difficulty) {
      'hard' => 28,
      'medium' => 34,
      _ => 44, // easy/default
    };
    final solved = _generateSolved(rnd);
    final puzzle = _digHoles(solved, clues, rnd);
    return puzzle;
  }
}

final sudokuProvider = StateNotifierProvider<SudokuNotifier, SudokuState>((ref) => SudokuNotifier());
