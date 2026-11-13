
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

/// Scrollable Pro screen for mobile and Android TV.
/// Purchases are not yet connected.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _period = 1;
  int _plan = 1;

  // Example prices only, not live Supabase prices.
  static const _examplePrices = <List<double>>[
    [4.99, 9.99, 14.99],
    [39.99, 79.99, 119.99],
    [149.99, 249.99, 349.99],
  ];

  String _label(
    String code,
    String de,
    String tr,
    String en,
  ) {
    if (code == 'de') return de;
    if (code == 'tr') return tr;
    return en;
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code =
        context.watch<LocaleProvider>().locale.languageCode;
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final canGoBack = Navigator.of(context).canPop();

    final names = [
      'Starter Pro',
      'Family Pro',
      'Ultimate Pro',
    ];

    final counts = [1, 3, 5];

    final periods = [
      _label(code, 'Monatlich', 'Aylık', 'Monthly'),
      _label(code, 'Jährlich', 'Yıllık', 'Yearly'),
      _label(code, 'Lebenslang', 'Ömür boyu', 'Lifetime'),
    ];

    final features = [
      _label(
        code,
        'Live-TV, Filme und Serien',
        'Canlı TV, film ve diziler',
        'Live TV, movies and series',
      ),
      _label(
        code,
        'M3U und Xtream',
        'M3U ve Xtream',
        'M3U and Xtream',
      ),
      _label(
        code,
        'Favoriten und Wiedergabeverlauf',
        'Favoriler ve izleme geçmişi',
        'Favorites and watch history',
      ),
      _label(
        code,
        'Android TV und Fernbedienung',
        'Android TV ve kumanda',
        'Android TV and remote control',
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
                  tooltip: _label(
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
            _label(
              code,
              'Pro-Pakete',
              'Pro paketleri',
              'Pro plans',
            ),
          ),
          actions: [
            if (!canGoBack)
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: Text(
                  _label(
                    code,
                    'Abmelden',
                    'Çıkış',
                    'Log out',
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                children: [
                  Text(
                    _label(
                      code,
                      'Wähle dein Pro-Paket',
                      'Pro paketini seç',
                      'Choose your Pro plan',
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
                        ? _label(
                            code,
                            'Dein aktueller Zugang bleibt aktiv.',
                            'Mevcut erişimin aktif kalır.',
                            'Your current access remains active.',
                          )
                        : _label(
                            code,
                            'Für weiteren Zugriff ist ein Pro-Tarif erforderlich.',
                            'Erişime devam etmek için Pro paketi gerekir.',
                            'A Pro plan is required to continue.',
                          ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _label(
                      code,
                      'Tarifvorschau: Alle Beträge sind Beispielpreise, keine verbindlichen Angebote.',
                      'Paket önizlemesi: Tüm tutarlar örnek fiyattır, kesin teklif değildir.',
                      'Plan preview: All amounts are examples, not final offers.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      3,
                      (index) => ChoiceChip(
                        label: Text(periods[index]),
                        selected: _period == index,
                        onSelected: (_) {
                          setState(() => _period = index);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(3, (index) {
                    final selected = _plan == index;

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() => _plan = index);
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        names[index],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${counts[index]} ${counts[index] == 1 ? _label(code, 'Gerät', 'cihaz', 'device') : _label(code, 'Geräte', 'cihaz', 'devices')}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 10),
                                ...features.map(
                                  (feature) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check,
                                          size: 18,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(feature),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${_examplePrices[_period][index].toStringAsFixed(2)} €*',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    '${names[_plan]} · ${periods[_period]} · ${_examplePrices[_period][_plan].toStringAsFixed(2)} €*',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _label(
                      code,
                      '* Beispielpreise. Der Zahlungsanbieter ist noch nicht verbunden. Es erfolgt keine Abbuchung.',
                      '* Örnek fiyatlar. Ödeme sağlayıcısı henüz bağlı değil. Ücret alınmaz.',
                      '* Example prices. Payments are not connected. No charge will be made.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            _label(
                              code,
                              'Käufe sind noch nicht freigeschaltet.',
                              'Satın alma henüz etkin değil.',
                              'Purchases are not enabled yet.',
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: Text(
                      _label(
                        code,
                        'Zahlung noch nicht verfügbar',
                        'Ödeme henüz kullanılamıyor',
                        'Payment not available yet',
                      ),
                    ),
                  ),
                  if (canGoBack) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        _label(
                          code,
                          'Zurück zum Dashboard',
                          'Panele geri dön',
                          'Back to dashboard',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
