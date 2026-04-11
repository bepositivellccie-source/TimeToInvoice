import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Remplace par ton Web Client ID Google Cloud Console ──────────────────────
// APIs & Services → Credentials → OAuth 2.0 Client IDs → type "Web application"
const _kGoogleWebClientId =
    '387018121799-1qrhir98b9hqpi1m5196s0rdl1nc0kv3.apps.googleusercontent.com';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Traduction des erreurs Supabase ──────────────────────────────────────
  String _translateError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('email rate limit')) {
      return 'Trop de tentatives. Attendez 1 minute avant de réessayer.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Vérifiez votre boîte mail pour confirmer votre compte.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn(serverClientId: _kGoogleWebClientId);
      final account = await googleSignIn.signIn();
      if (account == null) {
        // Utilisateur a annulé
        setState(() => _googleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null) {
        setState(() {
          _error = 'Impossible de récupérer le token Google. Réessayez.';
          _googleLoading = false;
        });
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      // Le router réagit automatiquement via authStateProvider
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e));
    } catch (_) {
      setState(() => _error = 'Connexion Google échouée. Réessayez.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── Email / Password ──────────────────────────────────────────────────────
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
      setState(() => _error = _translateError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() =>
          _error = 'Entrez votre email pour réinitialiser le mot de passe.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lien envoyé. Vérifiez votre boîte mail.')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // ── Logo + tagline ───────────────────────────────────────
                  Text(
                    'TimeToInvoice',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Timer → Facture conforme FR en 1 tap.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Bouton Google ────────────────────────────────────────
                  _GoogleButton(
                    loading: _googleLoading,
                    onPressed: _signInWithGoogle,
                  ),
                  const SizedBox(height: 20),

                  // ── Séparateur — ou — ────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Email ────────────────────────────────────────────────
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Mot de passe ─────────────────────────────────────────
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  // ── Mot de passe oublié ──────────────────────────────────
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Mot de passe oublié ?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),

                  // ── Erreur ───────────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Bouton Se connecter / Créer un compte ────────────────
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isSignUp ? 'Créer un compte' : 'Se connecter',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // ── Toggle inscription / connexion ───────────────────────
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Déjà un compte ? Se connecter'
                            : "Pas de compte ? S'inscrire",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton Google officiel ─────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF374151),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF374151)),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleLogo(),
                const SizedBox(width: 12),
                const Text(
                  'Continuer avec Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Logo Google en SVG-like via CustomPaint
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..style = PaintingStyle.fill;

    // Bleu (bas gauche)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      2.356, // 135°
      1.571, // 90°
      true,
      paint,
    );

    // Rouge (haut gauche)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      3.927, // 225°
      1.571,
      true,
      paint,
    );

    // Jaune (haut droite)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      5.498, // 315°
      0.785, // 45°
      true,
      paint,
    );

    // Vert (bas droite)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, s, s),
      6.283, // 0° = 360°
      1.178, // ~67.5°
      true,
      paint,
    );

    // Centre blanc
    paint.color = Colors.white;
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.33, paint);

    // Barre horizontale bleue (partie "G")
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.42, s * 0.42, s * 0.16),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
