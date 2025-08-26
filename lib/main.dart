import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/home/home_page.dart';
import 'features/sudoku/sudoku_page.dart';
import 'features/memory/memory_page.dart';
import 'features/sos/sos_page.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/sudoku',
          builder: (context, state) => const SudokuPage(),
        ),
        GoRoute(
          path: '/memory',
          builder: (context, state) => const MemoryGamePage(),
        ),
        GoRoute(
          path: '/sos',
          builder: (context, state) => const SOSGamePage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Mini Game Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
