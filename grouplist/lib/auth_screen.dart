// lib/auth_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Controladores para os campos de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Variáveis de estado da UI
  var _isLoginMode = true; // Alterna entre Login e Cadastro
  var _isLoading = false;

  void _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // Se o formulário não for válido, não faz nada
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // Modo Login
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Modo Cadastro
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      // Se chegou aqui, o login/cadastro foi bem sucedido.
      // O pop() volta para a tela anterior (newgroup).
      if (mounted) {
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro. Verifique suas credenciais.';
      if (e.code == 'weak-password') {
        message = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Este email já foi cadastrado.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email ou senha inválidos.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
       if(mounted) {
         setState(() => _isLoading = false);
       }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Login' : 'Criar Conta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty || !value.contains('@')) {
                      return 'Por favor, insira um email válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true, // Esconde a senha
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'A senha deve ter no mínimo 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: Text(_isLoginMode ? 'Entrar' : 'Criar Conta'),
                  ),
                if (!_isLoading)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode; // Inverte o modo
                      });
                    },
                    child: Text(
                      _isLoginMode
                          ? 'Não tem uma conta? Crie uma agora'
                          : 'Já tenho uma conta. Fazer Login',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}