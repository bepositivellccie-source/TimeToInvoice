import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo / titre
              Text(
                'TimeToInvoice',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Timer → Facture conforme FR en 1 tap.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 40),
              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              // Password
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              // Submit button
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isSignUp ? 'Créer un compte' : 'Se connecter'),
              ),
              const SizedBox(height: 16),
              // Toggle sign-up / login
              Center(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Déjà un compte ? Se connecter'
                        : 'Pas de compte ? S\'inscrire',
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
