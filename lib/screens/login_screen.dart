
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _createAccount = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.play_circle_filled_rounded,
                    color: AppTheme.electricBlue,
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'STREAMIA PLAYER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _createAccount
                        ? 'Konto erstellen'
                        : 'Anmelden',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    autofocus: true,
                    controller: _email,
                    keyboardType:
                        TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _decoration(
                      'E-Mail-Adresse',
                      Icons.email_outlined,
                    ).copyWith(
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.electricBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: !_showPassword,
                    autofillHints: const [
                      AutofillHints.password,
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _decoration(
                      'Passwort',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showPassword =
                                !_showPassword;
                          });
                        },
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: auth.isBusy
                        ? null
                        : () async {
                            if (_email.text
                                    .trim()
                                    .isEmpty ||
                                _password.text.length <
                                    6) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bitte E-Mail und ein '
                                    'Passwort mit mindestens '
                                    '6 Zeichen eingeben.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final provider =
                                context.read<
                                    AuthProvider>();

                            if (_createAccount) {
                              await provider.signUp(
                                _email.text,
                                _password.text,
                              );
                            } else {
                              await provider.signIn(
                                _email.text,
                                _password.text,
                              );
                            }

                            // StreamiaApp observes
                            // AuthProvider and advances
                            // to the setup flow.
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTheme.electricBlue,
                      overlayColor: Colors.white24,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                    child: auth.isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _createAccount
                                ? 'KONTO ERSTELLEN'
                                : 'ANMELDEN',
                          ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.white70,
                      overlayColor:
                          AppTheme.electricBlue
                              .withValues(
                        alpha: 0.28,
                      ),
                    ),
                    onPressed: auth.isBusy
                        ? null
                        : () {
                            setState(() {
                              _createAccount =
                                  !_createAccount;
                            });
                          },
                    child: Text(
                      _createAccount
                          ? 'Ich habe bereits ein '
                              'Konto – anmelden'
                          : 'Noch kein Konto? '
                              'Jetzt registrieren',
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Streamia Player stellt keine '
                    'Sender, Streams, Playlists oder '
                    'Abonnements bereit. Füge nur '
                    'Inhalte hinzu, zu deren Nutzung '
                    'du berechtigt bist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white60,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white54,
      ),
      filled: true,
      fillColor: AppTheme.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
