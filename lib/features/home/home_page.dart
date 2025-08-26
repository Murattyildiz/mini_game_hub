import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Game Hub')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/sudoku'),
              icon: const Icon(Icons.grid_4x4),
              label: const Text('Sudoku'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/memory'),
              icon: const Icon(Icons.style),
              label: const Text('Kart Eşleştirme'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.go('/sos'),
              icon: const Icon(Icons.circle_outlined),
              label: const Text('SOS Oyunu'),
            ),
          ],
        ),
      ),
    );
  }
}
