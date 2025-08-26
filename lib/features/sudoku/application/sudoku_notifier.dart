import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Cell {
  final int row;
  final int col;
  final int value; // 0 = empty
  final bool given; // true if pre-filled
  final Set<int> notes; // candidate notes 1..9
  const Cell({required this.row, required this.col, required this.value, required this.given, this.notes = const {}});

  Cell copyWith({int? value, Set<int>? notes}) => Cell(
    row: row,
    col: col,
    value: value ?? this.value,
    given: given,
    notes: notes ?? this.notes,
  );
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
  final int elapsedSeconds;
  final int moves;
  final bool strictValidation; // reject invalid moves

  const SudokuState({
    required this.board,
    required this.selected,
    required this.conflicts,
    required this.completed,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.moves,
    required this.strictValidation,
  });

  SudokuState copyWith({
    List<List<Cell>>? board,
    Pos? selected,
    Set<Pos>? conflicts,
    bool? completed,
    String? difficulty,
    int? elapsedSeconds,
    int? moves,
    bool? strictValidation,
  }) {
    return SudokuState(
      board: board ?? this.board,
      selected: selected ?? this.selected,
      conflicts: conflicts ?? this.conflicts,
      completed: completed ?? this.completed,
      difficulty: difficulty ?? this.difficulty,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      moves: moves ?? this.moves,
      strictValidation: strictValidation ?? this.strictValidation,
    );
  }
}

class SudokuNotifier extends StateNotifier<SudokuState> {
  SudokuNotifier() : super(_initial()) {
    // keep a copy of the initial board for reset()
    _initialBoard = _cloneBoard(state.board);
    _startTimerIfNeeded();
  }

  // Undo/redo stacks store only the board snapshots
  final List<List<List<Cell>>> _undo = [];
  final List<List<List<Cell>>> _redo = [];
  late List<List<Cell>> _initialBoard; // for reset
  Timer? _timer;

  static SudokuState _initial() {
    final puzzle = _puzzle('easy');
    final board = List.generate(9, (r) => List.generate(9, (c) {
          final v = puzzle[r][c];
          return Cell(row: r, col: c, value: v, given: v != 0);
        }));
    return SudokuState(
      board: board,
      selected: null,
      conflicts: <Pos>{},
      completed: false,
      difficulty: 'easy',
      elapsedSeconds: 0,
      moves: 0,
      strictValidation: false,
    );
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
    state = SudokuState(
      board: board,
      selected: null,
      conflicts: <Pos>{},
      completed: false,
      difficulty: difficulty,
      elapsedSeconds: 0,
      moves: 0,
      strictValidation: false,
    );
    _restartTimer();
  }

  void toggleStrictValidation() {
    state = state.copyWith(strictValidation: !state.strictValidation);
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
    // strict validation: reject invalid move
    if (state.strictValidation && _hasConflictFor(newBoard, r, c, number)) {
      final Set<Pos> conflicts = { Pos(r, c) };
      for (int cc = 0; cc < 9; cc++) {
        if (cc != c && newBoard[r][cc].value == number) conflicts.add(Pos(r, cc));
      }
      for (int rr = 0; rr < 9; rr++) {
        if (rr != r && newBoard[rr][c].value == number) conflicts.add(Pos(rr, c));
      }
      final br = (r ~/ 3) * 3;
      final bc = (c ~/ 3) * 3;
      for (int rr = br; rr < br + 3; rr++) {
        for (int cc = bc; cc < bc + 3; cc++) {
          if (!(rr == r && cc == c) && newBoard[rr][cc].value == number) conflicts.add(Pos(rr, cc));
        }
      }
      state = state.copyWith(conflicts: conflicts, moves: state.moves + 1);
      return;
    }
    // set value; clear notes in this cell
    newBoard[r][c] = newBoard[r][c].copyWith(value: number, notes: const {});
    _removeNotesFromPeers(newBoard, r, c, number);
    final conflicts = _computeConflicts(newBoard, r, c);
    state = state.copyWith(
      board: newBoard,
      conflicts: conflicts,
      completed: _isComplete(newBoard) && conflicts.isEmpty,
      moves: state.moves + 1,
    );
    if (state.completed) {
      _timer?.cancel();
      _timer = null;
    }
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
    // clear value only
    newBoard[r][c] = newBoard[r][c].copyWith(value: 0);
    final conflicts = _computeConflicts(newBoard, r, c);
    state = state.copyWith(
      board: newBoard,
      conflicts: conflicts,
      completed: false,
      moves: state.moves + 1,
    );
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
      elapsedSeconds: 0,
      moves: 0,
      strictValidation: state.strictValidation,
    );
    _restartTimer();
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

  static bool _hasConflictFor(List<List<Cell>> b, int r, int c, int v) {
    // row
    for (int cc = 0; cc < 9; cc++) {
      if (cc == c) continue;
      if (b[r][cc].value == v) return true;
    }
    // col
    for (int rr = 0; rr < 9; rr++) {
      if (rr == r) continue;
      if (b[rr][c].value == v) return true;
    }
    // box
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if (rr == r && cc == c) continue;
        if (b[rr][cc].value == v) return true;
      }
    }
    return false;
  }

  // Remove placed value from notes of all peers (row/col/box)
  static void _removeNotesFromPeers(List<List<Cell>> b, int r, int c, int v) {
    // row
    for (int cc = 0; cc < 9; cc++) {
      if (cc == c) continue;
      final notes = b[r][cc].notes;
      if (notes.contains(v)) {
        final next = Set<int>.from(notes)..remove(v);
        b[r][cc] = b[r][cc].copyWith(notes: next);
      }
    }
    // col
    for (int rr = 0; rr < 9; rr++) {
      if (rr == r) continue;
      final notes = b[rr][c].notes;
      if (notes.contains(v)) {
        final next = Set<int>.from(notes)..remove(v);
        b[rr][c] = b[rr][c].copyWith(notes: next);
      }
    }
    // box
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int rr = br; rr < br + 3; rr++) {
      for (int cc = bc; cc < bc + 3; cc++) {
        if (rr == r && cc == c) continue;
        final notes = b[rr][cc].notes;
        if (notes.contains(v)) {
          final next = Set<int>.from(notes)..remove(v);
          b[rr][cc] = b[rr][cc].copyWith(notes: next);
        }
      }
    }
  }

  void _startTimerIfNeeded() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _startTimerIfNeeded();
  }

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

  // Count solutions up to a limit (used to enforce uniqueness during digging)
  static int _countSolutions(List<List<int>> start, int limit) {
    int solutions = 0;
    final g = List.generate(9, (r) => List<int>.from(start[r]));

    bool step(int idx) {
      if (solutions >= limit) return true; // early stop
      if (idx == 81) {
        solutions++;
        return solutions >= limit;
      }
      final r = idx ~/ 9;
      final c = idx % 9;
      if (g[r][c] != 0) return step(idx + 1);
      for (int v = 1; v <= 9; v++) {
        if (_canPlace(g, r, c, v)) {
          g[r][c] = v;
          final stop = step(idx + 1);
          g[r][c] = 0;
          if (stop) return true;
        }
      }
      return false;
    }

    step(0);
    return solutions;
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
      final backup = puzzle[r][c];
      puzzle[r][c] = 0;
      // enforce uniqueness: if more than 1 solution, revert
      final count = _countSolutions(puzzle, 2);
      if (count != 1) {
        puzzle[r][c] = backup;
        continue;
      }
      filled--;
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

  // (Hint and Pencil Mode removed)

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sudokuProvider = StateNotifierProvider<SudokuNotifier, SudokuState>((ref) => SudokuNotifier());
