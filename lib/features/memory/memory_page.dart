import 'package:flutter/material.dart';

class MemoryGamePage extends StatelessWidget {
  const MemoryGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kart Eşleştirme')),
      body: const Center(
        child: Text('Kart grid ve animasyonlar burada olacak.'),
      ),
    );
  }
}
