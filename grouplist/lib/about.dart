import 'package:flutter/material.dart';

void main() {
  runApp(const GroupListApp());
}

class GroupListApp extends StatelessWidget {
  const GroupListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AboutPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sobre"),
        centerTitle: true,
        
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Group List',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('© 2025 GroupList'),
            SizedBox(height: 24),
            Icon(Icons.check_box, size: 64),
            SizedBox(height: 24),
            Text('Diego Moreira'),
            Text('Iago Fereguetti'),
            Text('Luan Barbosa'),
            Text('Lucas Hauck'),
          ],
        ),
      ),
      
    );
  }
}