import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
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

  static const Map<String, Map<String, String>> _translations = {
    'de': {
      'invalid_credentials': 'E-Mail-Adresse oder Passwort ist falsch.',
      'email_not_confirmed': 'Bitte bestätige zuerst deine E-Mail-Adresse.',
      'too_many_requests': 'Zu viele Versuche. Bitte versuche es später erneut.',

      'signIn': 'Anmelden',
      'createAccount': 'Konto erstellen',
      'email': 'E-Mail-Adresse',
      'password': 'Passwort',
      'signInButton': 'ANMELDEN',
      'registerButton': 'KONTO ERSTELLEN',
      'registerLink': 'Noch kein Konto? Jetzt registrieren',
      'signInLink': 'Ich habe bereits ein Konto – anmelden',
      'validation':
          'Bitte E-Mail und ein Passwort mit mindestens 6 Zeichen eingeben.',
      'disclaimer':
          'Streamia Player stellt keine Sender, Streams, Playlists oder Abonnements bereit. Füge nur Inhalte hinzu, zu deren Nutzung du berechtigt bist.',
      'showPassword': 'Passwort anzeigen',
      'hidePassword': 'Passwort verbergen',
    },
    'tr': {
      'invalid_credentials': 'E-posta adresi veya şifre hatalı.',
      'email_not_confirmed': 'Lütfen önce e-posta adresinizi doğrulayın.',
      'too_many_requests': 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.',

      'signIn': 'Giriş yap',
      'createAccount': 'Hesap oluştur',
      'email': 'E-posta adresi',
      'password': 'Şifre',
      'signInButton': 'GİRİŞ YAP',
      'registerButton': 'HESAP OLUŞTUR',
      'registerLink': 'Hesabınız yok mu? Şimdi kayıt olun',
      'signInLink': 'Zaten hesabım var – giriş yap',
      'validation':
          'Lütfen e-posta adresinizi ve en az 6 karakterli bir şifre girin.',
      'disclaimer':
          'Streamia Player kanal, yayın, oynatma listesi veya abonelik sağlamaz. Yalnızca kullanma hakkına sahip olduğunuz içerikleri ekleyin.',
      'showPassword': 'Şifreyi göster',
      'hidePassword': 'Şifreyi gizle',
    },
    'en': {
      'invalid_credentials': 'Incorrect email address or password.',
      'email_not_confirmed': 'Please confirm your email address first.',
      'too_many_requests': 'Too many attempts. Please try again later.',

      'signIn': 'Sign in',
      'createAccount': 'Create account',
      'email': 'Email address',
      'password': 'Password',
      'signInButton': 'SIGN IN',
      'registerButton': 'CREATE ACCOUNT',
      'registerLink': 'No account yet? Register now',
      'signInLink': 'Already have an account? Sign in',
      'validation':
          'Please enter your email and a password with at least 6 characters.',
      'disclaimer':
          'Streamia Player does not provide channels, streams, playlists or subscriptions. Only add content you are authorized to use.',
      'showPassword': 'Show password',
      'hidePassword': 'Hide password',
    },
    'ru': {
      'invalid_credentials': 'Неверный адрес электронной почты или пароль.',
      'email_not_confirmed': 'Сначала подтвердите адрес электронной почты.',
      'too_many_requests': 'Слишком много попыток. Повторите позже.',

      'signIn': 'Войти',
      'createAccount': 'Создать аккаунт',
      'email': 'Электронная почта',
      'password': 'Пароль',
      'signInButton': 'ВОЙТИ',
      'registerButton': 'СОЗДАТЬ АККАУНТ',
      'registerLink': 'Нет аккаунта? Зарегистрироваться',
      'signInLink': 'Уже есть аккаунт? Войти',
      'validation':
          'Введите адрес электронной почты и пароль длиной не менее 6 символов.',
      'disclaimer':
          'Streamia Player не предоставляет каналы, потоки, плейлисты или подписки. Добавляйте только контент, на использование которого у вас есть права.',
      'showPassword': 'Показать пароль',
      'hidePassword': 'Скрыть пароль',
    },
    'ar': {
      'invalid_credentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'email_not_confirmed': 'يرجى تأكيد بريدك الإلكتروني أولاً.',
      'too_many_requests': 'محاولات كثيرة جدًا. حاول مرة أخرى لاحقًا.',

      'signIn': 'تسجيل الدخول',
      'createAccount': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'signInButton': 'تسجيل الدخول',
      'registerButton': 'إنشاء حساب',
      'registerLink': 'ليس لديك حساب؟ سجل الآن',
      'signInLink': 'لديك حساب بالفعل؟ تسجيل الدخول',
      'validation':
          'يرجى إدخال بريدك الإلكتروني وكلمة مرور لا تقل عن 6 أحرف.',
      'disclaimer':
          'لا يوفر Streamia Player قنوات أو بثًا أو قوائم تشغيل أو اشتراكات. أضف فقط المحتوى الذي تملك حق استخدامه.',
      'showPassword': 'إظهار كلمة المرور',
      'hidePassword': 'إخفاء كلمة المرور',
    },
    'pl': {
      'invalid_credentials': 'Nieprawidłowy adres e-mail lub hasło.',
      'email_not_confirmed': 'Najpierw potwierdź swój adres e-mail.',
      'too_many_requests': 'Zbyt wiele prób. Spróbuj ponownie później.',

      'signIn': 'Zaloguj się',
      'createAccount': 'Utwórz konto',
      'email': 'Adres e-mail',
      'password': 'Hasło',
      'signInButton': 'ZALOGUJ SIĘ',
      'registerButton': 'UTWÓRZ KONTO',
      'registerLink': 'Nie masz konta? Zarejestruj się',
      'signInLink': 'Masz już konto? Zaloguj się',
      'validation':
          'Podaj adres e-mail i hasło składające się z co najmniej 6 znaków.',
      'disclaimer':
          'Streamia Player nie udostępnia kanałów, transmisji, playlist ani subskrypcji. Dodawaj wyłącznie treści, do których masz prawa.',
      'showPassword': 'Pokaż hasło',
      'hidePassword': 'Ukryj hasło',
    },
    'es': {
      'invalid_credentials': 'Correo electrónico o contraseña incorrectos.',
      'email_not_confirmed': 'Confirma primero tu correo electrónico.',
      'too_many_requests': 'Demasiados intentos. Inténtalo más tarde.',

      'signIn': 'Iniciar sesión',
      'createAccount': 'Crear cuenta',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'signInButton': 'INICIAR SESIÓN',
      'registerButton': 'CREAR CUENTA',
      'registerLink': '¿No tienes cuenta? Regístrate',
      'signInLink': '¿Ya tienes cuenta? Inicia sesión',
      'validation':
          'Introduce tu correo electrónico y una contraseña de al menos 6 caracteres.',
      'disclaimer':
          'Streamia Player no proporciona canales, transmisiones, listas de reproducción ni suscripciones. Añade únicamente contenido que tengas derecho a utilizar.',
      'showPassword': 'Mostrar contraseña',
      'hidePassword': 'Ocultar contraseña',
    },
    'fr': {
      'invalid_credentials': 'Adresse e-mail ou mot de passe incorrect.',
      'email_not_confirmed': 'Veuillez d’abord confirmer votre adresse e-mail.',
      'too_many_requests': 'Trop de tentatives. Réessayez plus tard.',

      'signIn': 'Se connecter',
      'createAccount': 'Créer un compte',
      'email': 'Adresse e-mail',
      'password': 'Mot de passe',
      'signInButton': 'SE CONNECTER',
      'registerButton': 'CRÉER UN COMPTE',
      'registerLink': 'Pas encore de compte ? Inscrivez-vous',
      'signInLink': 'Déjà un compte ? Connectez-vous',
      'validation':
          'Saisissez votre adresse e-mail et un mot de passe d’au moins 6 caractères.',
      'disclaimer':
          'Streamia Player ne fournit aucune chaîne, aucun flux, aucune playlist ni aucun abonnement. Ajoutez uniquement du contenu que vous êtes autorisé à utiliser.',
      'showPassword': 'Afficher le mot de passe',
      'hidePassword': 'Masquer le mot de passe',
    },
  };

  String _t(String languageCode, String key) {
    return _translations[languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    String label,
    IconData icon,
    Color surfaceColor,
    Color foregroundColor,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: foregroundColor.withValues(alpha: 0.65),
      ),
      prefixIcon: Icon(
        icon,
        color: foregroundColor.withValues(alpha: 0.60),
      ),
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.electricBlue,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    final languageCode = localeProvider.locale.languageCode;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor =
        isDark ? AppTheme.darkBg : const Color(0xFFF3F6FB);

    final surfaceColor =
        isDark ? AppTheme.darkSurface : Colors.white;

    final foregroundColor =
        isDark ? Colors.white : const Color(0xFF152238);

    final secondaryColor =
        isDark ? Colors.white70 : const Color(0xFF53647A);

    final hintColor =
        isDark ? Colors.white38 : const Color(0xFF64748B);

    final isArabic = languageCode == 'ar';

    return Directionality(
      textDirection:
          isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: FocusTraversalGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.play_circle_filled_rounded,
                        color: AppTheme.electricBlue,
                        size: 72,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'STREAMIA PLAYER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _t(
                          languageCode,
                          _createAccount
                              ? 'createAccount'
                              : 'signIn',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 28),

                      TextField(
                        autofocus: true,
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                        style: TextStyle(
                          color: foregroundColor,
                        ),
                        decoration: _decoration(
                          _t(languageCode, 'email'),
                          Icons.email_outlined,
                          surfaceColor,
                          foregroundColor,
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [
                          AutofillHints.password,
                        ],
                        style: TextStyle(
                          color: foregroundColor,
                        ),
                        decoration: _decoration(
                          _t(languageCode, 'password'),
                          Icons.lock_outline,
                          surfaceColor,
                          foregroundColor,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: _t(
                              languageCode,
                              _showPassword
                                  ? 'hidePassword'
                                  : 'showPassword',
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: hintColor,
                            ),
                          ),
                        ),
                      ),

                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _t(languageCode, auth.error!),
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
                                if (_email.text.trim().isEmpty ||
                                    _password.text.length < 6) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _t(
                                          languageCode,
                                          'validation',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final provider =
                                    context.read<AuthProvider>();

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
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.electricBlue,
                          foregroundColor: Colors.white,
                          overlayColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                        ),
                        child: auth.isBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _t(
                                  languageCode,
                                  _createAccount
                                      ? 'registerButton'
                                      : 'signInButton',
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),

                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryColor,
                          overlayColor:
                              AppTheme.electricBlue.withValues(
                            alpha: 0.20,
                          ),
                        ),
                        onPressed: auth.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _createAccount = !_createAccount;
                                });
                              },
                        child: Text(
                          _t(
                            languageCode,
                            _createAccount
                                ? 'signInLink'
                                : 'registerLink',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _t(languageCode, 'disclaimer'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
