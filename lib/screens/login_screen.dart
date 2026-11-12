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
  final _formScrollController = ScrollController();

  bool _createAccount = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _confirmationNeedsEmail = true;

  static const Map<String, Map<String, String>> _translations = {
    'de': {
      'email_confirmed': 'E-Mail erfolgreich bestätigt! Du kannst dich jetzt anmelden.',
      'invalid_email': 'Bitte gib eine gültige E-Mail-Adresse ein.',
      'registration_received': 'Registrierungsanfrage angenommen',
      'confirmation_instructions': 'Prüfe dein E-Mail-Postfach und bestätige deine Adresse über den Link. Sieh auch im Spam-Ordner nach.',
      'back_to_sign_in': 'Zur Anmeldung',
      'registration_success': 'Registrierung erfolgreich.',
      'email_already_registered': 'Diese E-Mail ist möglicherweise bereits registriert.',
      'weak_password': 'Das Passwort erfüllt die Sicherheitsanforderungen nicht.',
      'registration_failed': 'Die Registrierung konnte nicht abgeschlossen werden.',
      'auth_unavailable': 'Anmeldung derzeit nicht möglich. Bitte später erneut versuchen.',

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
      'email_confirmed': 'E-posta adresin doğrulandı! Artık giriş yapabilirsin.',
      'invalid_email': 'Lütfen geçerli bir e-posta adresi girin.',
      'registration_received': 'Kayıt isteği alındı',
      'confirmation_instructions': 'E-posta kutunuzu kontrol edin ve bağlantıyla adresinizi doğrulayın. Spam klasörünü de kontrol edin.',
      'back_to_sign_in': 'Giriş ekranına dön',
      'registration_success': 'Kayıt başarılı.',
      'email_already_registered': 'Bu e-posta zaten kayıtlı olabilir.',
      'weak_password': 'Şifre güvenlik gereksinimlerini karşılamıyor.',
      'registration_failed': 'Kayıt tamamlanamadı.',
      'auth_unavailable': 'İşlem şu anda yapılamıyor. Daha sonra tekrar deneyin.',

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
      'email_confirmed': 'Email confirmed successfully! You can now sign in.',
      'invalid_email': 'Please enter a valid email address.',
      'registration_received': 'Registration request received',
      'confirmation_instructions': 'Check your inbox and confirm your address using the link. Check your spam folder too.',
      'back_to_sign_in': 'Back to sign in',
      'registration_success': 'Registration successful.',
      'email_already_registered': 'This email may already be registered.',
      'weak_password': 'Password does not meet security requirements.',
      'registration_failed': 'Registration could not be completed.',
      'auth_unavailable': 'Authentication is temporarily unavailable. Please try again later.',

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
      'email_confirmed': 'Адрес электронной почты подтверждён! Теперь вы можете войти.',
      'invalid_email': 'Введите действительный адрес электронной почты.',
      'registration_received': 'Запрос на регистрацию принят',
      'confirmation_instructions': 'Проверьте почту и подтвердите адрес по ссылке. Проверьте папку «Спам».',
      'back_to_sign_in': 'Вернуться ко входу',
      'registration_success': 'Регистрация успешна.',
      'email_already_registered': 'Этот адрес, возможно, уже зарегистрирован.',
      'weak_password': 'Пароль не соответствует требованиям безопасности.',
      'registration_failed': 'Не удалось завершить регистрацию.',
      'auth_unavailable': 'Авторизация временно недоступна.',

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
      'email_confirmed': 'تم تأكيد بريدك الإلكتروني بنجاح! يمكنك الآن تسجيل الدخول.',
      'invalid_email': 'يرجى إدخال بريد إلكتروني صالح.',
      'registration_received': 'تم استلام طلب التسجيل',
      'confirmation_instructions': 'تحقق من بريدك الإلكتروني وأكد عنوانك عبر الرابط. تحقق أيضاً من مجلد الرسائل غير المرغوب فيها.',
      'back_to_sign_in': 'العودة إلى تسجيل الدخول',
      'registration_success': 'تم التسجيل بنجاح.',
      'email_already_registered': 'قد يكون هذا البريد مسجلاً بالفعل.',
      'weak_password': 'كلمة المرور لا تستوفي متطلبات الأمان.',
      'registration_failed': 'تعذر إكمال التسجيل.',
      'auth_unavailable': 'المصادقة غير متاحة حالياً.',

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
      'email_confirmed': 'Adres e-mail został potwierdzony! Możesz się teraz zalogować.',
      'invalid_email': 'Podaj prawidłowy adres e-mail.',
      'registration_received': 'Otrzymano zgłoszenie rejestracji',
      'confirmation_instructions': 'Sprawdź pocztę i potwierdź adres przez link. Sprawdź też spam.',
      'back_to_sign_in': 'Wróć do logowania',
      'registration_success': 'Rejestracja zakończona.',
      'email_already_registered': 'Ten adres może być już zarejestrowany.',
      'weak_password': 'Hasło nie spełnia wymagań bezpieczeństwa.',
      'registration_failed': 'Nie udało się zakończyć rejestracji.',
      'auth_unavailable': 'Logowanie jest chwilowo niedostępne.',

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
      'email_confirmed': '¡Correo electrónico confirmado! Ya puedes iniciar sesión.',
      'invalid_email': 'Introduce una dirección de correo válida.',
      'registration_received': 'Solicitud de registro recibida',
      'confirmation_instructions': 'Revisa tu correo y confirma la dirección mediante el enlace. Comprueba también el spam.',
      'back_to_sign_in': 'Volver al inicio de sesión',
      'registration_success': 'Registro completado.',
      'email_already_registered': 'Es posible que este correo ya esté registrado.',
      'weak_password': 'La contraseña no cumple los requisitos de seguridad.',
      'registration_failed': 'No se pudo completar el registro.',
      'auth_unavailable': 'La autenticación no está disponible.',

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
      'email_confirmed': 'Adresse e-mail confirmée ! Vous pouvez maintenant vous connecter.',
      'invalid_email': 'Saisissez une adresse e-mail valide.',
      'registration_received': 'Demande d’inscription reçue',
      'confirmation_instructions': 'Vérifiez votre boîte mail et confirmez votre adresse via le lien. Vérifiez aussi les spams.',
      'back_to_sign_in': 'Retour à la connexion',
      'registration_success': 'Inscription réussie.',
      'email_already_registered': 'Cette adresse est peut-être déjà enregistrée.',
      'weak_password': 'Le mot de passe ne respecte pas les exigences de sécurité.',
      'registration_failed': 'Impossible de terminer l’inscription.',
      'auth_unavailable': 'Authentification indisponible.',

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

  bool _validEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _formScrollController.dispose();
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
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                controller: _formScrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(28, 20, 28,
                    MediaQuery.viewInsetsOf(context).bottom > 0 ? 28 : 20),
                child: FocusTraversalGroup(
                  child: _showConfirmation
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.mark_email_read_outlined,
                                color: AppTheme.electricBlue, size: 76),
                            const SizedBox(height: 24),
                            Text(_t(languageCode, _confirmationNeedsEmail
                                    ? 'registration_received' : 'registration_success'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: foregroundColor,
                                    fontSize: 23, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 18),
                            if (_confirmationNeedsEmail)
                              Text(_t(languageCode, 'confirmation_instructions'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: secondaryColor, fontSize: 16)),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: () => setState(() {
                                _showConfirmation = false;
                                _createAccount = false;
                                _password.clear();
                              }),
                              child: Text(_t(languageCode, 'back_to_sign_in')),
                            ),
                          ],
                        )
                      : Column(
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
                        autofocus: false,
                        controller: _email,
                        scrollPadding: const EdgeInsets.only(bottom: 140),
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
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
                        scrollPadding: const EdgeInsets.only(bottom: 140),
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.visiblePassword,
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

                      if (auth.emailConfirmationSuccess) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              _t(languageCode, 'email_confirmed'),
                              style: TextStyle(color: foregroundColor),
                            )),
                            IconButton(
                              tooltip: 'OK',
                              onPressed: auth.dismissEmailConfirmationSuccess,
                              icon: Icon(Icons.close, color: foregroundColor),
                            ),
                          ]),
                        ),
                      ],

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
                                if (!_validEmail(_email.text.trim())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_t(languageCode, 'invalid_email'))),
                                  );
                                  return;
                                }
                                if (_password.text.length < 6) {
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
                                  if (!mounted) return;
                                  if (provider.registrationSubmitted) {
                                    setState(() {
                                      _showConfirmation = true;
                                      _confirmationNeedsEmail =
                                          provider.registrationNeedsConfirmation;
                                    });
                                  }
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
