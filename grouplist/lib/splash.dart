import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'main.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Tempo de exibição do splash
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ou qualquer cor de fundo
      body: Center(
        child: Lottie.asset('assets/animations/loadingsticks.json'),
      ),
    );
  }
}
