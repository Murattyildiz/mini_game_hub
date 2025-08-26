import 'package:flutter/material.dart';

class SOSGamePage extends StatelessWidget {
  const SOSGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Oyunu')),
      body: const Center(
        child: Text('3x3/5x5 grid ve sıra mantığı burada olacak.'),
      ),
    );
  }
}
