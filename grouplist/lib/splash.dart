// lib/splash.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'main.dart'; // Importa a HomeScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navega para a HomeScreen após um curto período, sempre.
    Timer(
      const Duration(seconds: 2),
      () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset('assets/animations/loadingsticks.json'),
      ),
    );
  }
}