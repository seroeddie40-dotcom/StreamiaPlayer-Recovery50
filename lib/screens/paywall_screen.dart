
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

/// Responsive Pro plan preview for phones, tablets and Android TV.
/// Payments are intentionally not connected yet.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _period = 1;
  int _plan = 1;

  // Preview prices only. Not connected to Supabase or payments.
  static const List<List<double>> _examplePrices = [
    [4.99, 9.99, 14.99],
    [39.99, 79.99, 119.99],
    [149.99, 249.99, 349.99],
  ];

  static const List<String> _planNames = [
    'Starter Pro',
    'Family Pro',
    'Ultimate Pro',
  ];

  static const List<int> _deviceCounts = [1, 3, 5];

  String _text(
    String code,
    String de,
    String tr,
    String en, {
    String? ru,
    String? pl,
    String? es,
    String? fr,
    String? ar,
  }) {
    switch (code) {
      case 'de':
        return de;
      case 'tr':
        return tr;
      case 'ru':
        return ru ?? en;
      case 'pl':
        return pl ?? en;
      case 'es':
        return es ?? en;
      case 'fr':
        return fr ?? en;
      case 'ar':
        return ar ?? en;
      default:
        return en;
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _selectPlan(int index) {
    HapticFeedback.selectionClick();
    setState(() => _plan = index);
  }

  void _selectPeriod(int index) {
    HapticFeedback.selectionClick();
    setState(() => _period = index);
  }

  void _showPaymentUnavailable(String code) {
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(
            code,
            'Käufe sind noch nicht freigeschaltet.',
            'Satın alma henüz etkin değil.',
            'Purchases are not enabled yet.',
            ru: 'Покупки пока недоступны.',
            pl: 'Zakupy nie są jeszcze dostępne.',
            es: 'Las compras aún no están disponibles.',
            fr: 'Les achats ne sont pas encore disponibles.',
            ar: 'عمليات الشراء غير متاحة بعد.',
          ),
        ),
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required String code,
    required int index,
    required List<String> features,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _plan == index;
    final count = _deviceCounts[index];

    final deviceLabel = _text(
      code,
      count == 1 ? 'Gerät' : 'Geräte',
      'cihaz',
      count == 1 ? 'device' : 'devices',
      ru: count == 1 ? 'устройство' : 'устройств',
      pl: count == 1 ? 'urządzenie' : 'urządzenia',
      es: count == 1 ? 'dispositivo' : 'dispositivos',
      fr: count == 1 ? 'appareil' : 'appareils',
      ar: 'أجهزة',
    );

    final price = _examplePrices[_period][index];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 3 : 0,
      color: selected
          ? scheme.primaryContainer
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? scheme.primary
              : scheme.outlineVariant,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectPlan(index),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: scheme.primary,
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.verified,
                      color: scheme.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _planNames[index],
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$count $deviceLabel',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '${price.toStringAsFixed(2)} €*',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected ? scheme.onPrimaryContainer : scheme.primary,
                    ),
              ),
              const Divider(height: 28),
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          softWrap: true,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: selected
                    ? FilledButton.icon(
                        onPressed: () =>
                            _selectPlan(index),
                        icon: const Icon(
                          Icons.check_circle_outline,
                        ),
                        label: Text(
                          _text(
                            code,
                            'Ausgewählt',
                            'Seçildi',
                            'Selected',
                            ru: 'Выбрано',
                            pl: 'Wybrano',
                            es: 'Seleccionado',
                            fr: 'Sélectionné',
                            ar: 'تم الاختيار',
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () =>
                            _selectPlan(index),
                        child: Text(
                          _text(
                            code,
                            'Auswählen',
                            'Seç',
                            'Select',
                            ru: 'Выбрать',
                            pl: 'Wybierz',
                            es: 'Seleccionar',
                            fr: 'Choisir',
                            ar: 'اختيار',
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code =
        context.watch<LocaleProvider>().locale.languageCode;
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final canGoBack = Navigator.of(context).canPop();

    final periods = [
      _text(
        code,
        'Monatlich',
        'Aylık',
        'Monthly',
        ru: 'Ежемесячно',
        pl: 'Miesięcznie',
        es: 'Mensual',
        fr: 'Mensuel',
        ar: 'شهرياً',
      ),
      _text(
        code,
        'Jährlich',
        'Yıllık',
        'Yearly',
        ru: 'Ежегодно',
        pl: 'Rocznie',
        es: 'Anual',
        fr: 'Annuel',
        ar: 'سنوياً',
      ),
      _text(
        code,
        'Lebenslang',
        'Ömür boyu',
        'Lifetime',
        ru: 'Навсегда',
        pl: 'Dożywotnio',
        es: 'De por vida',
        fr: 'À vie',
        ar: 'مدى الحياة',
      ),
    ];

    final features = [
      _text(
        code,
        'Live-TV, Filme und Serien',
        'Canlı TV, film ve diziler',
        'Live TV, movies and series',
        ru: 'ТВ, фильмы и сериалы',
        pl: 'Telewizja, filmy i seriale',
        es: 'TV, películas y series',
        fr: 'TV, films et séries',
        ar: 'البث المباشر والأفلام والمسلسلات',
      ),
      _text(
        code,
        'M3U und Xtream',
        'M3U ve Xtream',
        'M3U and Xtream',
        ru: 'M3U и Xtream',
        pl: 'M3U i Xtream',
        es: 'M3U y Xtream',
        fr: 'M3U et Xtream',
        ar: 'M3U وXtream',
      ),
      _text(
        code,
        'Favoriten und Wiedergabeverlauf',
        'Favoriler ve izleme geçmişi',
        'Favorites and watch history',
        ru: 'Избранное и история',
        pl: 'Ulubione i historia',
        es: 'Favoritos e historial',
        fr: 'Favoris et historique',
        ar: 'المفضلة وسجل المشاهدة',
      ),
      _text(
        code,
        'Android TV und Fernbedienung',
        'Android TV ve kumanda',
        'Android TV and remote control',
        ru: 'Android TV и пульт',
        pl: 'Android TV i pilot',
        es: 'Android TV y mando',
        fr: 'Android TV et télécommande',
        ar: 'Android TV وجهاز التحكم',
      ),
    ];

    return PopScope(
      canPop: canGoBack,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: canGoBack
              ? IconButton(
                  autofocus: true,
                  tooltip: _text(
                    code,
                    'Zurück',
                    'Geri',
                    'Back',
                  ),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            _text(
              code,
              'Pro-Pakete',
              'Pro paketleri',
              'Pro plans',
              ru: 'Тарифы Pro',
              pl: 'Pakiety Pro',
              es: 'Planes Pro',
              fr: 'Offres Pro',
              ar: 'باقات Pro',
            ),
          ),
          actions: [
            if (!canGoBack)
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: Text(
                  _text(
                    code,
                    'Abmelden',
                    'Çıkış',
                    'Log out',
                    ru: 'Выйти',
                    pl: 'Wyloguj',
                    es: 'Salir',
                    fr: 'Déconnexion',
                    ar: 'تسجيل الخروج',
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth =
                  constraints.maxWidth;
              final threeColumns =
                  availableWidth >= 720;

              return Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 1200),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    children: [
                      Text(
                        _text(
                          code,
                          'Wähle dein Pro-Paket',
                          'Pro paketini seç',
                          'Choose your Pro plan',
                          ru: 'Выберите тариф Pro',
                          pl: 'Wybierz pakiet Pro',
                          es: 'Elige tu plan Pro',
                          fr: 'Choisissez votre offre Pro',
                          ar: 'اختر باقة Pro',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        auth.hasAccess
                            ? _text(
                                code,
                                'Dein aktueller Zugang bleibt aktiv.',
                                'Mevcut erişimin aktif kalır.',
                                'Your current access remains active.',
                                ru: 'Ваш доступ остаётся активным.',
                                pl: 'Twój dostęp pozostaje aktywny.',
                                es: 'Tu acceso sigue activo.',
                                fr: 'Votre accès reste actif.',
                                ar: 'سيظل وصولك الحالي نشطاً.',
                              )
                            : _text(
                                code,
                                'Für weiteren Zugriff ist ein Pro-Tarif erforderlich.',
                                'Erişime devam etmek için Pro paketi gerekir.',
                                'A Pro plan is required to continue.',
                                ru: 'Для продолжения нужен тариф Pro.',
                                pl: 'Aby kontynuować, potrzebujesz pakietu Pro.',
                                es: 'Necesitas un plan Pro para continuar.',
                                fr: 'Une offre Pro est nécessaire pour continuer.',
                                ar: 'يلزم اشتراك Pro للمتابعة.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _text(
                          code,
                          'Tarifvorschau: Alle Beträge sind Beispielpreise.',
                          'Paket önizlemesi: Tüm tutarlar örnek fiyattır.',
                          'Plan preview: All prices are examples.',
                          ru: 'Предпросмотр: цены приведены для примера.',
                          pl: 'Podgląd: ceny są przykładowe.',
                          es: 'Vista previa: precios de ejemplo.',
                          fr: 'Aperçu : prix indicatifs.',
                          ar: 'معاينة الباقات: الأسعار توضيحية.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            3,
                            (index) => ChoiceChip(
                              label: Text(periods[index]),
                              selected: _period == index,
                              onSelected: (_) =>
                                  _selectPeriod(index),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (threeColumns)
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            for (var index = 0;
                                index < 3;
                                index++) ...[
                              if (index > 0)
                                const SizedBox(width: 12),
                              Expanded(
                                child: _planCard(
                                  context: context,
                                  code: code,
                                  index: index,
                                  features: features,
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Column(
                          children: [
                            for (var index = 0;
                                index < 3;
                                index++) ...[
                              _planCard(
                                context: context,
                                code: code,
                                index: index,
                                features: features,
                              ),
                              if (index < 2)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text(
                        '${_planNames[_plan]} · '
                        '${periods[_period]} · '
                        '${_examplePrices[_period][_plan].toStringAsFixed(2)} €*',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _text(
                          code,
                          '* Beispielpreise. Der Zahlungsanbieter ist noch nicht verbunden. Es erfolgt keine Abbuchung.',
                          '* Örnek fiyatlar. Ödeme sağlayıcısı henüz bağlı değil. Ücret alınmaz.',
                          '* Example prices. Payments are not connected. No charge will be made.',
                          ru: '* Цены примерные. Оплата пока недоступна. Списаний нет.',
                          pl: '* Ceny przykładowe. Płatności nie są podłączone.',
                          es: '* Precios de ejemplo. Los pagos no están disponibles.',
                          fr: '* Prix indicatifs. Les paiements ne sont pas disponibles.',
                          ar: '* الأسعار توضيحية. الدفع غير متاح حالياً.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _showPaymentUnavailable(code),
                          icon: const Icon(
                            Icons.info_outline,
                          ),
                          label: Text(
                            _text(
                              code,
                              'Zahlung noch nicht verfügbar',
                              'Ödeme henüz kullanılamıyor',
                              'Payment not available yet',
                              ru: 'Оплата пока недоступна',
                              pl: 'Płatność niedostępna',
                              es: 'Pago no disponible',
                              fr: 'Paiement indisponible',
                              ar: 'الدفع غير متاح حالياً',
                            ),
                          ),
                        ),
                      ),
                      if (canGoBack) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                            ),
                            label: Text(
                              _text(
                                code,
                                'Zurück zum Dashboard',
                                'Panele geri dön',
                                'Back to dashboard',
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
