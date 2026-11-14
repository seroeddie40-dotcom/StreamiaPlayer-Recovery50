import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/focus_navigation.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'live_tv_screen.dart';
import 'downloads_screen.dart';
import 'master_search_screen.dart';
import 'paywall_screen.dart';
import 'recordings_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'vod_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _label(
    BuildContext context,
    String de,
    String tr,
    String en,
  ) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'de') return de;
    if (language == 'tr') return tr;
    return en;
  }

  String _recordingsLabel(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de': return 'Aufnahmen';
      case 'tr': return 'Kayıtlar';
      case 'ru': return 'Записи';
      case 'pl': return 'Nagrania';
      case 'es': return 'Grabaciones';
      case 'fr': return 'Enregistrements';
      case 'ar': return 'التسجيلات';
      default: return 'Recordings';
    }
  }

  String _downloadsLabel(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'de': return 'Downloads';
      case 'tr': return 'İndirilenler';
      case 'ru': return 'Загрузки';
      case 'pl': return 'Pobrane';
      case 'es': return 'Descargas';
      case 'fr': return 'Téléchargements';
      case 'ar': return 'التنزيلات';
      default: return 'Downloads';
    }
  }

  // All trial dates are issued by Supabase, never by the device.
  DateTime? _trialExpiry(AuthProvider auth) {
    final raw = auth.access?['trial_ends_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  String _trialText(BuildContext context, int days) {
    final code = Localizations.localeOf(context).languageCode;
    final remaining = days < 1 ? 1 : days;
    switch (code) {
      case 'de': return 'Noch $remaining ${remaining == 1 ? 'Tag' : 'Tage'} Testphase';
      case 'tr': return 'Deneme süresinde $remaining gün kaldı';
      case 'ru': return 'Пробный период: осталось $remaining дн.';
      case 'pl': return 'Pozostało $remaining dni okresu próbnego';
      case 'es': return 'Quedan $remaining días de prueba';
      case 'fr': return 'Essai : encore $remaining jours';
      case 'ar': return 'متبقٍ $remaining يوم من الفترة التجريبية';
      default: return '$remaining ${remaining == 1 ? 'day' : 'days'} left in trial';
    }
  }

  void _open(Widget screen) {
    pushWithFocusRestore(
      context,
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final trialExpiry = _trialExpiry(auth);
    final now = DateTime.now().toUtc();
    final trialActive = auth.hasAccountAccess &&
        auth.access?['access_status'] == 'trial' &&
        auth.access?['entitlement_source'] == 'trial' &&
        trialExpiry != null && trialExpiry.isAfter(now);
    final trialDaysLeft = trialActive
        ? (trialExpiry.difference(now).inSeconds / 86400).ceil()
        : 0;
    // No promotional trial claim for a paid or admin-enabled account.
    final showTrialCard = auth.isLoggedIn && auth.accessChecked &&
        (trialActive || !auth.hasAccountAccess);


    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;

    // Pro is available during the trial as well.
    final showPro = auth.isLoggedIn;

    final entries = <_HomeEntry>[
      _HomeEntry(
        Icons.live_tv_rounded,
        l10n.t('nav_live'),
        () => _open(const LiveTvScreen()),
      ),
      _HomeEntry(
        Icons.movie_creation_outlined,
        l10n.t('nav_vod'),
        () => _open(const VodScreen()),
      ),
      _HomeEntry(
        Icons.video_library_outlined,
        l10n.t('nav_series'),
        () => _open(const SeriesScreen()),
      ),
      _HomeEntry(
        Icons.download_for_offline_outlined,
        _downloadsLabel(context),
        () => _open(const DownloadsScreen()),
      ),
      _HomeEntry(
        Icons.fiber_manual_record_rounded,
        _recordingsLabel(context),
        () => _open(const RecordingsScreen()),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 36,
                12,
                compact ? 12 : 36,
                8,
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 40 : 52,
                    height: compact ? 40 : 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('app_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 17 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (showPro) ...[
                    _ProButton(
                      label: l10n.t('nav_pro'),
                      onTap: () => _open(const PaywallScreen()),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: _label(
                      context,
                      'Suche',
                      'Ara',
                      'Search',
                    ),
                    onPressed: () =>
                        _open(const MasterSearchScreen()),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: _label(
                      context,
                      'Design wechseln',
                      'Temayı değiştir',
                      'Change theme',
                    ),
                    onPressed: () =>
                        context.read<ThemeProvider>().toggleTheme(),
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: _label(
                      context,
                      'Einstellungen',
                      'Ayarlar',
                      'Settings',
                    ),
                    onPressed: () =>
                        _open(const SettingsScreen()),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final horizontal = width < 600 ? 16.0 : 36.0;

                  final int columns;
                  if (width < 380) {
                    columns = 1;
                  } else if (width < 650) {
                    columns = 2;
                  } else {
                    columns = 3;
                  }

                  final double aspectRatio;
                  if (columns == 1) {
                    aspectRatio = 3.2;
                  } else if (columns == 2) {
                    aspectRatio = 1.45;
                  } else {
                    aspectRatio = width >= 1100 ? 2.05 : 1.6;
                  }

                  return FocusTraversalGroup(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            18,
                            horizontal,
                            12,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (showTrialCard)
                                  _TrialInfoCard(
                                    title: trialActive
                                        ? _trialText(context, trialDaysLeft)
                                        : _label(
                                            context,
                                            'Streamia Pro entdecken',
                                            'Streamia Pro paketlerini keşfet',
                                            'Explore Streamia Pro',
                                          ),
                                    subtitle: trialActive
                                        ? _label(
                                            context,
                                            '1 Gerät · Testphase aktiv',
                                            '1 cihaz · Deneme aktif',
                                            '1 device · Trial active',
                                          )
                                        : _label(
                                            context,
                                            'Tarife für 1, 3 oder 5 Geräte ansehen',
                                            '1, 3 veya 5 cihazlık paketler',
                                            'View plans for 1, 3 or 5 devices',
                                          ),
                                    actionLabel: _label(
                                      context,
                                      'Pro-Tarife',
                                      'Pro paketleri',
                                      'Pro plans',
                                    ),
                                    onTap: () =>
                                        _open(const PaywallScreen()),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            8,
                            horizontal,
                            28,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _PremiumTile(
                                entry: entries[index],
                                autofocus: index == 0,
                              ),
                              childCount: entries.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: aspectRatio,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEntry {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HomeEntry(
    this.icon,
    this.title,
    this.onTap,
  );
}

class _TrialInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _TrialInfoCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        focusColor: AppTheme.electricBlue.withOpacity(0.25),
        child: Ink(
          decoration: BoxDecoration(
            color: dark
                ? AppTheme.darkSurface
                : const Color(0xFFE6EDF2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.electricBlue.withOpacity(0.28),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: AppTheme.electricBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: actionLabel,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.electricBlue,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        focusColor: AppTheme.electricBlue.withOpacity(0.25),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTile extends StatelessWidget {
  final _HomeEntry entry;
  final bool autofocus;

  const _PremiumTile({
    required this.entry,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        autofocus: autofocus,
        onTap: entry.onTap,
        focusColor: AppTheme.electricBlue.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.electricBlue.withOpacity(0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.electricBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    entry.icon,
                    size: 24,
                    color: AppTheme.electricBlue,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
