
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPeriod = 1;
  int _selectedTier = 1;

  static const List<List<double>> _prices = [
    [4.99, 9.99, 14.99],
    [39.99, 79.99, 119.99],
    [149.99, 249.99, 349.99],
  ];

  static const Map<String, Map<String, String>> _translations = {
    'de': {
      'title': 'Auf Pro upgraden',
      'inactive': 'Zugriff derzeit nicht aktiv',
      'description':
          'Für dieses Gerät liegt derzeit keine gültige Testphase oder Freischaltung vor. Die Tarifauswahl ist eine Vorschau; ein echter Zahlungsvorgang ist noch nicht angebunden.',
      'monthly': 'Monatlich',
      'yearly': 'Jährlich',
      'lifetime': 'Lebenslang',
      'device': 'Gerät',
      'devices': 'Geräte',
      'popular': 'Beliebt',
      'total': 'Gesamtpreis',
      'subscribe': 'JETZT ABONNIEREN',
      'paymentUnavailable':
          'Zahlungen sind in dieser Version noch nicht verfügbar.',
      'paymentNotice':
          'Keine Zahlung wird ausgelöst. Eine Freischaltung erfolgt erst nach serverseitiger Zahlungsbestätigung.',
      'month': '/Monat',
      'year': '/Jahr',
      'once': 'einmalig',
      'logout': 'Abmelden',
      'logoutQuestion': 'Abmelden?',
      'logoutConfirm': 'Möchtest du dich wirklich abmelden?',
      'cancel': 'Abbrechen',
    },
    'tr': {
      'title': "Pro'ya yükselt",
      'inactive': 'Erişim şu anda aktif değil',
      'description':
          'Bu cihaz için geçerli bir deneme süresi veya erişim yetkisi bulunmuyor. Paket seçimi önizlemedir; ödeme sistemi henüz bağlı değildir.',
      'monthly': 'Aylık',
      'yearly': 'Yıllık',
      'lifetime': 'Ömür boyu',
      'device': 'Cihaz',
      'devices': 'Cihaz',
      'popular': 'Popüler',
      'total': 'Toplam fiyat',
      'subscribe': 'ŞİMDİ ABONE OL',
      'paymentUnavailable':
          'Bu sürümde ödeme henüz kullanılamıyor.',
      'paymentNotice':
          'Herhangi bir ödeme alınmaz. Erişim yalnızca sunucu tarafında ödeme doğrulandıktan sonra etkinleştirilir.',
      'month': '/ay',
      'year': '/yıl',
      'once': 'tek seferlik',
      'logout': 'Çıkış yap',
      'logoutQuestion': 'Çıkış yapılsın mı?',
      'logoutConfirm': 'Çıkış yapmak istediğinize emin misiniz?',
      'cancel': 'İptal',
    },
    'en': {
      'title': 'Upgrade to Pro',
      'inactive': 'Access is currently inactive',
      'description':
          'This device currently has no valid trial or active entitlement. The plans are a preview; real payments are not yet connected.',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
      'lifetime': 'Lifetime',
      'device': 'Device',
      'devices': 'Devices',
      'popular': 'Popular',
      'total': 'Total price',
      'subscribe': 'SUBSCRIBE NOW',
      'paymentUnavailable':
          'Payments are not available in this version yet.',
      'paymentNotice':
          'No payment will be charged. Access is activated only after server-side payment confirmation.',
      'month': '/month',
      'year': '/year',
      'once': 'one-time',
      'logout': 'Log out',
      'logoutQuestion': 'Log out?',
      'logoutConfirm': 'Do you really want to log out?',
      'cancel': 'Cancel',
    },
    'ru': {
      'title': 'Перейти на Pro',
      'inactive': 'Доступ сейчас неактивен',
      'description':
          'Для этого устройства нет действующего пробного периода или доступа. Тарифы показаны для ознакомления; оплата пока не подключена.',
      'monthly': 'Месяц',
      'yearly': 'Год',
      'lifetime': 'Навсегда',
      'device': 'Устройство',
      'devices': 'Устройства',
      'popular': 'Популярный',
      'total': 'Итого',
      'subscribe': 'ПОДПИСАТЬСЯ',
      'paymentUnavailable':
          'Оплата пока недоступна в этой версии.',
      'paymentNotice':
          'Платёж не выполняется. Доступ активируется только после подтверждения оплаты на сервере.',
      'month': '/мес.',
      'year': '/год',
      'once': 'один раз',
      'logout': 'Выйти',
      'logoutQuestion': 'Выйти?',
      'logoutConfirm': 'Вы действительно хотите выйти?',
      'cancel': 'Отмена',
    },
    'ar': {
      'title': 'الترقية إلى Pro',
      'inactive': 'الوصول غير نشط حاليًا',
      'description':
          'لا توجد فترة تجريبية صالحة أو صلاحية وصول نشطة لهذا الجهاز. الباقات للمعاينة فقط، ولم يتم ربط الدفع بعد.',
      'monthly': 'شهري',
      'yearly': 'سنوي',
      'lifetime': 'مدى الحياة',
      'device': 'جهاز',
      'devices': 'أجهزة',
      'popular': 'الأكثر شعبية',
      'total': 'السعر الإجمالي',
      'subscribe': 'اشترك الآن',
      'paymentUnavailable':
          'الدفع غير متاح بعد في هذا الإصدار.',
      'paymentNotice':
          'لن يتم تحصيل أي مبلغ. يتم تفعيل الوصول فقط بعد تأكيد الدفع من الخادم.',
      'month': '/شهر',
      'year': '/سنة',
      'once': 'مرة واحدة',
      'logout': 'تسجيل الخروج',
      'logoutQuestion': 'تسجيل الخروج؟',
      'logoutConfirm': 'هل تريد حقًا تسجيل الخروج؟',
      'cancel': 'إلغاء',
    },
    'pl': {
      'title': 'Przejdź na Pro',
      'inactive': 'Dostęp jest obecnie nieaktywny',
      'description':
          'To urządzenie nie ma aktywnego okresu próbnego ani uprawnienia. Plany są podglądem; płatności nie są jeszcze dostępne.',
      'monthly': 'Miesięcznie',
      'yearly': 'Rocznie',
      'lifetime': 'Dożywotnio',
      'device': 'Urządzenie',
      'devices': 'Urządzenia',
      'popular': 'Popularny',
      'total': 'Cena łączna',
      'subscribe': 'SUBSKRYBUJ TERAZ',
      'paymentUnavailable':
          'Płatności nie są jeszcze dostępne w tej wersji.',
      'paymentNotice':
          'Płatność nie zostanie pobrana. Dostęp jest aktywowany dopiero po potwierdzeniu płatności przez serwer.',
      'month': '/mies.',
      'year': '/rok',
      'once': 'jednorazowo',
      'logout': 'Wyloguj',
      'logoutQuestion': 'Wylogować?',
      'logoutConfirm': 'Czy na pewno chcesz się wylogować?',
      'cancel': 'Anuluj',
    },
    'es': {
      'title': 'Actualizar a Pro',
      'inactive': 'El acceso está inactivo',
      'description':
          'Este dispositivo no tiene una prueba válida ni acceso activo. Los planes son una vista previa; los pagos aún no están conectados.',
      'monthly': 'Mensual',
      'yearly': 'Anual',
      'lifetime': 'De por vida',
      'device': 'Dispositivo',
      'devices': 'Dispositivos',
      'popular': 'Popular',
      'total': 'Precio total',
      'subscribe': 'SUSCRIBIRSE',
      'paymentUnavailable':
          'Los pagos aún no están disponibles en esta versión.',
      'paymentNotice':
          'No se realizará ningún cobro. El acceso se activa solo tras confirmar el pago en el servidor.',
      'month': '/mes',
      'year': '/año',
      'once': 'pago único',
      'logout': 'Cerrar sesión',
      'logoutQuestion': '¿Cerrar sesión?',
      'logoutConfirm': '¿Seguro que quieres cerrar sesión?',
      'cancel': 'Cancelar',
    },
    'fr': {
      'title': 'Passer à Pro',
      'inactive': 'Accès actuellement inactif',
      'description':
          'Cet appareil ne dispose pas d’un essai valide ni d’un accès actif. Les offres sont un aperçu ; les paiements ne sont pas encore connectés.',
      'monthly': 'Mensuel',
      'yearly': 'Annuel',
      'lifetime': 'À vie',
      'device': 'Appareil',
      'devices': 'Appareils',
      'popular': 'Populaire',
      'total': 'Prix total',
      'subscribe': "S'ABONNER",
      'paymentUnavailable':
          'Les paiements ne sont pas encore disponibles dans cette version.',
      'paymentNotice':
          'Aucun paiement ne sera effectué. L’accès sera activé uniquement après confirmation du paiement côté serveur.',
      'month': '/mois',
      'year': '/an',
      'once': 'une fois',
      'logout': 'Déconnexion',
      'logoutQuestion': 'Se déconnecter ?',
      'logoutConfirm': 'Voulez-vous vraiment vous déconnecter ?',
      'cancel': 'Annuler',
    },
  };

  String _t(String languageCode, String key) {
    return _translations[languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  String _price(int period, int tier) {
    return _prices[period][tier].toStringAsFixed(2);
  }

  String _priceSuffix(String languageCode) {
    switch (_selectedPeriod) {
      case 0:
        return _t(languageCode, 'month');
      case 1:
        return _t(languageCode, 'year');
      default:
        return _t(languageCode, 'once');
    }
  }

  Future<void> _confirmLogout(String languageCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t(languageCode, 'logoutQuestion')),
        content: Text(_t(languageCode, 'logoutConfirm')),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: Text(_t(languageCode, 'cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: Text(_t(languageCode, 'logout')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  Widget _periodButton(
    String label,
    int index,
  ) {
    final selected = _selectedPeriod == index;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        focusColor:
            AppTheme.electricBlue.withValues(alpha: 0.25),
        onTap: () {
          setState(() {
            _selectedPeriod = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(
            minHeight: 48,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.electricBlue
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.electricBlue,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tierCard(
    int index,
    String languageCode, {
    required bool horizontal,
  }) {
    final selected = _selectedTier == index;
    final colorScheme = Theme.of(context).colorScheme;

    final deviceCount = [1, 3, 5][index];

    final deviceLabel =
        '$deviceCount ${_t(languageCode, deviceCount == 1 ? 'device' : 'devices')}';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        focusColor:
            AppTheme.electricBlue.withValues(alpha: 0.24),
        onTap: () {
          setState(() {
            _selectedTier = index;
          });
        },
        child: Container(
          padding: EdgeInsets.all(horizontal ? 20 : 14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.electricBlue.withValues(alpha: 0.12)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.electricBlue
                  : colorScheme.outline.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: horizontal
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.devices,
                      size: 38,
                      color: selected
                          ? AppTheme.electricBlue
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      deviceLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_price(_selectedPeriod, index)} €',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? AppTheme.electricBlue
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (index == 1) ...[
                      const SizedBox(height: 10),
                      _popularBadge(languageCode),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.devices,
                      size: 28,
                      color: selected
                          ? AppTheme.electricBlue
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceLabel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (index == 1) ...[
                            const SizedBox(height: 5),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _popularBadge(languageCode),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${_price(_selectedPeriod, index)} €',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? AppTheme.electricBlue
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppTheme.electricBlue
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _popularBadge(String languageCode) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _t(languageCode, 'popular'),
        style: const TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        context.watch<LocaleProvider>().locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(languageCode, 'title')),
        actions: [
          IconButton(
            tooltip: _t(languageCode, 'logout'),
            focusColor:
                AppTheme.electricBlue.withValues(alpha: 0.28),
            onPressed: () => _confirmLogout(languageCode),
            icon: const Icon(Icons.logout),
          ),
          // Platz fuer den globalen Theme-Button.
          const SizedBox(width: 52),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700;
            final maxContentWidth =
                horizontal ? 1100.0 : 540.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal ? 32 : 16,
                vertical: horizontal ? 24 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _t(languageCode, 'inactive'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: horizontal ? 28 : 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t(languageCode, 'description'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: horizontal ? 16 : 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Laufzeitwahl
                      LayoutBuilder(
                        builder: (context, periodConstraints) {
                          final narrow =
                              periodConstraints.maxWidth < 340;

                          if (narrow) {
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  _periodButton(
                                    _t(
                                      languageCode,
                                      ['monthly', 'yearly', 'lifetime'][i],
                                    ),
                                    i,
                                  ),
                                  if (i != 2)
                                    const SizedBox(height: 8),
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                Expanded(
                                  child: _periodButton(
                                    _t(
                                      languageCode,
                                      ['monthly', 'yearly', 'lifetime'][i],
                                    ),
                                    i,
                                  ),
                                ),
                                if (i != 2)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      if (horizontal)
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 220,
                                  child: _tierCard(
                                    i,
                                    languageCode,
                                    horizontal: true,
                                  ),
                                ),
                              ),
                              if (i != 2)
                                const SizedBox(width: 16),
                            ],
                          ],
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              SizedBox(
                                width: double.infinity,
                                child: _tierCard(
                                  i,
                                  languageCode,
                                  horizontal: false,
                                ),
                              ),
                              if (i != 2)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),

                      const SizedBox(height: 24),

                      Text(
                        '${_t(languageCode, 'total')}: '
                        '${_price(_selectedPeriod, _selectedTier)} € '
                        '${_priceSuffix(languageCode)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 360,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _t(
                                        languageCode,
                                        'paymentUnavailable',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AppTheme.electricBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                _t(languageCode, 'subscribe'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _t(languageCode, 'paymentNotice'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
