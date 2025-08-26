import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

enum MemoryDifficulty { easy, medium, hard }

class MemoryGameResult {
  final MemoryDifficulty difficulty;
  final int timeSeconds;
  final int moves;
  final bool success;
  final int timestampMs;
  final int bonus; // challenge bonus points (if any)

  MemoryGameResult({
    required this.difficulty,
    required this.timeSeconds,
    required this.moves,
    required this.success,
    required this.timestampMs,
    this.bonus = 0,
  });

  Map<String, dynamic> toMap() => {
        'difficulty': difficulty.name,
        'timeSeconds': timeSeconds,
        'moves': moves,
        'success': success,
        'timestampMs': timestampMs,
        'bonus': bonus,
        'platform': defaultTargetPlatform.name,
      };
}

class MemoryLeaderboardEntry {
  final String id;
  final String difficulty;
  final int timeSeconds;
  final int moves;
  final int bonus;
  final int timestampMs;

  MemoryLeaderboardEntry({
    required this.id,
    required this.difficulty,
    required this.timeSeconds,
    required this.moves,
    required this.bonus,
    required this.timestampMs,
  });

  factory MemoryLeaderboardEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MemoryLeaderboardEntry(
      id: doc.id,
      difficulty: (d['difficulty'] ?? '').toString(),
      timeSeconds: (d['timeSeconds'] ?? 0) as int,
      moves: (d['moves'] ?? 0) as int,
      bonus: (d['bonus'] ?? 0) as int,
      timestampMs: (d['timestampMs'] ?? 0) as int,
    );
  }
}

class MemoryStatsRepo {
  static const _prefPrefix = 'memory.stats.';
  static const _playsKey = '${_prefPrefix}plays.'; // + difficulty
  static const _bestTimeKey = '${_prefPrefix}best.time.'; // + difficulty
  static const _bestMovesKey = '${_prefPrefix}best.moves.'; // + difficulty

  final FirebaseFirestore? _firestore;
  MemoryStatsRepo._(this._firestore);

  static Future<MemoryStatsRepo> create() async {
    FirebaseFirestore? fs;
    try {
      if (Firebase.apps.isNotEmpty) {
        fs = FirebaseFirestore.instance;
      }
    } catch (_) {}
    return MemoryStatsRepo._(fs);
  }

  String _diff(MemoryDifficulty d) => d.name;

  Future<void> recordGameResult(MemoryGameResult r) async {
    final sp = await SharedPreferences.getInstance();
    final d = _diff(r.difficulty);

    // Update local plays count
    final plays = sp.getInt(_playsKey + d) ?? 0;
    await sp.setInt(_playsKey + d, plays + 1);

    // Update bests only on success
    if (r.success) {
      final bestT = sp.getInt(_bestTimeKey + d);
      final bestM = sp.getInt(_bestMovesKey + d);
      if (bestT == null || r.timeSeconds < bestT) {
        await sp.setInt(_bestTimeKey + d, r.timeSeconds);
      }
      if (bestM == null || r.moves < bestM) {
        await sp.setInt(_bestMovesKey + d, r.moves);
      }
    }

    // Push to Firestore if available and success
    if (_firestore != null && r.success) {
      try {
        await _firestore.collection('memory_leaderboard').add(r.toMap());
      } catch (_) {
        // ignore failures
      }
    }
  }

  Future<int?> getBestTime(MemoryDifficulty d) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_bestTimeKey + _diff(d));
  }

  Future<int?> getBestMoves(MemoryDifficulty d) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_bestMovesKey + _diff(d));
  }

  Future<int> getPlayCount(MemoryDifficulty d) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_playsKey + _diff(d)) ?? 0;
  }

  Stream<List<MemoryLeaderboardEntry>> leaderboard(MemoryDifficulty d, {int limit = 20}) {
    if (_firestore == null) {
      return const Stream<List<MemoryLeaderboardEntry>>.empty();
    }
    return _firestore
        .collection('memory_leaderboard')
        .where('difficulty', isEqualTo: d.name)
        .orderBy('timeSeconds')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(MemoryLeaderboardEntry.fromDoc).toList());
  }
}
