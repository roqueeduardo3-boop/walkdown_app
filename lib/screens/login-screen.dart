import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walkdown_app/config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. FAZER LOGIN NO FIREBASE
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = credential.user;

      // 2. VERIFICAR SE É DEV E SE EMAIL É PERMITIDO
      if (kUseDevFirebase) {
        if (!isEmailAllowedInDev(user?.email)) {
          // ❌ EMAIL NÃO AUTORIZADO NO DEV
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;
          setState(() {
            _error = '🚫 Acesso DEV bloqueado!\n\n'
                'Apenas estes emails podem entrar:\n'
                '${allowedDevEmails.join('\n')}';
          });
          return;
        }

        // ✅ EMAIL AUTORIZADO NO DEV
        print('✅ DEV: Email autorizado - ${user?.email}');
      }

      // 3. LOGIN ACEITE - Navigator vai detectar automaticamente via StreamBuilder
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'user-not-found') {
          _error = '❌ Utilizador não encontrado';
        } else if (e.code == 'wrong-password') {
          _error = '❌ Password incorreta';
        } else if (e.code == 'invalid-email') {
          _error = '❌ Email inválido';
        } else {
          _error = '❌ Erro: ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '❌ Erro: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(kUseDevFirebase ? '🧪 Walkdown DEV' : '🚀 Walkdown App'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  'assets/1logo_2ws.png',
                  height: 100,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.wind_power, size: 80),
                ),
                const SizedBox(height: 32),

                // TÍTULO
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // INDICADOR DEV/PROD
                if (kUseDevFirebase)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Modo DEV',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // EMAIL
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // PASSWORD
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 24),

                // ERRO
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_error != null) const SizedBox(height: 16),

                // BOTÃO LOGIN
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C7CBA),
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                // INFO DEV
                if (kUseDevFirebase) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Emails autorizados no DEV:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...allowedDevEmails.map((email) => Padding(
                              padding: const EdgeInsets.only(left: 20, top: 2),
                              child: Text(
                                '• $email',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
