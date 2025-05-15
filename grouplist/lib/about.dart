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
        backgroundColor: Colors.deepPurple.shade200,
        
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Group List',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            Text('© 2025 GroupList', style: TextStyle(color: Colors.deepPurple)),
            SizedBox(height: 24),
            Icon(Icons.check_box, size: 64, color: Colors.deepPurple),
            SizedBox(height: 24),
            Text('Diego Moreira', style: TextStyle(color: Colors.deepPurple)),
            Text('Iago Fereguetti', style: TextStyle(color: Colors.deepPurple)),
            Text('Luan Barbosa', style: TextStyle(color: Colors.deepPurple)),
            Text('Lucas Hauck', style: TextStyle(color: Colors.deepPurple)),
          ],
        ),
      ),
      
    );
  }
}